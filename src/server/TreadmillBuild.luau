--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.TreadmillBuild
-- Prefers clones from ServerStorage.TreadmillTemplates (saved from Workspace._TreadmillPreview).
-- Falls back to mesh rebuild from GameTreadmill when a template is missing.
-- Belt motion: streaming neon chevron arrows (front → back).

local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")
local GameTreadmill = require(game.ReplicatedStorage.BabyBeastsShared.GameTreadmill)
local Archive = require(script.Parent.Map.MeshArchive)

local Build = {}

local templates: { [string]: MeshPart } = {}
local failed: { [string]: boolean } = {}
local pending: { [string]: BindableEvent } = {}

local ARROW_COLOR = Color3.fromRGB(110, 220, 255)
local ARROW_COUNT = 3
local ARROW_BEAM_TEXTURE = "rbxassetid://446111271"
-- Tier 1 ≈ 6.5 studs/sec; each higher tier adds 1.5 (Angelic ≈ 20).
local ARROW_SPEED_BASE = 5
local ARROW_SPEED_PER_TIER = 1.5

local function arrowSpeedForTier(tier: number?): number
	local level = if typeof(tier) == "number" then math.max(1, math.floor(tier)) else 1
	return ARROW_SPEED_BASE + level * ARROW_SPEED_PER_TIER
end

local function template(meshId: string): MeshPart?
	local cached = templates[meshId]
	if cached then
		return cached
	end
	local stored = Archive.find(meshId)
	if stored then
		templates[meshId] = stored
		return stored
	end
	if failed[meshId] then
		return nil
	end
	local gate = pending[meshId]
	if gate then
		gate.Event:Wait()
		return templates[meshId]
	end
	gate = Instance.new("BindableEvent")
	pending[meshId] = gate
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
		})
	end)
	if ok and typeof(result) == "Instance" and result:IsA("MeshPart") then
		result.Anchored = true
		result.CanCollide = false
		result = Archive.keep(meshId, result)
		templates[meshId] = result
	else
		failed[meshId] = true
		warn("[BabyBeasts] Treadmill mesh failed ", meshId, result)
	end
	pending[meshId] = nil
	gate:Fire()
	gate:Destroy()
	return templates[meshId]
end

type BeltSurface = {
	Top: number,
	Width: number,
	Length: number,
}

local function beltSurface(spec: GameTreadmill.Treadmill): BeltSurface
	local limit = math.max(2.5, spec.Bounds.Y * 0.42)
	local best: BeltSurface = {
		Top = 1,
		Width = math.max(3.5, spec.Bounds.X * 0.4),
		Length = math.max(6, spec.Bounds.Z * 0.55),
	}
	local bestScore = -1
	for _, part in spec.Parts do
		if part.Transparency > 0.5 then
			continue
		end
		local size = part.Size
		local long = math.max(size.X, size.Z)
		local wide = math.min(size.X, size.Z)
		if long < 5 or wide < 2.5 or size.Y < 0.45 or size.Y > 3 then
			continue
		end
		local top = part.Offset.Position.Y + size.Y * 0.5
		if top < 0.35 or top > limit then
			continue
		end
		local score = top * 20 + (size.X * size.Z) / math.max(size.Y, 0.2)
		if score > bestScore then
			bestScore = score
			best = {
				Top = top,
				Width = wide,
				Length = long,
			}
		end
	end
	return best
end

local function styleBeam(beam: Beam, width0: number, width1: number, fadeStrong: boolean)
	beam.Texture = ARROW_BEAM_TEXTURE
	beam.TextureSpeed = 0
	beam.TextureLength = 1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(ARROW_COLOR)
	beam.Width0 = width0
	beam.Width1 = width1
	if fadeStrong then
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.45, 0.35),
			NumberSequenceKeypoint.new(0.75, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.45, 0.72),
			NumberSequenceKeypoint.new(0.8, 0.92),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function makeChevron(model: Model, origin: CFrame, beltY: number, alongZ: number, width: number, index: number)
	local depth = math.clamp(width * 0.38, 1.4, 2.8)
	local host = Instance.new("Part")
	host.Name = "BeltArrow"
	host.Size = Vector3.new(width, 0.05, depth)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	host.CFrame = origin * CFrame.new(0, beltY, alongZ)
	host:SetAttribute("ArrowIndex", index)
	host.Parent = model

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0.06, -depth * 0.42)
	tip.Parent = host

	local left = Instance.new("Attachment")
	left.Name = "Left"
	left.Position = Vector3.new(-width * 0.5, 0.06, depth * 0.42)
	left.Parent = host

	local right = Instance.new("Attachment")
	right.Name = "Right"
	right.Position = Vector3.new(width * 0.5, 0.06, depth * 0.42)
	right.Parent = host

	for _, layer in {
		{ name = "CoreL", a0 = tip, a1 = left, w0 = 1.1, w1 = 1.5, strong = true },
		{ name = "CoreR", a0 = tip, a1 = right, w0 = 1.1, w1 = 1.5, strong = true },
		{ name = "GlowL", a0 = tip, a1 = left, w0 = 2.2, w1 = 3.0, strong = false },
		{ name = "GlowR", a0 = tip, a1 = right, w0 = 2.2, w1 = 3.0, strong = false },
	} do
		local beam = Instance.new("Beam")
		beam.Name = layer.name
		beam.Attachment0 = layer.a0
		beam.Attachment1 = layer.a1
		styleBeam(beam, layer.w0, layer.w1, layer.strong)
		beam.Parent = host
	end
end

local function attachBeltFx(model: Model, origin: CFrame, deck: BasePart, tier: number?)
	local stand = origin:PointToObjectSpace(deck.Position).Y
	model:SetAttribute("Origin", origin)
	model:SetAttribute("DeckY", stand)
	model:SetAttribute("DeckHalfX", deck.Size.X * 0.5 + 0.6)
	model:SetAttribute("DeckHalfZ", deck.Size.Z * 0.5 + 0.6)
	model:SetAttribute("DeckMinY", stand - 1)
	model:SetAttribute("DeckMaxY", stand + 7)
	model:SetAttribute("CatchHalfX", deck.Size.X * 0.5 + 2.5)
	model:SetAttribute("CatchHalfZ", deck.Size.Z * 0.5 + 3.5)
	model:SetAttribute("CatchMinY", math.max(0.2, stand - 3))
	model:SetAttribute("CatchMaxY", stand + 9)

	-- Drop preview/runtime arrows; rebuild at the new origin.
	for _, child in model:GetChildren() do
		if child.Name == "BeltArrow" then
			child:Destroy()
		end
	end

	local span = deck.Size.Z
	local beltY = stand + 0.1
	local arrowWidth = deck.Size.X * 1.08
	model:SetAttribute("BeltY", beltY)
	model:SetAttribute("BeltSpan", span)
	model:SetAttribute("BeltArrowCount", ARROW_COUNT)
	model:SetAttribute("BeltArrowSpeed", arrowSpeedForTier(tier))
	for i = 0, ARROW_COUNT - 1 do
		local along = span * 0.5 - (i + 0.5) * (span / ARROW_COUNT)
		makeChevron(model, origin, beltY, along, arrowWidth, i)
	end

	-- Mark flat Top textures on the black conveyor so the client can scroll them.
	local beltDir = origin.ZVector
	for _, d in model:GetDescendants() do
		if not d:IsA("Texture") or d.Face ~= Enum.NormalId.Top then
			continue
		end
		local part = d.Parent
		if not (part and part:IsA("BasePart")) then
			continue
		end
		if part.Name == "BeltArrow" or part.Name == "Deck" then
			continue
		end
		if part.Size.Y > 1.2 or math.max(part.Size.X, part.Size.Z) < 4 then
			continue
		end
		local alongX = math.abs(part.CFrame.XVector:Dot(beltDir))
		local alongZ = math.abs(part.CFrame.ZVector:Dot(beltDir))
		local axis = if alongX > alongZ then "U" else "V"
		local axisVec = if axis == "U" then part.CFrame.XVector else part.CFrame.ZVector
		-- Positive scroll moves the pattern toward the back (-Z), matching arrows.
		local sign = if axisVec:Dot(beltDir) >= 0 then -1 else 1
		d:SetAttribute("BeltScrollAxis", axis)
		d:SetAttribute("BeltScrollSign", sign)
	end
end

local function findStoredTemplate(spec: GameTreadmill.Treadmill): Model?
	local folder = ServerStorage:FindFirstChild("TreadmillTemplates")
	if not folder then
		return nil
	end
	if spec.Tier then
		local byTier = folder:FindFirstChild("Tier" .. tostring(spec.Tier))
		if byTier and byTier:IsA("Model") then
			return byTier
		end
	end
	local byId = folder:FindFirstChild(spec.Id)
	if byId and byId:IsA("Model") then
		return byId
	end
	return nil
end

local function cloneFromTemplate(spec: GameTreadmill.Treadmill, origin: CFrame): Model?
	local src = findStoredTemplate(spec)
	if not src then
		return nil
	end
	local oldOrigin = src:GetAttribute("TemplateOrigin")
	if typeof(oldOrigin) ~= "CFrame" then
		oldOrigin = src:GetAttribute("Origin")
	end
	if typeof(oldOrigin) ~= "CFrame" then
		local deck = src:FindFirstChild("Deck")
		if deck and deck:IsA("BasePart") then
			oldOrigin = deck.CFrame * CFrame.new(0, -deck.Size.Y * 0.5, 0)
			oldOrigin = CFrame.lookAt(Vector3.new(oldOrigin.Position.X, 0, oldOrigin.Position.Z), Vector3.new(oldOrigin.Position.X, 0, oldOrigin.Position.Z) - oldOrigin.LookVector)
		else
			return nil
		end
	end

	local model = src:Clone()
	model.Name = spec.DisplayName
	for _, d in model:GetDescendants() do
		if d.Name == "PreviewLabel" or d.Name == "PreviewLabelAnchor" then
			d:Destroy()
		end
	end
	model:SetAttribute("PreviewOnly", nil)
	model:SetAttribute("TemplateId", nil)
	model:SetAttribute("TemplateTier", nil)
	model:SetAttribute("TemplateOrigin", nil)

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local localCf = oldOrigin:ToObjectSpace(d.CFrame)
			d.CFrame = origin * localCf
			d.Anchored = true
		end
	end

	local deck = model:FindFirstChild("Deck")
	if not (deck and deck:IsA("BasePart")) then
		-- Template missing deck — synthesize from bounds.
		local surface = beltSurface(spec)
		deck = Instance.new("Part")
		deck.Name = "Deck"
		deck.Size = Vector3.new(math.max(3.2, surface.Width), 0.35, math.max(5.5, surface.Length))
		deck.CFrame = origin * CFrame.new(0, surface.Top, 0)
		deck.Transparency = 1
		deck.Anchored = true
		deck.CanCollide = true
		deck.CanTouch = true
		deck.CanQuery = false
		deck.Parent = model
	else
		deck.CanCollide = true
		deck.CanTouch = true
		deck.Transparency = 1
	end
	model.PrimaryPart = deck
	attachBeltFx(model, origin, deck, spec.Tier)
	return model
end

local function buildFromMeshes(spec: GameTreadmill.Treadmill, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = spec.DisplayName
	model:SetAttribute("Origin", origin)

	for _, specPart in spec.Parts do
		local part: BasePart
		if specPart.MeshId ~= "" then
			local src = template(specPart.MeshId)
			if not src then
				continue
			end
			local mesh = Instance.new("MeshPart")
			mesh:ApplyMesh(src)
			part = mesh
		else
			part = Instance.new("Part")
		end
		part.Name = specPart.Name
		part.Size = specPart.Size
		part.Color = specPart.Color
		part.Transparency = specPart.Transparency
		part.Material = specPart.Material
		part.CanCollide = specPart.CanCollide
		part.CanTouch = false
		part.CanQuery = false
		part.Anchored = true
		part.CastShadow = specPart.Transparency < 0.5
		part.CFrame = origin * specPart.Offset
		for _, lightSpec in specPart.Lights do
			local light = Instance.new("PointLight")
			light.Brightness = lightSpec.Brightness
			light.Range = lightSpec.Range
			light.Color = lightSpec.Color
			light.Parent = part
		end
		part.Parent = model
	end

	local surface = beltSurface(spec)
	local stand = surface.Top
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(math.max(3.2, surface.Width), 0.35, math.max(5.5, surface.Length))
	deck.CFrame = origin * CFrame.new(0, stand, 0)
	deck.Transparency = 1
	deck.Anchored = true
	deck.CanCollide = true
	deck.CanTouch = true
	deck.CanQuery = false
	deck.Parent = model
	model.PrimaryPart = deck
	attachBeltFx(model, origin, deck, spec.Tier)
	return model
end

function Build.model(spec: GameTreadmill.Treadmill, origin: CFrame): Model
	local fromTemplate = cloneFromTemplate(spec, origin)
	if fromTemplate then
		return fromTemplate
	end
	return buildFromMeshes(spec, origin)
end

function Build.warm()
	-- Prefer stored Studio templates; still warm mesh archive as fallback.
	if ServerStorage:FindFirstChild("TreadmillTemplates") then
		return
	end
	local seen: { [string]: boolean } = {}
	for _, spec in GameTreadmill.Models do
		for _, specPart in spec.Parts do
			if specPart.MeshId ~= "" and not seen[specPart.MeshId] then
				seen[specPart.MeshId] = true
				template(specPart.MeshId)
			end
		end
	end
end

return Build
