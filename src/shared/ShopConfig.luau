--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.ShopConfig
-- The Robux shop (Steal an Egg style): passes you can buy or gift, the treadmill upgrade, vehicles,
-- weekly Lucky Egg and Mount Star stock and cash packs. Dashboard ids live in ShopProductIds (0 = not created yet).

local Ids = require(script.Parent.ShopProductIds)

local ShopConfig = {}

export type Pass = {
	Id: string,
	Name: string,
	Blurb: string,
	Icon: string, -- ShopArt key
	Robux: number, -- shown until the live dashboard price loads
	Section: string,
	GamePassId: number, -- preferred when set
	SelfProductId: number, -- developer product for yourself, used while GamePassId is 0
	GiftProductId: number,
}

-- Owned forever, bought with cash or Robux (developer product), saved with the passes (Perks) and
-- spawned from a hotbar Tool (Boats.server).
export type Vehicle = {
	Id: string,
	Name: string,
	Blurb: string,
	Image: string,
	Cash: number,
	Robux: number, -- shown until the live dashboard price loads
	ProductId: number,
}

export type Offer = {
	Id: string,
	Amount: number,
	Robux: number,
	ProductId: number,
	Best: boolean?,
	Popular: boolean?,
}

ShopConfig.Passes = {
	{ Id = "Growth", Name = "x2 Growth", Blurb = "Eggs Grow x2 faster!", Icon = "Stopwatch", Robux = 149, Section = "Passes", GamePassId = Ids.Passes.Growth, SelfProductId = Ids.Self.Growth, GiftProductId = Ids.Gifts.Growth },
	{ Id = "Money", Name = "x2 Money", Blurb = "Get x2 Money!", Icon = "Coin", Robux = 199, Section = "Passes", GamePassId = Ids.Passes.Money, SelfProductId = Ids.Self.Money, GiftProductId = Ids.Gifts.Money },
	{ Id = "Speed", Name = "x2 Speed", Blurb = "DOUBLE Your SPEED", Icon = "Sneaker", Robux = 99, Section = "Speed", GamePassId = Ids.Passes.Speed, SelfProductId = Ids.Self.Speed, GiftProductId = Ids.Gifts.Speed },
} :: { Pass }

ShopConfig.Vehicles = {
	{
		Id = "Boat",
		Name = "Fishing Boat",
		Blurb = "Sail across the water! Equip it while swimming.",
		Image = "rbxassetid://127503029975255", -- _blender/fishing_boat.py render
		Cash = 100_000_000_000,
		Robux = 399,
		ProductId = Ids.Vehicles.Boat,
	},
} :: { Vehicle }

ShopConfig.GrowthBoost = 2 -- eggs in your pen hatch this many times faster
ShopConfig.MoneyBoost = 2 -- pen pet income
ShopConfig.SpeedBoost = 2 -- speed points (like a trail multiplier)

-- Lucky Eggs: one of every biome's rarest eggs, a few per player each week.
ShopConfig.LuckyEgg = "Lucky Egg"
ShopConfig.LuckyWeeklyStock = 5
ShopConfig.LuckyOffers = {
	{ Id = "Lucky1", Amount = 1, Robux = 79, ProductId = Ids.Lucky[1] },
	{ Id = "Lucky3", Amount = 3, Robux = 199, ProductId = Ids.Lucky[3] },
	{ Id = "Lucky5", Amount = 5, Robux = 299, ProductId = Ids.Lucky[5], Best = true },
} :: { Offer }

-- Mount Stars: feed one to a pen pet to make it a rideable mount (MountConfig). Weekly stock like Lucky Eggs.
ShopConfig.StarWeeklyStock = 5
ShopConfig.StarOffers = {
	{ Id = "Stars1", Amount = 1, Robux = 299, ProductId = Ids.Stars[1] },
	{ Id = "Stars3", Amount = 3, Robux = 699, ProductId = Ids.Stars[3], Popular = true },
	{ Id = "Stars5", Amount = 5, Robux = 1099, ProductId = Ids.Stars[5], Best = true },
} :: { Offer }

-- Cash packs pay a stretch of your pen's income (Amount = minutes), with a floor for new players.
ShopConfig.CashFloor = 2500
ShopConfig.CashOffers = {
	{ Id = "CashS", Amount = 10, Robux = 29, ProductId = Ids.Cash.Small },
	{ Id = "CashM", Amount = 60, Robux = 99, ProductId = Ids.Cash.Medium },
	{ Id = "CashL", Amount = 360, Robux = 299, ProductId = Ids.Cash.Large, Best = true },
} :: { Offer }

local WEEK = 7 * 24 * 3600
local WEEK_START = 4 * 24 * 3600 -- unix day 0 is a Thursday: weeks roll over Monday 00:00 UTC

function ShopConfig.pass(id: string): Pass?
	for _, pass in ShopConfig.Passes do
		if pass.Id == id then
			return pass
		end
	end
	return nil
end

function ShopConfig.vehicle(id: string): Vehicle?
	for _, vehicle in ShopConfig.Vehicles do
		if vehicle.Id == id then
			return vehicle
		end
	end
	return nil
end

-- Anything saved in the Perks list: a pass or a vehicle.
function ShopConfig.perk(id: string): boolean
	return ShopConfig.pass(id) ~= nil or ShopConfig.vehicle(id) ~= nil
end

function ShopConfig.week(now: number): number
	return math.floor((now - WEEK_START) / WEEK)
end

function ShopConfig.restockAt(now: number): number
	return (ShopConfig.week(now) + 1) * WEEK + WEEK_START
end

-- incomePerSecond: the player's PenIncome attribute (already includes x2 Money)
function ShopConfig.cashFor(offer: Offer, incomePerSecond: number): number
	local rate = if incomePerSecond == incomePerSecond and incomePerSecond > 0 then incomePerSecond else 0
	return math.floor(math.max(ShopConfig.CashFloor * offer.Amount / 10, rate * offer.Amount * 60))
end

-- "5d 11hr", "3hr 12m", "45m"
function ShopConfig.formatLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then
		return string.format("%dd %dhr", d, h)
	elseif h > 0 then
		return string.format("%dhr %dm", h, m)
	end
	return string.format("%dm %ds", m, seconds % 60)
end

return ShopConfig
