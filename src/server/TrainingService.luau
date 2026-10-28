local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local SpeedData = require(script.Parent.SpeedDataManager)
local Service = {}
local training = {}
local started = false
local function trainPrompt(machine)
	local deck = machine:FindFirstChild("Deck")
	local prompt = deck and deck:FindFirstChildOfClass("ProximityPrompt")
	if prompt and prompt.Name ~= "UpgradePrompt" then
		return prompt
	end
	for _, child in machine:GetDescendants() do
		if child:IsA("ProximityPrompt") and child.Name ~= "UpgradePrompt" then
			return child
		end
	end
	return nil
end

local function upgradePrompt(machine): ProximityPrompt?
	local deck = machine:FindFirstChild("Deck")
	local prompt = deck and deck:FindFirstChild("UpgradePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	for _, child in machine:GetDescendants() do
		if child:IsA("ProximityPrompt") and child.Name == "UpgradePrompt" then
			return child
		end
	end
	return nil
end

local function setUpgradeEnabled(machine, enabled: boolean)
	local prompt = upgradePrompt(machine)
	if prompt then
		prompt.Enabled = enabled
	end
end

local function stop(player, move)
	local t = training[player]
	if not t then
		return
	end
	training[player] = nil
	t.machine:SetAttribute("TrainingUserId", 0)
	t.machine:SetAttribute("TrainingStartedAt", 0)
	local prompt = trainPrompt(t.machine)
	if prompt then
		prompt.Enabled = true
	end
	setUpgradeEnabled(t.machine, false)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root == t.root then
		root.Anchored = t.anchored
		root.AssemblyLinearVelocity = Vector3.zero
		if move and hum and hum.Health > 0 then
			-- Step off into the yard. The console (+Z) points away from the tank.
			root.CFrame = t.origin * CFrame.new(0, 4, 12)
		end
		if hum then
			hum.AutoRotate = t.autoRotate
		end
	end
	player:SetAttribute("TrainingTreadmill", nil)
	player:SetAttribute("TrainingRate", nil)
	player:SetAttribute("TrainingStartedAt", nil)
end

-- Keep the runner on the belt when PersonalTreadmills swaps the machine mid-run.
function Service.retarget(player: Player, machine: Model)
	local t = training[player]
	if not t then
		return
	end
	local origin = machine:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	t.machine = machine
	t.origin = origin
	local train = trainPrompt(machine)
	if train then
		train.Enabled = false
	end
	setUpgradeEnabled(machine, true)
	player:SetAttribute("TrainingTreadmill", machine:GetAttribute("TreadmillId"))
	player:SetAttribute("TrainingRate", SpeedData.gain(player))
end
local function standCFrame(origin: CFrame, hip: number): CFrame
	-- The machine faces one way. The runner on the belt faces the other.
	return origin * CFrame.new(0, hip, 0) * CFrame.Angles(0, math.pi, 0)
end

local function deckY(machine): number
	local y = machine:GetAttribute("DeckY")
	if typeof(y) == "number" then
		return y
	end
	return 2.4
end

local function owns(player, machine): boolean
	local owner = machine:GetAttribute("OwnerUserId")
	return typeof(owner) ~= "number" or owner == 0 or owner == player.UserId
end

local function onDeck(machine, localPos: Vector3): boolean
	local halfX = machine:GetAttribute("DeckHalfX")
	local halfZ = machine:GetAttribute("DeckHalfZ")
	local minY = machine:GetAttribute("DeckMinY")
	local maxY = machine:GetAttribute("DeckMaxY")
	if typeof(halfX) ~= "number" then
		halfX = 4.4
	end
	if typeof(halfZ) ~= "number" then
		halfZ = 7.6
	end
	if typeof(minY) ~= "number" then
		minY = 1.5
	end
	if typeof(maxY) ~= "number" then
		maxY = 8
	end
	return math.abs(localPos.X) < halfX
		and math.abs(localPos.Z) < halfZ
		and localPos.Y > minY
		and localPos.Y < maxY
end

local function begin(player, machine)
	if not SpeedData.isReady(player) then
		return
	end
	if training[player] or machine:GetAttribute("TrainingUserId") ~= 0 or not owns(player, machine) then
		return
	end
	if player:GetAttribute("MommyState") then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local origin = machine:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	if (root.Position - origin.Position).Magnitude > 60 then
		return
	end
	training[player] = {
		machine = machine,
		root = root,
		origin = origin,
		anchored = root.Anchored,
		autoRotate = hum.AutoRotate,
	}
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	hum.AutoRotate = false
	local hip = hum.HipHeight
		+ root.Size.Y / 2
		+ (if hum.RigType == Enum.HumanoidRigType.R6 then 2 else 0)
	-- Center of the moving mat. The machine stays put; the runner faces away from the tank.
	root.CFrame = standCFrame(origin, deckY(machine) + hip)
	local startedAt = workspace:GetServerTimeNow()
	machine:SetAttribute("TrainingUserId", player.UserId)
	machine:SetAttribute("TrainingStartedAt", startedAt)
	local prompt = trainPrompt(machine)
	if prompt then
		prompt.Enabled = false
	end
	setUpgradeEnabled(machine, true)
	player:SetAttribute("TrainingTreadmill", machine:GetAttribute("TreadmillId"))
	player:SetAttribute("TrainingStartedAt", startedAt)
	player:SetAttribute("TrainingRate", SpeedData.gain(player))
end
local function bindMachine(machine)
	local deck = machine:FindFirstChild("Deck")
	if deck and deck:IsA("BasePart") and not deck:GetAttribute("TouchBound") then
		deck:SetAttribute("TouchBound", true)
		deck.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				begin(player, machine)
			end
		end)
	end
	local prompt = trainPrompt(machine)
	if prompt and not prompt:GetAttribute("TrainingBound") then
		prompt:SetAttribute("TrainingBound", true)
		prompt.Triggered:Connect(function(player)
			begin(player, machine)
		end)
	end
	local upgrade = upgradePrompt(machine)
	if upgrade and not upgrade:GetAttribute("UpgradeBound") then
		upgrade:SetAttribute("UpgradeBound", true)
		upgrade.Enabled = false
		upgrade.Triggered:Connect(function(player)
			if machine:GetAttribute("TrainingUserId") ~= player.UserId then
				return
			end
			if not owns(player, machine) then
				return
			end
			local Shop = script.Parent:FindFirstChild("ShopServer")
			if Shop then
				require(Shop).upgradeTreadmill(player)
			end
		end)
	end
end
function Service.canAccess(_player, _habitat)
	return true
end

local collisionReady = false

function Service.prepareCollision()
	if collisionReady then
		return
	end
	collisionReady = true
	for slot = 1, 8 do
		pcall(function()
			PhysicsService:RegisterCollisionGroup("Lane" .. slot)
		end)
		pcall(function()
			PhysicsService:RegisterCollisionGroup("LaneOwner" .. slot)
		end)
	end
	for slot = 1, 8 do
		local lane = "Lane" .. slot
		PhysicsService:CollisionGroupSetCollidable(lane, "Default", false)
		for other = 1, 8 do
			PhysicsService:CollisionGroupSetCollidable(lane, "Lane" .. other, false)
			PhysicsService:CollisionGroupSetCollidable(lane, "LaneOwner" .. other, slot == other)
		end
	end
end

local function catchNumber(machine, name: string, fallback: number): number
	local value = machine:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function insideCatch(machine, worldPos: Vector3): boolean
	local origin = machine:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return false
	end
	local localPos = origin:PointToObjectSpace(worldPos)
	return math.abs(localPos.X) < catchNumber(machine, "CatchHalfX", 6)
		and math.abs(localPos.Z) < catchNumber(machine, "CatchHalfZ", 8)
		and localPos.Y > catchNumber(machine, "CatchMinY", 0)
		and localPos.Y < catchNumber(machine, "CatchMaxY", 12)
end

local function sweptHit(machine, a: Vector3, b: Vector3): boolean
	local distance = (b - a).Magnitude
	local steps = math.max(1, math.ceil(distance / 1.25))
	for i = 0, steps do
		if insideCatch(machine, a:Lerp(b, i / steps)) then
			return true
		end
	end
	return false
end

local function paintOwner(player: Player)
	Service.prepareCollision()
	local slot = player:GetAttribute("TankSlot")
	if typeof(slot) ~= "number" then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local group = "LaneOwner" .. slot
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end
function Service.start(_map)
	if started then
		return
	end
	started = true
	for _, g in CollectionService:GetTagged("BiomeSpeedGate") do
		if g:IsA("BasePart") then
			g.CanCollide = false
			g.CanQuery = false
		end
	end
	local shared = game.ReplicatedStorage:FindFirstChild("BabyBeastsShared") or game.ReplicatedStorage
	local remote = shared:FindFirstChild("TrainingExit")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "TrainingExit"
		remote.Parent = shared
	end
	remote.OnServerEvent:Connect(function(player)
		stop(player, true)
	end)
	for _, m in CollectionService:GetTagged("TrainingTreadmill") do
		bindMachine(m)
	end
	CollectionService:GetInstanceAddedSignal("TrainingTreadmill"):Connect(bindMachine)
	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			stop(player, false)
		end)
		player.CharacterAdded:Connect(function(character)
			character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					local slot = player:GetAttribute("TankSlot")
					if typeof(slot) == "number" then
						descendant.CollisionGroup = "LaneOwner" .. slot
					end
				end
			end)
			task.defer(paintOwner, player)
		end)
		player:GetAttributeChangedSignal("TankSlot"):Connect(function()
			paintOwner(player)
		end)
		if player.Character then
			task.defer(paintOwner, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stop(player, false)
	end)
	Service.prepareCollision()
	local lastPos: { [Player]: Vector3 } = {}
	RunService.PreSimulation:Connect(function()
		for _, p in Players:GetPlayers() do
			if training[p] then
				lastPos[p] = nil
				continue
			end
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 or root.Anchored or p:GetAttribute("MommyState") then
				lastPos[p] = nil
				continue
			end
			local previous = lastPos[p]
			lastPos[p] = root.Position
			for _, m in CollectionService:GetTagged("TrainingTreadmill") do
				if m:GetAttribute("TrainingUserId") ~= 0 or not owns(p, m) then
					continue
				end
				if insideCatch(m, root.Position) or (previous ~= nil and sweptHit(m, previous, root.Position)) then
					begin(p, m)
					break
				end
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local t = training[p]
				if t then
					if
						not root
						or root ~= t.root
						or not hum
						or hum.Health <= 0
						or p:GetAttribute("MommyState")
					then
						stop(p, true)
					elseif SpeedData.isReady(p) then
						local hip = hum.HipHeight
							+ root.Size.Y / 2
							+ (if hum.RigType == Enum.HumanoidRigType.R6 then 2 else 0)
						root.CFrame = standCFrame(t.origin, deckY(t.machine) + hip)
						root.AssemblyLinearVelocity = Vector3.zero
						SpeedData.addTraining(p, dt)
					end
				elseif root and hum and hum.Health > 0 and not root.Anchored then
					for _, m in CollectionService:GetTagged("TrainingTreadmill") do
						local origin = m:GetAttribute("Origin")
						if typeof(origin) == "CFrame" and m:GetAttribute("TrainingUserId") == 0 then
							local localPos = origin:PointToObjectSpace(root.Position)
							if owns(p, m) and onDeck(m, localPos) then
								begin(p, m)
								break
							end
						end
					end
				end
			end
		end
	end)
end
return Service
