local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local Config = require(Shared.MommyConfig)
local Motion = require(Shared.MommyMotion)
local GameUI = require(Shared.GameUI)
local Knockdown = require(script.Parent.Knockdown)
local Service = {}
local active, cooldown = {}, {}
local queue, running, origins = {}, {}, {}
local map, remote
local boundaryZ = 0

local function removeState(player, record)
	if active[player] ~= record then return end
	player:SetAttribute("LastMommyOutcome", record.outcome or "Cancelled")
	active[player] = nil
	player:SetAttribute("MommyState", nil)
	player:SetAttribute("MommyHabitat", nil)
	player:SetAttribute("MommyDeadline", nil)
	player:SetAttribute("MommyCF", nil)
	player:SetAttribute("MommyPending", nil)
	if player.Parent then remote:FireClient(player, "Return", record.habitat) end
end

local function discardBaby(player, character)
	local bag = player:FindFirstChild("Backpack")
	local tool = character:FindFirstChild("BabyBeast") or (bag and bag:FindFirstChild("BabyBeast"))
	if tool then
		tool:Destroy()
	end
end

local function ownedTank(player)
 local tanks=map and map:FindFirstChild("PlayerTanks")
 local tank=tanks and tanks:FindFirstChild("Tank"..tostring(player:GetAttribute("TankSlot")))
 return if tank and tank:GetAttribute("OwnerUserId")==player.UserId then tank else nil
end
local function insideOwnedPen(tank, position)
 local center = tank:GetAttribute("Center")
 local half = tank:GetAttribute("HalfSize")
 if typeof(center) ~= "Vector3" or typeof(half) ~= "number" then
  return false
 end
 return math.abs(position.X - center.X) <= half + 4
  and math.abs(position.Z - center.Z) <= half + 4
  and position.Y < 24
  and position.Y > -8
end
local function touchesOwnedTank(player,character,root)
 local tank=ownedTank(player)
 if not tank then return false end
 if insideOwnedPen(tank, root.Position) then
  return true
 end
 local params=OverlapParams.new()
 params.FilterType=Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances={character}
 params.MaxParts=1
 local bounds = tank:FindFirstChild("PenBounds")
 if bounds and bounds:IsA("BasePart") and #workspace:GetPartsInPart(bounds, params) > 0 then
  return true
 end
 return false
end

local function chaseable(player: Player): boolean
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not hum or hum.Health <= 0 then
		return false
	end
	-- Plaza side of the zone 0 / zone 1 line is already safe.
	return root.Position.Z > boundaryZ + 4
end

local function enqueue(habitat: string, player: Player, captureOrigin: Vector3?)
	local list = queue[habitat]
	if not list then
		list = {}
		queue[habitat] = list
	end
	for _, queued in list do
		if queued == player then
			return
		end
	end
	origins[player] = if typeof(captureOrigin) == "Vector3" then captureOrigin else nil
	table.insert(list, player)
end

local function popTarget(habitat: string): Player?
	local list = queue[habitat]
	if not list then
		return nil
	end
	local index = 1
	while index <= #list do
		local queued = list[index]
		if chaseable(queued) and not active[queued] and os.clock() >= (cooldown[queued] or 0) then
			table.remove(list, index)
			return queued
		end
		if not chaseable(queued) then
			table.remove(list, index)
		else
			index += 1
		end
	end
	return nil
end

local function startChase(player: Player, habitat: string, fromCF: CFrame?)
	running[habitat] = true
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local habitats = map and map:FindFirstChild("BeastHabitats")
	local cave = habitats and habitats:FindFirstChild(habitat)
	local den = cave and cave:FindFirstChild("JailCell")
	if not root or not hum or hum.Health <= 0 or not den then
		running[habitat] = nil
		local nxt = popTarget(habitat)
		if nxt then
			startChase(nxt, habitat, nil)
		end
		return
	end
	local captureAt = origins[player]
	origins[player] = nil
	if typeof(captureAt) ~= "Vector3" then
		captureAt = root.Position
	end
	local record = { character = character, habitat = habitat, captureAt = captureAt, handOff = nil :: CFrame? }
	active[player] = record
	player:SetAttribute("MommyState", "Chase")
	player:SetAttribute("MommyHabitat", habitat)
	player:SetAttribute("MommyDeadline", nil)
	player:SetAttribute("MommyPending", if fromCF then nil else true)
	if fromCF then
		player:SetAttribute("MommySnap", true)
		player:SetAttribute("MommyCF", fromCF)
	end
	remote:FireClient(player, "Chase", habitat)
	local function valid()
		return player.Parent and active[player] == record and player.Character == character and root.Parent and hum.Health > 0
	end
	task.spawn(function()
		local ok, err = xpcall(function()
			local cf = fromCF or Motion.rest(den)
			player:SetAttribute("MommyCF", cf)
			local caught = false
			local lastReplication = 0
			if not fromCF then
				-- Hold in the cage until the player is far enough from the bubble capture point.
				while valid() do
					RunService.Heartbeat:Wait()
					if not valid() then return end
					if record.safe or touchesOwnedTank(player, character, root) then
						record.outcome = "Safe"
						return
					end
					cf = Motion.rest(den)
					if os.clock() - lastReplication >= 1 / Config.ReplicationRate then
						lastReplication = os.clock()
						player:SetAttribute("MommyCF", cf)
					end
					if (root.Position - captureAt).Magnitude >= Config.ChaseStartDistance then
						break
					end
				end
				if not valid() then return end
				player:SetAttribute("MommyPending", nil)
			end
			local openedAt = if fromCF then 0 else os.clock() + Config.GateSeconds
			local exiting = fromCF == nil
			while valid() do
				local dt = RunService.Heartbeat:Wait()
				if not valid() then return end
				if record.safe or touchesOwnedTank(player, character, root) then
					record.outcome = "Safe"
					return
				end
				if os.clock() < openedAt then
					cf = Motion.rest(den)
					continue
				end
				local previous = cf.Position
				local target = if exiting then Motion.exitPoint(den) else root.Position
				cf = Motion.advance(cf, den, target, dt, exiting)
				if exiting and (cf.Position - target).Magnitude < 1 then
					exiting = false
				end
				if not exiting and previous.Z > boundaryZ and cf.Position.Z <= boundaryZ then
					local clamped = Vector3.new(cf.Position.X, Motion.swimY(den, cf.Position), boundaryZ)
					local retreat = Vector3.new(previous.X - clamped.X, 0, previous.Z - clamped.Z)
					if retreat.Magnitude < 0.05 then
						retreat = Vector3.zAxis
					else
						retreat = retreat.Unit
					end
					cf = CFrame.lookAt(clamped, clamped + retreat)
					player:SetAttribute("MommyCF", cf)
					record.outcome = "Escaped"
					record.handOff = cf
					return
				end
				if os.clock() - lastReplication >= 1 / Config.ReplicationRate then
					lastReplication = os.clock()
					player:SetAttribute("MommyCF", cf)
					if player:GetAttribute("MommySnap") == true then
						player:SetAttribute("MommySnap", nil)
					end
				end
				if not exiting and Motion.caught(cf, den, root.Position) then
					-- Nose contact tackles. A faster player still gets away by
					-- staying ahead; the chase pace is the guardian's stud speed.
					caught = true
					record.outcome = "Caught"
					break
				end
			end
			if record.outcome == "Escaped" or not valid() or not caught then return end
			-- Nose on the player, then slide them along the floor.
			cf = Motion.noseStrike(den, cf, root.Position)
			local snout = Motion.snout(cf, den)
			local flat = Motion.throwDir(cf, den, root.Position)
			player:SetAttribute("MommyState", "Tackled")
			player:SetAttribute("MommyCF", cf)
			-- Caught: lose the baby; the player gets back up where they land.
			discardBaby(player, character)
			-- Leave swimming so the slide stays on the path.
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			local snap = Knockdown.prepare(character)
			local track = Knockdown.playRagdoll(character)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			params.IgnoreWater = true
			params.RespectCanCollide = true
			local hit = workspace:Raycast(root.Position + Vector3.yAxis * 4, Vector3.new(0, -1200, 0), params)
			local floor = if hit then hit.Position.Y else 0
			local origin = Vector3.new(snout.X, root.Position.Y, snout.Z) + flat * 1.2
			local wall = workspace:Raycast(Vector3.new(origin.X, floor + 4, origin.Z), flat * Config.SlideDistance, params)
			local distance = if wall then math.max(12, wall.Distance - 3) else Config.SlideDistance
			local landing = origin + flat * distance
			local slideY = floor + Knockdown.standHeight(character)
			landing = Vector3.new(landing.X, slideY, landing.Z)
			remote:FireClient(player, "Tackle", habitat, {
				origin = origin,
				landing = landing,
				throwDir = flat,
				beastCF = cf,
				snout = snout,
			})
			local start = Vector3.new(origin.X, slideY, origin.Z)
			if not Knockdown.slide(character, start, landing, flat, valid) then return end
			Knockdown.dizzy(character, Config.LandedHoldSeconds + 0.5)
			player:SetAttribute("MommyState", "Stopped")
			remote:FireClient(player, "Landed", habitat, landing)
			task.wait(Config.LandedHoldSeconds)
			if not valid() then return end
			-- Get up where the tackle left them (no respawn at the tank).
			cooldown[player] = os.clock() + Config.RespawnGraceSeconds
			if snap then
				Knockdown.recover(character, snap, track)
			end
		end, debug.traceback)
		local handoff = if record.outcome == "Escaped" then record.handOff else nil
		if not ok then
			warn("[MommyBeasts] Recovery: " .. tostring(err))
			if player.Parent and player.Character == character then
				pcall(function() player:LoadCharacterAsync() end)
			end
		end
		removeState(player, record)
		local nxt = popTarget(habitat)
		if nxt then
			startChase(nxt, habitat, handoff)
		else
			running[habitat] = nil
		end
	end)
end

function Service.begin(player, habitat, captureOrigin)
	if not Config.Enabled or not map or active[player] or os.clock() < (cooldown[player] or 0) then return false end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local habitats = map:FindFirstChild("BeastHabitats")
	local cave = habitats and habitats:FindFirstChild(habitat)
	local den = cave and cave:FindFirstChild("JailCell")
	if not root or not hum or hum.Health <= 0 or not den then return false end
	local origin = if typeof(captureOrigin) == "Vector3" then captureOrigin else root.Position
	enqueue(habitat, player, origin)
	if running[habitat] then
		return true
	end
	local nxt = popTarget(habitat)
	if not nxt then
		return false
	end
	startChase(nxt, habitat, nil)
	return true
end

function Service.canCollect(player)
	return not active[player] and os.clock() >= (cooldown[player] or 0)
end

function Service.start(root)
	if map then return end
	map = root
	remote = GameUI.remote("MommyEncounter")
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone1 = habitats and habitats:FindFirstChild("Zone01")
	local startZ = zone1 and zone1:GetAttribute("StartZ")
	boundaryZ = if typeof(startZ) == "number" then startZ else 0
	for _,tank in root.PlayerTanks:GetChildren() do
		local bounds = tank:FindFirstChild("PenBounds")
		if bounds and bounds:IsA("BasePart") then
			bounds.CanTouch = true
			bounds.Touched:Connect(function(hit)
				local character=hit:FindFirstAncestorOfClass("Model")
				local player=character and Players:GetPlayerFromCharacter(character)
				local record=player and active[player]
				if record and record.character==character and ownedTank(player)==tank then record.safe=true end
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		active[player], cooldown[player], origins[player] = nil, nil, nil
		for _, list in queue do
			for index = #list, 1, -1 do
				if list[index] == player then
					table.remove(list, index)
				end
			end
		end
	end)
end
return Service
