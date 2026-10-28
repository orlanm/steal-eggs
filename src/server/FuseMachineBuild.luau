--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.FuseMachineBuild
-- Builds the Steal an Egg fuse machine from the mesh asset ids on that model.

local AssetService = game:GetService("AssetService")
local Catalog = require(game.ReplicatedStorage.BabyBeastsShared.FuseMachine)
local Archive = require(script.Parent.Map.MeshArchive)

local Build = {}
Build.SCALE = 2 -- plaza fuse machine is double the Steal an Egg reference size
local SCALE = Build.SCALE
local templates: { [string]: MeshPart } = {}

local function meshFor(meshId: string): MeshPart?
	local cached = templates[meshId]
	if cached then
		return cached
	end
	local stored = Archive.find(meshId)
	if stored then
		templates[meshId] = stored
		return stored
	end
	local ok, created = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if not ok or not created or not created:IsA("MeshPart") then
		warn("[FuseMachine] Mesh failed " .. meshId .. " " .. tostring(created))
		return nil
	end
	created = Archive.keep(meshId, created)
	templates[meshId] = created
	return created
end

function Build.model(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "FuseMachine"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Origin", origin)
	for _, piece in Catalog.Pieces do
		local source = meshFor(piece.MeshId)
		if not source then
			continue
		end
		local part = Instance.new("MeshPart")
		part:ApplyMesh(source)
		part.Name = piece.Name
		part.Size = piece.Size * SCALE
		part.Color = piece.Color
		part.Transparency = piece.Transparency
		part.Material = Enum.Material.Plastic
		part.MaterialVariant = "Universal"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CastShadow = piece.Transparency < 0.5
		part.CFrame = origin * (piece.Offset - piece.Offset.Position + piece.Offset.Position * SCALE)
		part.Parent = model
	end

	-- Orange floor disc centered under the machine; sticks 3 studs past the front toward the road.
	local depth = Catalog.Size.X * SCALE
	local radius = depth * 0.5 + 3
	local disc = Instance.new("Part")
	disc.Name = "FuseFloorPad"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.35, radius * 2, radius * 2)
	disc.CFrame = origin * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.rad(90))
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
	model.PrimaryPart = disc

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusePrompt"
	prompt.ActionText = "Fuse"
	prompt.ObjectText = "Fuse Machine"
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = disc

	local sign = Instance.new("BillboardGui")
	sign.Name = "FuseSign"
	sign.Size = UDim2.fromOffset(80, 22)
	sign.StudsOffset = Vector3.new(0, Catalog.Size.Y * SCALE - 3 * SCALE + 1, 0)
	sign.MaxDistance = 90
	sign.LightInfluence = 0
	sign.Parent = disc
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.BuilderSansBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 120)
	title.TextStrokeTransparency = 0.4
	title.Text = "FUSE"
	title.Parent = sign

	local sparkHost = Instance.new("Part")
	sparkHost.Name = "FuseFxHost"
	sparkHost.Size = Vector3.new(0.4, 0.4, 0.4)
	sparkHost.Transparency = 1
	sparkHost.Anchored = true
	sparkHost.CanCollide = false
	sparkHost.CanTouch = false
	sparkHost.CanQuery = false
	sparkHost.CFrame = origin * CFrame.new(0, Catalog.Size.Y * SCALE * 0.72, 0)
	sparkHost.Parent = model
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "FuseFx"
	spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spark.Rate = 8
	spark.Lifetime = NumberRange.new(0.6, 1.2)
	spark.Speed = NumberRange.new(0.4, 1.4)
	spark.LightEmission = 0.8
	spark.Size = NumberSequence.new(0.35, 0.05)
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 120, 60))
	spark.Parent = sparkHost

	return model
end

return Build
