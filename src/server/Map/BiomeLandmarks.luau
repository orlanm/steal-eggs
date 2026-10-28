local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.BabyBeastsShared.BiomeLandmarkConfig)
local Archive = require(script.Parent.MeshArchive)
local Library = {}
local cache = {}

local function paintMesh(p: MeshPart, d)
	-- Painted atlas for original biomes; solid SmoothPlastic for extras that only had a UV checker.
	if d and d.PaintColor then
		p.TextureID = ""
		p.Color = d.PaintColor
		p.Material = Enum.Material.SmoothPlastic
	else
		p.TextureID = Config.TextureId
		p.Color = Color3.new(1, 1, 1)
		p.Material = Enum.Material.Plastic
	end
end

local function template(theme)
	if cache[theme] then
		return cache[theme]
	end
	local d = assert(Config.Models[theme], "Unknown biome " .. theme)
	local meshId = "rbxassetid://" .. d.Id
	local p = Archive.find(meshId)
	if not p then
		p = AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		p.Size = d.Size
		p = Archive.keep(meshId, p)
	end
	paintMesh(p, d)
	cache[theme] = p
	return p
end

local function neon(parent, pos, size, color, name)
	local p = Instance.new("Part")
	p.Name = name or "GlowPearl"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = parent
	return p
end

local function light(p, color, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = 28
	l.Shadows = false
	l.Enabled = false
	l:SetAttribute("BaseBrightness", brightness)
	l.Parent = p
	CollectionService:AddTag(l, "BiomeAmbientLight")
end

local function particles(parent, at, d, _index)
	local a = Instance.new("Attachment")
	a.Name = d.Effect
	a.Position = at
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Name = d.Effect
	e.Texture = Config.Sprites.Mote
	e.Color = ColorSequence.new(d.Glow, d.Secondary)
	e.LightEmission = 0.65
	e.LightInfluence = 0.15
	e.Rate = d.Rate
	e.Lifetime = NumberRange.new(3, 5)
	e.Speed = NumberRange.new(d.Speed * 0.4, d.Speed)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(0.75, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-35, 35)
	e.Drag = 0.8
	e.VelocityInheritance = 0
	e.Enabled = false
	if d.Effect == "Snowfall" or d.Effect == "BlossomPetals" then
		e.Texture = if d.Effect == "Snowfall" then Config.Sprites.Snow else Config.Sprites.Petal
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = Vector3.new(1, -0.6, 0.5)
		e.Lifetime = NumberRange.new(7, 10)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Size = NumberSequence.new(0.3)
		if d.Effect == "BlossomPetals" then
			e.Size = NumberSequence.new(0.55)
			e.RotSpeed = NumberRange.new(30, 90)
		end
	elseif d.Effect == "Embers" then
		e.Texture = Config.Sprites.Mote
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Acceleration = Vector3.new(0, 8, 0)
		e.Lifetime = NumberRange.new(1.5, 4)
		e.Speed = NumberRange.new(d.Speed * 0.8, d.Speed * 1.6)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Drag = 0.7
		e.LightEmission = 1
		e.Brightness = 10
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.22, 0.08),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Squash = NumberSequence.new({
			NumberSequenceKeypoint.new(0, -2.5),
			NumberSequenceKeypoint.new(0.4, -0.2),
			NumberSequenceKeypoint.new(1, -0.5),
		})
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 53, 2)),
			ColorSequenceKeypoint.new(0.45, d.Glow),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 5, 0)),
		})
		e.Rate = d.Rate * 1.8
		e:SetAttribute("BaseRate", d.Rate * 1.8)
	elseif d.Effect == "LotusMist" then
		e.Size = NumberSequence.new(0.6)
		e.LightEmission = 0.3
		e.Transparency = NumberSequence.new(0.65)
	elseif d.Effect == "Stardust" or d.Effect == "TitanRunes" then
		e.Texture = Config.Sprites.Star
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.75),
			NumberSequenceKeypoint.new(1, 0),
		})
	else
		e.Acceleration = Vector3.new(0.25, 0.1, 0.2)
	end
	e:SetAttribute("BaseRate", d.Rate)
	e.Parent = a
	CollectionService:AddTag(e, "BiomeAmbientParticle")
end

function Library.place(parent, pos, theme, index, side)
	local d = Config.Models[theme]
	local model = Instance.new("Model")
	model.Name = theme .. "_BlenderLandmark"
	model:SetAttribute("BlenderAuthored", true)
	model:SetAttribute("BiomeTheme", theme)
	local p = template(theme):Clone()
	p.Name = "SculptedLandmark"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	paintMesh(p, d)
	local scale = d.Scale * (if index == 1 then 1 else 0.9)
	p.Size = d.Size * scale
	local angle = if side < 0 then math.pi / 2 else -math.pi / 2
	p.CFrame = CFrame.new(pos + Vector3.yAxis * (p.Size.Y / 2)) * CFrame.Angles(0, angle, 0)
	p.Parent = model
	local halo = Instance.new("Part")
	halo.Name = "PedestalGlow"
	halo.Shape = Enum.PartType.Cylinder
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanTouch = false
	halo.CanQuery = false
	halo.CastShadow = false
	halo.Material = Enum.Material.Neon
	halo.Color = d.Glow
	halo.Size = Vector3.new(0.12, 19.5 * scale, 19.5 * scale)
	halo.CFrame = CFrame.new(pos + Vector3.yAxis * 0.12) * CFrame.Angles(0, 0, math.pi / 2)
	halo.Parent = model
	local anchor = Instance.new("Part")
	anchor.Name = "EffectOrigin"
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = model
	for k = 1, 3 do
		local theta = k * math.pi * 2 / 3
		local color = if k % 2 == 0 then d.Secondary else d.Glow
		local orb = neon(
			model,
			pos + Vector3.new(math.cos(theta) * 7 * scale, 3 + 2 * (k % 2), math.sin(theta) * 7 * scale),
			0.7,
			color
		)
		light(orb, color, if k == 1 then 0.85 else 0.55)
	end
	if theme == "Temple" then
		for _, x in { -2.5, 2.5 } do
			neon(model, pos + CFrame.Angles(0, angle, 0):VectorToWorldSpace(Vector3.new(x, 14, 4.3) * scale), 0.8 * scale, d.Glow, "TitanEyeGlow")
		end
	end
	local focus = neon(model, pos + Vector3.yAxis * (d.Height * scale), 1.25, d.Secondary, "BiomeHeart")
	light(focus, d.Secondary, 0.7)
	for k = 1, 2 do
		particles(anchor, Vector3.new((k * 2 - 3) * 4, d.Height * scale, 0), d, index)
	end
	model.Parent = parent
	return model
end

function Library.badge(parent, pos, theme, side)
	local d = Config.Models[theme]
	if not d or not d.BadgeId then
		return
	end
	local meshId = "rbxassetid://" .. d.BadgeId
	local src = Archive.find(meshId)
	if not src then
		src = AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		src = Archive.keep(meshId, src)
	end
	local p = src:Clone()
	p.Name = theme .. "_WallEmblem"
	p.Size = d.BadgeSize * 2.2
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	paintMesh(p, d)
	local angle = if side < 0 then math.pi / 2 else -math.pi / 2
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
	p.Parent = parent
	local rim = neon(parent, pos + Vector3.new(0, 0, 0), 1.4, d.Glow, theme .. "_BadgeGlow")
	rim.Shape = Enum.PartType.Ball
	rim.Size = Vector3.new(2.2, 2.2, 2.2)
	rim.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -1.2)
	rim.Transparency = 0.15
	light(rim, d.Glow, 0.65)
	local accent = neon(parent, pos, 0.9, d.Secondary, theme .. "_BadgeAccent")
	accent.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.6, -1.1)
	light(accent, d.Secondary, 0.45)
end

return Library
