--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.WaterVolume
-- The route channel is terrain water. RouteLandscape places it once.
-- Clearing terrain here used to erase that water on every play.

local Water = {}

function Water.ensure(root: Instance, config)
	if not root:FindFirstChild("WaterVolume") then
		local landscape = script.Parent:FindFirstChild("RouteLandscape")
		if landscape and landscape:IsA("ModuleScript") then
			require(landscape).apply(root, config)
		end
	end
	local terrain = workspace.Terrain
	terrain.WaterColor = config.WaterColor
	terrain.WaterTransparency = config.WaterTransparency
	terrain.WaterReflectance = config.WaterReflectance
	terrain.WaterWaveSize = config.WaterWaveSize
	terrain.WaterWaveSpeed = config.WaterWaveSpeed
end

return Water
