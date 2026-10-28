-- Explorer: ServerScriptService.BabyBeastsServer.Knockdown
-- Shared player knockdown for the guard tackle (MommyBeasts) and fast wall crashes (WallImpact):
-- the body goes limp under the Blender ragdoll animation (_blender/ragdoll), which carries the kick-up,
-- spin, face-down landing and bounce; the server keeps the anchored root upright at standing height
-- and slides it along the floor, and adds the impact / landing / dizzy VFX.
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.BabyBeastsShared.MommyConfig)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)

local Knockdown = {}

local LAND = Config.RagdollLandTime
local STOP = Config.RagdollStopTime
local AIR_SHARE = Config.RagdollAirShare

-- Root height above the floor when standing; the clip is authored for the root at this height.
function Knockdown.standHeight(character: Model): number
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return (if hum then hum.HipHeight else 2) + (if root then root.Size.Y * 0.5 else 1)
end

export type Snapshot = {
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
	autoRotate: boolean,
	requiresNeck: boolean,
	collides: { [BasePart]: boolean },
}

-- Keep the joints alive and hand the body to the server: root anchored, limbs loose and
-- non-colliding. Returns what recover() needs to stand the player back up.
function Knockdown.prepare(character: Model): Snapshot?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local snap: Snapshot = {
		walkSpeed = hum.WalkSpeed,
		jumpPower = hum.JumpPower,
		jumpHeight = hum.JumpHeight,
		autoRotate = hum.AutoRotate,
		requiresNeck = hum.RequiresNeck,
		collides = {},
	}
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.AutoRotate = false
	hum.PlatformStand = true
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, obj in character:GetDescendants() do
		if obj:IsA("BasePart") then
			snap.collides[obj] = obj.CanCollide
			pcall(function()
				obj:SetNetworkOwner(nil)
			end)
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
			if obj == root then
				obj.Anchored = true
				obj.CanCollide = true
			else
				obj.Anchored = false
				obj.CanCollide = false
			end
		elseif obj:IsA("Motor6D") then
			obj.Enabled = true
		end
	end
	return snap
end

-- Limp, twisted ragdoll fall (Blender: _blender/ragdoll). Drives Motor6D and AnimationConstraint
-- rigs alike; the last (crumpled) frame is held until the track is stopped or the character respawns.
local loaded: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

local function ragdollTrack(character: Model): AnimationTrack?
	local cached = loaded[character]
	if cached then
		return cached
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = Config.RagdollAnimationId
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok then
		warn("[Knockdown] ragdoll animation: " .. tostring(track))
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	loaded[character] = track
	return track
end

-- Load the clip when the character spawns so a knockdown starts on the first frame.
function Knockdown.warm(character: Model)
	ragdollTrack(character)
end

function Knockdown.playRagdoll(character: Model): AnimationTrack?
	local track = ragdollTrack(character)
	if not track then
		return nil
	end
	track:Play(0.06)
	track:AdjustSpeed(1)
	-- the slide is timed to the clip, so let it finish loading first (instant once warmed)
	local loadWait = 0
	while track.Length == 0 and loadWait < 0.6 do
		loadWait += task.wait()
	end
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 3 do
			waited += task.wait()
		end
		if track.Length == 0 then
			return
		end
		task.wait(math.max(0, track.Length - track.TimePosition - 0.05))
		if track.IsPlaying then
			track:AdjustSpeed(0)
		end
	end)
	return track
end

local function stillAll(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- VFX: built on every client (ParticleEmitter:Emit does not replicate), see shared KnockdownVfx
local vfxRemote = GameUI.remote("KnockdownVfx")

-- Stars circling over the head of a player lying knocked down, for `seconds` or until they get up.
function Knockdown.dizzy(character: Model, seconds: number)
	vfxRemote:FireAllClients("Dizzy", character, seconds)
end

-- Slide -------------------------------------------------------------------------------------------

-- Slide the anchored, upright root from origin to landing (both at standing height) while the clip
-- plays: steady travel through the air, then a skid that slows to a stop after the landing.
-- spin: yaw (radians) the body starts turned by and whips out of before it lands (wall crashes).
-- Fires the impact VFX at the start and the landing dust when the body slams down.
-- Returns false if valid() went false.
function Knockdown.slide(
	character: Model,
	origin: Vector3,
	landing: Vector3,
	facing: Vector3,
	valid: () -> boolean,
	spin: number?
): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local function at(t: number): Vector3
		local share
		if t < LAND then
			share = AIR_SHARE * t / LAND
		else
			local u = math.clamp((t - LAND) / (STOP - LAND), 0, 1)
			share = AIR_SHARE + (1 - AIR_SHARE) * (1 - (1 - u) * (1 - u))
		end
		local lift = math.clamp(t / 0.12, 0, 1)
		return Vector3.new(
			origin.X + (landing.X - origin.X) * share,
			origin.Y + (landing.Y - origin.Y) * lift,
			origin.Z + (landing.Z - origin.Z) * share
		)
	end
	vfxRemote:FireAllClients("Impact", origin)
	local began = os.clock()
	local landed = false
	while valid() and os.clock() - began < STOP do
		local t = os.clock() - began
		local pos = at(t)
		local turn = math.clamp(t / LAND, 0, 1)
		local yaw = (spin or 0) * (1 - turn * turn * (3 - 2 * turn))
		root.CFrame = CFrame.lookAt(pos, pos + facing) * CFrame.Angles(0, yaw, 0)
		if not landed and t >= LAND then
			landed = true
			-- the body lies ahead of the root, face down along `facing`
			local floorY = landing.Y - Knockdown.standHeight(character)
			local body = pos + facing * 1.6
			vfxRemote:FireAllClients("Landing", Vector3.new(body.X, floorY, body.Z))
		end
		stillAll(character)
		RunService.Heartbeat:Wait()
	end
	if not valid() then
		return false
	end
	root.CFrame = CFrame.lookAt(landing, landing + facing)
	stillAll(character)
	return true
end

local GET_UP = 0.35 -- seconds blending from the crumple back to standing
local GET_UP_HOP = 1.1 -- studs the root rises mid-blend so the legs swing up clear of the floor

-- Stand a knocked-down (not respawning) player back up where they lie: a quick hop up out of the
-- crumple (the blend from lying to standing would otherwise sweep the legs through the floor).
function Knockdown.recover(character: Model, snap: Snapshot, track: AnimationTrack?)
	if track then
		track:Stop(GET_UP)
	end
	vfxRemote:FireAllClients("DizzyStop", character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position + Vector3.yAxis * 3, Vector3.new(0, -60, 0), params)
	local pos = if hit then hit.Position + Vector3.yAxis * hum.HipHeight + Vector3.yAxis * root.Size.Y * 0.5
		else root.Position + Vector3.yAxis * 1.5
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis
	local began = os.clock()
	while root.Parent and os.clock() - began < GET_UP do
		local u = (os.clock() - began) / GET_UP
		local hop = pos + Vector3.yAxis * GET_UP_HOP * math.sin(math.pi * u)
		root.CFrame = CFrame.lookAt(hop, hop + flat)
		stillAll(character)
		RunService.Heartbeat:Wait()
	end
	root.CFrame = CFrame.lookAt(pos, pos + flat)
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	for part, canCollide in snap.collides do
		if part.Parent then
			part.CanCollide = canCollide
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			if player then
				pcall(function()
					part:SetNetworkOwner(player)
				end)
			end
		end
	end
	hum.PlatformStand = false
	hum.AutoRotate = snap.autoRotate
	hum.RequiresNeck = snap.requiresNeck
	hum.WalkSpeed = snap.walkSpeed
	hum.JumpPower = snap.jumpPower
	hum.JumpHeight = snap.jumpHeight
	hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
	if hum.Health > 0 then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

return Knockdown
