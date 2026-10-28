--!strict
local config = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
require(game.ReplicatedStorage.BabyBeastsShared.GameUI).ensureRemotes()
local generator = require(script.Parent.Map.Generator)
local ok, result = pcall(generator.build, config)
if not ok then
	error("[BabyBeastsMap] " .. tostring(result))
end
require(script.Parent.TankSigns).decorate(result)
require(script.Parent.LaneBoards).build(result)
require(script.Parent.JailSigns).build(result)
require(script.Parent.PlayerSlots).start(result)
require(script.Parent.TankBeasts).start(result)
require(script.Parent.PetAssets).start(result)
require(script.Parent.MommyBeasts).start(result)
require(script.Parent.WallImpact).start()
require(script.Parent.SpeedDataManager).start()
require(script.Parent.ShopServer).start()
require(script.Parent.PenPets).start()
require(script.Parent.TrainingService).start(result)
require(script.Parent.TankPassage).start(result)
require(script.Parent.PersonalTreadmills).start(result)
require(script.Parent.Map.TrailShops).build(result)
-- Plaza Most Money leaderboard removed.
for _, d in result:GetDescendants() do
	if d.Name == "MostMoneyBoard" then
		d:Destroy()
	end
end
require(script.Parent.FuseService).start(result)
require(script.Parent.CaveBubbles).start(result)
require(script.Parent.EggShop).start(result)
require(script.Parent.AdminEggs).start()
require(script.Parent.BeastData).start()
require(script.Parent.MountService).start(result)
require(script.Parent.SurfaceFinish).start(result)
require(script.Parent.TreadmillBuild).warm()
print("[BabyBeastsMap] Ready: seven pens, twenty-one biomes, jail bubbles; seed " .. config.Seed)
