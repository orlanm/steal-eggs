-- Studio Edit (MCP execute_luau or command bar): replace Zone00.FuseMachine with the uploaded
-- Blender model. Set ASSET to the id in _tools/fuse/uploaded.json. Save the place afterwards.
local ASSET = 112193861169683
local S = 0.9 -- Blender studs -> plaza size
-- Stairs face −X (the road). Wall is at +X; we bury 1/3 of the base into the wall after measuring.
local X, Z = 62, 565

local zone = workspace.BabyBeastsMap.BeastHabitats.Zone00
local raw = game:GetService("InsertService"):LoadAsset(ASSET):FindFirstChildWhichIsA("Model", true)
local STYLE = {
	Navy = { Color3.fromRGB(38, 46, 86), Enum.Material.SmoothPlastic, 0 },
	Purple = { Color3.fromRGB(118, 56, 210), Enum.Material.SmoothPlastic, 0 },
	Grey = { Color3.fromRGB(168, 170, 182), Enum.Material.SmoothPlastic, 0 },
	Neon = { Color3.fromRGB(255, 70, 230), Enum.Material.Neon, 0 },
	-- Not Enum.Material.Glass: it hides the transparent swirl/glow behind it.
	Glass = { Color3.fromRGB(240, 190, 255), Enum.Material.SmoothPlastic, 0.7 },
	Swirl = { Color3.fromRGB(255, 150, 245), Enum.Material.Neon, 0.15 },
	Crystal = { Color3.fromRGB(255, 140, 250), Enum.Material.Neon, 0 },
}
local COLLIDE = {
	Navy_BasePlinth = true, Navy_BaseTier = true, Navy_CoreFloor = true, Glass_CoreTube = true,
	Navy_Step0 = true, Navy_Step1 = true, Navy_Step2 = true, Grey_StairRail0 = true, Grey_StairRail2 = true,
}

local plinth = raw:FindFirstChild("Navy_BasePlinth", true)
local step = raw:FindFirstChild("Navy_Step1", true)
local minY = math.huge
for _, p in raw:GetDescendants() do
	if p:IsA("BasePart") then
		minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
	end
end
local c = Vector3.new(plinth.Position.X, minY, plinth.Position.Z)
local look = Vector3.new(step.Position.X - c.X, 0, step.Position.Z - c.Z)
if look.Magnitude < 0.01 then
	look = Vector3.new(0, 0, -1)
else
	look = look.Unit
end
local src = CFrame.lookAt(c, c + look)
local dst = CFrame.lookAt(Vector3.new(X, 0, Z), Vector3.new(X - 1, 0, Z))

local model = Instance.new("Model")
model.Name = "FuseMachine"
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model:SetAttribute("KeepFinish", true) -- SurfaceFinish leaves Neon/glass alone
model:SetAttribute("SourceAsset", ASSET)
model:SetAttribute("BuildScale", S)
local maxY = 0
for _, p in raw:GetDescendants() do
	if p:IsA("MeshPart") then
		local n = p:Clone()
		local g = STYLE[p.Name:match("^(%a+)_")] or STYLE.Navy
		n.Color, n.Material, n.MaterialVariant, n.Transparency = g[1], g[2], "", g[3]
		if p.Name:match("^Glass_") then
			n.Reflectance = 0.15
		end
		n.Anchored = true
		n.CanCollide = COLLIDE[p.Name] == true
		n.CanQuery = COLLIDE[p.Name] == true
		n.CanTouch = false
		n.CastShadow = g[3] < 0.5
		local rel = src:ToObjectSpace(p.CFrame)
		n.Size = p.Size * S
		n.CFrame = dst * (CFrame.new(rel.Position * S) * rel.Rotation)
		n.Parent = model
		maxY = math.max(maxY, n.Position.Y + n.Size.Y / 2)
		if p.Name:match("^Glass_") then
			local glow = n:Clone()
			glow.Name = "Glow_" .. p.Name:sub(7)
			glow.Size = n.Size * Vector3.new(0.93, 0.97, 0.93)
			glow.Material, glow.Color, glow.Transparency, glow.Reflectance = Enum.Material.Neon, Color3.fromRGB(215, 70, 255), 0.6, 0
			glow.CanCollide, glow.CanQuery, glow.CastShadow = false, false, false
			glow.Parent = model
		end
	end
end

-- Bury 1/3 of the base into the +X wall (machine faces −X toward the road).
local _, size = model:GetBoundingBox()
local bury = size.X / 3
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		p.CFrame += Vector3.new(bury, 0, 0)
	end
end
dst = dst + Vector3.new(bury, 0, 0)
model:SetAttribute("Origin", dst)
local pivot, size2 = model:GetBoundingBox()
size = size2

-- Orange floor disc centered under the machine; front edge sticks 3 studs past the base toward the road.
local radius = size.X * 0.5 + 3
local disc = Instance.new("Part")
disc.Name = "FuseFloorPad"
disc.Shape = Enum.PartType.Cylinder
disc.Size = Vector3.new(0.35, radius * 2, radius * 2)
disc.CFrame = CFrame.new(pivot.Position.X, 0.18, pivot.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
disc.Color = Color3.fromRGB(255, 140, 40)
disc.Material = Enum.Material.Neon
disc.Transparency = 0.3
disc.Anchored = true
disc.CanCollide = false
disc.CanTouch = false
disc.CanQuery = true
disc.CastShadow = false
disc:SetAttribute("FusePad", true)
disc.Parent = model

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "FusePrompt"
prompt.ActionText = "Fuse"
prompt.ObjectText = "Fuse Machine"
prompt.MaxActivationDistance = 18
prompt.RequiresLineOfSight = false
prompt.HoldDuration = 0
prompt.Parent = disc

local rim = Instance.new("Part")
rim.Name = "FuseFloorPadRim"
rim.Shape = Enum.PartType.Cylinder
rim.Size = Vector3.new(0.2, radius * 2 + 1.2, radius * 2 + 1.2)
rim.CFrame = disc.CFrame * CFrame.new(-0.05, 0, 0)
rim.Color = Color3.fromRGB(255, 90, 20)
rim.Material = Enum.Material.Neon
rim.Transparency = 0.55
rim.Anchored = true
rim.CanCollide = false
rim.CanTouch = false
rim.CanQuery = false
rim.CastShadow = false
rim.Parent = model

local glow = Instance.new("PointLight")
glow.Name = "PadGlow"
glow.Color = Color3.fromRGB(255, 150, 50)
glow.Brightness = 0.9
glow.Range = radius + 4
glow.Shadows = false
glow.Parent = disc

local swirl = Instance.new("ParticleEmitter")
swirl.Name = "PadSwirl"
swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
swirl.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 110, 30))
swirl.LightEmission = 0.75
swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.05) })
swirl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
swirl.Lifetime = NumberRange.new(0.6, 1.2)
swirl.Speed = NumberRange.new(0.3, 1.0)
swirl.SpreadAngle = Vector2.new(180, 180)
swirl.RotSpeed = NumberRange.new(-50, 50)
swirl.Rate = 18
swirl.Parent = disc

model.PrimaryPart = disc

local sign = Instance.new("BillboardGui")
sign.Name = "FuseSign"
sign.Size = UDim2.fromOffset(80, 22)
sign.StudsOffsetWorldSpace = Vector3.new(0, maxY - 1.5, 0)
sign.MaxDistance = 90
sign.LightInfluence = 0
sign.Parent = disc
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.fromScale(1, 1)
title.Font = Enum.Font.BuilderSansBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 170, 250)
title.TextStrokeTransparency = 0.4
title.Text = "FUSE"
title.Parent = sign

local host = Instance.new("Part")
host.Name = "FuseFxHost"
host.Size = Vector3.new(0.4, 0.4, 0.4)
host.Transparency = 1
host.Anchored, host.CanCollide, host.CanTouch, host.CanQuery = true, false, false, false
host.CFrame = CFrame.new(pivot.Position.X, 6, pivot.Position.Z)
host.Parent = model
local fx = Instance.new("ParticleEmitter")
fx.Name = "FuseFx"
fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
fx.Rate = 10
fx.Lifetime = NumberRange.new(0.8, 1.6)
fx.Speed = NumberRange.new(0.6, 1.8)
fx.SpreadAngle = Vector2.new(25, 25)
fx.LightEmission = 0.9
fx.Size = NumberSequence.new(0.45, 0.05)
fx.Color = ColorSequence.new(Color3.fromRGB(255, 170, 250), Color3.fromRGB(200, 90, 255))
fx.Parent = host

local old = zone:FindFirstChild("FuseMachine")
if old then
	old:Destroy()
end
model.Parent = zone
raw.Parent:Destroy()
return string.format(
	"FuseMachine buried %.1f into wall, pad radius %.1f, size %s",
	bury,
	radius,
	tostring(size)
)
