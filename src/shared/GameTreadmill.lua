--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.GameTreadmill
-- Treadmill meshes and effects from the Steal An Egg reference.
-- Mesh asset ids load in this place. The models contain no scripts;
-- speed gain stays in TrainingService using EconomyConfig tiers.
-- Gameplay tiers 1–13 match EconomyConfig / catalog models (see forTier).

export type Emitter = {
	Name: string,
	Texture: string,
	Rate: number,
	Lifetime: number,
	Speed: number,
	LightEmission: number,
	Brightness: number,
	Size: number,
	Color: Color3,
}

export type Light = {
	Brightness: number,
	Range: number,
	Color: Color3,
}

export type Part = {
	Name: string,
	MeshId: string,
	Size: Vector3,
	Color: Color3,
	Transparency: number,
	Material: Enum.Material,
	CanCollide: boolean,
	Offset: CFrame,
	Lights: { Light },
	Emitters: { Emitter },
}

export type Treadmill = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Price: number,
	SpeedMultiplier: number,
	Rarity: string,
	Tier: number?,
	ModelId: string,
	Bounds: Vector3,
	Parts: { Part },
}

local Models: { Treadmill } = {
	{
		Id = "Treadmill",
		DisplayName = "Default Treadmill",
		Icon = "rbxassetid://84421204509494",
		Price = 0,
		SpeedMultiplier = 2,
		Rarity = "Common",
		Tier = 1,
		ModelId = "rbxassetid://131863877989832",
		Bounds = Vector3.new(10.9707, 9.785, 12.1596),
		Parts = {
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(0.4825, 0.4825, 5.3076),
				Color = Color3.fromRGB(142, 140, 145),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(2.7968, 5.4, 1.764, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(0.4825, 0.4825, 5.3076),
				Color = Color3.fromRGB(142, 140, 145),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-2.8441, 5.4, 1.764, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.4403, 1.4403, 0.7201),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0233, 3.7718, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.015",
				MeshId = "rbxassetid://139342863555643",
				Size = Vector3.new(6.665, 1.3156, 2.2206),
				Color = Color3.fromRGB(99, 97, 100),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 5.5022, 4.7646, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.014",
				MeshId = "rbxassetid://92089887958328",
				Size = Vector3.new(5.8564, 1.4985, 11.4139),
				Color = Color3.fromRGB(109, 108, 111),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 0.9451, -0.3728, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.013",
				MeshId = "rbxassetid://121727705211616",
				Size = Vector3.new(6.337, 1.281, 2.6021),
				Color = Color3.fromRGB(67, 66, 68),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 0.8363, 3.0791, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.012",
				MeshId = "rbxassetid://94469836392197",
				Size = Vector3.new(4.7036, 0.3793, 8.8722),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 0.6583, -1.3112, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.005",
				MeshId = "rbxassetid://131863877989832",
				Size = Vector3.new(5.2833, 6.5853, 2.9549),
				Color = Color3.fromRGB(142, 140, 145),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 3.4885, 4.6023, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.011",
				MeshId = "rbxassetid://111789128875047",
				Size = Vector3.new(4.3484, 0.538, 8.9581),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0236, 0.6583, -1.3542, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.032, 4.9777, 3.5496, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6459, 5.1067, 3.6387, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.5956, 5.1067, 3.6387, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoDecorationPart",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.032, 4.9777, 3.603, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(11.094, 6.548, 5.6),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.274, 0.2767, 0, 0, 1, 0, 1, 0, -1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(10.9707, 6.3971, 5.4678),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.274, 0.2472, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.024, 9.061, 3.6466, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.4403, 1.4403, 0.7201),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0233, 3.7718, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "Sci-FiTreadmill",
		DisplayName = "Sci-Fi Treadmill",
		Icon = "rbxassetid://81563639782445",
		Price = 15000,
		SpeedMultiplier = 5,
		Rarity = "Uncommon",
		Tier = 2,
		ModelId = "rbxassetid://110953966676996",
		Bounds = Vector3.new(9.1847, 9.9645, 13.4416),
		Parts = {
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(0, 156, 170),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.057, 4.4505, 3.0306, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.5713, 4.5795, 3.0659, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6713, 4.5795, 3.0659, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.057, 4.4505, 2.9773, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.026",
				MeshId = "rbxassetid://86231180624257",
				Size = Vector3.new(5.9335, 4.8651, 4.6617),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.1838, 2.584, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.027",
				MeshId = "rbxassetid://107220672860500",
				Size = Vector3.new(5.7194, 4.9919, 3.4177),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.5406, 4.3623, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.001 (4)",
				MeshId = "rbxassetid://110953966676996",
				Size = Vector3.new(8.9073, 8.4538, 13.4416),
				Color = Color3.fromRGB(204, 209, 221),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.2715, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.024 (1)",
				MeshId = "rbxassetid://113919418981156",
				Size = Vector3.new(9.1847, 8.3275, 11.8167),
				Color = Color3.fromRGB(142, 147, 149),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.2083, -0.1777, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.030",
				MeshId = "rbxassetid://108458132421474",
				Size = Vector3.new(4.2671, 0.5279, 9.1315),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4985, -1.9131, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://118850709671124",
						Rate = 7,
						Lifetime = 1.5,
						Speed = 5.6818,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.9233,
						Color = Color3.fromRGB(105, 210, 255),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.023 (1)",
				MeshId = "rbxassetid://70749369334188",
				Size = Vector3.new(6.278, 5.2077, 13.2958),
				Color = Color3.fromRGB(86, 137, 176),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.6483, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.029",
				MeshId = "rbxassetid://77740470033712",
				Size = Vector3.new(4.6156, 0.3722, 9.0472),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4985, -1.871, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2001, -0.5727, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(11.9896, 7.2276, 7.0518),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.6138, -0.535, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2001, -0.5727, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.057, 9.2405, 2.9773, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "FlameTreadmill",
		DisplayName = "Flame Treadmill",
		Icon = "rbxassetid://103122274001487",
		Price = 250000,
		SpeedMultiplier = 12,
		Rarity = "Rare",
		Tier = 3,
		ModelId = "rbxassetid://140562238835915",
		Bounds = Vector3.new(9.1683, 9.7988, 14.5765),
		Parts = {
			{
				Name = "Meshes/untitled_Cube.087",
				MeshId = "rbxassetid://90522816041905",
				Size = Vector3.new(4.0813, 0.505, 9.7876),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4341, -1.777, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.090",
				MeshId = "rbxassetid://140562238835915",
				Size = Vector3.new(7.09, 6.5571, 12.1036),
				Color = Color3.fromRGB(220, 220, 220),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2786, -0.8505, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cylinder.002 (6)",
				MeshId = "rbxassetid://135463263718240",
				Size = Vector3.new(8.6812, 5.3854, 9.0083),
				Color = Color3.fromRGB(220, 220, 220),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.6927, 1.849, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.085",
				MeshId = "rbxassetid://118424771349753",
				Size = Vector3.new(6.2556, 1.2348, 2.0842),
				Color = Color3.fromRGB(71, 209, 240),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.9805, 3.9668, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.091",
				MeshId = "rbxassetid://102044675466388",
				Size = Vector3.new(7.0157, 1.8413, 12.4891),
				Color = Color3.fromRGB(194, 194, 194),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.9206, -0.5336, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.093",
				MeshId = "rbxassetid://112764495676085",
				Size = Vector3.new(4.4147, 0.356, 9.707),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4341, -1.7366, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cylinder.003 (2)",
				MeshId = "rbxassetid://129086025568665",
				Size = Vector3.new(9.1683, 5.2643, 9.1261),
				Color = Color3.fromRGB(58, 168, 199),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.6322, 2.0109, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0498, 3.5466, -0.9361, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0023, 4.7968, 2.6139, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(0, 255, 255),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0023, 4.7968, 2.6673, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.6306, 4.9258, 2.7025, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6119, 4.9258, 2.7025, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0498, 3.5466, -0.9361, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(14.5765, 8.6484, 9.1465),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.4672, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0023, 9.0748, 2.6139, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "GoldenTreadmill",
		DisplayName = "Golden Treadmill",
		Icon = "rbxassetid://99555941892079",
		Price = 120000000,
		SpeedMultiplier = 80,
		Rarity = "Legendary",
		Tier = 5,
		ModelId = "rbxassetid://75059913457738",
		Bounds = Vector3.new(10.7729, 10.5918, 13.3677),
		Parts = {
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.028",
				MeshId = "rbxassetid://105813078269691",
				Size = Vector3.new(9.9056, 1.9611, 11.2352),
				Color = Color3.fromRGB(220, 117, 44),
				Transparency = 0,
				Material = Enum.Material.Glass,
				CanCollide = false,
				Offset = CFrame.new(-0.1237, 0.9806, 0.34, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.034",
				MeshId = "rbxassetid://91384341677301",
				Size = Vector3.new(10.7729, 5.4146, 2.533),
				Color = Color3.fromRGB(60, 60, 61),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.7074, 3.677, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.033 (1)",
				MeshId = "rbxassetid://125230562749069",
				Size = Vector3.new(8.3532, 9.5256, 12.1167),
				Color = Color3.fromRGB(214, 164, 39),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.7628, 0.6255, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.003 (4)",
				MeshId = "rbxassetid://75059913457738",
				Size = Vector3.new(10.5094, 7.7501, 12.0198),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.8751, -0.2126, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.031",
				MeshId = "rbxassetid://73444015624070",
				Size = Vector3.new(4.2947, 0.4884, 8.6583),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4199, -1.6695, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://118850709671124",
						Rate = 12,
						Lifetime = 1.5,
						Speed = 5.2565,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.8542,
						Color = Color3.fromRGB(255, 223, 61),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.032 (1)",
				MeshId = "rbxassetid://117943441054180",
				Size = Vector3.new(4.6171, 0.3443, 8.5803),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4199, -1.6305, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.1063, 4.2135, -0.4539, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 7.661, 0.8113),
				Color = Color3.fromRGB(163, 163, 0),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0077, 4.8563, 3.1494, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6065, 5.4888, 3.1846, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.636, 5.4888, 3.1846, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0077, 5.3598, 3.0961, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.1063, 4.2135, -0.4539, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(13.004, 8.198, 8.3954),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0476, 4.3881, -0.1819, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0077, 9.8678, 3.0961, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "HackerTreadmill",
		DisplayName = "Hacker Treadmill",
		Icon = "rbxassetid://114661675379027",
		Price = 2000000000000,
		SpeedMultiplier = 500,
		Rarity = "Secret",
		Tier = 8,
		ModelId = "rbxassetid://86291678240298",
		Bounds = Vector3.new(10.2468, 9.6932, 14.8613),
		Parts = {
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.006",
				MeshId = "rbxassetid://119163447211907",
				Size = Vector3.new(9.7421, 9.0427, 2.1943),
				Color = Color3.fromRGB(83, 83, 84),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 4.5217, 5.6837, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.057",
				MeshId = "rbxassetid://87250269172567",
				Size = Vector3.new(7.3098, 5.1493, 0.5256),
				Color = Color3.fromRGB(61, 61, 62),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 3.8845, 5.6837, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.054",
				MeshId = "rbxassetid://124387325110265",
				Size = Vector3.new(9.5585, 0.4458, 5.3948),
				Color = Color3.fromRGB(39, 48, 34),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 0.2232, 1.5925, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.053",
				MeshId = "rbxassetid://104913051349192",
				Size = Vector3.new(6.1594, 0.3355, 10.5977),
				Color = Color3.fromRGB(52, 57, 50),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 0.4916, 1.9607, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.056",
				MeshId = "rbxassetid://139991069535368",
				Size = Vector3.new(2.9408, 3.0153, 0.4104),
				Color = Color3.fromRGB(28, 43, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 8.1855, 5.6091, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.059",
				MeshId = "rbxassetid://120634102405402",
				Size = Vector3.new(4.9606, 0.5097, 11.3787),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 0.4382, -0.9783, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://109008033162084",
						Rate = 15,
						Lifetime = 1.5,
						Speed = 3.2914,
						LightEmission = 0,
						Brightness = 20,
						Size = 0.8914,
						Color = Color3.fromRGB(0, 0, 0),
					},
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://109008033162084",
						Rate = 15,
						Lifetime = 1.5,
						Speed = 3.2914,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.8914,
						Color = Color3.fromRGB(68, 171, 0),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.055",
				MeshId = "rbxassetid://72842051977726",
				Size = Vector3.new(6.4206, 9.008, 14.4222),
				Color = Color3.fromRGB(36, 56, 34),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 4.504, 0.2195, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.052",
				MeshId = "rbxassetid://86291678240298",
				Size = Vector3.new(8.7197, 7.9608, 13.3644),
				Color = Color3.fromRGB(111, 193, 67),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0555, 4.3021, 0.4387, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Effect",
						Texture = "rbxassetid://99126241303927",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 5,
						Size = 0,
						Color = Color3.fromRGB(53, 214, 17),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://101465239890649",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 2.1943,
						Color = Color3.fromRGB(133, 255, 124),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://101465239890649",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 2.1943,
						Color = Color3.fromRGB(133, 255, 124),
					},
					{
						Name = "Effect",
						Texture = "rbxassetid://99126241303927",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 5,
						Size = 0,
						Color = Color3.fromRGB(53, 214, 17),
					},
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0425, 3.3078, 1.2837, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0006, 4.4999, 4.8871, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.6289, 4.6289, 4.9223, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6136, 4.6289, 4.9223, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0006, 4.4999, 4.8337, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0425, 3.3078, 1.2837, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(14.4952, 8.2057, 10.2468),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.3139, -0.1831, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0006, 8.7779, 4.8337, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "BrockTreadmill",
		DisplayName = "Brock Treadmill",
		Icon = "",
		Price = 0,
		SpeedMultiplier = 1000000000,
		Rarity = "Titan",
		Tier = nil, -- catalog only (max = Angelic Lv.10)
		ModelId = "rbxassetid://84620385245134",
		Bounds = Vector3.new(11.455, 13.5397, 12.3103),
		Parts = {
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.486, 4.6043, 0.0325),
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 4.1374, 2.3868, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(0.7475, 1.768, 0.0325),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.1948, 4.1374, 2.3868, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(0.7475, 1.768, 0.0325),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.1948, 4.1374, 2.3868, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.003",
				MeshId = "rbxassetid://80527979370183",
				Size = Vector3.new(6.8166, 0.1331, 0.9761),
				Color = Color3.fromRGB(188, 155, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 7.9594, 2.861, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.007",
				MeshId = "rbxassetid://108182901922886",
				Size = Vector3.new(0.3939, 0.8974, 8.7556),
				Color = Color3.fromRGB(140, 135, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(2.1587, 0.5053, -1.556, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.014",
				MeshId = "rbxassetid://131558008371117",
				Size = Vector3.new(4.6661, 8.4333, 2.051),
				Color = Color3.fromRGB(140, 135, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 4.242, 2.9822, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.018",
				MeshId = "rbxassetid://130110382509526",
				Size = Vector3.new(0.3939, 0.8974, 8.7556),
				Color = Color3.fromRGB(140, 135, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-2.1587, 0.5053, -1.556, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.021",
				MeshId = "rbxassetid://125368589869935",
				Size = Vector3.new(1.3589, 3.109, 0.3388),
				Color = Color3.fromRGB(188, 155, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 5.2745, 3.8497, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.034",
				MeshId = "rbxassetid://73346165547724",
				Size = Vector3.new(7.1346, 1.1752, 0.9496),
				Color = Color3.fromRGB(124, 134, 86),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.9168, 1.6647, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.057",
				MeshId = "rbxassetid://73781870411879",
				Size = Vector3.new(8.5318, 8.0899, 9.0997),
				Color = Color3.fromRGB(200, 188, 138),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.0865, -1.2334, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Plane",
				MeshId = "rbxassetid://106553713059834",
				Size = Vector3.new(1.5841, 1.1533, 0.6584),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0098, 11.5702, 2.089, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "back",
				MeshId = "rbxassetid://80998526600999",
				Size = Vector3.new(3.7655, 6.6428, 0.001),
				Color = Color3.fromRGB(126, 125, 93),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.5338, 3.7123, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "black",
				MeshId = "rbxassetid://120324747079000",
				Size = Vector3.new(3.4312, 0.775, 7.619),
				Color = Color3.fromRGB(41, 41, 42),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4525, -1.9364, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "body brick.066",
				MeshId = "rbxassetid://84620385245134",
				Size = Vector3.new(10.6495, 7.6419, 10.9227),
				Color = Color3.fromRGB(150, 149, 111),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.821, -0.6747, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "brick",
				MeshId = "rbxassetid://92627557064171",
				Size = Vector3.new(10.861, 6.179, 10.4476),
				Color = Color3.fromRGB(118, 112, 83),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.1159, -0.3736, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "brick.001",
				MeshId = "rbxassetid://83025303882167",
				Size = Vector3.new(8.4632, 0.4714, 1.9656),
				Color = Color3.fromRGB(140, 131, 96),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 1.4781, -1.8767, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "brick.002",
				MeshId = "rbxassetid://71198133333914",
				Size = Vector3.new(2.8011, 4.1637, 0.2599),
				Color = Color3.fromRGB(147, 138, 104),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0342, 4.3913, 3.7075, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "crock eye.006",
				MeshId = "rbxassetid://103274056879315",
				Size = Vector3.new(6.8196, 0.1282, 0.0997),
				Color = Color3.fromRGB(166, 139, 72),
				Transparency = 0,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Offset = CFrame.new(0, 6.3766, 1.7688, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "crystal.006",
				MeshId = "rbxassetid://116092076765557",
				Size = Vector3.new(9.3081, 8.6118, 10.0462),
				Color = Color3.fromRGB(116, 221, 42),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.2842, -0.5415, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "glow green.008",
				MeshId = "rbxassetid://122587596863048",
				Size = Vector3.new(4.2959, 5.928, 7.9611),
				Color = Color3.fromRGB(52, 229, 21),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 3.0634, -1.7162, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "green.041",
				MeshId = "rbxassetid://78610465729571",
				Size = Vector3.new(10.7674, 7.4518, 10.9681),
				Color = Color3.fromRGB(111, 167, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 4.1185, -0.6711, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "hat",
				MeshId = "rbxassetid://130803402041019",
				Size = Vector3.new(6.1302, 3.1174, 5.5946),
				Color = Color3.fromRGB(65, 73, 47),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0088, 10.6656, 3.3578, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "head 2",
				MeshId = "rbxassetid://119113785611291",
				Size = Vector3.new(3.5991, 1.3316, 4.5278),
				Color = Color3.fromRGB(204, 179, 126),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0088, 8.6394, 1.9446, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "head.005",
				MeshId = "rbxassetid://83832117119854",
				Size = Vector3.new(3.1126, 2.8945, 5.1702),
				Color = Color3.fromRGB(146, 181, 47),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0078, 9.4208, 2.166, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "leaf.015",
				MeshId = "rbxassetid://82720035021537",
				Size = Vector3.new(11.455, 7.3049, 7.303),
				Color = Color3.fromRGB(45, 89, 27),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.8128, 1.3297, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "orange.001",
				MeshId = "rbxassetid://138748509334698",
				Size = Vector3.new(4.4623, 2.275, 1.0217),
				Color = Color3.fromRGB(243, 140, 13),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0078, 9.1496, 2.9305, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "screen",
				MeshId = "rbxassetid://114831841921880",
				Size = Vector3.new(3.486, 7.3479, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 4.1375, 2.4818, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "water.013",
				MeshId = "rbxassetid://106475565723338",
				Size = Vector3.new(7.8181, 3.3883, 7.5758),
				Color = Color3.fromRGB(43, 255, 255),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 1.7357, -1.8311, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "white.004",
				MeshId = "rbxassetid://122080919069376",
				Size = Vector3.new(3.3053, 1.9416, 3.0659),
				Color = Color3.fromRGB(252, 250, 255),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0083, 9.5916, 1.2167, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "yellow.004",
				MeshId = "rbxassetid://115231568841820",
				Size = Vector3.new(4.6071, 0.5327, 1.1001),
				Color = Color3.fromRGB(253, 197, 97),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0078, 8.4896, 2.9631, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.1348, 1.1348, 0.5674),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.1699, -1.9364, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(11.455, 12.2243, 12.3103),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 6.1122, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(2.5986, 0.9407, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0098, 13.0693, 2.3868, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "CelebrityTreadmill",
		DisplayName = "Celebrity Treadmill",
		Icon = "rbxassetid://75188836342954",
		Price = 5000000,
		SpeedMultiplier = 30,
		Rarity = "Epic",
		Tier = 4,
		ModelId = "rbxassetid://131255517870419",
		Bounds = Vector3.new(10.6295, 10.1678, 15.0367),
		Parts = {
			{
				Name = "Meshes/untitled_Cylinder (5)",
				MeshId = "rbxassetid://131255517870419",
				Size = Vector3.new(10.6295, 6.4696, 8.0947),
				Color = Color3.fromRGB(214, 164, 39),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2405, 3.471, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.082",
				MeshId = "rbxassetid://129109923047395",
				Size = Vector3.new(4.4206, 0.3565, 8.3385),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4347, -2.7382, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cylinder.001 (4)",
				MeshId = "rbxassetid://78111438770381",
				Size = Vector3.new(10.37, 5.9196, 7.5532),
				Color = Color3.fromRGB(97, 158, 255),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.273, 3.5132, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.083",
				MeshId = "rbxassetid://136282094931013",
				Size = Vector3.new(4.0869, 0.5056, 8.4192),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4347, -2.7785, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.018",
				MeshId = "rbxassetid://96379747837516",
				Size = Vector3.new(5.5041, 1.4084, 10.7274),
				Color = Color3.fromRGB(214, 164, 39),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.7042, -1.8563, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(0.4535, 0.4535, 4.9883),
				Color = Color3.fromRGB(235, 138, 59),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6508, 4.4946, -0.3772, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.022",
				MeshId = "rbxassetid://132254305048191",
				Size = Vector3.new(6.2641, 1.8202, 2.2797),
				Color = Color3.fromRGB(214, 164, 39),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.2791, 3.0684, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.002 (1)",
				MeshId = "rbxassetid://122398194148075",
				Size = Vector3.new(6.361, 1.2039, 9.9625),
				Color = Color3.fromRGB(225, 124, 51),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.602, -2.5003, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.019",
				MeshId = "rbxassetid://85651229085876",
				Size = Vector3.new(4.9655, 5.3363, 2.1659),
				Color = Color3.fromRGB(53, 54, 56),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.6682, 2.514, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(0.4535, 0.4535, 4.9883),
				Color = Color3.fromRGB(235, 138, 59),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(2.6508, 4.4946, -0.3772, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.020",
				MeshId = "rbxassetid://124655830928653",
				Size = Vector3.new(6.037, 3.3722, 3.2888),
				Color = Color3.fromRGB(235, 138, 59),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.89, 1.5841, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.6399, 1.6399, 0.8199),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0036, 4.5228, -1.8798, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6307, 5.2838, 1.7588, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 7.596, 0.8113),
				Color = Color3.fromRGB(255, 176, 0),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0165, 4.6838, 1.7236, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.6118, 5.2838, 1.7588, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0165, 5.1548, 1.6702, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.474, 1.474, 0.737),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0036, 4.0653, -1.8798, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(13.0312, 7.6162, 9.7521),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0036, 3.9123, -1.0027, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0165, 9.4438, 1.6702, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "The FreezeTreadmill",
		DisplayName = "The Freeze Treadmill",
		Icon = "rbxassetid://97611802500180",
		Price = 3000000000,
		SpeedMultiplier = 100,
		Rarity = "Mythic",
		Tier = 6,
		ModelId = "rbxassetid://85074866931573",
		Bounds = Vector3.new(11.5075, 10.6054, 15.336),
		Parts = {
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.5749, 1.5749, 0.7874),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.8202, -0.3123, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.039 (1)",
				MeshId = "rbxassetid://85074866931573",
				Size = Vector3.new(11.5075, 8.5015, 14.5095),
				Color = Color3.fromRGB(71, 139, 198),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.4576, -0.4133, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.037",
				MeshId = "rbxassetid://129383409535668",
				Size = Vector3.new(8.4196, 6.6684, 12.8617),
				Color = Color3.fromRGB(51, 95, 149),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.5256, -0.7987, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.041 (1)",
				MeshId = "rbxassetid://111911417405885",
				Size = Vector3.new(8.344, 4.6475, 12.0526),
				Color = Color3.fromRGB(32, 67, 97),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 2.5151, -1.0771, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.038 (1)",
				MeshId = "rbxassetid://128739113485278",
				Size = Vector3.new(4.1506, 0.5135, 10.5065),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.6329, -1.7409, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://118850709671124",
						Rate = 15,
						Lifetime = 1.5,
						Speed = 5.5267,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.8981,
						Color = Color3.fromRGB(30, 116, 255),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.043",
				MeshId = "rbxassetid://135621505470556",
				Size = Vector3.new(4.4896, 0.362, 10.4245),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.6329, -1.6999, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.036",
				MeshId = "rbxassetid://71323865106994",
				Size = Vector3.new(4.6605, 7.7441, 0.4684),
				Color = Color3.fromRGB(110, 156, 191),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.4596, 3.275, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.040",
				MeshId = "rbxassetid://70576566176982",
				Size = Vector3.new(8.885, 2.9303, 9.0972),
				Color = Color3.fromRGB(88, 177, 191),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 1.6565, 1.0706, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.044",
				MeshId = "rbxassetid://118789270193342",
				Size = Vector3.new(8.0571, 0.7394, 1.4788),
				Color = Color3.fromRGB(82, 163, 230),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.5611, 3.8439, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.004",
				MeshId = "rbxassetid://104413197864160",
				Size = Vector3.new(6.3618, 1.2557, 2.1196),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.2564, 4.3767, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.042",
				MeshId = "rbxassetid://80330095529695",
				Size = Vector3.new(6.2816, 0.6565, 0.8671),
				Color = Color3.fromRGB(38, 93, 165),
				Transparency = 0,
				Material = Enum.Material.Glass,
				CanCollide = false,
				Offset = CFrame.new(0, 4.9646, 2.7023, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0177, 5.0584, 3.2377, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(18, 238, 212),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0177, 5.0584, 3.2911, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.6106, 5.1874, 3.3263, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6319, 5.1874, 3.3263, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.5749, 1.5749, 0.7874),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.8202, -0.3123, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(15.2091, 10.0075, 8.666),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0257, 5.0037, 0.0635, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0177, 9.8814, 3.2377, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "Lucky BlockTreadmill",
		DisplayName = "Lucky Block Treadmill",
		Icon = "rbxassetid://85546442623094",
		Price = 75000000000,
		SpeedMultiplier = 200,
		Rarity = "Cosmic",
		Tier = 7,
		ModelId = "rbxassetid://86671110061799",
		Bounds = Vector3.new(12.4632, 11.6316, 14.5426),
		Parts = {
			{
				Name = "Meshes/untitled_Cube.010",
				MeshId = "rbxassetid://86671110061799",
				Size = Vector3.new(10.7542, 10.9343, 11.0625),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.2253, 6.1645, 1.6667, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.080",
				MeshId = "rbxassetid://103577920171047",
				Size = Vector3.new(10.7945, 7.2532, 10.0602),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.2542, 3.7523, 1.934, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.079",
				MeshId = "rbxassetid://134524096391339",
				Size = Vector3.new(9.7395, 7.4337, 10.9684),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.2945, 5.2731, 1.1703, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.081",
				MeshId = "rbxassetid://114789724047876",
				Size = Vector3.new(4.5067, 11.0868, 7.9508),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(2.9599, 5.6691, 2.6348, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.076 (1)",
				MeshId = "rbxassetid://87932248849453",
				Size = Vector3.new(9.2127, 1.3115, 14.3581),
				Color = Color3.fromRGB(43, 43, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0245, 0.7811, -0.0923, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://73401929769565",
						Rate = 5,
						Lifetime = 1.5,
						Speed = 5.0674,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.6334,
						Color = Color3.fromRGB(255, 135, 66),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.074 (1)",
				MeshId = "rbxassetid://137521096585770",
				Size = Vector3.new(5.3232, 0.3319, 11.3096),
				Color = Color3.fromRGB(177, 177, 184),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0245, 0.5302, -1.3255, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.075 (1)",
				MeshId = "rbxassetid://138044172413469",
				Size = Vector3.new(4.82, 0.6606, 11.2358),
				Color = Color3.fromRGB(189, 127, 96),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0245, 0.5302, -1.5402, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.073 (1)",
				MeshId = "rbxassetid://118227326593662",
				Size = Vector3.new(2.998, 0.4709, 11.3848),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0245, 0.5302, -1.3631, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.6582, 1.6582, 0.8291),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.025, 3.0445, 0.0436, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 7.704, 0.8113),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0714, 4.3732, 3.647, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.6997, 5.0272, 3.6822, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.5428, 5.0272, 3.6822, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0714, 4.8982, 3.5936, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.6582, 1.6582, 0.8291),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.025, 3.0445, 0.0436, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(14.4398, 7.6545, 12.4632),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.8273, 0.0514, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0714, 9.2852, 3.5936, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "DemonicTreadmill",
		DisplayName = "Demonic Treadmill",
		Icon = "rbxassetid://99849961715962",
		Price = 50000000000000,
		SpeedMultiplier = 1000,
		Rarity = "Eternal",
		Tier = 9,
		ModelId = "rbxassetid://103146825149794",
		Bounds = Vector3.new(11.0053, 9.8052, 16.2745),
		Parts = {
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.064",
				MeshId = "rbxassetid://74974050923003",
				Size = Vector3.new(9.8429, 1.6528, 9.8883),
				Color = Color3.fromRGB(109, 75, 63),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 0.8987, 2.3714, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.063",
				MeshId = "rbxassetid://96160561165550",
				Size = Vector3.new(8.6388, 2.4345, 9.0871),
				Color = Color3.fromRGB(153, 88, 50),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 1.6215, 2.2445, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmills 1_Cube.007",
				MeshId = "rbxassetid://118184815531909",
				Size = Vector3.new(9.3021, 9.4465, 8.2429),
				Color = Color3.fromRGB(61, 65, 75),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 4.7257, 2.222, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.062",
				MeshId = "rbxassetid://101267894294917",
				Size = Vector3.new(7.9479, 2.1874, 13.7155),
				Color = Color3.fromRGB(193, 108, 75),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 1.5679, -0.4139, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.066",
				MeshId = "rbxassetid://108215315332083",
				Size = Vector3.new(3.9999, 0.4549, 12.0925),
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 0.4631, -1.0098, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.484,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 0, 0),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.065",
				MeshId = "rbxassetid://85886496335448",
				Size = Vector3.new(4.3002, 0.3207, 12.0198),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 0.4631, -0.9735, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.067",
				MeshId = "rbxassetid://103146825149794",
				Size = Vector3.new(8.7279, 8.0589, 13.4331),
				Color = Color3.fromRGB(88, 49, 37),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0466, 4.1015, -0.7646, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "fire",
						Texture = "rbxassetid://12972038293",
						Rate = 8,
						Lifetime = 1.3,
						Speed = 5.875,
						LightEmission = 1,
						Brightness = 1,
						Size = 0,
						Color = Color3.fromRGB(255, 0, 0),
					},
					{
						Name = "fire",
						Texture = "rbxassetid://138453386704018",
						Rate = 8,
						Lifetime = 1,
						Speed = 5.875,
						LightEmission = 0.1,
						Brightness = 1,
						Size = 0,
						Color = Color3.fromRGB(50, 0, 0),
					},
					{
						Name = "fire",
						Texture = "rbxassetid://138453386704018",
						Rate = 8,
						Lifetime = 1,
						Speed = 5.875,
						LightEmission = 0.1,
						Brightness = 1,
						Size = 0,
						Color = Color3.fromRGB(50, 0, 0),
					},
					{
						Name = "fire",
						Texture = "rbxassetid://12972038293",
						Rate = 8,
						Lifetime = 1.3,
						Speed = 5.875,
						LightEmission = 1,
						Brightness = 1,
						Size = 0,
						Color = Color3.fromRGB(255, 0, 0),
					},
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2924, 0.1458, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.5939, 4.5088, 3.7844, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.6877, 6.556, 0.726),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0344, 4.3798, 3.6958, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.4674, 2.9713, 0.7854),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.6486, 4.5088, 3.7844, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.7848, 6.654, 0.8113),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0344, 4.3798, 3.7491, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.2924, 0.1458, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(16.2745, 9.8052, 11.0053),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.9026, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0344, 8.6578, 3.6958, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "AngelicTreadmill",
		DisplayName = "Angelic Treadmill",
		Icon = "rbxassetid://104277706019985",
		Price = 1000000000000000,
		SpeedMultiplier = 2000,
		Rarity = "Divine",
		Tier = 10,
		ModelId = "rbxassetid://117285494184150",
		Bounds = Vector3.new(15.1003, 10.5398, 15.3809),
		Parts = {
			{
				Name = "Meshes/untitled_Cube.084",
				MeshId = "rbxassetid://76754364286149",
				Size = Vector3.new(8.5791, 1.0892, 2.9618),
				Color = Color3.fromRGB(182, 180, 184),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 9.7743, 4.7963, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Energy",
						Texture = "rbxassetid://136162665037108",
						Rate = 2,
						Lifetime = 3,
						Speed = 0.0009,
						LightEmission = 10,
						Brightness = 12,
						Size = 3.2723,
						Color = Color3.fromRGB(252, 255, 187),
					},
					{
						Name = "Energy",
						Texture = "rbxassetid://136162665037108",
						Rate = 2,
						Lifetime = 3,
						Speed = 0.0009,
						LightEmission = 10,
						Brightness = 12,
						Size = 3.2723,
						Color = Color3.fromRGB(252, 255, 187),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.068",
				MeshId = "rbxassetid://82403794339925",
				Size = Vector3.new(2.6079, 0.2804, 10.3027),
				Color = Color3.fromRGB(184, 189, 96),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4087, -1.6668, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.008 (3)",
				MeshId = "rbxassetid://112221484148661",
				Size = Vector3.new(15.1003, 8.1005, 12.889),
				Color = Color3.fromRGB(237, 235, 240),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.1019, -0.8347, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.071",
				MeshId = "rbxassetid://113873551411593",
				Size = Vector3.new(10.1596, 8.2748, 12.8078),
				Color = Color3.fromRGB(214, 168, 76),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.189, -0.7984, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.6933,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.4918,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 2.356,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.6933,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 2.356,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.4918,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.6933,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://107970911527060",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.6933,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(242, 161, 0),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.070",
				MeshId = "rbxassetid://130188875646149",
				Size = Vector3.new(3.6511, 0.4152, 10.3757),
				Color = Color3.fromRGB(42, 42, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4087, -1.7033, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://118850709671124",
						Rate = 5,
						Lifetime = 1.5,
						Speed = 4.4689,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.7262,
						Color = Color3.fromRGB(255, 172, 55),
					},
				},
			},
			{
				Name = "Meshes/untitled_Cube.069",
				MeshId = "rbxassetid://140710241468261",
				Size = Vector3.new(3.9252, 0.2927, 10.3094),
				Color = Color3.fromRGB(25, 25, 26),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.4087, -1.6702, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/untitled_Cube.072",
				MeshId = "rbxassetid://117285494184150",
				Size = Vector3.new(15.1003, 8.3935, 13.2349),
				Color = Color3.fromRGB(165, 128, 43),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.2484, -0.6617, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0296, 3.9463, -0.0627, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.8428, 6.8318, 0.7565),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0099, 5.3073, 3.4949, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(3.944, 7.713, 0.8454),
				Color = Color3.fromRGB(231, 231, 236),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0099, 4.9178, 3.5506, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(2.5712, 3.0963, 0.8184),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.7137, 5.4417, 3.5875, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(2.5712, 3.0963, 0.8184),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.7487, 5.4417, 3.5872, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(15.3809, 9.8472, 12.4408),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0296, 4.9236, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(8.9729, 8.5105, 0.226),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0.65,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0.0093, 5.75, 3.2962, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(4, 1.448, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0.0103, 9.8158, 3.4876, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(-0.0296, 3.9463, -0.0627, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "AstralTreadmill",
		DisplayName = "Astral Treadmill",
		Icon = "rbxassetid://118444572497588",
		Price = 2500000000000000,
		SpeedMultiplier = 3000,
		Rarity = "Titan",
		Tier = nil, -- catalog only (max = Angelic Lv.10)
		ModelId = "rbxassetid://93149970374244",
		Bounds = Vector3.new(11.0685, 16.1039, 18.2647),
		Parts = {
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(4.6501, 6.0489, 0.7565),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.4508, 5.584, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 2.1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(4.8663, 6.8244, 0.8454),
				Color = Color3.fromRGB(231, 231, 236),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.1406, 5.7837, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(1.302, 2.722, 0.8184),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-4.6499, 5.2957, 5.5039, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(1.302, 2.722, 0.8184),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(4.6499, 5.2957, 5.5039, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Cube.095 (2)",
				MeshId = "",
				Size = Vector3.new(5.4071, 7.755, 0.4237),
				Color = Color3.fromRGB(39, 42, 43),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.1406, 6.0039, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Cube.099 (2)",
				MeshId = "rbxassetid://124624154198946",
				Size = Vector3.new(10.1602, 11.9383, 17.5334),
				Color = Color3.fromRGB(180, 135, 30),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.9692, -0.2188, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Effect",
						Texture = "rbxassetid://12160798454",
						Rate = 3,
						Lifetime = 2,
						Speed = 1,
						LightEmission = 1,
						Brightness = 4,
						Size = 0,
						Color = Color3.fromRGB(14, 69, 214),
					},
					{
						Name = "Effect",
						Texture = "rbxassetid://12160798454",
						Rate = 3,
						Lifetime = 2,
						Speed = 1,
						LightEmission = 1,
						Brightness = 4,
						Size = 0,
						Color = Color3.fromRGB(14, 69, 214),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 2.4,
						Color = Color3.fromRGB(43, 149, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 2.4,
						Color = Color3.fromRGB(43, 149, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 2.4,
						Color = Color3.fromRGB(43, 149, 255),
					},
					{
						Name = "Effect",
						Texture = "rbxassetid://12160798454",
						Rate = 3,
						Lifetime = 2,
						Speed = 1,
						LightEmission = 1,
						Brightness = 4,
						Size = 0,
						Color = Color3.fromRGB(14, 69, 214),
					},
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Cylinder.009 (2)",
				MeshId = "rbxassetid://93149970374244",
				Size = Vector3.new(11.0685, 14.2774, 17.9772),
				Color = Color3.fromRGB(115, 202, 255),
				Transparency = 0,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Offset = CFrame.new(0, 7.4416, -0.0527, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "Spec",
						Texture = "rbxassetid://94575713790678",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.8187,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(60, 173, 242),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://94575713790678",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.8187,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(60, 173, 242),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://94575713790678",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.8187,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(60, 173, 242),
					},
					{
						Name = "Spec",
						Texture = "rbxassetid://94575713790678",
						Rate = 6,
						Lifetime = 2,
						Speed = 1.8187,
						LightEmission = 0,
						Brightness = 15,
						Size = 0,
						Color = Color3.fromRGB(60, 173, 242),
					},
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://14960943986",
						Rate = 5,
						Lifetime = 1.5,
						Speed = 6,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.75,
						Color = Color3.fromRGB(65, 178, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://12160798454",
						Rate = 1,
						Lifetime = 2,
						Speed = 0,
						LightEmission = 1,
						Brightness = 15,
						Size = 1,
						Color = Color3.fromRGB(43, 149, 255),
					},
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Cube.089 (2)",
				MeshId = "rbxassetid://139413809742166",
				Size = Vector3.new(6.2685, 0.4404, 14.1988),
				Color = Color3.fromRGB(26, 26, 27),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.3994, -1.5146, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 5, Range = 10, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://14960943986",
						Rate = 5,
						Lifetime = 1.5,
						Speed = 6,
						LightEmission = 1,
						Brightness = 20,
						Size = 0.975,
						Color = Color3.fromRGB(255, 172, 55),
					},
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Plane (2)",
				MeshId = "rbxassetid://103788266474577",
				Size = Vector3.new(4.6335, 0.001, 12.4603),
				Color = Color3.fromRGB(255, 180, 83),
				Transparency = 0,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Offset = CFrame.new(0, 0.6286, -2.0708, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Meshes/Steal an Egg Treadmill 2_Cylinder.005 (2)",
				MeshId = "rbxassetid://72902889847458",
				Size = Vector3.new(11.0619, 12.5335, 18.2647),
				Color = Color3.fromRGB(45, 50, 55),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 6.2667, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(11.0685, 14.5803, 18.2647),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 7.2901, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Part",
				MeshId = "",
				Size = Vector3.new(5.9478, 7.9101, 0.226),
				Color = Color3.fromRGB(17, 17, 17),
				Transparency = 0.65,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.6059, 5.3838, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(3.9978, 1.4472, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 15.3803, 5.584, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.7459, 1.7459, 0.8729),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.9591, -2.0708, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
	{
		Id = "GuardianTreadmill",
		DisplayName = "Guardian Treadmill",
		Icon = "rbxassetid://90899568339219",
		Price = 7500000000000000,
		SpeedMultiplier = 8500,
		Rarity = "Titan",
		Tier = nil, -- catalog only (max = Angelic Lv.10)
		ModelId = "rbxassetid://125091408573206",
		Bounds = Vector3.new(10.5039, 14.1783, 13.8088),
		Parts = {
			{
				Name = "Cube",
				MeshId = "rbxassetid://76957273077406",
				Size = Vector3.new(9.6938, 7.2369, 13.3063),
				Color = Color3.fromRGB(70, 79, 90),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.6186, -0.1501, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.001",
				MeshId = "rbxassetid://125091408573206",
				Size = Vector3.new(9.2863, 12.1569, 13.1213),
				Color = Color3.fromRGB(108, 117, 130),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 6.0786, 0.2101, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.002",
				MeshId = "rbxassetid://125564190438619",
				Size = Vector3.new(5.8835, 7.8765, 1.5358),
				Color = Color3.fromRGB(74, 80, 89),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 4.2327, 4.8631, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.003",
				MeshId = "rbxassetid://89445247103182",
				Size = Vector3.new(3.4312, 0.3895, 12.7805),
				Color = Color3.fromRGB(9, 42, 56),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 0.1948, -0.3078, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
					{ Brightness = 1, Range = 8, Color = Color3.fromRGB(255, 255, 255) },
				},
				Emitters = {
					{
						Name = "StarFollow1",
						Texture = "rbxassetid://14960943986",
						Rate = 5,
						Lifetime = 1.5,
						Speed = 3.9,
						LightEmission = 1,
						Brightness = 4,
						Size = 0.6338,
						Color = Color3.fromRGB(51, 150, 255),
					},
				},
			},
			{
				Name = "Cube.005",
				MeshId = "rbxassetid://82621243238341",
				Size = Vector3.new(10.5039, 7.9343, 12.9789),
				Color = Color3.fromRGB(63, 69, 76),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.9673, 0.415, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.006",
				MeshId = "rbxassetid://107765325107416",
				Size = Vector3.new(7.2444, 8.0374, 12.9869),
				Color = Color3.fromRGB(92, 144, 255),
				Transparency = 0,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Offset = CFrame.new(0, 4.0189, -0.411, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.007",
				MeshId = "rbxassetid://110490713570459",
				Size = Vector3.new(8.4667, 11.816, 12.5077),
				Color = Color3.fromRGB(115, 153, 24),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 6.955, -0.0358, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Cube.009",
				MeshId = "rbxassetid://126060210612431",
				Size = Vector3.new(7.314, 11.4732, 12.8572),
				Color = Color3.fromRGB(46, 100, 249),
				Transparency = 0,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 5.7367, -0.3461, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "sigil2",
						Texture = "rbxassetid://14960943986",
						Rate = 3,
						Lifetime = 2,
						Speed = 0.0006,
						LightEmission = 1,
						Brightness = 2,
						Size = 0.7719,
						Color = Color3.fromRGB(33, 81, 255),
					},
					{
						Name = "Fireflies 2",
						Texture = "rbxassetid://87790026409442",
						Rate = 5,
						Lifetime = 3,
						Speed = 0,
						LightEmission = 1,
						Brightness = 10,
						Size = 3.2084,
						Color = Color3.fromRGB(65, 147, 255),
					},
				},
			},
			{
				Name = "Cube.010",
				MeshId = "rbxassetid://125933722475049",
				Size = Vector3.new(3.6963, 4.882, 0.151),
				Color = Color3.fromRGB(86, 166, 190),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.7869, 3.9393, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "VideoFeedScreen",
				MeshId = "",
				Size = Vector3.new(3.5115, 4.6379, 0.0325),
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.7869, 3.8443, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapLeft",
				MeshId = "",
				Size = Vector3.new(0.7475, 1.768, 0.0325),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(2.2075, 3.7869, 3.8443, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SwapRight",
				MeshId = "",
				Size = Vector3.new(0.7475, 1.768, 0.0325),
				Color = Color3.fromRGB(27, 42, 53),
				Transparency = 1,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Offset = CFrame.new(-2.2075, 3.7869, 3.8443, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "Root",
				MeshId = "",
				Size = Vector3.new(1.1348, 1.1348, 0.5674),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 3.7195, -0.3078, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "BoundingBoxPart",
				MeshId = "",
				Size = Vector3.new(10.5039, 12.8629, 13.8085),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 6.4315, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
			{
				Name = "SpeedPerSecond",
				MeshId = "",
				Size = Vector3.new(2.5986, 0.9407, 0.001),
				Color = Color3.fromRGB(163, 162, 165),
				Transparency = 1,
				Material = Enum.Material.Plastic,
				CanCollide = false,
				Offset = CFrame.new(0, 13.708, 3.9393, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Lights = {
				},
				Emitters = {
				},
			},
		},
	},
}

local ById: { [string]: Treadmill } = {}
local ByTier: { [number]: Treadmill } = {}
for _, model in Models do
	ById[model.Id] = model
	if model.Tier then
		ByTier[model.Tier] = model
	end
end

local GameTreadmill = {}

function GameTreadmill.get(id: string): Treadmill?
	return ById[id]
end

function GameTreadmill.forTier(tier: number): Treadmill
	local maxTier = 1
	for level in pairs(ByTier) do
		if level > maxTier then
			maxTier = level
		end
	end
	return ByTier[math.clamp(math.floor(tier), 1, maxTier)] or ByTier[1]
end

GameTreadmill.Models = Models
GameTreadmill.ById = ById
GameTreadmill.ByTier = ByTier

return GameTreadmill
