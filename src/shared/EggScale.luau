--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.EggScale
-- Egg sizes. Every egg is drawn at its native size, with a little natural variance (NORMAL_MIN..MAX).
-- Only a Huge roll makes an egg - in the wild, carried, in the pen - and the pet it hatches big:
--   * HUGE_SCALE x, rolled once when the egg spawns (HUGE_ODDS: 1 in 10,000 for Common eggs down to
--     1 in 1,000,000 for Secret / Divine / Eternal). It is saved with the egg and pet, so it is permanent.
--   * Huge pays more (sizePayout: 3x size is ~7.6x income), shows HUGE / [HUGE] on its tags and a glow
--     at the pet's feet. Admins can grant one with ;give / ;drop ... huge.
-- A placed egg keeps its size while it hatches (PEN_GROWTH = 1), so only Huge eggs look big in the pen.
-- Weight class (Small .. Super) sets the egg's height, carry slowdown and hatch time.
-- Rarity comes from how hard the egg is to find (EggScale.rarityOf).

local GameEgg = require(script.Parent.GameEgg)

local EggScale = {}

-- R15 two-handed carry pose (KeyframeSequence built by _tools/eggs/carry_pose.py)
EggScale.CarryAnimation = 104772808948116

-- 1x egg for an egg with no native model, in studs (the median Steal An Egg egg is ~5.4 tall).
local NEST_UNIT = 4.2
-- A 1x egg is this many studs tall per unit of its profile height (HeightMin..HeightMax): Small eggs
-- ~2 studs, Medium ~3.6, Heavy ~5.6, Super ~8. The reference meshes come in at any size, so only
-- their shape is kept.
local EGG_HEIGHT_UNIT = 3.6
local CARRY_HEIGHT = 2.4 -- tag / fallback height when the carried egg is unknown

-- Ordinary eggs vary a little around 1x; the only big size is Huge.
local NORMAL_MIN, NORMAL_MAX = 0.9, 1.05
EggScale.HUGE_SCALE = 3
-- 1 in N chance that a new egg rolls Huge, by the egg's rarity (rarer eggs are rarer still).
EggScale.HUGE_ODDS = {
	Common = 10000,
	Uncommon = 25000,
	Rare = 50000,
	Epic = 100000,
	Legendary = 250000,
	Mythic = 500000,
	Boss = 500000,
	Cosmic = 1000000,
	Secret = 1000000,
	Eternal = 1000000,
	Divine = 1000000,
} :: { [string]: number }
-- EggScaling: a pre-growth egg is drawn at size x native, floored at 0.6x and capped at 8x.
local EGG_VISUAL_MIN, EGG_VISUAL_MAX = 0.6, 8
-- A placed egg's size at hatch time relative to when it was placed (1 = it stays the same size).
EggScale.PEN_GROWTH = 1
-- Game.Balance.Earnings: income x size^1.85 up to 5x, then x size^1.2 (tapered).
local STEEP_POWER, TAPER_KNEE, TAPER_POWER = 1.85, 5, 1.2

local NEST_BAND: { [string]: { number } } = {
	Small = { 1.0, 1.0 },
	Medium = { 1.3, 1.5 },
	Heavy = { 2.0, 2.5 },
	Super = { 3.5, 5.0 },
}

-- HeightMin/HeightMax span of each class in GameEgg profiles.
local CLASS_SPAN: { [string]: { number } } = {
	Small = { 0.42, 0.75 },
	Medium = { 0.75, 1.20 },
	Heavy = { 1.20, 1.90 },
	Super = { 1.90, 2.70 },
}

local RARITY_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(236, 236, 236),
	Uncommon = Color3.fromRGB(126, 220, 96),
	Rare = Color3.fromRGB(96, 176, 255),
	Epic = Color3.fromRGB(186, 120, 255),
	Legendary = Color3.fromRGB(255, 207, 31),
	Mythic = Color3.fromRGB(255, 96, 96),
	Cosmic = Color3.fromRGB(120, 230, 255),
	Boss = Color3.fromRGB(255, 170, 64),
	Secret = Color3.fromRGB(255, 236, 160),
}

export type Nest = {
	Scale: number,
	Height: number,
	Penalty: number,
	Class: string,
	ClassLabel: string,
	Rarity: string,
}

local function clamp01(n: number): number
	return math.clamp(n, 0, 1)
end

function EggScale.classOf(className: string?): string
	if className == "Small" or className == "Medium" or className == "Heavy" or className == "Super" then
		return className
	end
	return "Medium"
end

function EggScale.classLabel(className: string): string
	if className == "Super" then
		return "Super Heavy"
	end
	return className
end

-- Where this profile sits inside its weight class. 0 is the lightest tier.
function EggScale.tierAlpha(className: string, heightMin: number, heightMax: number): number
	local span = CLASS_SPAN[EggScale.classOf(className)]
	local mid = (heightMin + heightMax) * 0.5
	local width = span[2] - span[1]
	if width <= 0 then
		return 0
	end
	return clamp01((mid - span[1]) / width)
end

-- override: the egg profile's explicit Rarity, when it has one.
function EggScale.rarity(className: string, alpha: number, eggName: string, override: string?): string
	if override then
		return override
	end
	local lowered = string.lower(eggName)
	if string.find(lowered, "boss", 1, true) then
		return "Boss"
	end
	local class = EggScale.classOf(className)
	if class == "Small" then
		return if alpha > 0.66 then "Uncommon" else "Common"
	elseif class == "Medium" then
		return if alpha > 0.5 then "Epic" else "Rare"
	elseif class == "Heavy" then
		return if alpha > 0.5 then "Cosmic" else "Mythic"
	end
	return "Secret"
end

-- Biome rarity ladder by drop chance in the egg's easiest biome (EggSources.Biomes), Steal an Egg
-- style: the rarer the find, the higher the tier. { min chance, rarity }.
local CHANCE_TIERS: { { any } } = {
	{ 0.25, "Common" },
	{ 0.15, "Uncommon" },
	{ 0.08, "Rare" },
	{ 0.03, "Epic" },
	{ 0.005, "Legendary" },
	{ 0.001, "Mythic" },
	{ 0, "Secret" },
}
local bestChance: { [string]: number }? = nil

local function chances(): { [string]: number }
	if bestChance then
		return bestChance
	end
	local map = {}
	-- lazy: EggSources requires GameEgg only, so there is no require cycle
	local EggSources = require(script.Parent.EggSources) :: any
	for _, rows in EggSources.Biomes do
		local total = 0
		for _, row in rows do
			total += row[2]
		end
		for _, row in rows do
			local chance = if total > 0 then row[2] / total else 0
			map[row[1]] = math.max(map[row[1]] or 0, chance)
		end
	end
	bestChance = map
	return map
end

-- The one rarity for an egg / pet everywhere (nests, pen tags, shop, Pet Index): its explicit
-- profile Rarity, Boss for boss eggs, the biome drop ladder, else (event / shop eggs) its class tier.
function EggScale.rarityOf(eggName: string?): string
	if typeof(eggName) ~= "string" or eggName == "" then
		return "Common"
	end
	local profile = GameEgg.profile(eggName)
	if profile.Rarity then
		return profile.Rarity
	end
	if string.find(string.lower(eggName), "boss", 1, true) then
		return "Boss"
	end
	local chance = chances()[eggName]
	if chance then
		for _, tier in CHANCE_TIERS do
			if chance >= tier[1] then
				return tier[2]
			end
		end
	end
	local alpha = EggScale.tierAlpha(profile.Class, profile.HeightMin, profile.HeightMax)
	return EggScale.rarity(profile.Class, alpha, eggName, nil)
end

function EggScale.isUltraRare(rarity: string, eggName: string): boolean
	if rarity == "Secret" or rarity == "Eternal" or rarity == "Divine" then
		return true
	end
	local lowered = string.lower(eggName)
	return string.find(lowered, "eternal", 1, true) ~= nil or string.find(lowered, "divine", 1, true) ~= nil
end

-- Daytime hatch length. Night runs this clock at 30x.
function EggScale.hatchSeconds(className: string): number
	local class = EggScale.classOf(className)
	if class == "Small" then
		return 90
	elseif class == "Medium" then
		return 300
	elseif class == "Heavy" then
		return 1200
	end
	return 3600
end

-- Slowdown by weight class. The floor stays at half speed.
local SLOWDOWN: { [string]: { number } } = {
	Small = { 0.00, 0.10 },
	Medium = { 0.15, 0.25 },
	Heavy = { 0.30, 0.40 },
	Super = { 0.50, 0.50 },
}

local SHELL_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(236, 228, 210),
	Uncommon = Color3.fromRGB(176, 214, 140),
	Rare = Color3.fromRGB(110, 176, 255),
	Epic = Color3.fromRGB(186, 110, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
	Mythic = Color3.fromRGB(255, 86, 96),
	Cosmic = Color3.fromRGB(110, 220, 255),
	Boss = Color3.fromRGB(255, 150, 60),
	Secret = Color3.fromRGB(255, 220, 120),
	Eternal = Color3.fromRGB(255, 130, 210),
	Divine = Color3.fromRGB(255, 206, 70),
}

local PLAIN_SHELLS = {
	Color3.fromRGB(244, 240, 232),
	Color3.fromRGB(226, 206, 176),
	Color3.fromRGB(214, 196, 168),
	Color3.fromRGB(236, 232, 214),
}

function EggScale.slowdown(className: string, alpha: number): number
	local band = SLOWDOWN[EggScale.classOf(className)]
	return band[1] + (band[2] - band[1]) * clamp01(alpha)
end

function EggScale.penalty(scale: number): number
	if typeof(scale) ~= "number" or scale ~= scale then
		return 1
	end
	if scale <= 1.15 then
		return 1 - 0.10 * clamp01((scale - 1) / 0.15)
	elseif scale <= 1.5 then
		return 1 - (0.15 + 0.10 * clamp01((scale - 1.3) / 0.2))
	elseif scale <= 2.5 then
		return 1 - (0.30 + 0.10 * clamp01((scale - 2.0) / 0.5))
	end
	return 0.5
end

function EggScale.shellColor(rarity: string, index: number): Color3
	if rarity == "Common" or rarity == "Uncommon" then
		return PLAIN_SHELLS[((index - 1) % #PLAIN_SHELLS) + 1]
	end
	return SHELL_COLOR[rarity] or SHELL_COLOR.Common
end

function EggScale.showsAura(rarity: string): boolean
	return rarity == "Legendary"
		or rarity == "Mythic"
		or rarity == "Cosmic"
		or rarity == "Boss"
		or rarity == "Secret"
		or rarity == "Eternal"
		or rarity == "Divine"
end

function EggScale.rollShell(rng: Random): (string, number)
	local roll = rng:NextNumber()
	if roll < 0.012 then
		return "Rainbow", 3
	elseif roll < 0.047 then
		return "Golden", 2
	elseif roll < 0.127 then
		return "Silver", 1.25
	end
	return "", 1
end

function EggScale.mutationColor(mutation: string): Color3?
	if mutation == "Silver" then
		return Color3.fromRGB(214, 222, 232)
	elseif mutation == "Golden" then
		return Color3.fromRGB(255, 196, 48)
	end
	return nil
end

function EggScale.nest(className: string, alpha: number, eggName: string, rarity: string?): Nest
	local class = EggScale.classOf(className)
	local band = NEST_BAND[class]
	local scale = band[1] + (band[2] - band[1]) * clamp01(alpha)
	return {
		Scale = scale,
		Height = NEST_UNIT * scale,
		Penalty = 1 - EggScale.slowdown(class, alpha),
		Class = class,
		ClassLabel = EggScale.classLabel(class),
		Rarity = EggScale.rarity(class, alpha, eggName, rarity),
	}
end

function EggScale.rarityColor(rarity: string): Color3
	return RARITY_COLOR[rarity] or RARITY_COLOR.Common
end

function EggScale.carryHeight(): number
	return CARRY_HEIGHT
end

-- Size scale -------------------------------------------------------------------------------------

-- A new egg's size: Huge (HUGE_SCALE) on a rare roll for its rarity, else about 1x.
function EggScale.rollSize(rng: Random, rarity: string?): number
	local odds = EggScale.HUGE_ODDS[rarity or "Common"] or EggScale.HUGE_ODDS.Common
	if rng:NextNumber() * odds < 1 then
		return EggScale.HUGE_SCALE
	end
	return math.round(rng:NextNumber(NORMAL_MIN, NORMAL_MAX) * 100) / 100
end

function EggScale.isHuge(size: any): boolean
	return typeof(size) == "number" and math.abs(size - EggScale.HUGE_SCALE) < 1e-3
end

-- A saved / attribute size scale, sanitised: Huge stays Huge, ordinary sizes stay as rolled, and
-- anything else (old saves from the previous 0.1x .. 35x size bands, or none) is drawn at 1x.
function EggScale.sizeOf(value: any): number
	if EggScale.isHuge(value) then
		return EggScale.HUGE_SCALE
	end
	if typeof(value) == "number" and value >= NORMAL_MIN - 0.05 and value <= NORMAL_MAX then
		return value
	end
	return 1
end

-- Income multiplier for a size scale.
function EggScale.sizePayout(size: number): number
	size = EggScale.sizeOf(size)
	if size <= TAPER_KNEE then
		return size ^ STEEP_POWER
	end
	return TAPER_KNEE ^ STEEP_POWER * (size / TAPER_KNEE) ^ TAPER_POWER
end

-- "HUGE" for Huge eggs and pets; nil for ordinary ones.
function EggScale.sizeLabel(size: number): string?
	return if EggScale.isHuge(size) then "HUGE" else nil
end

-- 1x egg height in studs from the egg's weight-class profile.
function EggScale.eggHeight(eggName: string?): number
	if not eggName or eggName == "" then
		return NEST_UNIT
	end
	local profile = GameEgg.profile(eggName)
	return EGG_HEIGHT_UNIT * (profile.HeightMin + profile.HeightMax) * 0.5
end

-- Native (1x) egg box in studs: the egg model's shape at its class height (eggHeight), or a
-- NEST_UNIT egg when there is no model.
function EggScale.nativeEggBox(eggName: string?): Vector3
	local egg = if eggName and eggName ~= "" then GameEgg.get(eggName) else nil
	local height = EggScale.eggHeight(eggName)
	if egg and egg.Bounds.Y > 0.05 then
		return egg.Bounds * (height / egg.Bounds.Y)
	end
	return Vector3.new(height * 0.86, height, height * 0.86)
end

-- The egg as found, carried and first placed: native x size (floored / capped like EggScaling).
function EggScale.eggBox(eggName: string?, size: number?): Vector3
	return EggScale.nativeEggBox(eggName) * math.clamp(EggScale.sizeOf(size), EGG_VISUAL_MIN, EGG_VISUAL_MAX)
end

-- The carried egg box (no egg info: the old fixed carry size).
function EggScale.carryBox(eggName: string?, size: number?): Vector3
	if eggName == nil and size == nil then
		return Vector3.new(CARRY_HEIGHT, CARRY_HEIGHT, CARRY_HEIGHT)
	end
	return EggScale.eggBox(eggName, size)
end

-- The placed egg at hatch progress 0..1: grows from eggBox to PEN_GROWTH x eggBox.
function EggScale.penEggBox(eggName: string?, size: number?, progress: number): Vector3
	return EggScale.eggBox(eggName, size) * (1 + (EggScale.PEN_GROWTH - 1) * math.clamp(progress, 0, 1))
end

-- Pen egg name/countdown tag: floats just above the egg (not drawn over it), width capped so big eggs
-- don't get giant labels. bodyHeight = the model Body's Y size (the tag hangs off the box-centred root).
local TAG_MIN_WIDTH, TAG_MAX_WIDTH, TAG_ASPECT = 3.5, 7, 0.42
function EggScale.hatchTagLayout(box: Vector3, bodyHeight: number): (UDim2, Vector3)
	local width = math.clamp(box.X * 1.1, TAG_MIN_WIDTH, TAG_MAX_WIDTH)
	local height = width * TAG_ASPECT
	return UDim2.fromScale(width, height), Vector3.new(0, -bodyHeight * 0.5 + box.Y + height * 0.5 + 0.2, 0)
end

-- Cosmetic mutations that make the pet glow (size comes from PetScale, not from here).
function EggScale.mutationGlows(mutation: string?): boolean
	if typeof(mutation) ~= "string" then
		return false
	end
	local name = string.lower(mutation)
	return name == "golden" or name == "gold" or name == "rainbow" or name == "shiny"
end

function EggScale.variantColor(mutation: string?): Color3
	if typeof(mutation) ~= "string" then
		return Color3.fromRGB(255, 214, 130)
	end
	local name = string.lower(mutation)
	if name == "golden" then
		return Color3.fromRGB(255, 196, 64)
	elseif name == "rainbow" then
		return Color3.fromRGB(255, 150, 230)
	elseif name == "shiny" then
		return Color3.fromRGB(170, 240, 255)
	end
	return Color3.fromRGB(255, 214, 130)
end

return EggScale
