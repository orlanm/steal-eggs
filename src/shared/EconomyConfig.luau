--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.EconomyConfig
-- Speed, treadmill tiers, trail shop catalog, and egg-weight penalties.
local Economy = {}

Economy.StartingSpeed = 16
Economy.MaximumSpeed = 1e12
Economy.DataStoreName = "BabyBeastsEconomy_v1"
Economy.LegacyStoreName = "BabyBeastsTrainingSpeed_v1"
Economy.SaveInterval = 60

-- Speed points = BaseSpeed * TrailMultiplier * EggWeightPenalty.
-- TrailMultiplier is the card value (x1.5 => 1.5). No trail equipped => 1.
-- Walk speed in studs comes from SpeedCurve, not from the point total itself.

export type Trail = {
	Id: string,
	Name: string,
	Rarity: string,
	Multiplier: number,
	Cash: number,
	Robux: number,
	Card: Color3,
	Card2: Color3,
	Figure: Color3,
	Style: string,
}

export type Tier = {
	Tier: number,
	Name: string,
	Rarity: string,
	Cost: number,
	Robux: number,
	Gain: number,
}

local trails: { Trail } = {
	{ Id = "Grey", Name = "Grey Trail", Rarity = "Common", Multiplier = 1.5, Cash = 100, Robux = 0, Card = Color3.fromRGB(232, 232, 236), Card2 = Color3.fromRGB(246, 246, 248), Figure = Color3.fromRGB(186, 190, 198), Style = "solid" },
	{ Id = "Green", Name = "Green Trail", Rarity = "Uncommon", Multiplier = 2, Cash = 5000, Robux = 16, Card = Color3.fromRGB(126, 230, 70), Card2 = Color3.fromRGB(196, 255, 120), Figure = Color3.fromRGB(70, 210, 80), Style = "solid" },
	{ Id = "Blue", Name = "Blue Trail", Rarity = "Rare", Multiplier = 2.5, Cash = 75000, Robux = 24, Card = Color3.fromRGB(88, 176, 255), Card2 = Color3.fromRGB(170, 220, 255), Figure = Color3.fromRGB(90, 170, 230), Style = "solid" },
	{ Id = "Purple", Name = "Purple Trail", Rarity = "Epic", Multiplier = 3, Cash = 1500000, Robux = 40, Card = Color3.fromRGB(156, 70, 255), Card2 = Color3.fromRGB(196, 120, 255), Figure = Color3.fromRGB(150, 70, 240), Style = "solid" },
	{ Id = "Golden", Name = "Golden Trail", Rarity = "Legendary", Multiplier = 3.5, Cash = 30000000, Robux = 64, Card = Color3.fromRGB(255, 214, 60), Card2 = Color3.fromRGB(255, 236, 140), Figure = Color3.fromRGB(255, 196, 40), Style = "solid" },
	{ Id = "Red", Name = "Red Trail", Rarity = "Mythic", Multiplier = 4, Cash = 750000000, Robux = 96, Card = Color3.fromRGB(220, 48, 48), Card2 = Color3.fromRGB(255, 110, 90), Figure = Color3.fromRGB(210, 50, 50), Style = "solid" },
	{ Id = "Galaxy", Name = "Galaxy Trail", Rarity = "Cosmic", Multiplier = 5, Cash = 20000000000, Robux = 160, Card = Color3.fromRGB(70, 20, 140), Card2 = Color3.fromRGB(40, 80, 200), Figure = Color3.fromRGB(130, 80, 255), Style = "galaxy" },
	{ Id = "Secret", Name = "Secret Trail", Rarity = "Secret", Multiplier = 7, Cash = 500000000000, Robux = 280, Card = Color3.fromRGB(236, 236, 240), Card2 = Color3.fromRGB(210, 210, 216), Figure = Color3.fromRGB(20, 20, 24), Style = "zebra" },
	{ Id = "Eternal", Name = "Eternal Trail", Rarity = "Eternal", Multiplier = 10, Cash = 12500000000000, Robux = 480, Card = Color3.fromRGB(255, 120, 210), Card2 = Color3.fromRGB(120, 240, 255), Figure = Color3.fromRGB(230, 90, 230), Style = "solid" },
	{ Id = "Divine", Name = "Divine Trail", Rarity = "Divine", Multiplier = 14, Cash = 300000000000000, Robux = 800, Card = Color3.fromRGB(255, 210, 60), Card2 = Color3.fromRGB(80, 140, 255), Figure = Color3.fromRGB(255, 230, 80), Style = "rainbow" },
	{ Id = "Moonbloom", Name = "Moonbloom Trail", Rarity = "Divine", Multiplier = 20, Cash = 5000000000000000, Robux = 960, Card = Color3.fromRGB(120, 230, 255), Card2 = Color3.fromRGB(170, 255, 150), Figure = Color3.fromRGB(150, 230, 255), Style = "solid" },
}

-- Levels match GameTreadmill.Tier. Angelic (Lv. 10) is the max unlock.
-- Gain = training speed multiplier; Cost = in-game cash; Robux = instant unlock.
local tiers: { Tier } = {
	{ Tier = 1, Name = "Default Treadmill", Rarity = "Common", Cost = 0, Robux = 0, Gain = 2 },
	{ Tier = 2, Name = "Sci-Fi Treadmill", Rarity = "Uncommon", Cost = 15000, Robux = 19, Gain = 5 },
	{ Tier = 3, Name = "Flame Treadmill", Rarity = "Rare", Cost = 250000, Robux = 39, Gain = 12 },
	{ Tier = 4, Name = "Celebrity Treadmill", Rarity = "Epic", Cost = 5000000, Robux = 69, Gain = 30 },
	{ Tier = 5, Name = "Golden Treadmill", Rarity = "Legendary", Cost = 120000000, Robux = 119, Gain = 80 },
	{ Tier = 6, Name = "The Freeze Treadmill", Rarity = "Mythic", Cost = 3000000000, Robux = 199, Gain = 100 },
	{ Tier = 7, Name = "Lucky Block Treadmill", Rarity = "Cosmic", Cost = 75000000000, Robux = 299, Gain = 200 },
	{ Tier = 8, Name = "Hacker Treadmill", Rarity = "Secret", Cost = 2000000000000, Robux = 499, Gain = 500 },
	{ Tier = 9, Name = "Demonic Treadmill", Rarity = "Eternal", Cost = 50000000000000, Robux = 799, Gain = 1000 },
	{ Tier = 10, Name = "Angelic Treadmill", Rarity = "Divine", Cost = 1000000000000000, Robux = 1299, Gain = 2000 },
}

local byId: { [string]: Trail } = {}
for _, trail in trails do
	byId[trail.Id] = trail
end

Economy.Trails = trails
Economy.Tiers = tiers

function Economy.trail(id: string): Trail?
	return byId[id]
end

function Economy.tier(level: number): Tier
	local index = math.clamp(math.floor(level), 1, #tiers)
	return tiers[index]
end

function Economy.nextTier(level: number): Tier?
	local nextLevel = math.floor(level) + 1
	return tiers[nextLevel]
end

local SpeedCurve = require(script.Parent.SpeedCurve)

function Economy.points(base: number, multiplier: number, penalty: number): number
	if typeof(base) ~= "number" or base ~= base or base < 0 then
		base = Economy.StartingSpeed
	end
	if typeof(multiplier) ~= "number" or multiplier ~= multiplier or multiplier <= 0 then
		multiplier = 1
	end
	if typeof(penalty) ~= "number" or penalty ~= penalty or penalty <= 0 then
		penalty = 1
	end
	local speed = base * multiplier * penalty
	if speed ~= speed then
		return Economy.StartingSpeed
	end
	return math.clamp(speed, 0, Economy.MaximumSpeed)
end

function Economy.walkSpeed(base: number, multiplier: number, penalty: number): number
	return SpeedCurve.studs(Economy.points(base, multiplier, penalty))
end

-- Nest slowdown follows the weight class. Half speed is the floor.
function Economy.penaltyForScale(scale: number): number
	if typeof(scale) ~= "number" or scale ~= scale then
		return 1
	end
	if scale <= 1.15 then
		return 1 - 0.10 * math.clamp((scale - 1) / 0.15, 0, 1)
	elseif scale <= 1.5 then
		return 1 - (0.15 + 0.10 * math.clamp((scale - 1.3) / 0.2, 0, 1))
	elseif scale <= 2.5 then
		return 1 - (0.30 + 0.10 * math.clamp((scale - 2.0) / 0.5, 0, 1))
	end
	return 0.5
end

function Economy.weightName(penalty: number): string
	if penalty >= 0.90 then
		return "Small"
	elseif penalty >= 0.75 then
		return "Medium"
	elseif penalty >= 0.60 then
		return "Heavy"
	end
	return "Super"
end

local SUFFIXES = {
	{ 1e15, "Qa" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

function Economy.formatCash(amount: number): string
	local n = if typeof(amount) == "number" and amount == amount then math.floor(amount + 1e-6) else 0
	if n < 0 then
		n = 0
	end
	for _, entry in SUFFIXES do
		local step = entry[1]
		local suffix = entry[2]
		if n >= step then
			local value = n / step
			if math.abs(value - math.floor(value + 1e-8)) < 1e-4 then
				return "$" .. tostring(math.floor(value + 1e-6)) .. suffix
			end
			local text = string.format("%.1f", value)
			text = string.gsub(text, "%.0$", "")
			return "$" .. text .. suffix
		end
	end
	return "$" .. tostring(n)
end

-- Earning per second: "$4/s", small rates keep a decimal ("$0.6/s"). bare: no "/s".
function Economy.formatRate(perSecond: number, bare: boolean?): string
	local n = if typeof(perSecond) == "number" and perSecond == perSecond then math.max(perSecond, 0) else 0
	local text = if n < 10 and math.abs(n - math.floor(n + 0.5)) > 0.05
		then "$" .. (string.gsub(string.format("%.1f", n), "%.0$", ""))
		else Economy.formatCash(n + 0.5)
	return if bare then text else text .. "/s"
end

function Economy.formatMultiplier(multiplier: number): string
	if math.abs(multiplier - math.floor(multiplier)) < 1e-6 then
		return "x" .. tostring(math.floor(multiplier))
	end
	return string.format("x%.1f", multiplier)
end

return Economy
