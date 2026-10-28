--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local config = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local SpeedCurve = require(game.ReplicatedStorage.BabyBeastsShared.SpeedCurve)
local player = Players.LocalPlayer
local Controller = {}
local changed = Instance.new("BindableEvent")
Controller.Changed = changed.Event
local humanoid: Humanoid? = nil
local character: Model? = nil
local descent: RBXScriptConnection? = nil
local swimSteer: RBXScriptConnection? = nil
local lastMode = nil
-- 0 = head-up / upright, 1 = head-down dive.
local swimPitch = 0
local heldFacing: Vector3? = nil
local VERTICAL_SWIM_SPEED = config.SwimSpeed
-- Fast enough that the unavoidable ~90° belly pose is only a brief flip, not a hold.
local PITCH_LERP_SPEED = 6.5
if player:GetAttribute("MovementMode") ~= "SWIM" and player:GetAttribute("MovementMode") ~= "RUN" then
	player:SetAttribute("MovementMode", "RUN")
end
local function landPace(): number
	local trained = tonumber(player:GetAttribute("Speed")) or 0
	return SpeedCurve.scaled(SpeedCurve.studs(trained), player:GetAttribute("SpeedScale"))
end
local function refreshLandPace()
	if humanoid and humanoid.Health > 0 and Controller.getMode() == "RUN" then
		humanoid.WalkSpeed = landPace()
	end
end
player:GetAttributeChangedSignal("Speed"):Connect(refreshLandPace)
player:GetAttributeChangedSignal("SpeedScale"):Connect(refreshLandPace)

function Controller.getMode()
	return player:GetAttribute("MovementMode")
end

local function cancelDescent()
	if descent then
		descent:Disconnect()
		descent = nil
	end
end

local function cancelSwimSteer()
	if swimSteer then
		swimSteer:Disconnect()
		swimSteer = nil
	end
end

local function verticalInput(): number
	local up = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if up and not down then
		return 1
	end
	if down and not up then
		return -1
	end
	return 0
end

local function terrainHasWater(at: Vector3): boolean
	local ok, materials = pcall(function()
		local region = Region3.new(at - Vector3.one * 2, at + Vector3.one * 2):ExpandToGrid(4)
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok or materials == nil then
		return false
	end
	local size = (materials :: any).Size
	if not size then
		return false
	end
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water then
					return true
				end
			end
		end
	end
	return false
end

local function isInWater(root: BasePart): boolean
	if root.Position.Y >= config.WaterTop - 1.5 then
		return false
	end
	if terrainHasWater(root.Position) then
		return true
	end
	local c, s = config.OceanCenter, config.OceanSize
	local p = root.Position
	return math.abs(p.X - c.X) <= s.X * 0.5
		and math.abs(p.Y - c.Y) <= s.Y * 0.5
		and math.abs(p.Z - c.Z) <= s.Z * 0.5
end

local function flatFacing(root: BasePart): Vector3
	if heldFacing and heldFacing.Magnitude > 0.05 then
		return heldFacing
	end
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude < 0.05 then
		facing = Vector3.zAxis
	else
		facing = facing.Unit
	end
	heldFacing = facing
	return facing
end

-- pitch 0 = head-up upright, pitch 1 = inverted head-down (Up=-Y).
-- NOTE: A -90° pitch makes Look=-Y with head still horizontal (= belly looking at floor).
-- A -180° pitch puts the head below the body for a real pencil dive.
local function swimOrientation(root: BasePart, pitch: number): CFrame
	local facing = flatFacing(root)
	local upright = CFrame.lookAt(root.Position, root.Position + facing, Vector3.yAxis)
	return upright * CFrame.Angles(-math.clamp(pitch, 0, 1) * math.pi, 0, 0)
end

local function startSwimSteer()
	cancelSwimSteer()
	swimPitch = 0
	heldFacing = nil
	swimSteer = RunService.PreSimulation:Connect(function(dt)
		dt = math.clamp(dt, 0, 0.05)
		if Controller.getMode() ~= "SWIM" or not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		local state = player:GetAttribute("MommyState")
		if state == "Tackled" or state == "Stopped" or state == "Respawning" then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end

		if not isInWater(root) then
			humanoid.AutoRotate = true
			swimPitch = 0
			heldFacing = nil
			return
		end

		local input = verticalInput()
		local targetPitch = if input < 0 then 1 else 0
		local alpha = math.min(1, dt * PITCH_LERP_SPEED)
		swimPitch += (targetPitch - swimPitch) * alpha

		if input == 0 then
			if swimPitch < 0.04 then
				swimPitch = 0
				heldFacing = nil
				humanoid.AutoRotate = true
			else
				humanoid.AutoRotate = false
				root.CFrame = swimOrientation(root, swimPitch)
			end
			return
		end

		humanoid.AutoRotate = false
		if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
		end
		root.CFrame = swimOrientation(root, swimPitch)
		root.AssemblyAngularVelocity = Vector3.zero

		local v = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(v.X, 0, v.Z)
		if input < 0 then
			-- Always dive world-down. Using Up at ~90° pitch pushes HORIZONTAL (belly swim).
			local t = math.clamp(swimPitch / 0.35, 0, 1)
			root.AssemblyLinearVelocity = horizontal * (1 - 0.9 * t) + (-Vector3.yAxis) * (VERTICAL_SWIM_SPEED * t)
		else
			-- Rise only after mostly upright again; push world-up once head is on top.
			local uprightAmt = 1 - swimPitch
			local t = math.clamp((uprightAmt - 0.72) / 0.28, 0, 1)
			root.AssemblyLinearVelocity = Vector3.new(horizontal.X, VERTICAL_SWIM_SPEED * t, horizontal.Z)
		end
	end)
end

local function apply()
	if player:GetAttribute("TrainingTreadmill") then
		cancelDescent()
		cancelSwimSteer()
		if humanoid then
			humanoid.AutoRotate = false
		end
		return
	end
	local state = player:GetAttribute("MommyState")
	if state == "Tackled" or state == "Stopped" or state == "Respawning" then
		cancelDescent()
		cancelSwimSteer()
		if humanoid then
			humanoid.AutoRotate = true
		end
		return
	end
	local mode = Controller.getMode()
	if humanoid and humanoid.Health > 0 then
		-- Land pace comes from the zone chart. Swim keeps its own pace.
		humanoid.WalkSpeed = if mode == "SWIM"
			then config.SwimSpeed
			else landPace()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, mode == "SWIM")
		if mode == "SWIM" then
			cancelDescent()
			startSwimSteer()
		else
			cancelDescent()
			cancelSwimSteer()
			humanoid.AutoRotate = true
			swimPitch = 0
			heldFacing = nil
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if lastMode == "SWIM" and root and root:IsA("BasePart") then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { character :: Model }
				params.IgnoreWater = true
				params.RespectCanCollide = true
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), params)
				if hit then
					local clearance = humanoid.HipHeight + root.Size.Y / 2
					local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
					if look.Magnitude < 0.05 then
						look = Vector3.zAxis
					else
						look = look.Unit
					end
					local pos = Vector3.new(root.Position.X, hit.Position.Y + clearance, root.Position.Z)
					root.CFrame = CFrame.lookAt(pos, pos + look)
				end
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			if lastMode ~= "RUN" then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
	end
	lastMode = mode
	changed:Fire(mode)
end

function Controller.setMode(mode)
	assert(mode == "RUN" or mode == "SWIM", "Invalid mode")
	if player:GetAttribute("MovementMode") ~= mode then
		player:SetAttribute("MovementMode", mode)
	end
end

function Controller.toggle()
	Controller.setMode(if Controller.getMode() == "SWIM" then "RUN" else "SWIM")
end

player:GetAttributeChangedSignal("MovementMode"):Connect(apply)
player:GetAttributeChangedSignal("MommyState"):Connect(apply)
player:GetAttributeChangedSignal("TrainingTreadmill"):Connect(apply)

local function bind(nextCharacter: Model)
	cancelDescent()
	cancelSwimSteer()
	character = nextCharacter
	humanoid = nextCharacter:WaitForChild("Humanoid") :: Humanoid
	swimPitch = 0
	heldFacing = nil
	if player.Character ~= nextCharacter then
		return
	end
	lastMode = nil
	apply()
end

player.CharacterAdded:Connect(bind)
if player.Character then
	task.spawn(bind, player.Character)
end

return Controller
