--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.ShopProductIds
-- Roblox dashboard ids for the Shop (universe 10770569453), created by _tools/shop/create_products.py.
-- 0 = not created yet: the button says so instead of prompting a purchase.
--   Passes: Game Passes bought for yourself (preferred when set).
--   Self:   Developer Products that unlock the pass for yourself, only used when Passes is 0
--           (taken off sale 2026-10-26 once the game passes existed; receipts still honoured).
--   Gifts:  Developer Products, one per pass, bought to give that pass to another player.
--   Lucky / Cash / Stars: Developer Products.
--   Grow: Growing Eggs panel (PenConfig): Grow All + Skip tiers keyed by seconds covered.
return {
	Passes = { Growth = 2053932423, Money = 2052588360, Speed = 2052348431 },
	Self = { Growth = 3722430741, Money = 3722430751, Speed = 3722430758 },
	Gifts = { Growth = 3722430601, Money = 3722430619, Speed = 3722430627 },
	Lucky = { [1] = 3722430634, [3] = 3722430640, [5] = 3722430643 },
	Cash = { Small = 3722430653, Medium = 3722430663, Large = 3722430666 },
	Stars = { [1] = 3722532922, [3] = 3722532936, [5] = 3722532941 },
	Grow = { All = 3723013973, [900] = 3723013984, [1800] = 3723013987, [3600] = 3723013997 },
}
