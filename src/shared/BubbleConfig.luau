--!strict
return table.freeze({
	TextureId = "rbxassetid://140080853317761",
	PerCell = 9,
	Rows = 3,
	Columns = 3,
	-- Eggs rest on the nest floor, inside the jail mouth.
	-- NeighborGap is the clear space between two eggs. Front commons
	-- spread to the mouth edges, so their gap grows past this.
	NeighborGap = 3,
	BarClearance = 2.4,
	MouthInset = 0.8,
	ShellPad = 1,
	-- Bottoms sit on the water. A hair of lift keeps the mesh off the floor.
	BottomClearance = 0.05,
	PlayerHeight = 5,
	MinScale = 0.5,
	MaxScale = 1.5,
	NativeHeight = 1.71468,
	RiseMin = 0,
	RiseMax = 0,
	SpinMin = 0,
	SpinMax = 0,
	HoverAmp = 0,
	PopSurface = 2.5,
	-- Bubbles pop this many player-heights above the nearest standing player.
	PopHeights = 2,
	Pastels = {
		Color3.fromRGB(255, 186, 214),
		Color3.fromRGB(186, 230, 255),
		Color3.fromRGB(204, 255, 214),
		Color3.fromRGB(255, 236, 179),
		Color3.fromRGB(221, 198, 255),
		Color3.fromRGB(255, 208, 184),
		Color3.fromRGB(178, 242, 237),
		Color3.fromRGB(255, 196, 230),
		Color3.fromRGB(196, 214, 255),
		Color3.fromRGB(232, 255, 196),
		Color3.fromRGB(255, 220, 236),
		Color3.fromRGB(200, 236, 255),
	},
})
