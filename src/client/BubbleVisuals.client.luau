--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local BubbleMesh = require(game.ReplicatedStorage.BabyBeastsShared.BubbleMesh)
local BubbleConfig = require(game.ReplicatedStorage.BabyBeastsShared.BubbleConfig)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local GameEgg = require(game.ReplicatedStorage.BabyBeastsShared.GameEgg)
local GamePet = require(game.ReplicatedStorage.BabyBeastsShared.GamePet)
local EggVisual = require(game.ReplicatedStorage.BabyBeastsShared.EggVisual)
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)
local PetVisual = require(game.ReplicatedStorage.BabyBeastsShared.PetVisual)
local PetRig = require(game.ReplicatedStorage.BabyBeastsShared.PetRig)
local PetVfx = require(game.ReplicatedStorage.BabyBeastsShared.PetVfx)
local PetHatch = require(game.ReplicatedStorage.BabyBeastsShared.PetHatch)
local PetCatalog = require(game.ReplicatedStorage.BabyBeastsShared.PetCatalog)
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local PetScale = require(game.ReplicatedStorage.BabyBeastsShared.PetScale)

local folder = Instance.new("Folder")
folder.Name = "LocalCaveBubbleVisuals"
folder.Parent = workspace

type Bound = {
	part: MeshPart?,
	rig: (EggVisual.Rig | PetVisual.Rig | PetRig.Rig)?,
	hatchWatch: RBXScriptConnection?,
	vfx: PetVfx.Handle?,
	isEgg: boolean?,
	eggName: string?, -- pen egg: drawn at EggScale.penEggBox (its found size; PEN_GROWTH x by hatch time)
	aura: BasePart?, -- Huge pets: glowing ring at the feet
	eggBox: Vector3?,
	busy: boolean?, -- hatch sequence is driving placement
}

-- A pen egg's box right now: native x size scale, grown by how far it is through hatching.
local function penEggBox(model: Model, eggName: string): Vector3
	local total = model:GetAttribute("HatchTotal")
	local left = model:GetAttribute("HatchLeft")
	local progress = 0
	if typeof(total) == "number" and total > 0 and typeof(left) == "number" then
		progress = 1 - left / total
	end
	return EggScale.penEggBox(eggName, EggScale.sizeOf(model:GetAttribute("SizeScale")), progress)
end

-- Short countdown for the egg tag: 1h 5m, 4m 32s, 45s.
local function shortTime(seconds: number): string
	local t = math.max(0, math.ceil(seconds))
	if t >= 3600 then
		return string.format("%dh %dm", t // 3600, (t % 3600) // 60)
	elseif t >= 60 then
		return string.format("%dm %ds", t // 60, t % 60)
	end
	return string.format("%ds", t)
end

-- Keep a pen egg's name + countdown tag just above the egg as it grows.
local function updateTag(model: Model, box: Vector3?)
	local root = model.PrimaryPart
	local tag = root and root:FindFirstChild("HatchTag")
	if not (tag and tag:IsA("BillboardGui")) then
		return
	end
	local status = tag:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		local left = model:GetAttribute("HatchLeft")
		status.Text = if model:GetAttribute("Ready") == true
			then "Ready!"
			else shortTime(if typeof(left) == "number" then left else 0)
	end
	local src = model:FindFirstChild("Body")
	if box and src and src:IsA("BasePart") then
		tag.Size, tag.StudsOffset = EggScale.hatchTagLayout(box, src.Size.Y)
	end
end

local POP_RANGE = 120 -- only pets this close to the camera show their +$ popups
-- PetTag (TankBeasts, resized by PetTagScale) is 3 equal rows: rarity / name / earnings, sized in pixels.
local TAG_SIZE = Vector2.new(190, 84) -- fallback when the pet has no tag
local EARNINGS_FROM_CENTER = 0.66 + 0.34 * 0.5 - 0.5 -- earnings row centre, in tag heights below its centre
local POP_ROW = 0.8 -- popup text height, in tag rows
local POP_START_ROWS = 4 -- starts this many rows below the earnings row

-- "+$X" floating up off a pet once a second (X = its earning per second): starts 4 rows below the
-- earnings row and fades out just under it. Laid out in the tag's own pixels so it never overlaps
-- the tag at any distance or screen size.
local function popIncome(model: Model, root: BasePart, income: number)
	local size = model:GetAttribute("StaticSize")
	local extents = if typeof(size) == "Vector3" then size else Vector3.new(4, 5, 4)
	local tag = root:FindFirstChild("PetTag")
	local tagSize = if tag and tag:IsA("BillboardGui") then Vector2.new(tag.Size.X.Offset, tag.Size.Y.Offset) else TAG_SIZE
	local row = tagSize.Y / 3
	local textHeight = math.max(10, math.floor(row * POP_ROW))
	local earnings = tagSize.Y * EARNINGS_FROM_CENTER
	local startY = earnings + POP_START_ROWS * row
	local endY = tagSize.Y * 0.5 + textHeight * 0.5 + 2 -- top edge just under the tag's bottom
	local span = math.ceil(startY + textHeight)
	local gui = Instance.new("BillboardGui")
	gui.Name = "IncomePop"
	gui.Size = UDim2.fromOffset(math.floor(tagSize.X * 0.7), span * 2) -- centred on the tag's centre
	gui.StudsOffset = if tag and tag:IsA("BillboardGui") then tag.StudsOffset else Vector3.new(0, PetScale.uiOffset(extents) + 1, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = POP_RANGE
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, startY)
	label.Size = UDim2.new(1, 0, 0, textHeight)
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.Text = "+" .. Economy.formatRate(income, true)
	label.TextColor3 = Color3.fromRGB(110, 235, 90)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 40, 20)
	stroke.Thickness = 1.5
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = root
	local info = TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.new(0.5, 0, 0.5, endY) }):Play()
	TweenService:Create(label, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(1, function()
		gui:Destroy()
	end)
end

local bound: { [Model]: Bound } = {}
local tooled: { [Tool]: boolean } = {}
local unavailable = false

local function release(model: Model)
	local vis = bound[model]
	if not vis then
		return
	end
	if vis.hatchWatch then
		vis.hatchWatch:Disconnect()
	end
	if vis.part then
		vis.part:Destroy()
	end
	if vis.rig then
		vis.rig:destroy()
	end
	if vis.vfx then
		vis.vfx:destroy()
	end
	if vis.aura then
		vis.aura:Destroy()
	end
	bound[model] = nil
end

-- Huge pets stand on a glowing gold ring that sheds sparkles (EggScale: the Huge marker at the feet).
local HUGE_GOLD = Color3.fromRGB(255, 205, 60)
local function hugeAura(footprint: number): BasePart
	local ring = Instance.new("Part")
	ring.Name = "HugeAura"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, footprint, footprint)
	ring.Material = Enum.Material.Neon
	ring.Color = HUGE_GOLD
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = HUGE_GOLD
	light.Brightness = 1.2
	light.Range = math.clamp(footprint * 1.2, 8, 40)
	light.Shadows = false
	light.Parent = ring
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "HugeSparkle"
	sparkle.Texture = "rbxassetid://11844017484" -- PetVfxPool Glimmer
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), HUGE_GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, math.clamp(footprint * 0.06, 0.4, 1.6)), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Rate = math.clamp(footprint * 1.5, 6, 30)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis (X) points up
	sparkle.SpreadAngle = Vector2.new(12, 12)
	sparkle.Shape = Enum.ParticleEmitterShape.Disc
	sparkle.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparkle.Parent = ring
	return ring
end

local attach: (model: Model) -> ()

-- Pet rig (animated when uploaded, static otherwise) + its ambient pastel VFX ring.
local function buildPet(species: string, src: MeshPart): (PetRig.Rig?, PetVfx.Handle?)
	local rig = PetRig.build(species, src.Size)
	if not rig then
		return nil, nil
	end
	local entry = PetCatalog.get(species)
	local vfx = PetVfx.attach(folder, if entry then entry.Id else species, rig.size, entry)
	return rig, vfx
end

-- Hatching flipped off while the egg is on screen: play the crack + pop sequence.
local function hatch(model: Model, src: MeshPart, species: string)
	local vis = bound[model]
	if not vis or vis.busy or not vis.isEgg then
		return false
	end
	vis.busy = true
	task.spawn(function()
		local rig, vfx = buildPet(species, src)
		if not rig or bound[model] ~= vis or not model.Parent then
			if rig then
				rig:destroy()
			end
			if vfx then
				vfx:destroy()
			end
			vis.busy = false
			if model.Parent then
				release(model)
				attach(model)
			end
			return
		end
		rig.model.Parent = folder
		local egg = vis.rig
		vis.isEgg = false
		vis.rig = rig
		vis.vfx = vfx
		local root = model.PrimaryPart or src
		PetHatch.play({
			root = root,
			parent = folder,
			egg = egg :: any,
			pet = rig,
			size = rig.size,
			vfx = vfx,
			onDone = function()
				vis.busy = false
			end,
		})
	end)
	return true
end

local function attachDragon(model: Model, src: MeshPart)
	if unavailable then
		return
	end
	local ok, template = pcall(function()
		return BubbleMesh.template()
	end)
	if not ok then
		unavailable = true
		warn(template)
		return
	end
	local vis = Instance.new("MeshPart")
	vis:ApplyMesh(template)
	vis.Name = "CaveBubbleBody"
	vis.TextureID = (model:GetAttribute("ModelId") :: any) or GameUI.modelIdForLevel(GameUI.CurrentLevel) or BubbleConfig.TextureId
	vis.Color = Color3.new(1, 1, 1)
	vis.Material = Enum.Material.SmoothPlastic
	vis.Anchored = true
	vis.CanCollide = false
	vis.CanQuery = false
	vis.CanTouch = false
	vis.CastShadow = true
	pcall(function()
		vis.DoubleSided = true
	end)
	vis.Size = src.Size
	local root = model.PrimaryPart or src
	vis.CFrame = root.CFrame
	vis.Transparency = if model:GetAttribute("Hidden") == true then 1 else 0
	src.LocalTransparencyModifier = 1
	vis.Parent = folder
	bound[model] = { part = vis }
	model.Destroying:Connect(function()
		release(model)
	end)
end

function attach(model: Model)
	if bound[model] then
		return
	end
	local src = model:FindFirstChild("Body")
	if not (src and src:IsA("MeshPart")) then
		return
	end
	local species = model:GetAttribute("EggName")
	if typeof(species) ~= "string" or species == "" then
		attachDragon(model, src)
		return
	end

	local hatching = model:GetAttribute("Hatching") == true
	local pet = GamePet.get(species)
	local catalogEntry = PetCatalog.get(species)
	local egg = GameEgg.get(species) or (catalogEntry and GameEgg.get(catalogEntry.GameName))

	bound[model] = {
		hatchWatch = model:GetAttributeChangedSignal("Hatching"):Connect(function()
			local nowHatching = model:GetAttribute("Hatching") == true
			if not nowHatching and hatch(model, src, species) then
				return
			end
			release(model)
			attach(model)
		end),
	}
	model.Destroying:Connect(function()
		release(model)
	end)

	task.spawn(function()
		local rig: (EggVisual.Rig | PetVisual.Rig | PetRig.Rig)? = nil
		local vfx: PetVfx.Handle? = nil
		local isEgg = false
		-- Hatched pens show the creature (animated PetRig + VFX ring). Eggs show while still hatching.
		if not hatching and (pet or PetCatalog.get(species)) then
			local petRig
			petRig, vfx = buildPet(species, src)
			rig = petRig
			if petRig then
				petRig:play("Idle", 0)
			end
		elseif egg then
			-- stands on the pen floor under the pet box the server placed (root = box centre)
			rig = EggVisual.build(egg, penEggBox(model, egg.Name), true, -src.Size.Y * 0.5)
			isEgg = rig ~= nil
		elseif pet then
			local petRig
			petRig, vfx = buildPet(species, src)
			rig = petRig
			if petRig then
				petRig:play("Idle", 0)
			end
		end
		if not model.Parent or bound[model] == nil then
			if rig then
				rig:destroy()
			end
			if vfx then
				vfx:destroy()
			end
			return
		end
		if not rig then
			local watch = bound[model] and bound[model].hatchWatch
			bound[model] = nil
			if watch then
				watch:Disconnect()
			end
			attachDragon(model, src)
			return
		end
		rig.model.Parent = folder
		local root = model.PrimaryPart or src
		rig:place(root.CFrame)
		src.LocalTransparencyModifier = 1
		local vis = bound[model]
		if vis then
			vis.rig = rig
			vis.vfx = vfx
			vis.isEgg = isEgg
			vis.eggName = if isEgg and egg then egg.Name else nil
		else
			rig:destroy()
			if vfx then
				vfx:destroy()
			end
		end
	end)
end

-- Held pets (TankBeasts pet Tools): the animated pet rig follows the tool's carried Body box.
local held: { [Tool]: { rig: PetRig.Rig, body: BasePart } } = {}

local function attachPetTool(tool: Tool)
	tooled[tool] = true
	task.spawn(function()
		local body = tool:FindFirstChild("Body") or tool:WaitForChild("Body", 8)
		local species = tool:GetAttribute("EggName")
		if not (body and body:IsA("BasePart") and typeof(species) == "string") then
			tooled[tool] = nil
			return
		end
		local rig = PetRig.build(species, body.Size)
		if not rig then
			tooled[tool] = nil
			return
		end
		if not tool.Parent then
			rig:destroy()
			return
		end
		rig.model.Parent = folder
		rig:play("Idle", 0)
		held[tool] = { rig = rig, body = body }
		tool.Destroying:Connect(function()
			tooled[tool] = nil
			local h = held[tool]
			held[tool] = nil
			if h then
				h.rig:destroy()
			end
		end)
	end)
end

local function attachTool(tool: Tool)
	if tooled[tool] then
		return
	end
	if tool:GetAttribute("PetTool") == true then
		attachPetTool(tool)
		return
	end
	if tool:GetAttribute("BeastMesh") ~= true then
		return
	end
	tooled[tool] = true
	task.spawn(function()
		local src = tool:FindFirstChild("Body")
		if not src then
			src = tool:WaitForChild("Body", 8)
		end
		if not (src and src:IsA("MeshPart")) then
			tooled[tool] = nil
			return
		end
		local eggName = tool:GetAttribute("EggName")
		local egg = if typeof(eggName) == "string" then GameEgg.get(eggName) else nil
		if egg then
			src.Transparency = 1
			-- the egg's own meshes; if they can't load, fall through to the plain egg mesh below
			if EggVisual.weld(src, egg, src.Size) then
				tool.Destroying:Connect(function()
					tooled[tool] = nil
				end)
				return
			end
		end
		local ok, template = pcall(function()
			return BubbleMesh.template()
		end)
		if not ok then
			unavailable = true
			tooled[tool] = nil
			warn(template)
			return
		end
		local size = src.Size
		src:ApplyMesh(template)
		src.Size = size
		src.Transparency = 0
		local modelId = tool:GetAttribute("ModelId")
		src.TextureID = if typeof(modelId) == "string" then modelId else GameUI.UploadedModelId
		src.LocalTransparencyModifier = 0
		tool.Destroying:Connect(function()
			tooled[tool] = nil
		end)
	end)
end

local function hookCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			attachTool(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			attachTool(child)
		end
	end
end

local function hookBackpack(backpack: Instance)
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			attachTool(child)
		end
	end)
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") then
			attachTool(child)
		end
	end
end

local function hookPlayer(other: Player)
	other.CharacterAdded:Connect(hookCharacter)
	if other.Character then
		hookCharacter(other.Character)
	end
	local backpack = other:FindFirstChild("Backpack")
	if backpack then
		hookBackpack(backpack)
	end
	other.ChildAdded:Connect(function(child)
		if child.Name == "Backpack" then
			hookBackpack(child)
		end
	end)
end

local function scan(root: Instance)
	for _, inst in root:GetDescendants() do
		if inst:IsA("Model") and inst.Name == "TankBeast" then
			attach(inst)
		end
	end
end

for _, other in Players:GetPlayers() do
	hookPlayer(other)
end
Players.PlayerAdded:Connect(hookPlayer)

task.spawn(function()
	local map = workspace:WaitForChild("BabyBeastsMap", 30)
	if map then
		scan(map)
		map.DescendantAdded:Connect(function(inst)
			if inst:IsA("Model") and inst.Name == "TankBeast" then
				attach(inst)
			elseif inst:IsA("MeshPart") and inst.Name == "Body" and inst.Parent and inst.Parent.Name == "TankBeast" then
				attach(inst.Parent :: Model)
			end
		end)
	end
end)

local scanClock = 0
local growClock = 0
local popClock = 0
RunService.PreRender:Connect(function(dt)
	for tool, h in held do
		-- in the backpack the tool has no world position: hide the rig until it is held again
		local out = tool.Parent ~= nil and tool.Parent:IsA("Model")
		h.rig:place(h.body.CFrame)
		h.rig:setTransparency(if out then 0 else 1)
	end
	scanClock += dt
	if scanClock > 0.6 then
		scanClock = 0
		local map = workspace:FindFirstChild("BabyBeastsMap")
		if map then
			scan(map)
		end
	end
	popClock += dt
	if popClock >= 1 then
		popClock = 0
		local camera = workspace.CurrentCamera
		for model, vis in bound do
			local root = model.PrimaryPart
			local income = model:GetAttribute("Income")
			if
				root
				and not vis.isEgg
				and not vis.busy
				and model:GetAttribute("Hatching") ~= true
				and model:GetAttribute("Hidden") ~= true
				and model:GetAttribute("RiddenBy") == nil
				and typeof(model:GetAttribute("OwnerUserId")) == "number"
				and typeof(income) == "number"
				and income > 0
				and camera
				and (camera.CFrame.Position - root.Position).Magnitude < POP_RANGE
			then
				local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId"))
				popIncome(model, root, if owner and owner:GetAttribute("PassMoney") then income * 2 else income)
			end
		end
	end
	growClock += dt
	if growClock > 0.25 then
		growClock = 0
		for model, vis in bound do
			if vis.isEgg and vis.eggName and vis.rig and not vis.busy then
				local box = penEggBox(model, vis.eggName)
				if not vis.eggBox or math.abs(box.Y - vis.eggBox.Y) > box.Y * 0.004 then
					vis.eggBox = box;
					(vis.rig :: EggVisual.Rig):resize(box)
				end
			end
			updateTag(model, vis.eggBox)
		end
	end
	for model, vis in bound do
		local root = model.PrimaryPart
		if root and not vis.busy then
			-- a pet out riding (MountService) is drawn under its rider instead (Mounts.client)
			local hidden = model:GetAttribute("Hidden") == true or model:GetAttribute("RiddenBy") ~= nil
			if vis.part then
				vis.part.CFrame = root.CFrame
				vis.part.Transparency = if hidden then 1 else 0
			elseif vis.rig then
				vis.rig:place(root.CFrame)
				vis.rig:setTransparency(if hidden then 1 else 0)
			end
			if vis.vfx then
				vis.vfx:update(root.CFrame, dt)
				vis.vfx.host.Parent = if hidden then nil else folder
			end
			local static = model:GetAttribute("StaticSize")
			if not vis.isEgg and vis.rig and typeof(static) == "Vector3" and EggScale.isHuge(model:GetAttribute("SizeScale")) then
				if not vis.aura then
					vis.aura = hugeAura(math.max(static.X, static.Z) * 1.15)
				end
				local aura = vis.aura :: BasePart
				aura.CFrame = CFrame.new(root.Position - Vector3.new(0, static.Y * 0.5 - 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
				aura.Parent = if hidden then nil else folder
			end
		end
	end
end)
