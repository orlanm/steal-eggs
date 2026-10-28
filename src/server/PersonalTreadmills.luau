--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.PersonalTreadmills
-- One treadmill per owner, beside that tank's entrance. The runner faces
-- the tank. The machine is removed when its owner leaves. Tier upgrades
-- swap the model in place even while the owner is still training.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local GameTreadmill = require(game.ReplicatedStorage.BabyBeastsShared.GameTreadmill)
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Layout = require(script.Parent.Map.Layout)
local Build = require(script.Parent.TreadmillBuild)
local Training = require(script.Parent.TrainingService)

local Personal = {}
local machines: { [Player]: Model } = {}
local busy: { [Player]: boolean } = {}
local rerun: { [Player]: boolean } = {}

local function tankFor(root: Instance, slot: number): Instance?
	local tanks = root:FindFirstChild("PlayerTanks")
	return tanks and tanks:FindFirstChild("Tank" .. slot)
end

local function originFor(root: Instance, slot: number, spec: GameTreadmill.Treadmill): CFrame?
	local tank = tankFor(root, slot)
	if not tank then
		return nil
	end
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		return nil
	end
	local front = tank:GetAttribute("FrontDir")
	if typeof(front) ~= "Vector3" then
		front = Layout.frontDir(center)
	end
	front = Vector3.new(front.X, 0, front.Z)
	if front.Magnitude < 0.05 then
		front = Layout.frontDir(center)
	else
		front = front.Unit
	end
	-- LookVector is the way the owner runs, back toward the tank.
	-- Local +Z is the console, so that end points out into the yard.
	local facing = CFrame.lookAt(Vector3.zero, front)
	local right = facing.RightVector
	local half = tank:GetAttribute("HalfSize")
	if typeof(half) ~= "number" then
		half = MapConfig.PenSize * 0.5
	end
	local face = center + front * half
	local pathHalf = MapConfig.CheckerSize * 1.5
	local halfAcross = spec.Bounds.X * 0.5
	local halfOut = spec.Bounds.Z * 0.5
	local pos = face + front * (halfOut + 3) + right * (pathHalf + halfAcross + 2)
	pos = Vector3.new(pos.X, 0, pos.Z)
	return CFrame.lookAt(pos, pos - front)
end

local function laneFolder(tank: Instance): Instance
	local folder = tank:FindFirstChild("OwnerTreadmill")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "OwnerTreadmill"
		folder.Parent = tank
	end
	return folder
end

local function ensureUpgradePrompt(model: Model)
	local deck = model:FindFirstChild("Deck")
	if not (deck and deck:IsA("BasePart")) then
		return
	end
	local existing = deck:FindFirstChild("UpgradePrompt")
	if existing and existing:IsA("ProximityPrompt") then
		existing.Enabled = false
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = "Treadmill"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Enabled = false
	prompt.Parent = deck
end

local function place(player: Player, root: Instance)
	local slot = player:GetAttribute("TankSlot")
	if typeof(slot) ~= "number" then
		return
	end
	local tier = player:GetAttribute("TreadmillTier")
	if typeof(tier) ~= "number" then
		tier = 1
	end
	local existing = machines[player]
	if existing and existing.Parent and existing:GetAttribute("ShownTier") == tier then
		ensureUpgradePrompt(existing)
		return
	end
	local wasTraining = existing
		and existing.Parent
		and existing:GetAttribute("TrainingUserId") == player.UserId
	local startedAt = if wasTraining then existing:GetAttribute("TrainingStartedAt") else nil
	local spec = GameTreadmill.forTier(tier)
	local tank = tankFor(root, slot)
	local origin = originFor(root, slot, spec)
	if not tank or not origin then
		return
	end
	local folder = laneFolder(tank)
	local model = Build.model(spec, origin)
	model.Name = "PersonalTreadmill"
	model:SetAttribute("TreadmillId", player.UserId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("TrainingUserId", 0)
	model:SetAttribute("ShownTier", tier)
	model:SetAttribute("Origin", origin)
	model:SetAttribute("LaneSlot", slot)
	model.Parent = folder
	ensureUpgradePrompt(model)
	Training.prepareCollision()
	local deck = model:FindFirstChild("Deck")
	if deck and deck:IsA("BasePart") then
		deck.CollisionGroup = "Lane" .. slot
	end
	CollectionService:AddTag(model, "TrainingTreadmill")
	if wasTraining then
		model:SetAttribute("TrainingUserId", player.UserId)
		model:SetAttribute(
			"TrainingStartedAt",
			if typeof(startedAt) == "number" and startedAt > 0 then startedAt else workspace:GetServerTimeNow()
		)
	end
	if existing then
		existing:Destroy()
	end
	machines[player] = model
	if wasTraining then
		Training.retarget(player, model)
	end
end

function Personal.start(root: Instance)
	local function refresh(player: Player)
		if busy[player] then
			rerun[player] = true
			return
		end
		busy[player] = true
		task.spawn(function()
			repeat
				rerun[player] = nil
				place(player, root)
			until not rerun[player]
			busy[player] = false
		end)
	end
	local function watch(player: Player)
		player:GetAttributeChangedSignal("TankSlot"):Connect(function()
			refresh(player)
		end)
		player:GetAttributeChangedSignal("TreadmillTier"):Connect(function()
			refresh(player)
		end)
		refresh(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local model = machines[player]
		if model then
			model:Destroy()
		end
		machines[player] = nil
		busy[player] = nil
		rerun[player] = nil
	end)
end

return Personal
