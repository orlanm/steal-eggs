--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PenConfig
-- The left-side pen panels (Steal an Egg style): Growing Eggs (Grow All / per-egg Skip developer
-- products) and Active Pets (equip slots bought with cash, Equip Best). Dashboard ids live in
-- ShopProductIds.Grow (0 = not created yet: free in Studio, "not on sale" live).

local Ids = require(script.Parent.ShopProductIds)

local PenConfig = {}

-- Active pets: how many hatched pets earn in your pen at once. You start with StartSlots; each
-- "+1 EQUIP" buys the next entry for in-game cash.
PenConfig.StartSlots = 7
PenConfig.SlotCosts = {
	1e3, -- 8
	1e6, -- 9
	75e6, -- 10
	500e6, -- 11
	1e9, -- 12
	50e9, -- 13
	500e9, -- 14
	1e12, -- 15
	25e12, -- 16
	100e12, -- 17
	500e12, -- 18
	5e15, -- 19 (max)
}
PenConfig.EquipBestCooldown = 3 -- seconds between Equip Best presses
PenConfig.MaxHeldPets = 250 -- unequipped pets carried as Tools (Steal an Egg's backpack limit)

-- Growing eggs: Grow All finishes every growing egg in your pen; Skip finishes one egg and is only
-- offered while that egg has more than MinSkipSeconds left. A Skip uses the smallest tier that
-- covers the time left (the biggest tier covers anything longer).
local grow = (Ids :: any).Grow or {}
PenConfig.GrowAll = { Robux = 199, ProductId = grow.All or 0 }
PenConfig.MinSkipSeconds = 300
PenConfig.SkipTiers = {
	{ Seconds = 15 * 60, Robux = 9, ProductId = grow[900] or 0 },
	{ Seconds = 30 * 60, Robux = 19, ProductId = grow[1800] or 0 },
	{ Seconds = 60 * 60, Robux = 29, ProductId = grow[3600] or 0 },
}

-- Slot count for an equip level (0 = never upgraded).
function PenConfig.slots(level: number): number
	return PenConfig.StartSlots + math.clamp(math.floor(level), 0, #PenConfig.SlotCosts)
end

-- Cash for the next slot, or nil at the max.
function PenConfig.nextCost(level: number): number?
	return PenConfig.SlotCosts[math.floor(level) + 1]
end

function PenConfig.skipTier(secondsLeft: number): { Seconds: number, Robux: number, ProductId: number }
	for _, tier in PenConfig.SkipTiers do
		if secondsLeft <= tier.Seconds then
			return tier
		end
	end
	return PenConfig.SkipTiers[#PenConfig.SkipTiers]
end

return PenConfig
