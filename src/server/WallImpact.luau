-- Explorer: ServerScriptService.BabyBeastsServer.WallImpact
-- Slamming head-on into a wall at huge speed knocks the player down: the client (BabyBeastsClient.WallImpactRagdoll)
-- reports the crash, the server kicks them up off the wall, spinning, to land face down with the Blender
-- ragdoll fall (Knockdown), lets them lie a moment, then stands them back up in place.
local Players = game:GetService("Players")
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local Knockdown = require(script.Parent.Knockdown)

local WallImpact = {}

local COOLDOWN = 2.5 -- seconds between knockdowns
local Config = require(game.ReplicatedStorage.BabyBeastsShared.MommyConfig)
-- speed into the wall, studs/s; the client checks the same (a little slack for rounding)
local MIN_IMPACT = Config.WallRagdollMinImpact * 0.95
local HEAD_ON = math.cos(math.rad(Config.WallRagdollMaxAngle + 5))
local MAX_SPEED = 3500 -- clamp for client-reported speed
local WALL_REACH = 9 -- the wall must be this close to the crash point
-- The server sees a fast runner well behind the client (~65 studs at 400 studs/s), so the crash
-- point comes from the client, accepted within LAG_SLACK + speed * LAG_SECONDS of the server view.
local LAG_SLACK = 20
local LAG_SECONDS = 0.35
local BOUNCE_MIN, BOUNCE_MAX = 6, 16 -- studs slid back off the wall
local BOUNCE_PER_SPEED = 0.14 -- studs of bounce per stud/s of impact speed
local SPIN = math.pi -- starts facing the wall, whips round in the air to land head-away, face down
local LIE_SECONDS = 1.1 -- crumpled on the floor before getting up

local nextAllowed: { [Player]: number } = {}

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

local function knockDown(player: Player, normal: Vector3, speed: number, at: Vector3)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
		return
	end
	local away = Vector3.new(normal.X, 0, normal.Z)
	if away.Magnitude < 0.3 then
		return
	end
	away = away.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	if (at - root.Position).Magnitude > LAG_SLACK + speed * LAG_SECONDS then
		return
	end
	-- the wall has to really be there
	local wall = workspace:Raycast(at, -away * WALL_REACH, params)
		or workspace:Raycast(at + Vector3.yAxis * 1.2, -away * WALL_REACH, params)
	if not wall or wall.Normal.Y > 0.55 then
		return
	end

	local floorHit = workspace:Raycast(at + Vector3.yAxis * 2, Vector3.new(0, -60, 0), params)
	local floor = if floorHit then floorHit.Position.Y else at.Y - 3
	local distance = math.clamp(speed * BOUNCE_PER_SPEED, BOUNCE_MIN, BOUNCE_MAX)
	local behind = workspace:Raycast(Vector3.new(at.X, floor + 2, at.Z), away * (distance + 3), params)
	if behind then
		distance = math.max(1.5, behind.Distance - 3)
	end
	-- start at standing height: the crash itself can knock the root down a little before it is reported
	local origin = Vector3.new(at.X, floor + Knockdown.standHeight(character), at.Z)
	local landing = origin + away * distance

	player:SetAttribute("WallRagdoll", true)
	local function valid(): boolean
		return player.Parent ~= nil and player.Character == character and root.Parent ~= nil and hum.Health > 0
	end
	local snap = Knockdown.prepare(character)
	local track = Knockdown.playRagdoll(character)
	local ok, err = pcall(function()
		if not snap or not Knockdown.slide(character, origin, landing, away, valid, SPIN) then
			return
		end
		Knockdown.dizzy(character, LIE_SECONDS + 0.5)
		task.wait(LIE_SECONDS)
		if valid() then
			Knockdown.recover(character, snap, track)
		end
	end)
	if not ok then
		warn("[WallImpact] " .. tostring(err))
		if snap and valid() then
			Knockdown.recover(character, snap, track)
		end
	end
	player:SetAttribute("WallRagdoll", nil)
end

function WallImpact.start()
	local remote = GameUI.remote("RagdollImpact")
	remote.OnServerEvent:Connect(function(player: Player, normal: any, velocity: any, at: any)
		if typeof(normal) ~= "Vector3" or typeof(velocity) ~= "Vector3" or typeof(at) ~= "Vector3" then
			return
		end
		if not finite(normal) or not finite(velocity) or not finite(at) then
			return
		end
		local now = os.clock()
		if now < (nextAllowed[player] or 0) or player:GetAttribute("WallRagdoll") == true then
			return
		end
		local state = player:GetAttribute("MommyState")
		if typeof(state) == "string" and state ~= "" then
			return
		end
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = math.min(flat.Magnitude, MAX_SPEED)
		local wallNormal = Vector3.new(normal.X, 0, normal.Z)
		if wallNormal.Magnitude < 0.3 then
			return
		end
		local into = -wallNormal.Unit:Dot(flat)
		if speed < MIN_IMPACT or into < MIN_IMPACT or into < flat.Magnitude * HEAD_ON then
			return
		end
		nextAllowed[player] = now + COOLDOWN
		task.spawn(knockDown, player, normal, speed, at)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			Knockdown.warm(character)
		end)
		if player.Character then
			Knockdown.warm(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		nextAllowed[player] = nil
	end)
end

return WallImpact
