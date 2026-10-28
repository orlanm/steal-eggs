--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.Bake
-- Run once in Edit. The saved place then already contains the yard, the water
-- parts, and the mesh templates, so Play does not build them again.

local Bake = {}

function Bake.place(): Instance
	local config = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
	local map = require(script.Parent.Generator).build(config)
	require(script.Parent.Parent.TankSigns).decorate(map)
	require(script.Parent.TrailShops).build(map)
	require(script.Parent.Parent.FuseService).start(map)
	require(script.Parent.Parent.TreadmillBuild).warm()
	require(script.Parent.Parent.SurfaceFinish).start(map)
	map:SetAttribute("LoadReady", true)
	return map
end

return Bake
