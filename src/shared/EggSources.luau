--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.EggSources
-- Where every egg comes from, following Steal an Egg:
--   Biome     - weighted nest drop tables (Data.Areas.*.DropTable). Only these sit in biome nests.
--   Event     - limited-time events (Halloween Dimension, Rift). Live between StartsAt and EndsAt,
--               vaulted after. Their eggs show up in host-biome nests and the event shop tab.
--   Shop      - restock rotation (same stock on every server for the same window), cash prices.
--   Limited   - Robux-only eggs sold in x1/x3/x10/x50 offers until EndsAt (Data.LimitedEgg).
--   Admin     - Admin Abuse / Brainrot eggs dropped by admins (Data.AdminAbuseEgg, BrainrotEgg).
--   AdminOnly - testing / giveaway eggs; only an admin ;give hands these out.
--   TradeIn   - Dr. Scramble's machine: three pen pets from a rotating recipe for an event egg.
-- A "container" egg (Halloween Dimension Egg, Brainrot Egg...) rolls one egg from its DropTable
-- when it is granted, like Steal an Egg rolls the pet an event egg hatches into.

local Workspace = game:GetService("Workspace")
local GameEgg = require(script.Parent.GameEgg)
local BiomeConfig = require(script.Parent.BiomeConfig)

export type Drop = { any } -- { eggName: string, weight: number }

export type Container = {
	Id: string,
	DisplayName: string,
	Model: string, -- GameEgg name shown on cards
	Category: string,
	EventId: string?,
	Price: number?, -- cash, when it is sold for cash
	DropTable: { Drop },
}

export type Event = {
	Id: string,
	DisplayName: string,
	StartsAt: number, -- unix seconds (UTC)
	EndsAt: number,
	HostBiomes: { string },
	HostChance: number, -- per nest slot in a host biome
	NestChance: number, -- per nest slot anywhere else
	NestPool: { Drop },
	Container: string, -- sold in the event shop tab while live
	Color: Color3,
}

export type Limited = {
	Id: string,
	Container: string,
	EndsAt: number,
	RobuxPerEgg: number,
	Offers: { number },
}

export type Offer = {
	Slot: number,
	Name: string, -- egg name or container id
	IsContainer: boolean,
	Price: number,
	Stock: number,
	Rare: boolean,
}

export type Recipe = {
	Index: number,
	Banner: string,
	Pets: { string },
	EndsAt: number,
}

local EggSources = {}

-- Steal An Egg's 8-tier weight curve (Cherry Blossom / Titan Temple / Light Dark tables).
local CURVE = { 37.51, 26.27, 16.83, 13.96, 4.36, 0.74, 0.31, 0.02 }

-- Ordered common -> rare; weights come from CURVE (the rarest always takes the last tier).
local function curved(names: { string }): { Drop }
	local rows = {}
	for index, name in names do
		local weight = if index == #names then CURVE[#CURVE] else CURVE[math.min(index, #CURVE - 1)]
		table.insert(rows, { name, weight })
	end
	return rows
end

-- Biome nests ----------------------------------------------------------------------------------
-- Reference biomes use Steal An Egg's own tables. Our extra biomes use CURVE over permanent eggs, ordered
-- small -> super, each a set of its own (only themed sea / spooky biomes share with a reference biome).
-- This is the one biome -> egg table: nests, the Pet Index and egg rarity (EggScale.rarityOf) read it.
local BIOMES: { [string]: { Drop } } = {
	-- Everyday backyard pets, found nowhere else: 3 Common, 1 Uncommon, 2 Rare, 2 Epic, 1 Legendary.
	["Cozy Backyard"] = {
		{ "Dog", 24 },
		{ "Bunny", 22 },
		{ "Squirrel", 20 },
		{ "Kitten", 16 },
		{ "Hamster", 6.5 },
		{ "Goldfish", 5.5 },
		{ "Hedgehog", 2.6 },
		{ "Parrot", 2.2 },
		{ "Golden Retriever", 0.2 },
	},
	["Forest"] = { { "Chicken", 34 }, { "DesertLark", 17 }, { "Burrowing Owl", 10 }, { "Raccoon", 7 }, { "Mire Fox", 4.5 }, { "Bear", 2.5 }, { "Brr Brr Patapim", 1 } },
	["Bamboo Grove"] = curved({ "Banjo Firefly", "Petal Beetle", "Engine Snail", "Starry Wolf", "Astral Jackalope", "Baby Aurora Dragon", "Celestial Sunlion" }),
	["Lake"] = { { "Frog", 29.274167 }, { "Duckling", 23.217443 }, { "Catfish", 17.160719 }, { "Turtle", 12.113448 }, { "Trulimero Trulicina", 8.075632 }, { "Swan", 5.551997 }, { "Dream Axolotl", 4.037816 }, { "Basilisk", 0.568777 } },
	["Toxic Swamplands"] = curved({ "Abomination Kong Egg", "Toadstool Egg", "Toxic Crocodile", "Uncoiled Armadillo", "Mushroom Egg", "Toxic Hedgehog", "Unstable" }),
	["Desert"] = { { "Jerboa", 26.585432 }, { "FennecFox", 20.450332 }, { "Camel", 15.337749 }, { "Tob Tobi Tob Tob", 12.270199 }, { "Rattlesnake", 9.20265 }, { "Sand Spider", 8.180133 }, { "DeathstalkerScorpion", 6.646358 }, { "Irihorus", 1.327147 } },
	["Crystal Cavern"] = curved({ "Nibbles #013", "Ring Guard", "Ringlord", "Amethyst Runebear", "Crystal Egg", "Equinox" }),
	["Jungle"] = { { "Chimpanzee", 26.006779 }, { "Toucan", 20.005214 }, { "Crocodile", 17.004432 }, { "Gorilla", 13.003389 }, { "Orangutini Ananassini", 11.002868 }, { "Spider", 7.852047 }, { "Tiger", 5.001304 }, { "Warden", 0.123968 } },
	["Pirate Cove"] = curved({ "Shelltide Voyager Egg", "Citadel Snail", "Swordfish", "Shadow Dragon", "67", "ScorchedDragon" }),
	["Snow"] = { { "Penguin", 29.444067 }, { "Walrus", 21.570745 }, { "Polar Bear", 18.335133 }, { "Sabertooth Tiger", 14.020984 }, { "Mammoth", 11.86391 }, { "Colossal Mammoth", 4.171033 }, { "Yeti", 0.371904 }, { "Ice Dragon", 0.222224 } },
	["Neon Cyberpunk"] = curved({ "Mecha Egg", "Hooded Gerbil Egg", "Drill Monster", "Void Dragon", "Abyss Overlord" }),
	["Volcano"] = { { "Ash Gecko", 26.848869 }, { "Lava frog", 22.040116 }, { "Flaming Bull", 18.032822 }, { "Lava Iguana", 15.027352 }, { "Chillin Chilli", 17.030999 }, { "Cerberus", 0.61984 }, { "Ascended Vermilion Phoenix", 0.222224 }, { "Dragon", 0.177779 } },
	["Sunken Atlantis"] = curved({ "Parrotfish", "Race Seahorse", "Orca", "Jellyfish", "Ghost Fish" }),
	["Abyss Ocean"] = { { "Parrotfish", 34.755713 }, { "Swordfish", 24.665345 }, { "Finned Thresher", 19.059585 }, { "Orca", 14.574977 }, { "Whale Shark", 3.412663 }, { "Alabaster Whale", 2.616375 }, { "Kraken", 0.826453 }, { "El Maja", 0.08889 } },
	-- Permanent spooky pets; it hosts the Halloween event, so event eggs crowd in while it runs.
	["Haunted Graveyard"] = curved({ "Eye Bat", "Imp", "Demon Hound", "Dark Gargoyle", "Cerberus", "RazorFang", "Skeleton Horse" }),
	["Prehistoric"] = { { "Dodo", 39.066058 }, { "Pterodactyl", 26.044039 }, { "Ankylosaurus", 20.835231 }, { "Triceratops", 4.929402 }, { "Bronto", 6.995959 }, { "TyrannosaurusRex", 0.991743 }, { "Tralaledon", 0.826453 }, { "Mosasaurus", 0.311113 } },
	["Candy Kingdom"] = curved({ "Duckling", "Lamb", "Snowy Owl", "Ember Dragon", "World Spirit" }),
	["Cosmic"] = { { "Centapede", 39.869773 }, { "Galaxy Gecko", 34.387407 }, { "Cyclops Gorilla", 19.618806 }, { "La Vacca Saturno Saturnita", 4.550072 }, { "Alien Skeleton Boss", 0.495856 }, { "Cave Dragon", 0.743784 } }, -- Unicorn / Eternal Lunar Dragon live in Celestial Realm
	["Cherry Blossom"] = { { "Crane", 37.51 }, { "Salamander", 26.27 }, { "Red Panda", 16.83 }, { "Snowy Owl", 13.96 }, { "Koi", 4.36 }, { "Stag", 0.74 }, { "Oni Tiger", 0.31 }, { "Kitsune", 0.02 } },
	-- the end-game biome has few small eggs, so its big ones get explicit rare weights (size follows rarity)
	["Celestial Realm"] = { { "Galaxy Gecko", 55 }, { "Ostrich", 30 }, { "Unicorn", 10 }, { "Eternal Lunar Dragon", 4.5 }, { "Aetheron", 0.05 } },
	["Titan Temple"] = { { "Kaiju Spider", 37.51 }, { "Crab", 26.27 }, { "Shark", 16.83 }, { "Mantis", 13.96 }, { "Rhino", 4.36 }, { "Blade Head", 0.74 }, { "King Kong", 0.31 }, { "Godzilla", 0.02 } },
	-- Steal An Egg's "Light Dark" biome as one zone: Angels on one side, Demons on the other.
	["Angels & Demons"] = { { "Flame Sprite", 37.51 }, { "Toro", 26.27 }, { "Imp", 16.83 }, { "Demon Hound", 13.96 }, { "Dark Gargoyle", 4.36 }, { "RazorFang", 0.74 }, { "Skeleton Horse", 0.31 }, { "World Burner", 0.02 }, { "Dove", 37.51 }, { "Lamb", 26.27 }, { "Moth", 16.83 }, { "Peacock", 13.96 }, { "Jellyfish", 4.36 }, { "Centaur", 0.74 }, { "Pegasus", 0.31 }, { "ArchAngel", 0.02 } },
	["Enchanted Forest"] = { { "Prism Gecko", 37.51 }, { "Cosmic Beetle Blue", 26.27 }, { "Enchanted Bluejay", 16.83 }, { "Cosmic Fox", 0.74 }, { "Spirit Panda", 4.36 }, { "Spirit Hare", 13.96 }, { "Royal Skywhale", 0.02 }, { "Cosmic Lion", 0.31 } },
}

-- Containers ------------------------------------------------------------------------------------
local CONTAINERS: { [string]: Container } = {
	-- Data.HalloweenDimensionEgg: 51 / 24 / 18 / 6.5 / 0.5
	["Halloween Dimension Egg"] = {
		Id = "Halloween Dimension Egg",
		DisplayName = "Halloween Dimension Egg",
		Model = "Halloween Dimension Egg",
		Category = "Event",
		EventId = "Halloween",
		Price = 25000,
		DropTable = { { "Candy Corn Egg", 51 }, { "Halloween Egg", 24 }, { "Hexed Pumpkin Egg", 18 }, { "Halloween Royal Mimic Egg", 6.5 }, { "Halloween Boss Egg", 0.5 } },
	},
	["Rift Egg"] = {
		Id = "Rift Egg",
		DisplayName = "Rift Egg",
		Model = "Shattered Rift Egg",
		Category = "Event",
		EventId = "Rift",
		Price = 400000,
		DropTable = { { "Riftborn Egg", 55 }, { "Riftbeasts Egg", 35 }, { "Shattered Rift Egg", 10 } },
	},
	-- Data.LimitedEgg: the egg, with a small chance of its re-roll ("Depths ", "Skeletal ").
	["Depths Egg"] = {
		Id = "Depths Egg",
		DisplayName = "Depths Egg",
		Model = "Depths Egg",
		Category = "Limited",
		DropTable = { { "Depths Egg", 99 }, { "Depths Reroll Egg", 1 } },
	},
	["Extinction Egg"] = {
		Id = "Extinction Egg",
		DisplayName = "Extinction Egg",
		Model = "Extinction Egg",
		Category = "Limited",
		DropTable = { { "Extinction Egg", 99 }, { "Skeletal Egg", 1 } },
	},
	-- Data.BrainrotEgg, exactly.
	["Brainrot Egg"] = {
		Id = "Brainrot Egg",
		DisplayName = "Brainrot Egg",
		Model = "Bananita Dolphinita",
		Category = "Admin",
		Price = 75000,
		DropTable = { { "Tung Tung Sahur", 39 }, { "Bananita Dolphinita", 25 }, { "Belula Beluga", 20 }, { "Mangolini Parrochini", 10 }, { "Bomboclat Crocolat", 5 }, { "Strawberry Elephant", 1 } },
	},
	-- Data.AdminAbuseEgg ("Demonic Egg"): what admins drop in the plaza during Admin Abuse.
	["Admin Abuse Egg"] = {
		Id = "Admin Abuse Egg",
		DisplayName = "Admin Abuse Egg",
		Model = "Boss Egg",
		Category = "Admin",
		DropTable = { { "Monster Egg", 42 }, { "Monstrous Egg", 30 }, { "Boss Egg", 20 }, { "Brainrot Egg", 6 }, { "World Burner", 1.5 }, { "ArchAngel", 0.5 } },
	},
	-- Dr. Scramble trade-in banners (Data.ScrambleTradeIn: 45 / 36 / 15 / 3.5 / 0.5).
	["Experimental Pets"] = {
		Id = "Experimental Pets",
		DisplayName = "Experimental Pets",
		Model = "Experiment Egg",
		Category = "TradeIn",
		DropTable = { { "LimitedTimeExperimentPet", 45 }, { "LimitedExperimentEgg", 36 }, { "Pink Dragon Experiment", 15 }, { "Experiment Egg", 3.5 }, { "Mecha Scrambler", 0.5 } },
	},
	["Biohazard Pets"] = {
		Id = "Biohazard Pets",
		DisplayName = "Biohazard Pets",
		Model = "Biohazard Egg",
		Category = "TradeIn",
		DropTable = { { "LimitedTimeExperimentPet", 45 }, { "Pink Dragon Experiment", 36 }, { "Biohazard Egg", 15 }, { "Toxic Hedgehog", 3.5 }, { "Unstable", 0.5 } },
	},
}

-- Events ----------------------------------------------------------------------------------------
local EVENTS: { [string]: Event } = {
	Halloween = {
		Id = "Halloween",
		DisplayName = "Halloween Dimension",
		StartsAt = 1790812800, -- 2026-10-01
		EndsAt = 1794182400, -- 2026-11-09
		HostBiomes = { "Haunted Graveyard", "Candy Kingdom" },
		HostChance = 0.3,
		NestChance = 0.02,
		NestPool = curved({
			"Zombified Halloween Egg",
			"Witch Crow Egg",
			"Mummy Egg",
			"BloodBloom Egg",
			"Candlefang Egg",
			"Patchwork Imp Egg",
			"Haunted Scorpio Egg",
			"Jester Egg",
			"Jesterpop Egg",
			"Werewolf Egg",
			"Spirit Knight Egg",
			"Voidseer Pumpkin Egg",
			"Ghost Fish Egg",
			"Crowshade Egg",
			"Ghost Reaper Egg",
			"Graveyard Brute Egg",
			"Witch Pumpkin Egg",
		}),
		Container = "Halloween Dimension Egg",
		Color = Color3.fromRGB(255, 140, 40),
	},
	Rift = {
		Id = "Rift",
		DisplayName = "Rift Event",
		StartsAt = 1795132800, -- 2026-11-20
		EndsAt = 1796947200, -- 2026-12-11
		HostBiomes = { "Crystal Cavern", "Cosmic" },
		HostChance = 0.2,
		NestChance = 0.015,
		NestPool = { { "Riftborn Egg", 55 }, { "Riftbeasts Egg", 35 }, { "Shattered Rift Egg", 10 } },
		Container = "Rift Egg",
		Color = Color3.fromRGB(170, 110, 255),
	},
}

local LIMITED: { Limited } = {
	{ Id = "Depths Egg", Container = "Depths Egg", EndsAt = 1795996800, RobuxPerEgg = 99, Offers = { 1, 3, 10, 50 } }, -- 2026-11-30
	{ Id = "Extinction Egg", Container = "Extinction Egg", EndsAt = 1792249200, RobuxPerEgg = 99, Offers = { 1, 3, 10, 50 } }, -- vaulted 2026-10-17
}

-- Developer staff / giveaway variants. No nest, shop or trade-in hands these out.
local ADMIN_ONLY: { [string]: boolean } = {
	["67 OP"] = true,
	["Amethyst Runebear OP"] = true,
	["Ostrich OP"] = true,
	["Toxic Hedgehog OP"] = true,
}

EggSources.Shop = {
	RestockSeconds = 600,
	Slots = 5, -- regular slots; one more rare slot is added on top
	Stock = 3, -- per player, per restock
	RareStock = 1,
	RareLuck = 25,
	PriceSeconds = 900, -- price = this many seconds of the egg's income
	MinPrice = 250,
	-- the rare slot rolls from these first (exclusives), then falls back to a lucky biome roll
	Exclusives = { { "Brainrot Egg", 30 }, { "Whiskers Egg", 30 }, { "Boss Egg", 20 }, { "Race Cheetah", 10 }, { "Race Lizard", 10 }, { "Race Bird", 10 } },
	ExclusiveChance = 0.5,
}

EggSources.TradeIn = {
	RotationSeconds = 1800,
	-- Banner weights from Data.ScrambleTradeIn; the recipe pets come from these zones.
	Banners = {
		{ Id = "Biohazard Pets", Weight = 42.5, FromZone = 5, ToZone = 12 },
		{ Id = "Experimental Pets", Weight = 57.5, FromZone = 13, ToZone = 23 },
	},
	-- Easy / Medium / Hard: drop weight bands of the recipe pets (percent of their biome table).
	Bands = { { 15, 100 }, { 4, 15 }, { 0.25, 4 } },
}

EggSources.Admin = {
	-- Extra admins by UserId. The place owner (or group rank >= GroupRank) and Studio are admins.
	UserIds = {} :: { number },
	GroupRank = 254,
	DropLifetime = 120, -- seconds an admin drop sits in the plaza
	AbuseDropEvery = 20,
	AbuseLuck = 3,
}

-- Lookups ---------------------------------------------------------------------------------------

local function exists(name: string): boolean
	return CONTAINERS[name] ~= nil or GameEgg.get(name) ~= nil
end

-- Drop rows whose egg we have no model for (missing reference meshes).
for biome, rows in BIOMES do
	local kept = {}
	for _, row in rows do
		if exists(row[1]) then
			table.insert(kept, row)
		end
	end
	BIOMES[biome] = kept
end

-- Shop Lucky Egg: one of every biome's two rarest eggs (still weighted by their nest odds).
do
	local pool: { Drop } = {}
	for _, rows in BIOMES do
		local sorted = table.clone(rows)
		table.sort(sorted, function(a, b)
			return a[2] < b[2]
		end)
		for i = 1, math.min(2, #sorted) do
			table.insert(pool, { sorted[i][1], sorted[i][2] })
		end
	end
	table.sort(pool, function(a, b)
		return a[1] < b[1]
	end)
	CONTAINERS["Lucky Egg"] = {
		Id = "Lucky Egg",
		DisplayName = "Lucky Egg",
		Model = "Golden Retriever",
		Category = "Lucky",
		DropTable = pool,
	}
end

local CATEGORY: { [string]: string } = {}
for _, rows in BIOMES do
	for _, row in rows do
		CATEGORY[row[1]] = "Biome"
	end
end
local function mark(rows: { Drop }, category: string)
	for _, row in rows do
		if CATEGORY[row[1]] == nil then
			CATEGORY[row[1]] = category
		end
	end
end
mark(EggSources.Shop.Exclusives, "Shop")
for _, event in EVENTS do
	mark(event.NestPool, "Event")
	mark(CONTAINERS[event.Container].DropTable, "Event")
end
for _, container in CONTAINERS do
	mark(container.DropTable, container.Category)
end
for name in ADMIN_ONLY do
	CATEGORY[name] = "AdminOnly"
end

local ZONE_BIOME: { [string]: string } = {}
for _, biome in BiomeConfig do
	if biome.ZoneIndex > 0 then
		ZONE_BIOME[string.format("Zone%02d", biome.ZoneIndex)] = biome.Name
	end
end

local BIOME_ZONE: { [string]: number } = {}
for _, biome in BiomeConfig do
	BIOME_ZONE[biome.Name] = biome.ZoneIndex
end

EggSources.Biomes = BIOMES
EggSources.Containers = CONTAINERS
EggSources.Events = EVENTS
EggSources.Limited = LIMITED
EggSources.AdminOnly = ADMIN_ONLY

function EggSources.biomeOf(habitat: string): string
	return ZONE_BIOME[habitat] or habitat
end

function EggSources.category(name: string): string
	return CATEGORY[name] or (if CONTAINERS[name] then CONTAINERS[name].Category else "Unknown")
end

function EggSources.container(name: string): Container?
	return CONTAINERS[name]
end

local function totalWeight(rows: { Drop }): number
	local total = 0
	for _, row in rows do
		total += row[2]
	end
	return total
end

-- Percent chance of each row, for shop / trade-in cards.
function EggSources.chance(rows: { Drop }, name: string): number
	local total = totalWeight(rows)
	for _, row in rows do
		if row[1] == name and total > 0 then
			return row[2] / total * 100
		end
	end
	return 0
end

local function rollOnce(rows: { Drop }, rng: Random): Drop?
	local total = totalWeight(rows)
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	for _, row in rows do
		pick -= row[2]
		if pick <= 0 then
			return row
		end
	end
	return rows[#rows]
end

-- Weighted roll. Luck > 1 rolls that many times (fractions roll once more by chance) and keeps
-- the rarest result, like Steal an Egg's LuckRolls.
function EggSources.roll(rows: { Drop }, rng: Random, luck: number?): string?
	local rolls = 1
	local boost = if typeof(luck) == "number" and luck > 1 then luck else 1
	rolls = math.floor(boost)
	if rng:NextNumber() < boost - rolls then
		rolls += 1
	end
	local best: Drop? = nil
	for _ = 1, math.clamp(rolls, 1, 100) do
		local row = rollOnce(rows, rng)
		if row and (best == nil or row[2] < (best :: Drop)[2]) then
			best = row
		end
	end
	return if best then best[1] else nil
end

-- Roll a container down to a real egg (containers may nest, e.g. Admin Abuse -> Brainrot).
function EggSources.open(name: string, rng: Random, luck: number?): string
	for _ = 1, 4 do
		local container = CONTAINERS[name]
		if not container then
			return name
		end
		name = EggSources.roll(container.DropTable, rng, luck) or name
	end
	return name
end

-- Events ----------------------------------------------------------------------------------------

-- Workspace attribute EggEvent_<id> forces an event on (true) or off (false); unset follows dates.
function EggSources.eventLive(id: string, now: number?): boolean
	local event = EVENTS[id]
	if not event then
		return false
	end
	local forced = Workspace:GetAttribute("EggEvent_" .. id)
	if typeof(forced) == "boolean" then
		return forced
	end
	local t = now or os.time()
	return t >= event.StartsAt and t < event.EndsAt
end

function EggSources.liveEvents(now: number?): { Event }
	local list = {}
	for id, event in EVENTS do
		if EggSources.eventLive(id, now) then
			table.insert(list, event)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

function EggSources.limitedLive(limited: Limited, now: number?): boolean
	return (now or os.time()) < limited.EndsAt
end

-- Admin boosts (Shared.Util.AdminBoosts): AdminBoost_EggSpawnLuck on Workspace, with an expiry.
function EggSources.spawnLuck(now: number?): number
	local value = Workspace:GetAttribute("AdminBoost_EggSpawnLuck")
	local untilAt = Workspace:GetAttribute("AdminBoost_EggSpawnLuckUntil")
	if typeof(value) ~= "number" or value ~= value or value <= 1 then
		return 1
	end
	if typeof(untilAt) == "number" and (now or os.time()) >= untilAt then
		return 1
	end
	return value
end

-- Nests -----------------------------------------------------------------------------------------

-- One nest slot in this habitat (ZoneNN or biome name). Returns the egg and where it came from.
-- Biomes whose nests only ever hold their own pets (no event eggs mixed in).
local EVENT_FREE = { ["Cozy Backyard"] = true }

function EggSources.rollNest(habitat: string, rng: Random, now: number?, luck: number?): (string?, string)
	local biome = EggSources.biomeOf(habitat)
	for _, event in if EVENT_FREE[biome] then {} else EggSources.liveEvents(now) do
		local chance = if table.find(event.HostBiomes, biome) then event.HostChance else event.NestChance
		if rng:NextNumber() < chance then
			local egg = EggSources.roll(event.NestPool, rng, luck)
			if egg then
				return egg, "Event"
			end
		end
	end
	local rows = BIOMES[biome]
	if not rows or #rows == 0 then
		return nil, "Biome"
	end
	return EggSources.roll(rows, rng, luck), "Biome"
end

-- World announcements (Steal an Egg): only top-tier eggs that were a genuinely rare roll are broadcast,
-- so a normal 5-minute reset shows about 1-3, and admin luck (best-of-N rolls) pushes it to 5-8+.
-- Rarity labels come from biome chance (EggScale.rarityOf), but the chance check keeps the count
-- steady whatever the labels say.
EggSources.AnnounceMaxChance = 0.04 -- measured: ~1.3 per reset, 1-3 on ~70% of resets, x10 luck 3-12

local function share(rows: { Drop }, eggName: string): number?
	local total, hit = 0, nil
	for _, row in rows do
		total += row[2]
		if row[1] == eggName then
			hit = (hit or 0) + row[2]
		end
	end
	return if hit and total > 0 then hit / total else nil
end

-- Chance that one nest slot in this habitat holds this egg (from the table it was rolled on).
function EggSources.nestChance(habitat: string, eggName: string, source: string, now: number?): number
	local biome = EggSources.biomeOf(habitat)
	if source == "Event" then
		for _, event in EggSources.liveEvents(now) do
			local s = share(event.NestPool, eggName)
			if s then
				local slot = if table.find(event.HostBiomes, biome) then event.HostChance else event.NestChance
				return s * slot
			end
		end
		return 1
	end
	local rows = BIOMES[biome]
	return (rows and share(rows, eggName)) or 1
end

-- The rare egg an admin ;spawnrare puts in a nest: one of the three rarest of that biome.
function EggSources.rareFor(habitat: string, rng: Random): string?
	local rows = BIOMES[EggSources.biomeOf(habitat)]
	if not rows or #rows == 0 then
		return nil
	end
	local sorted = table.clone(rows)
	table.sort(sorted, function(a, b)
		return a[2] < b[2]
	end)
	local top = table.move(sorted, 1, math.min(3, #sorted), 1, {})
	return top[rng:NextInteger(1, #top)][1]
end

-- Shop ------------------------------------------------------------------------------------------

function EggSources.price(name: string): number
	local container = CONTAINERS[name]
	if container and container.Price then
		return container.Price
	end
	local income = GameEgg.profile(name).Income
	return math.max(EggSources.Shop.MinPrice, math.floor(income * EggSources.Shop.PriceSeconds))
end

function EggSources.restockIndex(now: number): number
	return math.floor(now / EggSources.Shop.RestockSeconds)
end

function EggSources.restockAt(index: number): number
	return (index + 1) * EggSources.Shop.RestockSeconds
end

-- The rotation for one restock window. Seeded by the window, so every server shows the same stock.
-- A Workspace attribute EggShopSalt lets an admin force a fresh roll mid-window.
function EggSources.shopStock(index: number): { Offer }
	local salt = Workspace:GetAttribute("EggShopSalt")
	local rng = Random.new(index * 7919 + 13 + (if typeof(salt) == "number" then salt else 0))
	local shop = EggSources.Shop
	local biomes = {}
	for name in BIOMES do
		table.insert(biomes, name)
	end
	table.sort(biomes)
	local offers: { Offer } = {}
	local seen: { [string]: boolean } = {}
	local guard = 0
	while #offers < shop.Slots and guard < 60 do
		guard += 1
		local biome = biomes[rng:NextInteger(1, #biomes)]
		local egg = EggSources.roll(BIOMES[biome], rng, 1)
		if egg and not seen[egg] then
			seen[egg] = true
			table.insert(offers, { Slot = #offers + 1, Name = egg, IsContainer = false, Price = EggSources.price(egg), Stock = shop.Stock, Rare = false })
		end
	end
	local rare: string? = nil
	if rng:NextNumber() < shop.ExclusiveChance then
		rare = EggSources.roll(shop.Exclusives, rng, 1)
	end
	if not rare or seen[rare] then
		local biome = biomes[rng:NextInteger(1, #biomes)]
		rare = EggSources.roll(BIOMES[biome], rng, shop.RareLuck)
	end
	if rare then
		table.insert(offers, {
			Slot = #offers + 1,
			Name = rare,
			IsContainer = CONTAINERS[rare] ~= nil,
			Price = EggSources.price(rare) * (if CONTAINERS[rare] then 1 else 2),
			Stock = shop.RareStock,
			Rare = true,
		})
	end
	return offers
end

-- Trade-in --------------------------------------------------------------------------------------

function EggSources.recipeIndex(now: number): number
	return math.floor(now / EggSources.TradeIn.RotationSeconds)
end

function EggSources.recipe(index: number): Recipe
	local cfg = EggSources.TradeIn
	local salt = Workspace:GetAttribute("TradeInSalt")
	local rng = Random.new(index * 104729 + 7 + (if typeof(salt) == "number" then salt else 0))
	local total = 0
	for _, banner in cfg.Banners do
		total += banner.Weight
	end
	local pick = rng:NextNumber() * total
	local chosen = cfg.Banners[#cfg.Banners]
	for _, banner in cfg.Banners do
		pick -= banner.Weight
		if pick <= 0 then
			chosen = banner
			break
		end
	end
	local pets = {}
	for _, band in cfg.Bands do
		local candidates = {}
		for biome, rows in BIOMES do
			local zone = BIOME_ZONE[biome] or 0
			if zone < chosen.FromZone or zone > chosen.ToZone then
				continue
			end
			local sum = totalWeight(rows)
			for _, row in rows do
				local percent = row[2] / sum * 100
				if percent >= band[1] and percent < band[2] and not table.find(pets, row[1]) and not table.find(candidates, row[1]) then
					table.insert(candidates, row[1])
				end
			end
		end
		table.sort(candidates)
		if #candidates > 0 then
			table.insert(pets, candidates[rng:NextInteger(1, #candidates)])
		end
	end
	return {
		Index = index,
		Banner = chosen.Id,
		Pets = pets,
		EndsAt = (index + 1) * cfg.RotationSeconds,
	}
end

return EggSources
