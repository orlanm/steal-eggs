--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Boats
-- Shop vehicles (ShopConfig.Vehicles): owners (player attribute OwnsBoat, from SpeedDataManager) get a
-- "Fishing Boat" Tool in the hotbar. Equipping it in the water spawns their boat
-- (ServerStorage.FishingBoat, built from _blender/fishing_boat.py) at the surface and seats them on the
-- red chair. Putting the Tool away (or dying / leaving) removes the boat. The owner's client drives it
-- (Boats.client) through network ownership while they sit; jumping up lets them walk the deck (inside
-- the template's invisible BoatBarrier walls) and BoatSit seats them again when they walk up to the chair.
-- Admin: ;vehicle <me|all|name> [Boat] gives a vehicle for free (testing).
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)
local ShopConfig = require(Shared.ShopConfig)
local AdminEggs = require(script.Parent.AdminEggs)
local SpeedData = require(script.Parent.SpeedDataManager)

local VEHICLE = ShopConfig.vehicle("Boat") :: ShopConfig.Vehicle
local TEMPLATE = ServerStorage:WaitForChild("FishingBoat") :: Model
local SEAT_BACK = 8.9 -- the chair sits this far behind the boat's centre (studs)
local SIT_RANGE = 6 -- studs from the chair a BoatSit request may come from

-- The map's invisible WaterWalkSupport slabs (players run on the water) sit just under the surface,
-- where the hull floats: boats pass through them, everything else still stands on them.
PhysicsService:RegisterCollisionGroup("BoatHull")
PhysicsService:RegisterCollisionGroup("WaterWalk")
PhysicsService:CollisionGroupSetCollidable("BoatHull", "WaterWalk", false)
for _, part in Workspace:GetDescendants() do
	if part.Name == "WaterWalkSupport" and part:IsA("BasePart") then
		part.CollisionGroup = "WaterWalk"
	end
end

local folder = Workspace:FindFirstChild("Boats") or Instance.new("Folder")
folder.Name = "Boats"
folder.Parent = Workspace

local sitRemote = GameUI.remote("BoatSit")
local boats: { [Player]: Model } = {}

local function tell(player: Player, text: string)
	GameUI.remote("EggAnnouncement"):FireClient(player, { text = text, color = Color3.fromRGB(255, 110, 110) })
end

local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.FilterDescendantsInstances = { Workspace.Terrain }
waterParams.IgnoreWater = false

-- Height of the terrain water surface at this spot, if there is water there.
local function waterSurface(position: Vector3): number?
	local hit = Workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), waterParams)
	if hit and hit.Material == Enum.Material.Water then
		return hit.Position.Y
	end
	return nil
end

local function isVehicleTool(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute("Vehicle") == VEHICLE.Id
end

local function despawn(player: Player)
	local boat = boats[player]
	boats[player] = nil
	if boat then
		boat:Destroy()
	end
end

local function sit(player: Player, boat: Model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = boat:FindFirstChild("Seat") :: Seat?
	if humanoid and humanoid.Health > 0 and seat and not seat.Occupant then
		seat:Sit(humanoid)
	end
end

local function launch(player: Player, tool: Tool)
	local character = tool.Parent :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and rootPart) then
		return
	end
	local surface = waterSurface(rootPart.Position)
	local inWater = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or (surface ~= nil and rootPart.Position.Y - surface < 6) -- swimming, or running on WaterWalkSupport
	if not (surface and inWater) then
		tell(player, "Jump in the water to launch your " .. VEHICLE.Name .. "!")
		task.defer(function()
			if tool.Parent == character then
				humanoid:UnequipTools()
			end
		end)
		return
	end
	despawn(player)
	local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	local heading = if look.Magnitude > 0.01 then math.atan2(-look.X, -look.Z) else 0
	local yaw = CFrame.Angles(0, heading, 0)
	local boat = TEMPLATE:Clone()
	boat.Name = player.Name .. "_Boat"
	boat:SetAttribute("Owner", player.UserId)
	for _, part in boat:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "BoatHull"
		end
	end
	-- the chair lands where the player is swimming
	boat:PivotTo(CFrame.new(rootPart.Position.X, surface, rootPart.Position.Z) * yaw * CFrame.new(0, 0, -SEAT_BACK))
	local root = boat.PrimaryPart :: BasePart
	local upright = root:FindFirstChild("Upright") :: AlignOrientation
	upright.CFrame = yaw
	boat.Parent = folder
	boats[player] = boat
	root:SetNetworkOwner(player)
	sit(player, boat)
end

local function giveTool(player: Player)
	if player:GetAttribute("Owns" .. VEHICLE.Id) ~= true then
		return
	end
	local function has(parent: Instance?): boolean
		if parent then
			for _, inst in parent:GetChildren() do
				if isVehicleTool(inst) then
					return true
				end
			end
		end
		return false
	end
	local function make(parent: Instance)
		local tool = Instance.new("Tool")
		tool.Name = VEHICLE.Name
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		tool.TextureId = VEHICLE.Image
		tool.ToolTip = "Equip in the water to sail"
		tool:SetAttribute("Vehicle", VEHICLE.Id)
		tool.Parent = parent
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not has(backpack) and not has(player.Character) then
		make(backpack)
	end
end

local function watchCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if isVehicleTool(child) then
			launch(player, child :: Tool)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if isVehicleTool(child) then
			despawn(player)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			despawn(player)
		end)
	end
	-- every spawn gets a fresh Backpack
	player:WaitForChild("Backpack", 10)
	giveTool(player)
end

sitRemote.OnServerEvent:Connect(function(player: Player)
	local boat = boats[player]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local seat = boat and boat:FindFirstChild("Seat") :: Seat?
	if boat and rootPart and seat and (rootPart.Position - seat.Position).Magnitude < SIT_RANGE then
		sit(player, boat)
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		despawn(player)
	end)
	player:GetAttributeChangedSignal("Owns" .. VEHICLE.Id):Connect(function()
		giveTool(player)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

AdminEggs.command("vehicle", ";vehicle <me|all|name> [Boat]: give a shop vehicle", function(caller, words)
	local vehicle = ShopConfig.vehicle(words[2] or VEHICLE.Id)
	if not vehicle then
		return "unknown vehicle " .. tostring(words[2])
	end
	local list = AdminEggs.targets(caller, words[1] or "me")
	for _, player in list do
		SpeedData.grantPass(player, vehicle.Id, true)
	end
	return string.format("gave %s to %d player(s)", vehicle.Name, #list)
end)

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(despawn)
