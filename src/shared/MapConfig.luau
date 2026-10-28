--!strict
return table.freeze({
 Seed = 64219,
 Version = 39,
 RootName = "BabyBeastsMap",
 -- Seven square pens. Each side is 1.5x the 53.5-stud Steal an Egg pen width.
 PlayerSlots = 7,
 PenSize = 80.25,
 TankRadius = 82.5,
 TankHeight = 64,
 -- Square yard. The zone 0 road runs through it to the back wall.
 PlazaSize = 960,
 RouteStart = 480,
 ZoneLength = 336,
 CellWidth = 72,
 CellDepth = 96,
 CellHeight = 28,
 WallHeight = 35,
 -- Two rows inside a tile-aligned yard. Five pens face the plaza. Two pens by the
 -- entrance sit on the outer corners and face each other. Thirty-two studs between
 -- pens, and about thirty-six studs of grass between the fences and the walls.
 PenAreaWidth = 600,
 PenAreaDepth = 264,
 PenAreaCenter = Vector3.new(0, 0, 264),
 PenMargin = 36,
 PenGap = 32,
 RoadWidth = 144,
 WaterTop = 0,
 -- Zone and S-curve floors sit this many studs under the plaza. Terrain water fills back up to WaterTop.
 ChannelDepth = 5,
 BubbleCeiling = 116,
 -- Terrain water in the route channel — clear enough to read floor textures.
	WaterColor = Color3.fromRGB(72, 148, 162),
	WaterTransparency = 0.78,
	WaterReflectance = 0.01,
	WaterWaveSize = 0.04,
	WaterWaveSpeed = 3,
 -- Covers the widened tank yard (x ±480, z to -480) and the early route.
 OceanCenter = Vector3.new(0, 54, 1840),
 OceanSize = Vector3.new(1100, 124, 4720),
 Sand = Color3.fromRGB(138, 210, 106),
 Road = Color3.fromRGB(255, 244, 70),
 RoadAlternate = Color3.fromRGB(255, 208, 36),
 CheckerSize = 12,
 WalkSpeed = 16,
 RunSpeed = 16,
 SwimSpeed = 16,
 Rock = Color3.fromRGB(54, 82, 91),
})
