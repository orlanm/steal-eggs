--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetVfxPool
-- Data-driven pool of ambient VFX that orbit every pet (PetVfx applies them).
-- Copied from Workspace["pet-vfx-pool"] (Part1..Part8; Part4 was an exact duplicate of Part1),
-- then re-tinted: every colour comes from the pastel Palette below - no black, no white.
--
-- To add an effect: append a table to Effects with a unique Id and one or more Emitters.
-- Emitter fields are ParticleEmitter properties; ranges are {min, max}, sequences are
-- {{time, value, envelope}, ...}.  Colour is never stored per emitter - it is picked from the
-- pastel Palette per pet, so effects automatically stay pastel.

local PetVfxPool = {}

-- How many effects surround each pet unless PetCatalog gives the pet its own VfxCount.
PetVfxPool.DefaultCount = 3

-- Ring the effects sit on, relative to the pet's bounding box.
PetVfxPool.Layout = {
	RadiusScale = 0.62, -- x max(width, depth)
	RadiusPad = 0.6, -- studs
	HeightMin = 0.25, -- fraction of pet height
	HeightMax = 0.8,
	OrbitSpeed = 0.35, -- radians / second (slow drift around the pet)
	BobAmplitude = 0.12, -- x pet height
	SizeReference = 8, -- emitter sizes below are authored for an 8-stud pet
	SizeClamp = { 0.3, 2.2 },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Pastel only: every channel stays between 150 and 245 and each colour keeps a visible hue.
PetVfxPool.Palette = {
	{ Name = "Blush", Color = rgb(245, 182, 213) },
	{ Name = "Peach", Color = rgb(245, 200, 170) },
	{ Name = "Butter", Color = rgb(245, 232, 168) },
	{ Name = "Mint", Color = rgb(176, 236, 205) },
	{ Name = "Aqua", Color = rgb(168, 230, 236) },
	{ Name = "Sky", Color = rgb(174, 206, 245) },
	{ Name = "Periwinkle", Color = rgb(192, 190, 245) },
	{ Name = "Lilac", Color = rgb(222, 188, 245) },
	{ Name = "Rose", Color = rgb(245, 170, 196) },
	{ Name = "Pistachio", Color = rgb(205, 236, 170) },
}

-- Shared emitter defaults (anything an effect does not set).
PetVfxPool.EmitterDefaults = {
	Rate = 2,
	Lifetime = { 1, 1 },
	Speed = { 0, 0 },
	SpreadAngle = { 0, 0 },
	Rotation = { -180, 180 },
	RotSpeed = { -10, 10 },
	Transparency = { { 0, 0.1, 0 }, { 1, 1, 0 } },
	LightEmission = 0.8, -- additive-ish: dark texels drop out instead of showing as black
	LightInfluence = 0,
	Brightness = 1.4,
	Shape = "Box",
	ShapeStyle = "Volume",
	Orientation = "FacingCamera",
	Drag = 1,
	LockedToPart = false,
	ZOffset = 0,
	FlipbookLayout = "None",
	FlipbookMode = "Loop",
	FlipbookFramerate = { 1, 1 },
}

PetVfxPool.Effects = {
	{
		Id = "SparkBloom",
		Source = "pet-vfx-pool.Part1 (and Part4)",
		Emitters = {
			{
				Name = "Bloom",
				Texture = "rbxassetid://11749129449",
				Rate = 2,
				RotSpeed = { -10, 10 },
				Size = { { 0, 5, 0 }, { 1, 5, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 1,
				FlipbookLayout = "Grid4x4",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 40, 40 },
			},
		},
	},
	{
		Id = "SoftBurst",
		Source = "pet-vfx-pool.Part2",
		Emitters = {
			{
				Name = "Burst",
				Texture = "rbxassetid://15011471927",
				Rate = 2,
				RotSpeed = { 0, 0 },
				Size = { { 0, 3, 0 }, { 1, 3, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 0.9, -- source used -10 (darkening); clamped so it stays pastel
				Brightness = 1.6, -- source 5
				FlipbookLayout = "Grid4x4",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 40, 40 },
			},
		},
	},
	{
		Id = "HaloRays",
		Source = "pet-vfx-pool.Part3",
		Emitters = {
			{
				Name = "Rays",
				Texture = "rbxassetid://1053548563",
				Rate = 8,
				Rotation = { 90, 270 },
				RotSpeed = { 0, 0 },
				Size = {
					{ 0, 0, 0 }, { 0.111, 4.447, 0 }, { 0.222, 7.15, 0 }, { 0.333, 8.68, 0 },
					{ 0.444, 9.469, 0 }, { 0.555, 9.825, 0 }, { 0.666, 9.958, 0 }, { 1, 10, 0 },
				},
				Transparency = { { 0, 0.4, 0.3 }, { 1, 1, 0 } },
				LightEmission = 1,
				Drag = 0,
				LockedToPart = true,
				SizeScale = 0.35, -- the 10-stud rays are scaled down so they read as a halo, not a wall
			},
			{
				Name = "Circles",
				Texture = "rbxassetid://1084982817",
				Rate = 8,
				Lifetime = { 1.1, 1.1 },
				Speed = { 20, 20 },
				SpreadAngle = { 90, 90 },
				Rotation = { 0, 0 },
				RotSpeed = { 0, 0 },
				Size = { { 0, 0.3, 0.2 }, { 1, 0.3, 0.2 } },
				Transparency = { { 0, 1, 0 }, { 0.1, 1, 0 }, { 0.1, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 1,
				Drag = 8,
				SpeedScale = 0.25,
			},
			{
				Name = "Spin",
				Texture = "rbxassetid://1084975295",
				Rate = 1,
				Lifetime = { 1.5, 1.5 },
				RotSpeed = { 22.5, 22.5 },
				Size = { { 0, 0, 0 }, { 0.1, 9, 0 }, { 1, 0, 0 } },
				Transparency = { { 0, 0.3, 0 }, { 0.75, 0.3, 0 }, { 1, 1, 0 } },
				LightEmission = 1,
				Drag = 0,
				LockedToPart = true,
				SizeScale = 0.35,
			},
			{
				Name = "Flare",
				Texture = "rbxassetid://867619398",
				Rate = 1,
				Rotation = { 0, 0 },
				RotSpeed = { 0, 0 },
				Size = { { 0, 7, 0 }, { 1, 7, 0 } },
				Transparency = { { 0, 1, 0 }, { 0.1, 1, 0 }, { 0.1, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 1,
				Drag = 0,
				LockedToPart = true,
				ZOffset = 4,
				SizeScale = 0.35,
			},
		},
	},
	{
		Id = "Glimmer",
		Source = "pet-vfx-pool.Part5",
		Emitters = {
			{
				Name = "Glimmer",
				Texture = "rbxassetid://11844017484",
				Rate = 3,
				RotSpeed = { -10, 10 },
				Size = { { 0, 3, 0 }, { 1, 3, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 0.8, -- source -1
				FlipbookLayout = "Grid4x4",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 40, 40 },
			},
		},
	},
	{
		Id = "StarSwirl",
		Source = "pet-vfx-pool.Part6",
		Emitters = {
			{
				Name = "Swirl",
				Texture = "rbxassetid://15011464541",
				Rate = 1,
				RotSpeed = { -10, 10 },
				Size = { { 0, 5, 0 }, { 1, 5, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 1,
				Brightness = 2, -- source 555 blew out to white
				FlipbookLayout = "Grid8x8",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 40, 40 },
			},
		},
	},
	{
		Id = "DreamPuff",
		Source = "pet-vfx-pool.Part7",
		Emitters = {
			{
				Name = "Puff",
				Texture = "rbxassetid://12906276200",
				Rate = 2,
				RotSpeed = { 0, 0 },
				Size = { { 0, 4, 0 }, { 1, 4, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 0.75, -- source -5
				FlipbookLayout = "Grid4x4",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 5, 5 },
			},
		},
	},
	{
		Id = "AuraRing",
		Source = "pet-vfx-pool.Part8",
		Emitters = {
			{
				Name = "Aura",
				Texture = "rbxassetid://12780365055",
				Rate = 1,
				Lifetime = { 2, 2 },
				RotSpeed = { -10, 10 },
				Size = { { 0, 5, 0 }, { 1, 5, 0 } },
				Transparency = { { 0, 0, 0 }, { 1, 1, 0 } },
				LightEmission = 0.75, -- source -5
				Brightness = 1.8, -- source 15
				FlipbookLayout = "Grid8x8",
				FlipbookMode = "OneShot",
				FlipbookFramerate = { 40, 40 },
			},
		},
	},
}

PetVfxPool.ById = {} :: { [string]: any }
for _, effect in PetVfxPool.Effects do
	assert(PetVfxPool.ById[effect.Id] == nil, "duplicate PetVfxPool effect " .. effect.Id)
	PetVfxPool.ById[effect.Id] = effect
end

-- True when a colour is pastel: light, not grey, never black or white.
function PetVfxPool.isPastel(c: Color3): boolean
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local hi, lo = math.max(r, g, b), math.min(r, g, b)
	return lo >= 150 and hi <= 250 and (hi - lo) >= 20
end

for _, swatch in PetVfxPool.Palette do
	assert(PetVfxPool.isPastel(swatch.Color), "PetVfxPool palette colour is not pastel: " .. swatch.Name)
end

return PetVfxPool
