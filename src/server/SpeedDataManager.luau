--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.SpeedDataManager
-- Persists Cash, BaseSpeed, treadmill tier, and owned trails. Applies walk speed.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local ShopConfig = require(game.ReplicatedStorage.BabyBeastsShared.ShopConfig)
local PenConfig = require(game.ReplicatedStorage.BabyBeastsShared.PenConfig)
local SpeedCurve = require(game.ReplicatedStorage.BabyBeastsShared.SpeedCurve)

local Manager = {}

type Session = {
	base: number,
	cash: number,
	cashBank: number,
	tier: number,
	trail: string,
	owned: { [string]: boolean },
	perks: { [string]: boolean }, -- shop passes bought or gifted (saved)
	passes: { [string]: boolean }, -- shop passes from owned Game Passes (checked each join)
	luckyWeek: number,
	luckyBought: number,
	stars: number, -- Mount Stars in the backpack (MountService)
	starWeek: number,
	starBought: number,
	discovered: { [string]: boolean }, -- Pet Index: pets hatched at least once
	claimed: { [string]: boolean }, -- Pet Index: rewards collected
	equipLevel: number, -- "+1 EQUIP" upgrades bought (PenConfig.slots)
	penalty: number,
	loaded: boolean,
	dirty: boolean,
	saving: boolean,
}

local sessions: { [Player]: Session } = {}
local started = false
local store = DataStoreService:GetDataStore(Economy.DataStoreName)
local legacy = DataStoreService:GetDataStore(Economy.LegacyStoreName)

local function finite(value: any, fallback: number): number
	if typeof(value) == "number" and value == value and value >= 0 then
		return value
	end
	return fallback
end

local function ownedList(owned: { [string]: boolean }): { string }
	local list = {}
	for id in owned do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

local function multiplierFor(trailId: string): number
	local trail = Economy.trail(trailId)
	if trail then
		return trail.Multiplier
	end
	return 1
end

local function hasPass(session: Session, id: string): boolean
	return session.perks[id] == true or session.passes[id] == true
end

local function boost(session: Session): number
	return multiplierFor(session.trail) * (if hasPass(session, "Speed") then ShopConfig.SpeedBoost else 1)
end

local function compute(session: Session): number
	return Economy.points(session.base, boost(session), session.penalty)
end

local function pace(session: Session): number
	return Economy.walkSpeed(session.base, boost(session), session.penalty)
end

local function luckyLeft(session: Session): number
	local week = ShopConfig.week(os.time())
	if session.luckyWeek ~= week then
		return ShopConfig.LuckyWeeklyStock
	end
	return math.max(0, ShopConfig.LuckyWeeklyStock - session.luckyBought)
end

local function starsLeft(session: Session): number
	if session.starWeek ~= ShopConfig.week(os.time()) then
		return ShopConfig.StarWeeklyStock
	end
	return math.max(0, ShopConfig.StarWeeklyStock - session.starBought)
end

local function leaderstat(player: Player, name: string, className: string): ValueBase
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local value = folder:FindFirstChild(name)
	if not value then
		value = Instance.new(className)
		value.Name = name
		value.Parent = folder
	end
	return value :: ValueBase
end

local function applyHumanoid(player: Player, speed: number)
	local state = player:GetAttribute("MommyState")
	if state == "Tackled" or state == "Stopped" or state == "Respawning" then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("MovementMode") == "SWIM" then
		humanoid.WalkSpeed = MapConfig.SwimSpeed
	else
		humanoid.WalkSpeed = SpeedCurve.scaled(speed, player:GetAttribute("SpeedScale"))
	end
end

local function publish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local speed = compute(session)
	local studs = pace(session)
	local owned = table.concat(ownedList(session.owned), ",")
	player:SetAttribute("BaseSpeed", session.base)
	player:SetAttribute("Cash", math.floor(session.cash))
	player:SetAttribute("TreadmillTier", session.tier)
	player:SetAttribute("EquippedTrail", session.trail)
	player:SetAttribute("TrailMultiplier", multiplierFor(session.trail))
	player:SetAttribute("OwnedTrails", owned)
	player:SetAttribute("EggWeightPenalty", session.penalty)
	player:SetAttribute("Speed", speed)
	player:SetAttribute("TrainingRate", Economy.tier(session.tier).Gain)
	player:SetAttribute("SpeedLoaded", session.loaded)
	for _, pass in ShopConfig.Passes do
		player:SetAttribute("Pass" .. pass.Id, hasPass(session, pass.Id))
	end
	for _, vehicle in ShopConfig.Vehicles do
		player:SetAttribute("Owns" .. vehicle.Id, hasPass(session, vehicle.Id))
	end
	player:SetAttribute("LuckyStock", luckyLeft(session))
	player:SetAttribute("Stars", session.stars)
	player:SetAttribute("StarStock", starsLeft(session))
	player:SetAttribute("EquipLevel", session.equipLevel)
	player:SetAttribute("EquipSlots", PenConfig.slots(session.equipLevel))
	local cash = leaderstat(player, "Cash", "NumberValue")
	local base = leaderstat(player, "BaseSpeed", "NumberValue")
	local shown = leaderstat(player, "Speed", "NumberValue")
	;(cash :: NumberValue).Value = math.floor(session.cash)
	;(base :: NumberValue).Value = math.floor(session.base)
	;(shown :: NumberValue).Value = math.floor(speed)
	player:SetAttribute("StudSpeed", studs)
	applyHumanoid(player, studs)
end

local function blank(): Session
	return {
		base = Economy.StartingSpeed,
		cash = 0,
		cashBank = 0,
		tier = 1,
		trail = "",
		owned = {},
		perks = {},
		passes = {},
		luckyWeek = -1,
		luckyBought = 0,
		stars = 0,
		starWeek = -1,
		starBought = 0,
		discovered = {},
		claimed = {},
		equipLevel = 0,
		penalty = 1,
		loaded = false,
		dirty = false,
		saving = false,
	}
end

local function readOwned(data: any): { [string]: boolean }
	local owned = {}
	if typeof(data) ~= "table" or typeof(data.OwnedTrails) ~= "table" then
		return owned
	end
	for _, id in data.OwnedTrails do
		if typeof(id) == "string" and Economy.trail(id) then
			owned[id] = true
		end
	end
	return owned
end

local function applyData(session: Session, data: any)
	if typeof(data) ~= "table" then
		local legacySpeed = finite(data, Economy.StartingSpeed)
		session.base = math.clamp(math.max(Economy.StartingSpeed, legacySpeed), Economy.StartingSpeed, Economy.MaximumSpeed)
		return
	end
	local legacySpeed = finite(data.Speed, 0)
	local base = finite(data.BaseSpeed, 0)
	session.base = math.clamp(math.max(Economy.StartingSpeed, base, legacySpeed), 0, Economy.MaximumSpeed)
	if session.base < Economy.StartingSpeed then
		session.base = Economy.StartingSpeed
	end
	session.cash = math.floor(finite(data.Cash, 0))
	session.tier = math.clamp(math.floor(finite(data.TreadmillTier, 1)), 1, #Economy.Tiers)
	session.owned = readOwned(data)
	if typeof(data.Perks) == "table" then
		for _, id in data.Perks do
			if typeof(id) == "string" and ShopConfig.perk(id) then
				session.perks[id] = true
			end
		end
	end
	for field, set in { IndexDiscovered = session.discovered, IndexClaimed = session.claimed } do
		if typeof(data[field]) == "table" then
			for _, id in data[field] do
				if typeof(id) == "string" then
					set[id] = true
				end
			end
		end
	end
	session.luckyWeek = math.floor(finite(data.LuckyWeek, -1))
	session.luckyBought = math.floor(finite(data.LuckyBought, 0))
	session.stars = math.max(0, math.floor(finite(data.Stars, 0)))
	session.starWeek = math.floor(finite(data.StarWeek, -1))
	session.starBought = math.floor(finite(data.StarBought, 0))
	session.equipLevel = math.clamp(math.floor(finite(data.EquipLevel, 0)), 0, #PenConfig.SlotCosts)
	local trail = if typeof(data.EquippedTrail) == "string" then data.EquippedTrail else ""
	session.trail = if session.owned[trail] then trail else ""
end

function Manager.isReady(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.loaded
end

function Manager.gain(player: Player): number
	local session = sessions[player]
	if not session then
		return Economy.tier(1).Gain
	end
	return Economy.tier(session.tier).Gain
end

function Manager.addTraining(player: Player, dt: number)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	if typeof(dt) ~= "number" or dt ~= dt or dt <= 0 then
		return
	end
	dt = math.min(dt, 0.5)
	local gain = Economy.tier(session.tier).Gain
	session.base = math.min(Economy.MaximumSpeed, session.base + gain * dt)
	session.cashBank += gain * dt
	local whole = math.floor(session.cashBank)
	if whole > 0 then
		session.cash += whole
		session.cashBank -= whole
	end
	session.dirty = true
	publish(player)
end

function Manager.setPenalty(player: Player, penalty: number)
	local session = sessions[player]
	if not session then
		return
	end
	if typeof(penalty) ~= "number" or penalty ~= penalty or penalty <= 0 then
		penalty = 1
	end
	-- The heaviest nest egg cuts walk speed in half. Nothing slows past that.
	session.penalty = math.clamp(penalty, 0.5, 1)
	publish(player)
end

function Manager.trySpend(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or not session.loaded then
		return false
	end
	if typeof(amount) ~= "number" or amount ~= amount or amount < 0 then
		return false
	end
	local price = math.floor(amount)
	if session.cash < price then
		return false
	end
	session.cash -= price
	session.dirty = true
	publish(player)
	return true
end

function Manager.cash(player: Player): number
	local session = sessions[player]
	if not session then
		return 0
	end
	return session.cash
end

function Manager.addCash(player: Player, amount: number)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	session.cashBank += amount
	local whole = math.floor(session.cashBank)
	if whole > 0 then
		session.cash += whole
		session.cashBank -= whole
	end
	session.dirty = true
	publish(player)
end

function Manager.refreshCarry(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local tool = (character and character:FindFirstChild("BabyBeast"))
		or (backpack and backpack:FindFirstChild("BabyBeast"))
	local penalty = 1
	if tool then
		local stored = tool:GetAttribute("WeightPenalty")
		if typeof(stored) == "number" then
			penalty = stored
		end
	end
	Manager.setPenalty(player, penalty)
end

local function result(ok: boolean, message: string)
	return ok, message
end

function Manager.buyTrail(player: Player, trailId: string): (boolean, string)
	local session = sessions[player]
	local trail = Economy.trail(trailId)
	if not session or not session.loaded or not trail then
		return result(false, "Shop is still loading")
	end
	if session.owned[trailId] then
		session.trail = trailId
		session.dirty = true
		publish(player)
		return result(true, "Equipped " .. trail.Name)
	end
	if session.cash + 1e-6 < trail.Cash then
		return result(false, "Not enough cash")
	end
	session.cash = math.floor(session.cash - trail.Cash)
	session.owned[trailId] = true
	session.trail = trailId
	session.dirty = true
	publish(player)
	return result(true, "Bought " .. trail.Name)
end

function Manager.grantTrail(player: Player, trailId: string): (boolean, string)
	local session = sessions[player]
	local trail = Economy.trail(trailId)
	if not session or not trail then
		return result(false, "Player is not ready")
	end
	session.owned[trailId] = true
	session.trail = trailId
	session.dirty = true
	if not session.loaded then
		session.loaded = true
	end
	publish(player)
	return result(true, "Unlocked " .. trail.Name)
end

function Manager.equipTrail(player: Player, trailId: string): (boolean, string)
	local session = sessions[player]
	local trail = Economy.trail(trailId)
	if not session or not session.loaded or not trail then
		return result(false, "Shop is still loading")
	end
	if not session.owned[trailId] then
		return result(false, "You do not own that trail")
	end
	session.trail = trailId
	session.dirty = true
	publish(player)
	return result(true, "Equipped " .. trail.Name)
end

function Manager.buyTier(player: Player): (boolean, string)
	local session = sessions[player]
	if not session or not session.loaded then
		return result(false, "Speed is still loading")
	end
	local nextTier = Economy.nextTier(session.tier)
	if not nextTier then
		return result(false, "Treadmill is fully upgraded")
	end
	if session.cash + 1e-6 < nextTier.Cost then
		local robux = if nextTier.Robux > 0 then (" or " .. tostring(nextTier.Robux) .. " Robux") else ""
		return result(false, "Need " .. Economy.formatCash(nextTier.Cost) .. robux)
	end
	session.cash = math.floor(session.cash - nextTier.Cost)
	session.tier = nextTier.Tier
	session.dirty = true
	publish(player)
	return result(true, nextTier.Name .. "  +" .. tostring(nextTier.Gain) .. "/sec")
end

-- Robux / grant path: upgrade exactly one tier when the receipt matches the next tier.
function Manager.grantTier(player: Player, targetTier: number): (boolean, string)
	local session = sessions[player]
	if not session or not session.loaded then
		return result(false, "Speed is still loading")
	end
	local nextTier = Economy.nextTier(session.tier)
	if not nextTier then
		return result(false, "Treadmill is fully upgraded")
	end
	if nextTier.Tier ~= math.floor(targetTier) then
		return result(false, "Wrong upgrade product for this treadmill")
	end
	session.tier = nextTier.Tier
	session.dirty = true
	publish(player)
	return result(true, nextTier.Name .. "  +" .. tostring(nextTier.Gain) .. "/sec")
end

-- Dev / one-shot: jump a player to any treadmill level (1 .. #Economy.Tiers).
function Manager.setTier(player: Player, tier: number): (boolean, string)
	local session = sessions[player]
	if not session then
		return result(false, "Player has no speed session")
	end
	local level = math.clamp(math.floor(tier), 1, #Economy.Tiers)
	local info = Economy.tier(level)
	session.tier = level
	session.dirty = true
	if not session.loaded then
		session.loaded = true
	end
	publish(player)
	return result(true, info.Name .. " (level " .. tostring(level) .. ")")
end

local function save(player: Player)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	if session.saving then
		while session.saving do
			task.wait(0.1)
		end
	end
	if not session.dirty then
		return
	end
	session.saving = true
	local snapshot = {
		Version = 2,
		BaseSpeed = session.base,
		Cash = math.floor(session.cash),
		TreadmillTier = session.tier,
		EquippedTrail = session.trail,
		OwnedTrails = ownedList(session.owned),
		Perks = ownedList(session.perks),
		LuckyWeek = session.luckyWeek,
		LuckyBought = session.luckyBought,
		Stars = session.stars,
		StarWeek = session.starWeek,
		StarBought = session.starBought,
		IndexDiscovered = ownedList(session.discovered),
		IndexClaimed = ownedList(session.claimed),
		EquipLevel = session.equipLevel,
	}
	local success = false
	for attempt = 1, 3 do
		local ok = pcall(function()
			store:UpdateAsync("u_" .. player.UserId, function()
				return snapshot
			end)
		end)
		if ok then
			success = true
			break
		end
		task.wait(attempt)
	end
	session.saving = false
	if success then
		session.dirty = session.base > snapshot.BaseSpeed
			or math.floor(session.cash) ~= snapshot.Cash
			or #ownedList(session.perks) ~= #snapshot.Perks
			or session.luckyBought ~= snapshot.LuckyBought
			or session.stars ~= snapshot.Stars
			or session.starBought ~= snapshot.StarBought
			or #ownedList(session.discovered) ~= #snapshot.IndexDiscovered
			or #ownedList(session.claimed) ~= #snapshot.IndexClaimed
			or session.equipLevel ~= snapshot.EquipLevel
	elseif player.Parent then
		player:SetAttribute("SpeedSaveError", true)
		warn("[Speed] Save failed for " .. player.UserId)
	end
end

local function loadPlayer(player: Player)
	local session = blank()
	sessions[player] = session
	publish(player)
	for attempt = 1, 3 do
		local ok, data = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			if not player.Parent then
				return
			end
			if data == nil then
				local oldOk, old = pcall(function()
					return legacy:GetAsync("u_" .. player.UserId)
				end)
				if oldOk then
					data = old
				end
			end
			local granted = if session.dirty then ownedList(session.owned) else nil
			local perksDuring = if session.dirty then ownedList(session.perks) else nil
			local foundDuring = ownedList(session.discovered)
			local equippedDuring = if session.dirty then session.trail else ""
			applyData(session, data)
			if granted then
				for _, id in granted do
					session.owned[id] = true
				end
				for _, id in perksDuring or {} do
					session.perks[id] = true
				end
				if equippedDuring ~= "" then
					session.trail = equippedDuring
				end
			end
			for _, id in foundDuring do
				session.discovered[id] = true
			end
			session.loaded = true
			session.dirty = granted ~= nil
			publish(player)
			Manager.refreshCarry(player)
			return
		end
		task.wait(attempt * 2)
	end
	session.loaded = true
	session.dirty = false
	publish(player)
	player:SetAttribute("SpeedLoadError", true)
	warn("[Speed] Could not load save; starting at 16 for " .. player.UserId)
end

local function hookCharacter(player: Player, character: Model)
	local function refresh()
		Manager.refreshCarry(player)
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "BabyBeast" then
			refresh()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "BabyBeast" then
			task.defer(refresh)
		end
	end)
	task.defer(refresh)
end

function Manager.start()
	if started then
		return
	end
	started = true
	-- HUD speed slider: 0 = stock WalkSpeed, 1 = full trained pace.
	local shared = game.ReplicatedStorage.BabyBeastsShared
	local remotes = shared:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = shared
	end
	local setScale = remotes:FindFirstChild("SetSpeedScale")
	if not setScale then
		setScale = Instance.new("RemoteEvent")
		setScale.Name = "SetSpeedScale"
		setScale.Parent = remotes
	end
	;(setScale :: RemoteEvent).OnServerEvent:Connect(function(player, value)
		if typeof(value) == "number" and value == value then
			player:SetAttribute("SpeedScale", math.clamp(value, 0, 1))
		end
	end)
	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal("SpeedScale"):Connect(function()
			local session = sessions[player]
			if session then
				applyHumanoid(player, pace(session))
			end
		end)
		player:GetAttributeChangedSignal("MovementMode"):Connect(function()
			local session = sessions[player]
			if session then
				applyHumanoid(player, pace(session))
			end
		end)
		player:GetAttributeChangedSignal("MommyState"):Connect(function()
			local session = sessions[player]
			if session then
				applyHumanoid(player, pace(session))
			end
		end)
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character then
			hookCharacter(player, player.Character)
		end
		task.spawn(loadPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessions[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Economy.SaveInterval)
			for player in sessions do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Pen equip slots (PenConfig) --------------------------------------------------------------------

-- How many hatched pets can earn in the player's pen at once.
function Manager.equipSlots(player: Player): number
	local session = sessions[player]
	return PenConfig.slots(if session then session.equipLevel else 0)
end

-- "+1 EQUIP": buy the next slot with cash.
function Manager.buyEquipSlot(player: Player): (boolean, string)
	local session = sessions[player]
	if not session or not session.loaded then
		return false, "Still loading, try again in a moment"
	end
	local cost = PenConfig.nextCost(session.equipLevel)
	if not cost then
		return false, "Max equip slots reached!"
	end
	if session.cash + 1e-6 < cost then
		return false, "Not enough money! Need " .. Economy.formatCash(cost)
	end
	session.cash = math.floor(session.cash - cost)
	session.equipLevel += 1
	session.dirty = true
	publish(player)
	task.spawn(save, player)
	return true, "+1 Equip slot! You can now have " .. PenConfig.slots(session.equipLevel) .. " active pets."
end

-- Shop passes ------------------------------------------------------------------------------------

function Manager.hasPass(player: Player, id: string): boolean
	local session = sessions[player]
	return session ~= nil and hasPass(session, id)
end

-- saved: bought as a gift / developer product (or a vehicle). Otherwise a Game Pass the player owns.
function Manager.grantPass(player: Player, id: string, saved: boolean): boolean
	local session = sessions[player]
	if not session or not ShopConfig.perk(id) then
		return false
	end
	if saved then
		session.perks[id] = true
		session.dirty = true
	else
		session.passes[id] = true
	end
	publish(player)
	if saved and session.loaded then
		task.spawn(save, player)
	end
	return true
end

function Manager.luckyLeft(player: Player): number
	local session = sessions[player]
	return if session then luckyLeft(session) else 0
end

-- Count Lucky Eggs bought this week (paid receipts always count, even past the stock).
function Manager.takeLucky(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or not session.loaded then
		return false
	end
	local week = ShopConfig.week(os.time())
	if session.luckyWeek ~= week then
		session.luckyWeek = week
		session.luckyBought = 0
	end
	session.luckyBought += amount
	session.dirty = true
	publish(player)
	task.spawn(save, player)
	return true
end

-- Mount Stars -----------------------------------------------------------------------------------

function Manager.stars(player: Player): number
	local session = sessions[player]
	return if session then session.stars else 0
end

function Manager.starsLeft(player: Player): number
	local session = sessions[player]
	return if session then starsLeft(session) else 0
end

-- bought: a shop purchase (counts against the weekly stock; paid receipts always land).
function Manager.addStars(player: Player, amount: number, bought: boolean?): boolean
	local session = sessions[player]
	if not session or not session.loaded or amount ~= amount then
		return false
	end
	amount = math.floor(amount)
	if bought then
		local week = ShopConfig.week(os.time())
		if session.starWeek ~= week then
			session.starWeek = week
			session.starBought = 0
		end
		session.starBought += amount
	end
	session.stars = math.max(0, session.stars + amount)
	session.dirty = true
	publish(player)
	task.spawn(save, player)
	return true
end

-- Spend one star (feeding a pet). False when there is none.
function Manager.useStar(player: Player): boolean
	local session = sessions[player]
	if not session or not session.loaded or session.stars < 1 then
		return false
	end
	session.stars -= 1
	session.dirty = true
	publish(player)
	task.spawn(save, player)
	return true
end

-- Pet Index ----------------------------------------------------------------------------------------
-- Rewards follow Steal an Egg: each pet you have hatched can be claimed once for its income x
-- PetIndexConfig.CashSeconds in cash, plus its SpeedReward added to your base speed.
-- PetIndexConfig is saved in the place (not in src), so it is looked up when first needed.

local indexConfig: any = nil
local function index(): any
	if indexConfig == nil then
		local module = game.ReplicatedStorage:WaitForChild("BabyBeastsShared"):FindFirstChild("PetIndexConfig")
		local ok, loaded = pcall(function()
			return require(module :: ModuleScript)
		end)
		indexConfig = if ok and typeof(loaded) == "table" then loaded else false
		if not indexConfig then
			warn("[PetIndex] PetIndexConfig missing: ", loaded)
		end
	end
	return indexConfig or nil
end

function Manager.indexSnapshot(player: Player)
	local session = sessions[player]
	if not session then
		return { Ready = false, Discovered = {}, Claimed = {} }
	end
	return { Ready = session.loaded, Discovered = table.clone(session.discovered), Claimed = table.clone(session.claimed) }
end

-- eggName: a pen pet's egg / species name. Returns true when it is new to the index.
function Manager.discoverPet(player: Player, eggName: string): boolean
	local session = sessions[player]
	local config = index()
	if not session or not session.loaded or not config or typeof(eggName) ~= "string" then
		return false
	end
	local entry = config.resolve(eggName)
	if not entry or session.discovered[entry.Id] then
		return false
	end
	session.discovered[entry.Id] = true
	session.dirty = true
	player:SetAttribute("PetIndexRevision", (player:GetAttribute("PetIndexRevision") or 0) + 1)
	return true
end

function Manager.claimIndex(player: Player, id: string): (boolean, string)
	local session = sessions[player]
	local config = index()
	if not session or not session.loaded or not config then
		return false, "Your collection is still loading"
	end
	local entry = config.ById[id]
	if not entry then
		return false, "Unknown pet"
	elseif not session.discovered[entry.Id] then
		return false, "Hatch a " .. entry.Name .. " to claim this"
	elseif session.claimed[entry.Id] then
		return false, "Already claimed"
	end
	session.claimed[entry.Id] = true
	local cash = math.max(0, math.floor(entry.CashReward or 0))
	local speed = math.max(0, math.floor(entry.SpeedReward or 0))
	session.cash += cash
	session.base = math.min(Economy.MaximumSpeed, session.base + speed)
	session.dirty = true
	publish(player)
	task.spawn(save, player)
	return true, "Claimed " .. Economy.formatCash(cash) .. " and +" .. speed .. " speed!"
end

function Manager.saveNow(player: Player)
	save(player)
end

function Manager.setBase(player: Player, value: number): boolean
	local session = sessions[player]
	if not session or not session.loaded then
		return false
	end
	if typeof(value) ~= "number" or value ~= value then
		return false
	end
	session.base = math.clamp(value, Economy.StartingSpeed, Economy.MaximumSpeed)
	session.dirty = true
	publish(player)
	save(player)
	return true
end

return Manager
