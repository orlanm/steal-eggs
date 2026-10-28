--!strict
-- Place a carried egg or held pet where you click (mouse) or tap (touch) inside your own pen. The server
-- puts it on that point, or the nearest free spot if a pet is there (TankBeasts PlaceEgg / PenPets Place). A marker follows the cursor
-- over the pen and a hint says what to do. Also hides the Hatch! prompt on other players' eggs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)

local player = Players.LocalPlayer
local placeRemote = GameUI.remote("PlaceEgg")
local petsRemote = GameUI.remote("PenPets")
local HINT_RANGE = 40 -- studs outside the fence where the hint starts showing

local function ownTank(): Instance?
	local slot = player:GetAttribute("TankSlot")
	local map = Workspace:FindFirstChild("BabyBeastsMap")
	local tanks = map and map:FindFirstChild("PlayerTanks")
	if not tanks or typeof(slot) ~= "number" then
		return nil
	end
	return tanks:FindFirstChild("Tank" .. slot)
end

local function heldEgg(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild("BabyBeast")
	return if tool and tool:IsA("Tool") then tool else nil
end

-- an unequipped pet Tool (TankBeasts syncPetTools) in the player's hands
local function heldPet(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("PetTool") == true then tool else nil
end

local function penBox(tank: Instance): (Vector3?, number?)
	local center = tank:GetAttribute("Center")
	local half = tank:GetAttribute("HalfSize")
	if typeof(center) ~= "Vector3" or typeof(half) ~= "number" then
		return nil, nil
	end
	return center, half
end

-- marker under the cursor
local marker = Instance.new("Part")
marker.Name = "EggPlaceMarker"
marker.Shape = Enum.PartType.Cylinder
marker.Size = Vector3.new(0.2, 5, 5)
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.CastShadow = false
marker.Material = Enum.Material.Neon
marker.Color = Color3.fromRGB(120, 255, 160)
marker.Transparency = 0.45

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function penPoint(ray: Ray, tank: Instance): Vector3?
	local ignore: { Instance } = { marker }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "LocalCaveBubbleVisuals" } do
		local inst = Workspace:FindFirstChild(name)
		if inst then
			table.insert(ignore, inst)
		end
	end
	local map = Workspace:FindFirstChild("BabyBeastsMap")
	local pets = map and map:FindFirstChild("TankBeasts")
	if pets then
		table.insert(ignore, pets)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	if not hit then
		return nil
	end
	local center, half = penBox(tank)
	if not center or not half then
		return nil
	end
	local p = hit.Position
	if math.abs(p.X - center.X) > half or math.abs(p.Z - center.Z) > half then
		return nil
	end
	return p
end

-- hint banner
local gui = Instance.new("ScreenGui")
gui.Name = "EggPlaceHint"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -120)
hint.Size = UDim2.fromOffset(460, 40)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.BuilderSansExtraBold
hint.TextScaled = true
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Visible = false
hint.Parent = gui
local hintStroke = Instance.new("UIStroke")
hintStroke.Thickness = 2.5
hintStroke.Color = Color3.fromRGB(20, 20, 24)
hintStroke.Parent = hint

local lastPlace = 0
local function place(ray: Ray)
	local tank = ownTank()
	local egg, pet = heldEgg(), heldPet()
	if not tank or not (egg or pet) or os.clock() - lastPlace < 0.4 then
		return
	end
	local point = penPoint(ray, tank)
	if point then
		lastPlace = os.clock()
		if egg then
			placeRemote:FireServer(point)
		else
			petsRemote:FireServer("Place", point)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local at = UserInputService:GetMouseLocation()
	place(Workspace.CurrentCamera:ViewportPointToRay(at.X, at.Y))
end)

-- A tap (not a camera drag) on touch screens. Not TouchTapInWorld: while a Tool is in your hands the
-- tap goes to the Tool and arrives as already processed, so a held pet / egg was never placed.
-- Instead: a short touch that barely moved and didn't start on a button (thumbstick, jump, HUD).
local TAP_TIME, TAP_MOVE = 0.4, 14
local touches: { [InputObject]: { at: Vector2, t: number } } = {}

local function onButton(at: Vector2): boolean
	for _, obj in player.PlayerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
		if obj.Visible and (obj:IsA("GuiButton") or obj:IsA("TextBox") or obj:IsA("ScrollingFrame") or obj.Active) then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if not onButton(at) then
			touches[input] = { at = at, t = os.clock() }
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local start = touches[input]
	touches[input] = nil
	if not start or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local at = Vector2.new(input.Position.X, input.Position.Y)
	if os.clock() - start.t <= TAP_TIME and (at - start.at).Magnitude <= TAP_MOVE then
		-- touch positions are in GUI space (below the top bar inset): ScreenPointToRay
		place(Workspace.CurrentCamera:ScreenPointToRay(at.X, at.Y))
	end
end)

-- The Roblox hotbar is hidden while you hold a pet (it's placed by tapping the pen, not picked there)
local hotbarHidden = false
local function setHotbar(pet: Tool?)
	if (pet ~= nil) ~= hotbarHidden then
		hotbarHidden = pet ~= nil
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, not hotbarHidden)
	end
end

RunService.RenderStepped:Connect(function()
	local tank = ownTank()
	local egg = heldEgg()
	local pet = heldPet()
	setHotbar(pet)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local center: Vector3?, half: number? = nil, nil
	if tank then
		center, half = penBox(tank)
	end
	local near = (egg ~= nil or pet ~= nil)
		and hrp ~= nil
		and hrp:IsA("BasePart")
		and center ~= nil
		and half ~= nil
		and math.abs(hrp.Position.X - center.X) <= half + HINT_RANGE
		and math.abs(hrp.Position.Z - center.Z) <= half + HINT_RANGE
	hint.Visible = near
	if not near or not tank then
		marker.Parent = nil
		return
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local what = if egg then "egg" else "pet"
	hint.Text = (if touch then "Tap" else "Click") .. " a spot in your pen to place your " .. what
	if touch then
		marker.Parent = nil
		return
	end
	local at = UserInputService:GetMouseLocation()
	local point = penPoint(Workspace.CurrentCamera:ViewportPointToRay(at.X, at.Y), tank)
	if point then
		marker.CFrame = CFrame.new(point + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		marker.Parent = Workspace
	else
		marker.Parent = nil
	end
end)

-- Hatch! is for the egg's owner only
local function watchPrompt(inst: Instance)
	if not (inst:IsA("ProximityPrompt") and inst.Name == "HatchPrompt") then
		return
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	local owner = model and model:GetAttribute("OwnerUserId")
	if owner ~= player.UserId then
		inst.Enabled = false
	end
end

task.spawn(function()
	local map = Workspace:WaitForChild("BabyBeastsMap", 30)
	if not map then
		return
	end
	for _, inst in map:GetDescendants() do
		watchPrompt(inst)
	end
	map.DescendantAdded:Connect(watchPrompt)
end)
