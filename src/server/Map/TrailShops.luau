--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.TrailShops
-- Neon trail stall on the right wall of zone 0. Players open the menu by stepping on the
-- glowing pad in front of the counter (no ProximityPrompt).

local AssetService = game:GetService("AssetService")
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Archive = require(script.Parent.MeshArchive)

local MESH_ID = "rbxassetid://132939920025798"
local TEXTURE_ID = "rbxassetid://77624838084077"
local MESH_SIZE = Vector3.new(20.69, 19.38, 8)
local MESH_CENTER = Vector3.new(0.065, 9.69, 0)
local CYAN = Color3.fromRGB(25, 235, 255)
local PAD_DIAMETER = 11

local Builder = {}

local template: MeshPart? = nil

local function meshTemplate(): MeshPart
	if template and template.Parent then
		return template
	end
	local stored = Archive.find(MESH_ID)
	if stored then
		stored.TextureID = TEXTURE_ID
		template = stored
		return stored
	end
	local created = AssetService:CreateMeshPartAsync(Content.fromUri(MESH_ID))
	created.TextureID = TEXTURE_ID
	created = Archive.keep(MESH_ID, created)
	template = created
	return created
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, collide: boolean): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Anchored = true
	piece.CanCollide = collide
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Material = Enum.Material.Plastic
	piece.MaterialVariant = "Universal"
	piece.Parent = parent
	return piece
end

local function clearOld(plaza: Instance)
	for _, child in plaza:GetChildren() do
		if child:GetAttribute("TrailShop") == true or child.Name == "TrailShopModel" or child.Name == "TrailShopModel2" then
			child:Destroy()
		end
	end
end

local function clearPrompt(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") and (d.Name == "ShopPrompt" or d.ObjectText == "Trail Shop") then
			d:Destroy()
		end
	end
end

local function ensurePad(model: Model, origin: CFrame)
	local existing = model:FindFirstChild("TrailShopPad")
	if existing then
		existing:Destroy()
	end
	local rim = model:FindFirstChild("TrailShopPadRim")
	if rim then
		rim:Destroy()
	end

	-- Flat disc on the road in front of the counter (+Z in stall space).
	local pad = Instance.new("Part")
	pad.Name = "TrailShopPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.35, PAD_DIAMETER, PAD_DIAMETER)
	pad.CFrame = origin * CFrame.new(0, 0.18, 7.2) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = Color3.fromRGB(18, 210, 255)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.35
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad:SetAttribute("TrailShopPad", true)
	pad.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "TrailShopPadRim"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, PAD_DIAMETER + 1.4, PAD_DIAMETER + 1.4)
	ring.CFrame = pad.CFrame * CFrame.new(-0.05, 0, 0)
	ring.Color = Color3.fromRGB(255, 120, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "PadGlow"
	light.Color = CYAN
	light.Brightness = 1.4
	light.Range = 18
	light.Shadows = false
	light.Parent = pad

	local swirl = Instance.new("ParticleEmitter")
	swirl.Name = "PadSwirl"
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(Color3.fromRGB(80, 240, 255), Color3.fromRGB(255, 140, 255))
	swirl.LightEmission = 0.85
	swirl.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	swirl.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	swirl.Lifetime = NumberRange.new(0.7, 1.3)
	swirl.Speed = NumberRange.new(0.4, 1.2)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.RotSpeed = NumberRange.new(-60, 60)
	swirl.Rate = 22
	swirl.Parent = pad

	local ringFx = Instance.new("ParticleEmitter")
	ringFx.Name = "PadRing"
	ringFx.Texture = "rbxasset://textures/particles/smoke_main.dds"
	ringFx.Color = ColorSequence.new(Color3.fromRGB(40, 220, 255))
	ringFx.LightEmission = 0.6
	ringFx.Size = NumberSequence.new(0.9, 0.2)
	ringFx.Transparency = NumberSequence.new(0.4, 1)
	ringFx.Lifetime = NumberRange.new(0.8, 1.4)
	ringFx.Speed = NumberRange.new(0.15, 0.45)
	ringFx.SpreadAngle = Vector2.new(12, 12)
	ringFx.EmissionDirection = Enum.NormalId.Top
	ringFx.Rate = 8
	ringFx.Parent = pad

	return pad
end

local function buildOne(parent: Instance, name: string, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("TrailShop", true)
	model:SetAttribute("Origin", origin)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local shell = meshTemplate():Clone()
	shell.Name = "NeonTrailsShop"
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanTouch = false
	shell.Material = Enum.Material.Plastic
	shell.MaterialVariant = "Universal"
	shell.Color = Color3.new(1, 1, 1)
	shell.TextureID = TEXTURE_ID
	shell.Size = MESH_SIZE
	-- The mesh faces the opposite way from the stall origin, so turn it toward the counter.
	shell.CFrame = origin * CFrame.new(MESH_CENTER) * CFrame.Angles(0, math.pi, 0)
	shell.Parent = model

	-- Invisible counter marker (no prompt). No collision: players walk through the stall.
	local counter = part(model, "CounterCollision", Vector3.new(13, 4.3, 3), origin * CFrame.new(0, 2.15, 2), Color3.new(), false)
	counter.Transparency = 1
	model.PrimaryPart = counter

	for _, x in { -7, 7 } do
		local column = part(model, "ColumnNeon", Vector3.new(0.42, 3.8, 0.12), origin * CFrame.new(x, 7.1, 0.98), CYAN, false)
		column.Material = Enum.Material.Plastic
		column.MaterialVariant = "Universal"
		local light = Instance.new("PointLight")
		light.Color = CYAN
		light.Brightness = 0.35
		light.Range = 12
		light.Shadows = false
		light.Parent = column
	end
	local strip = part(model, "CounterNeon", Vector3.new(8.9, 0.4, 0.1), origin * CFrame.new(0, 3.1, 3.51), CYAN, false)
	strip.Material = Enum.Material.Plastic
	strip.MaterialVariant = "Universal"

	ensurePad(model, origin)
	model.Parent = parent
	return model
end

local function findZone(root: Instance, name: string): Instance?
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = habitats and habitats:FindFirstChild(name)
	if zone then
		return zone
	end
	return root:FindFirstChild(name)
end

function Builder.build(map: Instance)
	local zone = findZone(map, "Zone00")
	if not zone then
		return
	end
	-- One trail shop (2026-10-27): the second stall's spot (z ≈ 601) now holds the Star Handler.
	local second = zone:FindFirstChild("TrailShopModel2")
	if second then
		second:Destroy()
	end
	local first = zone:FindFirstChild("TrailShopModel")
	if first and first:FindFirstChild("NeonTrailsShop", true) then
		clearPrompt(first)
		for _, piece in first:GetDescendants() do
			if piece:IsA("BasePart") and piece.Name ~= "TrailShopPad" and piece.Name ~= "TrailShopPadRim" then
				piece.CanCollide = false
			end
		end
		local originAttr = first:GetAttribute("Origin")
		local origin = if typeof(originAttr) == "CFrame" then originAttr else first:GetPivot()
		ensurePad(first :: Model, origin)
		return
	end
	local plaza = workspace:FindFirstChild("Plaza")
	if plaza then
		clearOld(plaza)
	end
	clearOld(zone)
	local startZ = zone:GetAttribute("StartZ")
	local length = zone:GetAttribute("ZoneLength")
	if typeof(startZ) ~= "number" or typeof(length) ~= "number" then
		return
	end
	-- Right-hand wall. Yaw faces the counter into the road, away from the treadmills.
	local x = MapConfig.RoadWidth / 2 - 6
	local yaw = CFrame.Angles(0, math.rad(-90), 0)
	buildOne(zone, "TrailShopModel", CFrame.new(x, 0, startZ + length * 0.28) * yaw)
end

return Builder
