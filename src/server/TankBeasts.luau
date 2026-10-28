--!strict
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local GameEgg = require(game.ReplicatedStorage.BabyBeastsShared.GameEgg)
local GamePet = require(game.ReplicatedStorage.BabyBeastsShared.GamePet)
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)
local PetScale = require(game.ReplicatedStorage.BabyBeastsShared.PetScale)
local PetCatalog = require(game.ReplicatedStorage.BabyBeastsShared.PetCatalog)
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local NightCycle = require(game.ReplicatedStorage.BabyBeastsShared.NightCycle)
local ShopConfig = require(game.ReplicatedStorage.BabyBeastsShared.ShopConfig)
local PenConfig = require(game.ReplicatedStorage.BabyBeastsShared.PenConfig)
local SpeedData = require(script.Parent.SpeedDataManager)
local Signs = require(script.Parent.TankSigns)
local PenNodes = require(script.Parent.PenNodes)
local CarryHold = require(script.Parent.CarryHold)

export type Pet = {
	model: Model,
	root: BasePart,
	body: BasePart,
	light: PointLight,
	burst: ParticleEmitter,
	glow: ParticleEmitter,
	tank: Instance,
	center: Vector3,
	size: Vector3,
	from: Vector3,
	landing: Vector3,
	kickT: number,
	kickDur: number,
	shakeT: number,
	age: number,
	angle: number,
	radius: number,
	spin: number,
	hoverPhase: number,
	roamT: number,
	state: string,
	face: Vector3,
	slot: number,
	glowing: boolean,
	income: number,
	ownerId: number,
	hatchLeft: number,
	ready: boolean, -- timer done, waiting for the owner's Hatch! prompt
	hatched: boolean,
}

-- What a pet is, independent of how it arrived (a carried egg Tool or a saved record).
export type Spec = {
	eggName: string?,
	mutation: string?,
	rarity: string?,
	modelId: string?,
	eggClass: string?,
	size: number?, -- the egg's rolled size scale (EggScale.rollSize)
	income: number,
	hatchLeft: number?,
	hatched: boolean?,
	rideable: boolean?, -- fed a Mount Star (MountService)
	near: Vector3?, -- where the owner asked for it in the pen (lands there unless taken, then the nearest free spot)
}

-- Saved form of a pen pet (BeastData). Hatch time is frozen while the owner is away.
export type Record = {
	Egg: string?,
	Mutation: string?,
	Rarity: string?,
	ModelId: string?,
	Class: string?,
	Size: number?,
	Income: number,
	HatchLeft: number,
	Hatched: boolean,
	Rideable: boolean?, -- fed a Mount Star: can be ridden as a mount
	Spot: { number }?, -- {right, front} studs from the pen centre
	Stored: boolean?, -- hatched but unequipped: a pet Tool in the backpack, not in the pen (Spot = where it stood)
	Id: string?, -- stored pets only: the pet Tool's PetId
}

local TankBeasts = {}
local petFolder: Folder? = nil
local rarityOf: (eggName: any) -> string
local placeOnNodes: (tank: Instance, model: Model, size: Vector3, folder: Instance, near: Vector3?) -> Vector3
local herd: { Pet } = {}
local stored: { [number]: { Record } } = {} -- unequipped pets per owner (the "backpack")
local heldId: { [number]: string } = {} -- the stored pet in the owner's hands: the only one that is a Tool
local storeSerial = 0
local storePet: (pet: Pet, reason: string?) -> ()
local recordOf: (pet: Pet) -> Record
local placeRecord: (player: Player, tank: Instance, rec: Record) -> Pet?
local keepStored: (userId: number, rec: Record) -> ()
local publishStored: (userId: number) -> ()
local syncPetTools: (player: Player) -> ()
local SHAKE_TIME = 1.15
local PLACE_REACH = 30 -- how far outside the fence a player can still place into their pen

local function heldTool(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChild("BabyBeast")
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function playKickSound(parent: Instance)
	local sound = Instance.new("Sound")
	sound.Name = "BeastKick"
	sound.SoundId = GameUI.KickSoundId
	sound.Volume = 1
	sound.PlaybackSpeed = 0.92
	sound.RollOffMaxDistance = 180
	sound.Parent = parent
	sound:Play()
	task.delay(0.4, function()
		if sound.Parent and sound.TimeLength == 0 then
			sound.SoundId = "rbxasset://sounds/impact_water.mp3"
			sound:Play()
		end
	end)
	Debris:AddItem(sound, 4)
end

local function makeEmitters(root: BasePart): (ParticleEmitter, ParticleEmitter)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "LandBurst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Shape = Enum.ParticleEmitterShape.Disc
	burst.Rate = 0
	burst.Speed = NumberRange.new(4, 9)
	burst.Lifetime = NumberRange.new(0.35, 0.8)
	burst.SpreadAngle = Vector2.new(0, 0)
	burst.Rotation = NumberRange.new(0, 180)
	burst.RotSpeed = NumberRange.new(-90, 90)
	burst.LightEmission = 0.7
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.4, 0.42),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 140)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 170, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 230, 255)),
	})
	burst.Enabled = false
	burst.Parent = root

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "HoverGlow"
	glow.Texture = "rbxasset://textures/particles/smoke_main.dds"
	glow.Rate = 6
	glow.Speed = NumberRange.new(0.2, 0.7)
	glow.Lifetime = NumberRange.new(0.7, 1.3)
	glow.SpreadAngle = Vector2.new(40, 40)
	glow.LightEmission = 0.55
	glow.LightInfluence = 0
	glow.Size = NumberSequence.new(0.35, 0.05)
	glow.Transparency = NumberSequence.new(0.35, 1)
	glow.Color = ColorSequence.new(Color3.fromRGB(255, 220, 130), Color3.fromRGB(180, 255, 230))
	glow.Enabled = false
	glow.Parent = root
	return burst, glow
end

local function flatDir(tank: Instance): Vector3
	local front = tank:GetAttribute("FrontDir")
	if typeof(front) ~= "Vector3" then
		return Vector3.new(0, 0, 1)
	end
	local flat = Vector3.new(front.X, 0, front.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, 1)
	end
	return flat.Unit
end

local function claimSlot(tank: Instance): number
	local used: { [number]: boolean } = {}
	for _, pet in herd do
		if pet.tank == tank then
			used[pet.slot] = true
		end
	end
	for index = 1, 16 do
		if not used[index] then
			return index
		end
	end
	return 1
end

-- Rarity tier of a species when the egg didn't carry one.
function rarityOf(eggName: any): string
	if typeof(eggName) ~= "string" or eggName == "" then
		return "Common"
	end
	return EggScale.rarityOf(eggName)
end

-- Reserve a pen spot for a static footprint; returns the box-centre landing point (flush on the floor).
function placeOnNodes(tank: Instance, model: Model, size: Vector3, folder: Instance, near: Vector3?): Vector3
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local claim = PenNodes.claim(tank, model, size, ignore, near)
	if not claim then
		warn("[TankBeasts] pen " .. tank.Name .. " has no free spot for a " .. tostring(size) .. " pet")
		local center = tank:GetAttribute("Center")
		local c = if typeof(center) == "Vector3" then center else Vector3.zero
		return PetScale.floorCFrame(CFrame.new(c), size).Position
	end
	return PetScale.floorCFrame(claim.cframe, size).Position
end

local function text(value: any): string?
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function specFromTool(tool: Tool): Spec
	local income = tool:GetAttribute("EggIncome")
	return {
		eggName = text(tool:GetAttribute("EggName")),
		mutation = text(tool:GetAttribute("Mutation")),
		rarity = text(tool:GetAttribute("EggRarity")),
		modelId = text(tool:GetAttribute("ModelId")),
		eggClass = text(tool:GetAttribute("EggClass")),
		size = EggScale.sizeOf(tool:GetAttribute("SizeScale")),
		income = if typeof(income) == "number" and income == income and income >= 0 then income else 0,
	}
end

-- The pen footprint of a pet: its static size, widened to the egg at full growth (a pet that is
-- already hatched only needs its own size).
local function footprintOf(spec: Spec): (Vector3, Vector3, Vector3, any)
	local eggName = spec.eggName
	local egg = if eggName then GameEgg.get(eggName) else nil
	local sizeScale = EggScale.sizeOf(spec.size)
	local static = PetScale.forSpecies(if typeof(eggName) == "string" then eggName else "", sizeScale, if egg then egg.Bounds else nil)
	local size = static.Extents
	local grown = EggScale.penEggBox(eggName, sizeScale, 1)
	if spec.hatched then
		return size, size, grown, static
	end
	return Vector3.new(math.max(size.X, grown.X), size.Y, math.max(size.Z, grown.Z)), size, grown, static
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

local function spawnPet(folder: Folder, tank: Instance, spec: Spec, from: Vector3): Pet
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		center = Vector3.zero
	end
	local eggName = spec.eggName
	local mutationName = spec.mutation
	local rarityName = spec.rarity or rarityOf(eggName)
	-- static size, fixed at hatch: native Steal An Egg size x the egg's size scale (PetScale);
	-- the pen keeps room for the egg at its full growth too (it can be wider than the pet)
	local sizeScale = EggScale.sizeOf(spec.size)
	local footprint, size, grown, static = footprintOf(spec)
	local glowing = EggScale.mutationGlows(mutationName)
	local modelId = spec.modelId or GameUI.UploadedModelId
	local face = flatDir(tank)
	local slot = claimSlot(tank)
	local rng = Random.new()

	local model = Instance.new("Model")
	model.Name = "TankBeast"
	-- stand flush on the pen spot reserved for this footprint
	local landing = placeOnNodes(tank, model, footprint, folder, spec.near)
	model:SetAttribute("BeastMesh", true)
	model:SetAttribute("ModelId", modelId)
	if typeof(eggName) == "string" and eggName ~= "" then
		model:SetAttribute("EggName", eggName)
	end
	if mutationName then
		model:SetAttribute("Mutation", mutationName)
	end
	model:SetAttribute("Rarity", rarityName)
	model:SetAttribute("Income", spec.income)
	model:SetAttribute("StaticScale", static.Scale)
	model:SetAttribute("StaticSize", size)
	model:SetAttribute("SizeScale", sizeScale)
	model:SetAttribute("PedestalSlot", slot)
	model:SetAttribute("Hidden", false)
	model:SetAttribute("TankSlot", tank:GetAttribute("Slot"))
	local className = spec.eggClass or "Medium"
	model:SetAttribute("EggClass", className)
	local hatchTotal = EggScale.hatchSeconds(className)
	local hatchLeft = if spec.hatchLeft then math.clamp(spec.hatchLeft, 0, hatchTotal) else hatchTotal
	model:SetAttribute("Hatching", true)
	model:SetAttribute("HatchTotal", hatchTotal)
	model:SetAttribute("HatchLeft", hatchLeft)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.new(from)
	root.Parent = model
	model.PrimaryPart = root
	-- egg tag: name over a countdown ("4m 32s" / "Ready!"), just above the egg (BubbleVisuals keeps it there as it grows)
	local hatchTag = Instance.new("BillboardGui")
	hatchTag.Name = "HatchTag"
	hatchTag.Size, hatchTag.StudsOffset = EggScale.hatchTagLayout(EggScale.penEggBox(eggName, sizeScale, 0), size.Y)
	hatchTag.AlwaysOnTop = false
	hatchTag.LightInfluence = 0
	hatchTag.MaxDistance = 60
	hatchTag.Parent = root
	local displayName = if typeof(eggName) == "string" and eggName ~= "" then eggName else "Egg"
	if not string.find(string.lower(displayName), "egg", 1, true) then
		displayName ..= " Egg"
	end
	local huge = EggScale.isHuge(sizeScale)
	if huge then
		displayName = "HUGE " .. displayName
	end
	for index, info in { { "EggName", displayName, 0.42 }, { "Status", shortTime(hatchLeft), 0.58 } } do
		local label = Instance.new("TextLabel")
		label.Name = info[1]
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, if index == 1 then 0 else 0.42)
		label.Size = UDim2.fromScale(1, info[3])
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextScaled = true
		label.TextColor3 = if index == 1 then (if huge then Color3.fromRGB(255, 205, 60) else Color3.fromRGB(235, 235, 235)) else Color3.new(1, 1, 1)
		label.Text = info[2]
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 24)
		stroke.Thickness = 2.5
		stroke.Parent = label
		label.Parent = hatchTag
	end

	local body = Instance.new("MeshPart")
	body.Name = "Body"
	body.Size = size
	body.TextureID = modelId :: string
	body.Color = Color3.new(1, 1, 1)
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	pcall(function()
		body.DoubleSided = true
	end)
	body.CFrame = root.CFrame
	body.Parent = model

	local accent = if glowing then EggScale.variantColor(mutationName) else Color3.fromRGB(255, 220, 130)
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = accent
	light.Brightness = if glowing then 1.2 else 0.55
	light.Range = math.max(14, size.Y * 2.2)
	light.Shadows = false
	light.Parent = root

	local burst, glow = makeEmitters(root)
	if glowing then
		glow.Color = ColorSequence.new(accent)
	end
	model.Parent = folder
	playKickSound(root)

	local dist = (from - landing).Magnitude
	return {
		model = model,
		root = root,
		body = body,
		light = light,
		burst = burst,
		glow = glow,
		tank = tank,
		center = center,
		size = size,
		from = from,
		landing = landing,
		kickT = 0,
		kickDur = math.clamp(0.45 + dist / 90, 0.55, 0.95),
		shakeT = 0,
		age = 0,
		angle = rng:NextNumber(0, math.pi * 2),
		radius = rng:NextNumber(14, 26),
		spin = rng:NextNumber(0.35, 0.8) * (if rng:NextNumber() < 0.5 then -1 else 1),
		hoverPhase = rng:NextNumber(0, math.pi * 2),
		roamT = 0,
		state = "kick",
		face = face,
		slot = slot,
		glowing = glowing,
		income = spec.income,
		ownerId = 0,
		hatchLeft = hatchLeft,
		ready = false,
		hatched = false,
	}
end

-- The owner's hatched pets standing in their pen (the Pets panel's "Active" list).
local function activePets(userId: number): { Pet }
	local list = {}
	for _, pet in herd do
		if pet.ownerId == userId and pet.hatched and pet.model.Parent then
			table.insert(list, pet)
		end
	end
	return list
end

local function capacity(userId: number): number
	local player = Players:GetPlayerByUserId(userId)
	return if player then SpeedData.equipSlots(player) else PenConfig.StartSlots
end

local function petName(eggName: string?, mutation: string?): string
	local entry = if eggName then PetCatalog.get(eggName) else nil
	local name = if entry then entry.DisplayName elseif eggName then (string.gsub(eggName, " Egg$", "")) else "Beast"
	return if mutation then mutation .. " " .. name else name
end

local function notify(userId: number, message: string, color: Color3?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		GameUI.remote("EggAnnouncement"):FireClient(player, { text = message, color = color or Color3.fromRGB(255, 170, 140), small = true })
	end
end

-- Hatched pet tag above its head: rarity, name, $/s.
local function addPetTag(pet: Pet)
	if pet.model:FindFirstChild("PetTag", true) then
		return
	end
	local model = pet.model
	local name = petName(text(model:GetAttribute("EggName")), text(model:GetAttribute("Mutation")))
	if EggScale.isHuge(model:GetAttribute("SizeScale")) then
		name = "[HUGE] " .. name
	end
	local rarity = text(model:GetAttribute("Rarity")) or "Common"
	local tag = Instance.new("BillboardGui")
	tag.Name = "PetTag"
	tag.Size = UDim2.fromOffset(190, 84)
	tag.StudsOffset = Vector3.new(0, PetScale.uiOffset(pet.size) + 1, 0)
	tag.AlwaysOnTop = false
	tag.LightInfluence = 0
	tag.MaxDistance = 80
	tag.Parent = pet.root
	local rows = {
		{ "Rarity", rarity, EggScale.rarityColor(rarity), 0, 0.36 },
		{ "PetName", name, Color3.new(1, 1, 1), 0.36, 0.3 },
		{ "Income", Economy.formatRate(pet.income), Color3.fromRGB(90, 230, 70), 0.66, 0.34 },
	}
	for _, row in rows do
		local label = Instance.new("TextLabel")
		label.Name = row[1]
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, row[4])
		label.Size = UDim2.fromScale(1, row[5])
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextScaled = true
		label.Text = row[2]
		label.TextColor3 = row[3]
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 24)
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = tag
	end
end

-- Finish hatching: drop the timer tag and prompt and let the pet earn.
local function markHatched(pet: Pet)
	pet.hatched = true
	pet.ready = false
	pet.hatchLeft = 0
	pet.model:SetAttribute("Hatching", false)
	pet.model:SetAttribute("Ready", false)
	pet.model:SetAttribute("HatchLeft", 0)
	for _, name in { "HatchTag", "HatchPrompt" } do
		local inst = pet.model:FindFirstChild(name, true)
		if inst then
			inst:Destroy()
		end
	end
	addPetTag(pet)
end

-- The owner opens a ready egg: hatch bonus cash, then it becomes a pet.
local function hatchNow(pet: Pet)
	if pet.hatched or not pet.ready then
		return
	end
	markHatched(pet)
	-- GameAudio: crack + reveal on every client near the pen
	pet.model:SetAttribute("HatchedAt", workspace:GetServerTimeNow())
	local owner = Players:GetPlayerByUserId(pet.ownerId)
	if owner and pet.income > 0 then
		SpeedData.addCash(owner, pet.income * 10)
	end
	pet.burst:Emit(36)
	-- every equip slot is taken: the new pet waits in the Pets list instead
	if #activePets(pet.ownerId) > capacity(pet.ownerId) then
		storePet(pet, "full")
	end
end

-- Timer done: the egg reads "Ready!" and waits for its owner's Hatch! prompt.
local function markReady(pet: Pet)
	if pet.ready or pet.hatched then
		return
	end
	pet.ready = true
	pet.hatchLeft = 0
	pet.model:SetAttribute("HatchLeft", 0)
	pet.model:SetAttribute("Ready", true)
	local status = pet.model:FindFirstChild("Status", true)
	if status and status:IsA("TextLabel") then
		status.Text = "Ready!"
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Hatch!"
	prompt.ObjectText = "Hatch!"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.clamp(math.max(pet.size.X, pet.size.Z) * 0.5 + 6, 8, 20)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.UIOffset = Vector2.new(0, 0)
	prompt.Triggered:Connect(function(player)
		if player.UserId == pet.ownerId then
			hatchNow(pet)
		end
	end)
	prompt.Parent = pet.root
end

local function kickCFrame(pet: Pet): CFrame
	local t = math.clamp(pet.kickT / pet.kickDur, 0, 1)
	local pos = pet.from:Lerp(pet.landing, t)
	local height = math.max(10, (pet.from - pet.landing).Magnitude * 0.42)
	pos += Vector3.new(0, 4 * height * t * (1 - t), 0)
	local tumble = CFrame.Angles(t * 9.5, t * 6.2, t * 3.4)
	return CFrame.new(pos) * tumble
end

local function landCFrame(pet: Pet, dt: number): CFrame
	pet.shakeT += dt
	local t = pet.shakeT
	local damp = math.clamp(1 - t / SHAKE_TIME, 0, 1)
	local shake = Vector3.new(math.sin(t * 54) * 0.28, math.sin(t * 47) * 0.18, math.cos(t * 51) * 0.28) * damp
	local wobble = CFrame.Angles(math.sin(t * 36) * 0.22 * damp, math.cos(t * 29) * 0.3 * damp, math.sin(t * 41) * 0.18 * damp)
	pet.light.Brightness = 1.2 + 2.4 * damp * (0.5 + 0.5 * math.sin(t * 22))
	pet.light.Range = 12 + 10 * damp
	pet.light.Color = Color3.fromRGB(255, 230, 140):Lerp(Color3.fromRGB(160, 255, 220), 0.5 + 0.5 * math.sin(t * 16))
	return CFrame.new(pet.landing + shake) * wobble
end

local function perchCFrame(pet: Pet, _dt: number): CFrame
	-- flush on the pen floor; size and height never change after hatch
	local pos = pet.landing
	if pet.glowing then
		pet.light.Brightness = 1.15 + 0.35 * math.sin(pet.age * 2.2 + pet.hoverPhase)
		pet.light.Range = 16
	else
		pet.light.Brightness = 0.45
		pet.light.Range = 8
		pet.light.Color = Color3.fromRGB(255, 214, 130)
	end
	local face = pet.face
	if face.Magnitude < 0.05 then
		face = Vector3.zAxis
	end
	return CFrame.lookAt(pos, pos + face)
end

function TankBeasts.species(userId: number): { { Name: string, Count: number, Income: number } }
	local grouped: { [string]: { Name: string, Count: number, Income: number } } = {}
	for _, pet in herd do
		if pet.ownerId ~= userId or pet.model.Parent == nil then
			continue
		end
		local eggName = pet.model:GetAttribute("EggName")
		if typeof(eggName) ~= "string" or eggName == "" then
			continue
		end
		local row = grouped[eggName]
		if not row then
			row = { Name = eggName, Count = 0, Income = pet.income }
			grouped[eggName] = row
		end
		row.Count += 1
		row.Income = math.max(row.Income, pet.income)
	end
	local list = {}
	for _, row in grouped do
		table.insert(list, row)
	end
	table.sort(list, function(a, b)
		if a.Count ~= b.Count then
			return a.Count > b.Count
		end
		return a.Name < b.Name
	end)
	return list
end

local function petCatalog(): { string }
	-- Prefer hatched creature meshes from AssetModels.
	local names = GamePet.names()
	if #names >= 70 then
		return names
	end
	local fallback = {}
	for _, egg in GameEgg.Eggs do
		local n = egg.Name
		if not string.find(n, "[Ee]gg") and not string.find(n, " OP$") then
			table.insert(fallback, n)
		end
	end
	table.sort(fallback)
	return fallback
end

local function buildShowcasePet(folder: Folder, tank: Instance, eggName: string, slot: number): Pet?
	local petMesh = GamePet.get(eggName)
	local egg = GameEgg.get(eggName)
	local bounds = if petMesh then petMesh.Bounds elseif egg then egg.Bounds else nil
	if not bounds then
		return nil
	end
	local rarityName = rarityOf(eggName)
	local static = PetScale.forSpecies(eggName, 1, bounds)
	local size = static.Extents
	local face = flatDir(tank)
	local center = tank:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		center = Vector3.zero
	end
	local profile = GameEgg.profile(eggName)
	local rng = Random.new(slot * 97 + (tank:GetAttribute("Slot") or 0) * 131)

	local model = Instance.new("Model")
	model.Name = "TankBeast"
	local landing = placeOnNodes(tank, model, size, folder)
	model:SetAttribute("Rarity", rarityName)
	model:SetAttribute("StaticScale", static.Scale)
	model:SetAttribute("StaticSize", size)
	model:SetAttribute("BeastMesh", true)
	model:SetAttribute("ModelId", GameUI.UploadedModelId)
	model:SetAttribute("EggName", eggName)
	model:SetAttribute("PedestalSlot", slot)
	model:SetAttribute("Hidden", false)
	model:SetAttribute("TankSlot", tank:GetAttribute("Slot"))
	model:SetAttribute("Hatching", false)
	model:SetAttribute("HatchLeft", 0)
	model:SetAttribute("Showcase", true)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.lookAt(landing, landing + face)
	root.Parent = model
	model.PrimaryPart = root

	local body = Instance.new("MeshPart")
	body.Name = "Body"
	body.Size = size
	body.TextureID = GameUI.UploadedModelId
	body.Color = Color3.new(1, 1, 1)
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	pcall(function()
		body.DoubleSided = true
	end)
	body.CFrame = root.CFrame
	body.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 0.55
	light.Range = math.max(14, size.Y * 2.2)
	light.Shadows = false
	light.Parent = root

	local burst, glow = makeEmitters(root)
	glow.Enabled = false
	model.Parent = folder

	return {
		model = model,
		root = root,
		body = body,
		light = light,
		burst = burst,
		glow = glow,
		tank = tank,
		center = center,
		size = size,
		from = landing,
		landing = landing,
		kickT = 0,
		kickDur = 0.01,
		shakeT = SHAKE_TIME,
		age = rng:NextNumber(0, 20),
		angle = rng:NextNumber(0, math.pi * 2),
		radius = rng:NextNumber(14, 26),
		spin = rng:NextNumber(0.35, 0.8) * (if rng:NextNumber() < 0.5 then -1 else 1),
		hoverPhase = rng:NextNumber(0, math.pi * 2),
		roamT = 0,
		state = "perch",
		face = face,
		slot = slot,
		glowing = false,
		income = profile.Income,
		ownerId = 0,
		hatchLeft = 0,
		ready = false,
		hatched = true,
	}
end

-- 10 unique Steal An Egg pets on each of the 7 pens (70 distinct creatures).
function TankBeasts.seedShowcase(root: Instance): number
	local tanksFolder = root:FindFirstChild("PlayerTanks")
	if not tanksFolder then
		return 0
	end
	local folder = root:FindFirstChild("TankBeasts")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TankBeasts"
		folder.Parent = root
	end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("Showcase") == true then
			child:Destroy()
		end
	end

	local catalog = petCatalog()
	if #catalog < 70 then
		warn("[TankBeasts] Need 70 unique pets, found " .. tostring(#catalog))
	end
	local spawned = 0
	for tankId = 1, 7 do
		local tank = tanksFolder:FindFirstChild("Tank" .. tankId)
		if not tank then
			continue
		end
		for slot = 1, 10 do
			local index = (tankId - 1) * 10 + slot
			local eggName = catalog[((index - 1) % math.max(#catalog, 1)) + 1]
			if not eggName then
				continue
			end
			local pet = buildShowcasePet(folder, tank, eggName, slot)
			if pet then
				table.insert(herd, pet)
				spawned += 1
			end
		end
	end
	return spawned
end

function TankBeasts.take(userId: number, eggName: string, count: number): (boolean, number)
	-- plain pets go first: a pet fed a Mount Star keeps its star while you keep it, so it is only
	-- spent when there are not enough others; a pet someone is riding is never taken
	local picked: { Pet } = {}
	for _, mounts in { false, true } do
		for _, pet in herd do
			local model = pet.model
			if
				#picked < count
				and pet.ownerId == userId
				and model.Parent
				and model:GetAttribute("EggName") == eggName
				and (model:GetAttribute("Rideable") == true) == mounts
				and model:GetAttribute("RiddenBy") == nil
			then
				table.insert(picked, pet)
			end
		end
	end
	if #picked < count then
		return false, 0
	end
	local spent = 0
	for _, pet in picked do
		spent += pet.income
		local index = table.find(herd, pet)
		if index then
			table.remove(herd, index)
		end
		pet.model:Destroy()
	end
	return true, spent
end

-- Mounts (MountService) ---------------------------------------------------------------------------

-- The owner's hatched pen pet behind this TankBeast model, or nil.
function TankBeasts.ownedPet(userId: number, model: Instance): Model?
	for _, pet in herd do
		if pet.model == model and pet.ownerId == userId and pet.hatched and pet.model.Parent then
			return pet.model
		end
	end
	return nil
end

-- Feed a Mount Star: the pet becomes rideable for good (saved in its pen record).
function TankBeasts.makeRideable(userId: number, model: Instance): boolean
	local owned = TankBeasts.ownedPet(userId, model)
	if not owned or owned:GetAttribute("Rideable") == true then
		return false
	end
	owned:SetAttribute("Rideable", true)
	for _, pet in herd do
		if pet.model == owned then
			pet.burst:Emit(48)
		end
	end
	return true
end

-- Persistence (BeastData) -------------------------------------------------------------------------

function recordOf(pet: Pet): Record
	local model = pet.model
	return {
		Egg = text(model:GetAttribute("EggName")),
		Mutation = text(model:GetAttribute("Mutation")),
		Rarity = text(model:GetAttribute("Rarity")),
		ModelId = text(model:GetAttribute("ModelId")),
		Class = text(model:GetAttribute("EggClass")),
		Size = EggScale.sizeOf(model:GetAttribute("SizeScale")),
		Income = pet.income,
		HatchLeft = if pet.hatched then 0 else math.max(pet.hatchLeft, 0),
		Hatched = pet.hatched,
		Rideable = if model:GetAttribute("Rideable") == true then true else nil,
		Spot = { PenNodes.toLocal(pet.tank, pet.landing) },
	}
end

-- The owner's pen pets as save records.
function TankBeasts.snapshot(userId: number): { Record }
	local list = {}
	-- reads the pet record, not the pen: on shutdown the map can be torn down before the save runs
	for _, pet in herd do
		if pet.ownerId == userId then
			table.insert(list, recordOf(pet))
		end
	end
	for _, rec in stored[userId] or {} do
		table.insert(list, rec)
	end
	return list
end

-- Put saved pets back in the owner's pen, already standing on their spots (no kick-in).
function TankBeasts.restore(player: Player, tank: Instance, records: { Record }): number
	local folder = petFolder
	if not folder then
		return 0
	end
	local restored = 0
	for _, rec in records do
		if rec.Stored == true then
			keepStored(player.UserId, rec)
			restored += 1
			continue
		end
		if placeRecord(player, tank, rec) then
			restored += 1
		end
	end
	-- more hatched pets than equip slots (e.g. an older save): the best ones stay out
	local active = activePets(player.UserId)
	local slots = capacity(player.UserId)
	if #active > slots then
		table.sort(active, function(a, b)
			return a.income > b.income
		end)
		for i = slots + 1, #active do
			storePet(active[i], "restore")
		end
	end
	publishStored(player.UserId)
	return restored
end

-- Put one saved pen record back in the pen, already standing on its spot (no kick-in).
function placeRecord(player: Player, tank: Instance, rec: Record): Pet?
	local folder = petFolder
	if not folder then
		return nil
	end
	local spec: Spec = {
		eggName = text(rec.Egg),
		mutation = text(rec.Mutation),
		rarity = text(rec.Rarity),
		modelId = text(rec.ModelId),
		eggClass = text(rec.Class),
		size = EggScale.sizeOf(rec.Size),
		income = if typeof(rec.Income) == "number" and rec.Income == rec.Income and rec.Income >= 0 then rec.Income else 0,
		hatchLeft = if typeof(rec.HatchLeft) == "number" and rec.HatchLeft == rec.HatchLeft then rec.HatchLeft else nil,
		hatched = rec.Hatched == true,
	}
	local spot = rec.Spot
	if typeof(spot) == "table" and typeof(spot[1]) == "number" and typeof(spot[2]) == "number" then
		spec.near = PenNodes.fromLocal(tank, spot[1], spot[2])
	end
	local center = tank:GetAttribute("Center")
	local pet = spawnPet(folder, tank, spec, if typeof(center) == "Vector3" then center else Vector3.zero)
	pet.ownerId = player.UserId
	pet.model:SetAttribute("OwnerUserId", player.UserId)
	-- already settled in the pen
	pet.from = pet.landing
	pet.kickT = pet.kickDur
	pet.shakeT = SHAKE_TIME
	pet.state = "perch"
	pet.glow.Enabled = pet.glowing
	local sound = pet.root:FindFirstChild("BeastKick")
	if sound then
		sound:Destroy()
	end
	if rec.Hatched == true then
		markHatched(pet)
		if rec.Rideable == true then
			pet.model:SetAttribute("Rideable", true)
		end
	elseif pet.hatchLeft <= 0 then
		markReady(pet)
	end
	local cf = CFrame.lookAt(pet.landing, pet.landing + pet.face)
	pet.root.CFrame = cf
	pet.body.CFrame = cf
	table.insert(herd, pet)
	return pet
end

-- Stored pets (Pets panel) ------------------------------------------------------------------------

function keepStored(userId: number, rec: Record)
	storeSerial += 1
	rec.Stored = true
	rec.Hatched = true
	rec.HatchLeft = 0
	rec.Id = tostring(storeSerial)
	local list = stored[userId]
	if not list then
		list = {}
		stored[userId] = list
	end
	table.insert(list, rec)
end

-- The client's view of the stored list: a JSON player attribute (Pets panel).
function publishStored(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local view = {}
	for _, rec in stored[userId] or {} do
		table.insert(view, {
			Id = rec.Id,
			Egg = rec.Egg,
			Mutation = rec.Mutation,
			Rarity = rec.Rarity,
			Income = rec.Income,
			Rideable = rec.Rideable,
		})
	end
	player:SetAttribute("StoredPets", HttpService:JSONEncode(view))
	syncPetTools(player)
	player:SetAttribute("HeldPet", heldId[userId])
end

-- Held pets (Steal an Egg style): the stored pet in your hands is a Tool, carried in both hands like
-- an egg. Click / tap a spot in your pen while holding it to put it back there (PenPets "Place").
-- The other stored pets are only data (Pets panel "Backpack", Hold button), so none of them show on
-- the Roblox hotbar. The held Tool is rebuilt on every spawn, so death never loses a pet.
local HELD_MAX = 4 -- studs: a held pet is shrunk so its biggest side fits this

local function petTools(player: Player): { [string]: Tool }
	local found = {}
	for _, holder in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, tool in (if holder then holder:GetChildren() else {}) do
			local id = tool:GetAttribute("PetId")
			if tool:IsA("Tool") and typeof(id) == "string" then
				found[id] = tool
			end
		end
	end
	return found
end

local function makePetTool(rec: Record): Tool
	local eggName = text(rec.Egg)
	local mutation = text(rec.Mutation)
	local egg = if eggName then GameEgg.get(eggName) else nil
	local extents = PetScale.forSpecies(eggName or "", EggScale.sizeOf(rec.Size), if egg then egg.Bounds else nil).Extents
	local carry = extents * math.min(1, HELD_MAX / math.max(extents.X, extents.Y, extents.Z, 0.1))
	local tool = Instance.new("Tool")
	tool.Name = petName(eggName, mutation)
	tool.ToolTip = Economy.formatRate(rec.Income)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("PetTool", true)
	tool:SetAttribute("PetId", rec.Id)
	if eggName then
		tool:SetAttribute("EggName", eggName)
	end
	tool:SetAttribute("Rarity", rec.Rarity or rarityOf(eggName))
	tool:SetAttribute("Income", rec.Income)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	handle.Parent = tool
	-- the client draws the pet rig on this box (BubbleVisuals)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = carry
	body.Transparency = 1
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = handle.CFrame * CFrame.new(0, carry.Y * 0.5, 0)
	body.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = body
	weld.Parent = handle
	CarryHold.holdInHands(tool, body, weld, carry)
	return tool
end

-- One pet Tool: the held stored pet, equipped. Put away (back in the Backpack, e.g. picking up an egg)
-- it stops being held and goes back to data.
function syncPetTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid then
		return
	end
	local id = heldId[player.UserId]
	local rec: Record? = nil
	for _, r in stored[player.UserId] or {} do
		if r.Id == id then
			rec = r
		end
	end
	if not rec then
		heldId[player.UserId] = nil
	end
	for toolId, tool in petTools(player) do
		if toolId ~= heldId[player.UserId] then
			tool:Destroy()
		end
	end
	if rec and not petTools(player)[rec.Id :: string] then
		local tool = makePetTool(rec)
		tool.Parent = backpack
		humanoid:EquipTool(tool)
		tool.Unequipped:Connect(function()
			task.defer(function()
				if tool.Parent and not tool.Parent:IsA("Model") and heldId[player.UserId] == rec.Id then
					heldId[player.UserId] = nil
					publishStored(player.UserId)
				end
			end)
		end)
	end
end

-- Take a hatched pet out of the pen and into the stored list.
function storePet(pet: Pet, reason: string?)
	local index = table.find(herd, pet)
	if index then
		table.remove(herd, index)
	end
	local rec = recordOf(pet)
	keepStored(pet.ownerId, rec)
	pet.model:Destroy()
	if reason == "full" then
		notify(pet.ownerId, "All equip slots are full! " .. petName(rec.Egg, rec.Mutation) .. " went to your backpack.")
	end
	if reason ~= "restore" then
		publishStored(pet.ownerId)
	end
end

local function ownTank(player: Player): Instance?
	local slot = player:GetAttribute("TankSlot")
	local root = petFolder and petFolder.Parent
	local tanks = root and root:FindFirstChild("PlayerTanks")
	return if tanks and typeof(slot) == "number" then tanks:FindFirstChild("Tank" .. slot) else nil
end

local function ownPet(player: Player, model: any): Pet?
	if typeof(model) ~= "Instance" then
		return nil
	end
	for _, pet in herd do
		if pet.model == model and pet.ownerId == player.UserId and pet.model.Parent then
			return pet
		end
	end
	return nil
end

-- Unequip: an active pet leaves the pen for the stored list.
function TankBeasts.unequip(player: Player, model: any): (boolean, string)
	local pet = ownPet(player, model)
	if not pet or not pet.hatched then
		return false, "That pet is not in your pen"
	end
	if pet.model:GetAttribute("RiddenBy") ~= nil then
		return false, "Dismount before unequipping this pet"
	end
	if #(stored[player.UserId] or {}) >= PenConfig.MaxHeldPets then
		return false, "Your backpack is full!"
	end
	local name = petName(text(pet.model:GetAttribute("EggName")), text(pet.model:GetAttribute("Mutation")))
	storePet(pet)
	-- now held in your hands: click / tap a spot in your pen to put it back
	local list = stored[player.UserId] or {}
	heldId[player.UserId] = list[#list].Id :: string
	publishStored(player.UserId)
	return true, "Unequipped " .. name
end

-- Hold a stored pet (Pets panel Backpack row); holding it already puts it away.
function TankBeasts.hold(player: Player, id: any): (boolean, string)
	for _, rec in stored[player.UserId] or {} do
		if rec.Id == id then
			heldId[player.UserId] = if heldId[player.UserId] == id then nil else id
			publishStored(player.UserId)
			return true, "Holding " .. petName(rec.Egg, rec.Mutation)
		end
	end
	return false, "That pet is not in your backpack"
end

-- Equip: a stored pet goes back into the pen (needs a free slot and room to stand).
-- at: where to stand it (a clicked pen point); default: back where it stood.
local function equipRecord(player: Player, tank: Instance, rec: Record, at: Vector3?): (boolean, string)
	local footprint = footprintOf({ eggName = text(rec.Egg), size = rec.Size, income = 0, hatched = true })
	-- on that point, or the nearest free spot to it
	local spot = rec.Spot
	local near = at
		or if typeof(spot) == "table" and typeof(spot[1]) == "number" and typeof(spot[2]) == "number"
			then PenNodes.fromLocal(tank, spot[1], spot[2])
			else nil
	if not PenNodes.fits(tank, footprint, near) then
		return false, "No room in your pen for this pet!"
	end
	local list = stored[player.UserId] or {}
	local index = table.find(list, rec)
	if index then
		table.remove(list, index)
	end
	local place = table.clone(rec)
	place.Stored, place.Id = nil, nil
	if at then
		place.Spot = { PenNodes.toLocal(tank, at) }
	end
	local pet = placeRecord(player, tank, place)
	if pet then
		pet.burst:Emit(28)
	end
	return true, "Successfully equipped " .. petName(text(rec.Egg), text(rec.Mutation)) .. "!"
end

-- The owner clicked / tapped a spot in their pen while holding a pet Tool.
function TankBeasts.placeHeld(player: Player, point: any): (boolean, string?)
	if typeof(point) ~= "Vector3" or point ~= point then
		return false, nil
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("PetId")
	local tank = ownTank(player)
	local rec: Record? = nil
	for _, r in stored[player.UserId] or {} do
		if r.Id == id then
			rec = r
		end
	end
	if not tank or not rec then
		return false, nil
	end
	local center = tank:GetAttribute("Center")
	local half = tank:GetAttribute("HalfSize")
	if typeof(center) ~= "Vector3" or typeof(half) ~= "number" then
		return false, nil
	end
	if math.abs(point.X - center.X) > half or math.abs(point.Z - center.Z) > half then
		return false, nil
	end
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart") and Signs.nearTank(tank, hrp.Position, PLACE_REACH)) then
		return false, "Get closer to your Pen to place pets!"
	end
	if #activePets(player.UserId) >= capacity(player.UserId) then
		return false, "All equip slots are full! Unequip a pet or buy +1 Equip."
	end
	local ok, message = equipRecord(player, tank, rec, point)
	publishStored(player.UserId)
	return ok, message
end

-- Equip Best: the highest-earning pets you own fill your equip slots (a pet being ridden stays).
function TankBeasts.equipBest(player: Player): (boolean, string)
	local tank = ownTank(player)
	if not tank then
		return false, "You have no pen yet"
	end
	local userId = player.UserId
	local slots = capacity(userId)
	type Choice = { income: number, pet: Pet?, rec: Record?, locked: boolean }
	local choices: { Choice } = {}
	for _, pet in activePets(userId) do
		table.insert(choices, { income = pet.income, pet = pet, locked = pet.model:GetAttribute("RiddenBy") ~= nil })
	end
	for _, rec in stored[userId] or {} do
		table.insert(choices, { income = rec.Income, rec = rec, locked = false })
	end
	table.sort(choices, function(a, b)
		if a.locked ~= b.locked then
			return a.locked
		end
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.pet ~= nil and b.pet == nil -- on a tie, keep what is already out
	end)
	local changed = 0
	for i = #choices, slots + 1, -1 do
		local pet = choices[i].pet
		if pet then
			storePet(pet)
			changed += 1
		end
	end
	local blocked = false
	for i = 1, math.min(slots, #choices) do
		local rec = choices[i].rec
		if rec then
			if equipRecord(player, tank, rec) then
				changed += 1
			else
				blocked = true
			end
		end
	end
	publishStored(userId)
	if blocked then
		return true, "Equipped your best pets! Some didn't fit in your pen."
	end
	return true, if changed > 0 then "Equipped your best pets!" else "Your best pets are already equipped!"
end

-- Growing eggs (Growing Eggs panel) --------------------------------------------------------------

-- Open a ready egg from the panel (same as its Hatch! prompt).
function TankBeasts.openEgg(player: Player, model: any): boolean
	local pet = ownPet(player, model)
	if not pet or pet.hatched or not pet.ready then
		return false
	end
	hatchNow(pet)
	return true
end

-- The owner's eggs still growing (not ready yet).
function TankBeasts.growing(userId: number): { Model }
	local list = {}
	for _, pet in herd do
		if pet.ownerId == userId and not pet.hatched and not pet.ready and pet.model.Parent then
			table.insert(list, pet.model)
		end
	end
	return list
end

-- Grow time left on one of the owner's growing eggs, or nil.
function TankBeasts.growLeft(userId: number, model: any): number?
	for _, pet in herd do
		if pet.model == model and pet.ownerId == userId and not pet.hatched and not pet.ready then
			return math.max(pet.hatchLeft, 0)
		end
	end
	return nil
end

-- Skip / Grow All: finish growing now (the egg reads Ready! and waits to be opened).
function TankBeasts.finishGrowing(userId: number, model: Instance): boolean
	for _, pet in herd do
		if pet.model == model and pet.ownerId == userId and not pet.hatched and not pet.ready then
			markReady(pet)
			pet.burst:Emit(20)
			return true
		end
	end
	return false
end


-- Take the owner's pets out of the pen (they are saved and come back when the owner returns).
function TankBeasts.release(userId: number): number
	local removed = 0
	for i = #herd, 1, -1 do
		local pet = herd[i]
		if pet.ownerId == userId then
			table.remove(herd, i)
			pet.model:Destroy()
			removed += 1
		end
	end
	stored[userId] = nil
	return removed
end

function TankBeasts.start(root: Instance)
	local tanksFolder = root:FindFirstChild("PlayerTanks")
	assert(tanksFolder)
	local folder = root:FindFirstChild("TankBeasts")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TankBeasts"
		folder.Parent = root
	end
	petFolder = folder :: Folder
	table.clear(herd)
	-- Clear any leftover showcase pets / circular pedestals from older builds.
	for _, child in folder:GetChildren() do
		if child:GetAttribute("Showcase") == true then
			child:Destroy()
		end
	end
	for _, d in folder:GetDescendants() do
		if d.Name == "Pedestal" then
			d:Destroy()
		end
	end
	local live = herd
	local busy: { [Player]: boolean } = {}

	local function deposit(player: Player, tank: Instance, tool: Tool, near: Vector3)
		busy[player] = true
		local body = tool:FindFirstChild("Body")
		local from: Vector3
		if body and body:IsA("BasePart") then
			from = body.Position
		else
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			from = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.zero
		end
		local spec = specFromTool(tool)
		spec.near = near
		local pet = spawnPet(folder, tank, spec, from)
		pet.ownerId = player.UserId
		pet.model:SetAttribute("OwnerUserId", player.UserId)
		-- GameAudio: the "secured" chime at the pen
		pet.model:SetAttribute("PlacedAt", workspace:GetServerTimeNow())
		tool:Destroy()
		table.insert(live, pet)
		task.delay(0.4, function()
			busy[player] = nil
		end)
	end

	-- pet Tools are rebuilt from the saved list after every spawn (a respawn empties the backpack)
	local function watchSpawns(player: Player)
		player.CharacterAdded:Connect(function()
			player:WaitForChild("Backpack", 10)
			task.defer(syncPetTools, player)
		end)
	end
	Players.PlayerAdded:Connect(watchSpawns)
	for _, player in Players:GetPlayers() do
		watchSpawns(player)
	end

	local placeRemote = GameUI.remote("PlaceEgg")
	local notice = GameUI.remote("EggAnnouncement")
	local function tell(player: Player, message: string)
		notice:FireClient(player, { text = message, color = Color3.fromRGB(255, 170, 140), small = true })
	end
	-- The owner clicked / tapped a spot in their pen while holding an egg.
	placeRemote.OnServerEvent:Connect(function(player: Player, point: any)
		if typeof(point) ~= "Vector3" or point ~= point then
			return
		end
		if busy[player] or player:GetAttribute("MommyState") then
			return
		end
		local tool = heldTool(player)
		local slot = player:GetAttribute("TankSlot")
		local tank = if typeof(slot) == "number" then tanksFolder:FindFirstChild("Tank" .. slot) else nil
		if not tool or not tank then
			return
		end
		local center = tank:GetAttribute("Center")
		local half = tank:GetAttribute("HalfSize")
		if typeof(center) ~= "Vector3" or typeof(half) ~= "number" then
			return
		end
		if math.abs(point.X - center.X) > half or math.abs(point.Z - center.Z) > half then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart") and Signs.nearTank(tank, hrp.Position, PLACE_REACH)) then
			tell(player, "Get closer to your pen to place the egg.")
			return
		end
		local footprint = footprintOf(specFromTool(tool))
		-- the egg lands on the clicked spot, or the nearest free spot when a pet is already there;
		-- only a pen with no room left for this footprint refuses
		if not PenNodes.fits(tank, footprint, point) then
			tell(player, "Your pen is full! Unequip pets (paw button) or fuse them to make room.")
			return
		end
		deposit(player, tank, tool, point)
	end)

	local purse: { [Player]: number } = {}
	local purseClock = 0

	RunService.Heartbeat:Connect(function(dt)
		for i = #live, 1, -1 do
			local pet = live[i]
			-- pets leave the herd only through take/release, so a save never misses one
			if not pet.model.Parent then
				continue
			end
			pet.age += dt
			local cf: CFrame
			if pet.state == "kick" then
				pet.kickT += dt
				cf = kickCFrame(pet)
				if pet.kickT >= pet.kickDur then
					pet.state = "land"
					pet.shakeT = 0
					pet.burst:Emit(28)
					pet.burst.Enabled = true
					pet.glow.Enabled = true
					cf = CFrame.new(pet.landing)
				end
			elseif pet.state == "land" then
				cf = landCFrame(pet, dt)
				if pet.shakeT >= SHAKE_TIME then
					pet.state = "perch"
					pet.burst.Enabled = false
					pet.glow.Enabled = pet.glowing
					pet.roamT = 0
				end
			else
				cf = perchCFrame(pet, dt)
			end
			pet.root.CFrame = cf
			pet.body.CFrame = cf
			if not pet.hatched and not pet.ready then
				pet.model:SetAttribute("HatchLeft", math.max(pet.hatchLeft, 0))
				local phase = NightCycle.state(workspace:GetServerTimeNow())
				local growth = if phase == "Night" then NightCycle.GrowthMultiplier else 1
				local grower = Players:GetPlayerByUserId(pet.ownerId)
				if grower and grower:GetAttribute("PassGrowth") then
					growth *= ShopConfig.GrowthBoost
				end
				pet.hatchLeft -= dt * growth
				if pet.hatchLeft <= 0 then
					markReady(pet)
				end
			elseif pet.hatched and pet.state ~= "kick" and pet.income > 0 then
				local owner = Players:GetPlayerByUserId(pet.ownerId)
				if owner then
					purse[owner] = (purse[owner] or 0) + pet.income * dt
				end
			end
		end

		purseClock += dt
		if purseClock >= 1 then
			local elapsed = purseClock
			purseClock = 0
			for _, owner in Players:GetPlayers() do
				local amount = (purse[owner] or 0) * (if owner:GetAttribute("PassMoney") then ShopConfig.MoneyBoost else 1)
				if amount > 0 then
					SpeedData.addCash(owner, amount)
				end
				-- shop cash packs scale with this
				owner:SetAttribute("PenIncome", math.floor(amount / elapsed * 10 + 0.5) / 10)
			end
			table.clear(purse)
		end
	end)
	print("[BabyBeasts] Tank deposit ready")
end

return TankBeasts
