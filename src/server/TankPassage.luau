--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.TankPassage
-- Props in the hex-tank yard do not collide with players. Plaza walls still do.
-- A thin red bar marks the line between zone 0 and zone 1.

local PhysicsService = game:GetService("PhysicsService")
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)

local Passage = {}
local GROUP = "TankProp"

local function findZone(root: Instance, name: string): Instance?
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = habitats and habitats:FindFirstChild(name)
	if zone then
		return zone
	end
	return root:FindFirstChild(name)
end

local function prepareGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
	for slot = 1, MapConfig.PlayerSlots do
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(GROUP, "LaneOwner" .. slot, false)
			PhysicsService:CollisionGroupSetCollidable(GROUP, "Lane" .. slot, false)
		end)
	end
end

local function isWall(part: BasePart): boolean
	if string.find(part.Name, "Wall", 1, true) then
		return true
	end
	local parent = part.Parent
	while parent and parent ~= workspace do
		if parent.Name == "PlazaWalls" or string.find(parent.Name, "Wall", 1, true) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function isFloor(part: BasePart): boolean
	return part.Name == "CheckerTile"
		or part.Name == "PathTile"
		or part.Name == "SandBottom"
		or (part.Parent ~= nil and string.sub(part.Parent.Name, 1, 7) == "TileRow")
end

function Passage.start(root: Instance)
	prepareGroup()
	local half = MapConfig.PlazaSize / 2 - 4
	local mouth = MapConfig.RouteStart - 2
	for _, inst in root:GetDescendants() do
		if not inst:IsA("BasePart") or isWall(inst) or isFloor(inst) then
			continue
		end
		local pos = inst.Position
		if math.abs(pos.X) < half and pos.Z < mouth and pos.Z > -half then
			inst.CollisionGroup = GROUP
		end
	end

	local zone1 = findZone(root, "Zone01")
	local zone0 = findZone(root, "Zone00")
	local boundary = zone1 and zone1:GetAttribute("StartZ")
	if typeof(boundary) ~= "number" then
		boundary = zone0 and zone0:GetAttribute("EndZ")
	end
	if typeof(boundary) ~= "number" then
		return
	end
	local old = root:FindFirstChild("ZoneSplitBar")
	if old then
		old:Destroy()
	end
	local bar = Instance.new("Part")
	bar.Name = "ZoneSplitBar"
	-- A neon strip on the floor. Tall enough to read, short enough to step over in the eye line.
	local height = 0.15
	bar.Size = Vector3.new(MapConfig.RoadWidth, height, 0.35)
	bar.CFrame = CFrame.new(0, height / 2, boundary)
	bar.Color = Color3.fromRGB(255, 42, 48)
	bar.Material = Enum.Material.Neon
	bar.Anchored = true
	bar.CanCollide = false
	bar.CanTouch = false
	bar.CanQuery = false
	bar.CastShadow = false
	bar.Parent = root
end

return Passage
