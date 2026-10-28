--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.AdminEggs
-- Admin egg tools, after Steal an Egg's Cmdr admin commands (giveEgg, spawnRareEgg,
-- globalEggLuckBoost, startEvent AdminAbuse, resetEggCycle, globalAlertShops). Type in chat:
--   ;give <me|all|others|name> <egg> [Silver|Golden|Rainbow] [huge]   (admin-only eggs too)
--   ;drop <egg> [mutation] [huge]       stealable egg on the red plaza pad
--   ;spawnrare [mutation]               one rare egg replaces a nest egg in a random biome
--   ;luck <multiplier> <seconds>        egg spawn luck (re-rolls the nests now)
--   ;abuse <minutes> | ;abuse off       Admin Abuse: luck + Admin Abuse Egg drops in the plaza
--   ;event <id> on|off|auto             force a limited-time event (Halloween, Rift)
--   ;restock / ;retrade / ;reset        new shop stock / new trade-in recipe / re-roll nests
--   ;global <command>                   run luck/abuse/event/restock/retrade/spawnrare/reset everywhere
-- Admins: the place owner (or group rank >= GroupRank), EggSources.Admin.UserIds, and Studio.
-- ServerStorage.AdminEggsRun (BindableFunction) runs a command line as the server, for testing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local EggScale = require(Shared.EggScale)
local EggSources = require(Shared.EggSources)
local GameEgg = require(Shared.GameEgg)
local GameUI = require(Shared.GameUI)
local CaveBubbles = require(script.Parent.CaveBubbles)
local EggShop = require(script.Parent.EggShop)

local AdminEggs = {}
local TOPIC = "BabyBeastsAdminEggs"
local GLOBAL_OK = { luck = true, abuse = true, event = true, restock = true, retrade = true, spawnrare = true, reset = true }
local MUTATIONS = { silver = "Silver", golden = "Golden", rainbow = "Rainbow" }

local started = false
local announce: RemoteEvent
-- commands other systems add with AdminEggs.command (e.g. MountService: stars, stardrop, rideable)
local extra: { [string]: { help: string, run: (caller: Player?, words: { string }) -> string } } = {}
local abuseToken = 0

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(EggSources.Admin.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= EggSources.Admin.GroupRank
end

local function shout(text: string, color: Color3?)
	announce:FireAllClients({ text = text, color = color or Color3.fromRGB(255, 90, 90) })
end

-- Case-insensitive egg / container name lookup.
local nameIndex: { [string]: string } = {}
local function indexName(name: string)
	nameIndex[string.lower(name)] = name
end
for name in GameEgg.ByName do
	indexName(name)
end
for name in EggSources.Containers do
	indexName(name)
end
for _, rows in EggSources.Biomes do
	for _, row in rows do
		indexName(row[1])
	end
end

local function resolveEgg(text: string): string?
	local lowered = string.lower(text)
	if nameIndex[lowered] then
		return nameIndex[lowered]
	end
	if GameEgg.get(text) then
		return text
	end
	-- unique prefix match ("tung" -> "Tung Tung Sahur")
	local found: string? = nil
	for key, name in nameIndex do
		if string.sub(key, 1, #lowered) == lowered then
			if found and found ~= name then
				return nil
			end
			found = name
		end
	end
	return found
end

-- Trailing "[mutation] [huge]" off an egg argument list ("huge" or a number; EggScale.sizeOf keeps only Huge / ~1x).
local function eggArgs(words: { string }): (string?, string?, number?)
	local list = table.clone(words)
	local size: number? = nil
	local mutation: string? = nil
	local last = list[#list]
	if last and string.lower(last) == "huge" then
		size = EggScale.HUGE_SCALE
		table.remove(list)
	elseif last and tonumber(last) then
		size = tonumber(last)
		table.remove(list)
	end
	-- a full egg name wins over a leading mutation word ("Golden Retriever")
	local whole = nameIndex[string.lower(table.concat(list, " "))]
	if whole then
		return whole, nil, size
	end
	-- the mutation may come before or after the egg name
	for index = #list, 1, -1 do
		local word = MUTATIONS[string.lower(list[index])]
		if word and (index == 1 or index == #list) then
			mutation = word
			table.remove(list, index)
			break
		end
	end
	if #list == 0 then
		return nil, mutation, size
	end
	return resolveEgg(table.concat(list, " ")), mutation, size
end

local function targets(caller: Player?, who: string): { Player }
	local lowered = string.lower(who)
	if lowered == "me" then
		return if caller then { caller } else {}
	elseif lowered == "all" then
		return Players:GetPlayers()
	elseif lowered == "others" then
		local list = {}
		for _, player in Players:GetPlayers() do
			if player ~= caller then
				table.insert(list, player)
			end
		end
		return list
	end
	for _, player in Players:GetPlayers() do
		if string.sub(string.lower(player.Name), 1, #lowered) == lowered or string.sub(string.lower(player.DisplayName), 1, #lowered) == lowered then
			return { player }
		end
	end
	return {}
end

local function setLuck(multiplier: number, seconds: number)
	multiplier = math.clamp(multiplier, 1, 100)
	if multiplier <= 1 or seconds <= 0 then
		Workspace:SetAttribute("AdminBoost_EggSpawnLuck", nil)
		Workspace:SetAttribute("AdminBoost_EggSpawnLuckUntil", nil)
		return
	end
	Workspace:SetAttribute("AdminBoost_EggSpawnLuck", multiplier)
	Workspace:SetAttribute("AdminBoost_EggSpawnLuckUntil", os.time() + seconds)
end

local function scatter(): Vector3
	local angle = math.random() * math.pi * 2
	local radius = math.random() * 6
	return EggShop.dropPoint() + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function startAbuse(minutes: number)
	abuseToken += 1
	local token = abuseToken
	local seconds = math.clamp(minutes, 0.5, 120) * 60
	local endsAt = os.time() + seconds
	Workspace:SetAttribute("AdminAbuseUntil", endsAt)
	setLuck(EggSources.Admin.AbuseLuck, seconds)
	CaveBubbles.reset()
	shout(string.format("ADMIN ABUSE! x%d egg luck + eggs dropping in the plaza for %d min", EggSources.Admin.AbuseLuck, math.ceil(seconds / 60)))
	task.spawn(function()
		local rng = Random.new()
		while token == abuseToken and os.time() < endsAt do
			local egg = EggSources.open("Admin Abuse Egg", rng)
			CaveBubbles.drop(egg, scatter(), nil, nil)
			task.wait(EggSources.Admin.AbuseDropEvery)
		end
		if token == abuseToken then
			Workspace:SetAttribute("AdminAbuseUntil", nil)
			shout("Admin Abuse is over", Color3.fromRGB(255, 244, 210))
		end
	end)
end

local function stopAbuse()
	abuseToken += 1
	Workspace:SetAttribute("AdminAbuseUntil", nil)
	setLuck(1, 0)
end

local run: (caller: Player?, line: string, fromGlobal: boolean?) -> string

local function publish(line: string): string
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, line)
	end)
	if not ok then
		-- Studio / no access: still run it here
		return run(nil, line, true) .. " (this server only: " .. tostring(err) .. ")"
	end
	return "sent to all servers: " .. line
end

run = function(caller: Player?, line: string, fromGlobal: boolean?): string
	local words = string.split(line, " ")
	for index = #words, 1, -1 do
		if words[index] == "" then
			table.remove(words, index)
		end
	end
	local command = string.lower(table.remove(words, 1) or "")
	if command == "global" then
		local inner = string.lower(words[1] or "")
		if not GLOBAL_OK[inner] then
			return "global works with: luck, abuse, event, restock, retrade, spawnrare, reset"
		end
		return publish(table.concat(words, " "))
	elseif command == "give" then
		local who = table.remove(words, 1)
		local egg, mutation, size = eggArgs(words)
		if not who or not egg then
			return "usage: ;give <me|all|others|name> <egg> [mutation] [huge]"
		end
		local list = targets(caller, who)
		local rng = Random.new()
		for _, player in list do
			local eggName = EggSources.open(egg, rng)
			local source = if EggSources.AdminOnly[eggName] then "AdminOnly" else "Admin"
			CaveBubbles.grant(player, eggName, { mutation = mutation, size = size, source = source })
		end
		return string.format("gave %s to %d player(s)", egg, #list)
	elseif command == "drop" then
		local egg, mutation, size = eggArgs(words)
		if not egg then
			return "usage: ;drop <egg> [mutation] [huge]"
		end
		local eggName = EggSources.open(egg, Random.new())
		local rec = CaveBubbles.drop(eggName, scatter(), mutation, size)
		if not rec then
			return "could not drop " .. eggName
		end
		shout("An admin dropped a " .. (if mutation then mutation .. " " else "") .. eggName .. " in the plaza!")
		return "dropped " .. eggName
	elseif command == "spawnrare" then
		local mutation = MUTATIONS[string.lower(words[1] or "")]
		local rare = CaveBubbles.spawnRare(mutation)
		if not rare then
			return "no nest egg to replace (night?)"
		end
		-- same banner + chat line as a reset's rare spawns
		GameUI.remote("NightNotice"):FireAllClients({ rares = { rare } })
		return "spawned " .. rare.name .. " in " .. rare.biome
	elseif command == "luck" then
		local multiplier = tonumber(words[1] or "")
		local seconds = tonumber(words[2] or "") or 300
		if not multiplier then
			return "usage: ;luck <multiplier 1-100> <seconds>"
		end
		setLuck(multiplier, seconds)
		CaveBubbles.reset()
		if multiplier > 1 then
			shout(string.format("x%s EGG LUCK for %d min!", tostring(multiplier), math.ceil(seconds / 60)), Color3.fromRGB(120, 255, 160))
		end
		return "luck x" .. multiplier .. " for " .. seconds .. "s"
	elseif command == "abuse" then
		if string.lower(words[1] or "") == "off" then
			stopAbuse()
			shout("Admin Abuse is over", Color3.fromRGB(255, 244, 210))
			return "admin abuse stopped"
		end
		startAbuse(tonumber(words[1] or "") or 10)
		return "admin abuse started"
	elseif command == "event" then
		local id = words[1]
		local mode = string.lower(words[2] or "")
		local event = nil
		for eventId, row in EggSources.Events do
			if id and string.lower(eventId) == string.lower(id) then
				event = row
			end
		end
		if not event then
			local ids = {}
			for eventId in EggSources.Events do
				table.insert(ids, eventId)
			end
			table.sort(ids)
			return "events: " .. table.concat(ids, ", ") .. "  (;event <id> on|off|auto)"
		end
		Workspace:SetAttribute("EggEvent_" .. event.Id, if mode == "on" then true elseif mode == "off" then false else nil)
		local live = EggSources.eventLive(event.Id)
		CaveBubbles.reset()
		shout(event.DisplayName .. (if live then " is LIVE!" else " has ended. Its eggs are vaulted."), event.Color)
		return event.Id .. " live = " .. tostring(live)
	elseif command == "restock" then
		Workspace:SetAttribute("EggShopSalt", math.random(1, 1e6))
		shout("The Egg Shop restocked!", Color3.fromRGB(255, 196, 64))
		return "shop restocked"
	elseif command == "retrade" then
		Workspace:SetAttribute("TradeInSalt", math.random(1, 1e6))
		shout("Dr. Scramble wants new pets!", Color3.fromRGB(110, 255, 150))
		return "trade-in recipe rerolled"
	elseif command == "reset" then
		CaveBubbles.reset()
		return "nests re-rolled"
	elseif extra[command] then
		return extra[command].run(caller, words)
	end
	local names = { "give", "drop", "spawnrare", "luck", "abuse", "event", "restock", "retrade", "reset", "global" }
	for name in extra do
		table.insert(names, name)
	end
	return "commands: " .. table.concat(names, ", ")
end

local function tell(player: Player, text: string)
	announce:FireClient(player, { text = text, color = Color3.fromRGB(200, 220, 255), small = true })
end

local function hook(player: Player)
	player.Chatted:Connect(function(message: string)
		if string.sub(message, 1, 1) ~= ";" or not isAdmin(player) then
			return
		end
		local ok, result = pcall(run, player, string.sub(message, 2))
		tell(player, if ok then result else "error: " .. tostring(result))
	end)
end

-- Add a chat command (;name ...). run gets the words after the command name.
function AdminEggs.command(name: string, help: string, fn: (caller: Player?, words: { string }) -> string)
	extra[string.lower(name)] = { help = help, run = fn }
end

AdminEggs.targets = function(caller: Player?, who: string): { Player }
	return targets(caller, who)
end

function AdminEggs.run(line: string): string
	return run(nil, line)
end

function AdminEggs.start()
	if started then
		return
	end
	started = true
	announce = GameUI.remote("EggAnnouncement")
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				if typeof(message.Data) == "string" then
					local word = string.lower(string.split(message.Data, " ")[1] or "")
					if GLOBAL_OK[word] then
						pcall(run, nil, message.Data, true)
					end
				end
			end)
		end)
		if not ok then
			warn("[AdminEggs] global commands unavailable: " .. tostring(err))
		end
	end)
	local bindable = ServerStorage:FindFirstChild("AdminEggsRun")
	if bindable then
		bindable:Destroy()
	end
	local runner = Instance.new("BindableFunction")
	runner.Name = "AdminEggsRun"
	runner.OnInvoke = function(line: string)
		return run(nil, line)
	end
	runner.Parent = ServerStorage
	print("[BabyBeasts] Admin egg commands ready (; prefix)")
end

return AdminEggs
