--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.WallImpactRagdoll
-- Detects slamming head-on into a wall at huge speed and asks the server (WallImpact) for the ragdoll knockdown.
-- The Humanoid's own FallingDown trip is turned off: it was the stiff fall-and-slide on crashes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared:WaitForChild("GameUI"))
local MommyConfig = require(Shared:WaitForChild("MommyConfig"))

local player = Players.LocalPlayer
local remote = GameUI.remote("RagdollImpact")

local MIN_IMPACT = MommyConfig.WallRagdollMinImpact
local HEAD_ON = math.cos(math.rad(MommyConfig.WallRagdollMaxAngle))
local MIN_STOP = MommyConfig.WallRagdollMinStop
local COOLDOWN = 1.1
local lastFire = 0
local lastHorizontal = Vector3.zero

local function busy(): boolean
	if player:GetAttribute("WallRagdoll") == true then
		return true
	end
	local state = player:GetAttribute("MommyState")
	if typeof(state) == "string" and state ~= "" then
		return true
	end
	return player:GetAttribute("TrainingTreadmill") == true
end

local function bind(character: Model)
	lastHorizontal = Vector3.zero
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not root or not root:IsA("BasePart") then
		return
	end
	local hum = character:WaitForChild("Humanoid", 8)
	if not hum or not hum:IsA("Humanoid") then
		return
	end
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	-- download the knockdown clip now so the server's track plays here without a delay
	local animator = hum:WaitForChild("Animator", 8)
	if animator and animator:IsA("Animator") then
		local clip = Instance.new("Animation")
		clip.AnimationId = MommyConfig.RagdollAnimationId
		animator:LoadAnimation(clip)
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if player.Character ~= character or not root.Parent or hum.Health <= 0 then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if busy() or hum.PlatformStand then
			lastHorizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local previous = lastHorizontal
		lastHorizontal = horizontal

		local prevSpeed = previous.Magnitude
		if prevSpeed < MIN_IMPACT then
			return
		end
		-- speed lost along the run direction (a wall bounce flips the velocity, so not just magnitude)
		local lost = prevSpeed - horizontal:Dot(previous.Unit)
		if lost < prevSpeed * MIN_STOP then
			return
		end
		if os.clock() - lastFire < COOLDOWN then
			return
		end

		local dir = previous.Unit
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.IgnoreWater = true
		params.RespectCanCollide = true
		local hit = workspace:Raycast(root.Position, dir * 4.5, params)
			or workspace:Raycast(root.Position + Vector3.yAxis * 1.2, dir * 4.5, params)
		if not hit then
			return
		end
		-- Only walls / steep surfaces — skip floors.
		if hit.Normal.Y > 0.55 then
			return
		end
		-- Only a near head-on slam at huge speed; softer or glancing hits keep the default stop at the wall.
		local into = -hit.Normal:Dot(previous)
		if into < MIN_IMPACT or into < prevSpeed * HEAD_ON then
			return
		end

		lastFire = os.clock()
		-- Stop the physics bounce; the server takes the body over from here.
		root.AssemblyLinearVelocity = Vector3.new(0, math.min(velocity.Y, 0), 0)
		remote:FireServer(hit.Normal, previous, root.Position)
	end)
end

if player.Character then
	task.spawn(bind, player.Character)
end
player.CharacterAdded:Connect(bind)
