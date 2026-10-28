--!strict
local Players = game:GetService("Players")
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Fences = require(script.Parent.Map.TankFences)
local Layout = require(script.Parent.Map.Layout)
local Farm = require(script.Parent.FarmPens)
local Signs = {}

-- Side tanks face the road. The back row faces the opening of the C.
local function openingDir(center: Vector3): Vector3
	return Layout.frontDir(center)
end

local function frontDir(center: Vector3): Vector3
	return openingDir(center)
end

function Signs.frontOf(tank: Instance): CFrame
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		center = Vector3.zero
	end
	local front = frontDir(center)
	local half = tank:GetAttribute("HalfSize")
	if typeof(half) ~= "number" then
		half = MapConfig.PenSize * 0.5
	end
	return CFrame.lookAt(
		center + front * (half + 8) + Vector3.new(0, 4, 0),
		center + front * (half + 16) + Vector3.new(0, 4, 0)
	)
end

function Signs.decorate(root: Instance)
	Farm.decorate(root)
end

function Signs.placeCharacter(player: Player, character: Model, tank: Instance)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (root and root:IsA("BasePart") and player.Parent) then
		return
	end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	player:SetAttribute("MovementMode", "RUN")
	local cf = Signs.spawnCFrame(tank)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not cf then
		local center = tank:GetAttribute("Center")
		if typeof(center) == "Vector3" then
			cf = CFrame.new(center + Vector3.new(0, 4, 0))
		end
	end
	if not cf then
		root.Anchored = false
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 40, 0), Vector3.new(0, -200, 0), params)
	if hit and humanoid then
		local clearance = humanoid.HipHeight + root.Size.Y * 0.5 + 0.15
		local pos = Vector3.new(cf.Position.X, hit.Position.Y + clearance, cf.Position.Z)
		local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if look.Magnitude < 0.05 then
			look = Vector3.zAxis
		else
			look = look.Unit
		end
		cf = CFrame.lookAt(pos, pos + look.Unit)
	end
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
		humanoid.PlatformStand = false
	end
	character:PivotTo(cf)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.spawn(function()
		local began = os.clock()
		while root.Parent and os.clock() - began < 0.45 do
			character:PivotTo(cf)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			task.wait()
		end
		if not root.Parent then
			return
		end
		character:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = false
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
end

function Signs.spawnCFrame(tank: Instance): CFrame?
	local spawnPos = tank:GetAttribute("SpawnPosition")
	local lookAt = tank:GetAttribute("SpawnLookAt")
	if typeof(spawnPos) == "Vector3" and typeof(lookAt) == "Vector3" then
		return CFrame.lookAt(spawnPos, lookAt)
	end
	local plaque = tank:FindFirstChild("OwnerPlaque")
	if plaque and plaque:IsA("BasePart") then
		local look = Vector3.new(plaque.CFrame.LookVector.X, 0, plaque.CFrame.LookVector.Z)
		if look.Magnitude < 0.05 then
			look = Vector3.new(0, 0, 1)
		else
			look = look.Unit
		end
		local pos = Vector3.new(plaque.Position.X, 4, plaque.Position.Z) + look * 4.5
		return CFrame.lookAt(pos, Vector3.new(plaque.Position.X, 4, plaque.Position.Z))
	end
	return nil
end

function Signs.setOwner(tank: Instance, player: Player?)
	Farm.setOwner(tank, player)
end

function Signs.insideTank(tank: Instance, position: Vector3): boolean
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		return false
	end
	local half = tank:GetAttribute("HalfSize")
	if typeof(half) ~= "number" then
		half = MapConfig.PenSize * 0.5
	end
	return math.abs(position.X - center.X) < half - 2
		and math.abs(position.Z - center.Z) < half - 2
		and position.Y < 24
end

function Signs.nearTank(tank: Instance, position: Vector3, padding: number): boolean
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		return false
	end
	local half = tank:GetAttribute("HalfSize")
	if typeof(half) ~= "number" then
		half = MapConfig.PenSize * 0.5
	end
	if math.abs(position.X - center.X) <= half + padding and math.abs(position.Z - center.Z) <= half + padding then
		return true
	end
	for _, inst in tank:GetDescendants() do
		if inst:IsA("BasePart") and (not tank:FindFirstChild("FarmArchitecture") or not inst:IsDescendantOf(tank.FarmArchitecture)) then
			if (position - inst.Position).Magnitude <= math.max(inst.Size.X, inst.Size.Z) * 0.5 + padding then
				return true
			end
		end
	end
	return false
end

return Signs

