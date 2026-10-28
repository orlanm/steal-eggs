--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local BubbleConfig = require(game.ReplicatedStorage.BabyBeastsShared.BubbleConfig)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local BubbleLife = require(game.ReplicatedStorage.BabyBeastsShared.BubbleLife)
local GameEgg = require(game.ReplicatedStorage.BabyBeastsShared.GameEgg)
local EggSources = require(game.ReplicatedStorage.BabyBeastsShared.EggSources)
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)
local NightCycle = require(game.ReplicatedStorage.BabyBeastsShared.NightCycle)

local MommyBeasts = require(script.Parent.MommyBeasts)
local holdInHands = require(script.Parent.CarryHold).holdInHands
local CaveBubbles = {}

-- Set by start(): admin hooks into the live nest state (AdminEggs).
local hooks: {
	drop: ((eggName: string, origin: Vector3, mutation: string?, size: number?) -> Instance?)?,
	spawnRare: ((mutation: string?) -> { name: string, rarity: string, biome: string }?)?,
	reset: (() -> ())?,
} = {}

local function holdingBeast(player: Player): boolean
	local character = player.Character
	if character and character:FindFirstChild("BabyBeast") then
		return true
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild("BabyBeast") then
		return true
	end
	return false
end

-- size: the egg's rolled size scale; income: per-second income once hatched (default: the
-- species income x the size payout).
local function equipBeast(
	player: Player,
	nest: EggScale.Nest,
	eggName: string?,
	keepExisting: boolean?,
	mutation: string?,
	size: number?,
	income: number?,
	source: string?
): Tool?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) then
		return nil
	end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return nil
	end
	if not keepExisting then
		for _, inst in character:GetChildren() do
			if inst:IsA("Tool") and inst.Name == "BabyBeast" then
				inst:Destroy()
			end
		end
		for _, inst in backpack:GetChildren() do
			if inst:IsA("Tool") and inst.Name == "BabyBeast" then
				inst:Destroy()
			end
		end
	end

	local modelId = GameUI.modelIdForLevel(GameUI.playerLevel(player))
	local tool = Instance.new("Tool")
	tool.Name = "BabyBeast"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("BeastMesh", true)
	tool:SetAttribute("ModelId", modelId)
	if typeof(eggName) == "string" and eggName ~= "" then
		tool:SetAttribute("EggName", eggName)
	end
	tool:SetAttribute("Scale", nest.Scale)
	tool:SetAttribute("NestScale", nest.Scale)
	tool:SetAttribute("WeightPenalty", nest.Penalty)
	tool:SetAttribute("EggClass", nest.Class)
	tool:SetAttribute("EggRarity", nest.Rarity)
	-- mutation is fixed from the egg on: it sets the pet's static size multiplier when it hatches
	if mutation and mutation ~= "" then
		tool:SetAttribute("Mutation", mutation)
	end
	-- where it came from (Biome, Event, Shop, Limited, Admin, AdminOnly, TradeIn)
	if source and source ~= "" then
		tool:SetAttribute("EggSource", source)
	end
	local sizeScale = EggScale.sizeOf(size)
	tool:SetAttribute("SizeScale", sizeScale)
	local profile = if typeof(eggName) == "string" and eggName ~= "" then GameEgg.profile(eggName) else nil
	local fallbackIncome = if profile then profile.Income * EggScale.sizePayout(sizeScale) else 0
	tool:SetAttribute("EggIncome", if typeof(income) == "number" and income == income and income >= 0 then income else fallbackIncome)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	handle.Parent = tool

	local body = Instance.new("MeshPart")
	body.Name = "Body"
	-- Carried at its real size: the native egg x its size scale, like Steal an Egg.
	local carry = EggScale.carryBox(eggName, sizeScale)
	body.Size = carry
	body.Transparency = if typeof(eggName) == "string" and eggName ~= "" then 1 else 0
	body.TextureID = modelId
	body.Color = Color3.new(1, 1, 1)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = false
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	pcall(function()
		body.DoubleSided = true
	end)
	body.CFrame = handle.CFrame * CFrame.new(0, carry.Y * 0.5, 0)
	body.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = body
	weld.Parent = handle
	holdInHands(tool, body, weld, carry)
	tool.Parent = backpack
	if not keepExisting then
		humanoid:EquipTool(tool)
	end
	return tool
end

export type GrantOptions = {
	mutation: string?,
	size: number?,
	source: string?,
}

-- Hand a player an egg (shop, trade-in, fuse, admin give). It goes in the backpack next to any
-- egg they already carry. Income follows the species x mutation x size, like a nest egg.
function CaveBubbles.grant(player: Player, eggName: string, options: GrantOptions?): Tool?
	local profile = GameEgg.profile(eggName)
	local alpha = EggScale.tierAlpha(profile.Class, profile.HeightMin, profile.HeightMax)
	local mutation = options and options.mutation
	local size = EggScale.sizeOf(if options and options.size then options.size else EggScale.rollSize(Random.new(), EggScale.rarityOf(eggName)))
	local multiplier = if mutation == "Rainbow" then 3 elseif mutation == "Golden" then 2 elseif mutation == "Silver" then 1.25 else 1
	return equipBeast(
		player,
		EggScale.nest(profile.Class, alpha, eggName, EggScale.rarityOf(eggName)),
		eggName,
		holdingBeast(player),
		mutation,
		size,
		profile.Income * multiplier * EggScale.sizePayout(size),
		options and options.source or nil
	)
end

-- Admin: drop a stealable egg at a spot (the plaza drop pad). Nil before start().
function CaveBubbles.drop(eggName: string, origin: Vector3, mutation: string?, size: number?): Instance?
	return if hooks.drop then hooks.drop(eggName, origin, mutation, size) else nil
end

-- Admin: swap one untouched nest egg in a random biome for one of that biome's rarest eggs.
function CaveBubbles.spawnRare(mutation: string?): { name: string, rarity: string, biome: string }?
	return if hooks.spawnRare then hooks.spawnRare(mutation) else nil
end

-- Admin: re-roll every nest now (uses the current spawn luck and live events).
function CaveBubbles.reset()
	if hooks.reset then
		hooks.reset()
	end
end

-- Persistence (BeastData) -------------------------------------------------------------------------

export type EggRecord = {
	Egg: string?,
	Mutation: string?,
	Class: string,
	Rarity: string,
	NestScale: number,
	Size: number?,
	Penalty: number,
	Income: number,
	ModelId: string?,
	Source: string?,
}

local function text(value: any): string?
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function number(value: any, default: number): number
	return if typeof(value) == "number" and value == value then value else default
end

-- Eggs the player is carrying (equipped or in the backpack) as save records.
function CaveBubbles.snapshot(player: Player): { EggRecord }
	local list = {}
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		if not container then
			continue
		end
		for _, tool in (container :: Instance):GetChildren() do
			if not (tool:IsA("Tool") and tool.Name == "BabyBeast") then
				continue
			end
			table.insert(list, {
				Egg = text(tool:GetAttribute("EggName")),
				Mutation = text(tool:GetAttribute("Mutation")),
				Class = text(tool:GetAttribute("EggClass")) or "Medium",
				Rarity = text(tool:GetAttribute("EggRarity")) or "Common",
				NestScale = number(tool:GetAttribute("NestScale"), 1),
				Size = EggScale.sizeOf(tool:GetAttribute("SizeScale")),
				Penalty = number(tool:GetAttribute("WeightPenalty"), 1),
				Income = math.max(number(tool:GetAttribute("EggIncome"), 0), 0),
				ModelId = text(tool:GetAttribute("ModelId")),
				Source = text(tool:GetAttribute("EggSource")),
			})
		end
	end
	return list
end

-- Hand saved eggs back, exactly as they were carried (stays in the backpack, not equipped).
function CaveBubbles.restore(player: Player, records: { EggRecord }): number
	local restored = 0
	for _, rec in records do
		local class = EggScale.classOf(text(rec.Class) or "Medium")
		local scale = number(rec.NestScale, 1)
		local nest: EggScale.Nest = {
			Scale = scale,
			Height = scale,
			Penalty = math.clamp(number(rec.Penalty, 1), 0, 1),
			Class = class,
			ClassLabel = EggScale.classLabel(class),
			Rarity = text(rec.Rarity) or "Common",
		}
		local tool = equipBeast(player, nest, text(rec.Egg), true, text(rec.Mutation), EggScale.sizeOf(rec.Size), math.max(number(rec.Income, 0), 0), text(rec.Source))
		if tool then
			local modelId = text(rec.ModelId)
			if modelId then
				tool:SetAttribute("ModelId", modelId)
				local body = tool:FindFirstChild("Body")
				if body and body:IsA("MeshPart") then
					body.TextureID = modelId
				end
			end
			restored += 1
		end
	end
	return restored
end

function CaveBubbles.start(root: Instance)
	local map = root
	for _, name in { "CaveBubbles", "CaveBubbleState" } do
		local leftover = map:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
	local state = Instance.new("Folder")
	state.Name = "CaveBubbleState"
	state.Parent = map

	local rng = Random.new(MapConfig.Seed + 77)
	local dens: { Instance } = {}
	local nextId = 0
	local locked = false
	local stealEgg: (Player, Instance) -> ()
	for _, inst in map:GetDescendants() do
		if inst.Name == "JailCell" then
			table.insert(dens, inst)
		end
	end

	local function habitatOf(den: Instance): string
		return den.Parent and den.Parent.Name or den.Name
	end

	local function biomeName(habitat: string): string
		local habitats = map:FindFirstChild("BeastHabitats")
		local zone = habitats and habitats:FindFirstChild(habitat)
		local name = zone and zone:GetAttribute("BiomeName")
		if typeof(name) == "string" and name ~= "" then
			return name
		end
		return habitat
	end

	local function attachPrompt(rec: Instance, origin: Vector3, shell: number, eggName: string)
		local anchor = Instance.new("Part")
		anchor.Name = "EggAnchor"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = true
		anchor.CastShadow = false
		anchor.CFrame = CFrame.new(origin)
		anchor.Parent = rec

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "Steal"
		prompt.ObjectText = if eggName ~= "" then eggName else "Egg"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = math.clamp(shell * 0.5 + 1.5, 4, 14)
		prompt.MaxIndicatorDistance = prompt.MaxActivationDistance
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.ClickablePrompt = true
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			if locked and rec:GetAttribute("AdminDrop") ~= true then
				return
			end
			stealEgg(player, rec)
		end)
	end

	local function commitDraft(draft: any, origin: Vector3): { name: string, rarity: string, biome: string }?
		local rec = Instance.new("Folder")
		rec.Name = "B" .. draft.id
		rec:SetAttribute("Id", draft.id)
		rec:SetAttribute("Habitat", draft.habitat)
		rec:SetAttribute("Origin", origin)
		rec:SetAttribute("EggIncome", draft.income)
		rec:SetAttribute("NestScale", draft.nest.Scale)
		rec:SetAttribute("EggClass", draft.nest.Class)
		rec:SetAttribute("EggRarity", draft.nest.Rarity)
		rec:SetAttribute("WeightPenalty", draft.nest.Penalty)
		rec:SetAttribute("Scale", draft.nest.Scale)
		rec:SetAttribute("BodySize", draft.bodySize)
		rec:SetAttribute("SizeScale", draft.size)
		rec:SetAttribute("ShellSize", draft.shellSize)
		rec:SetAttribute("Color", draft.color)
		rec:SetAttribute("ModelId", BubbleLife.modelId())
		if draft.eggName ~= "" then
			rec:SetAttribute("EggName", draft.eggName)
		end
		rec:SetAttribute("EggSource", draft.source)
		if draft.adminDrop then
			rec:SetAttribute("AdminDrop", true)
		end
		if draft.mutation ~= "" then
			rec:SetAttribute("ShellMutation", draft.mutation)
			rec:SetAttribute("CashMultiplier", draft.multiplier)
		end
		rec:SetAttribute("Spin", 0)
		rec:SetAttribute("Yaw", 0)
		rec:SetAttribute("Rise", 0)
		rec:SetAttribute("Phase", 0)
		rec:SetAttribute("Born", Workspace:GetServerTimeNow())
		rec:SetAttribute("Popping", false)
		-- world-announced egg: clients play its rarity music (GameAudio)
		if draft.ultra then
			rec:SetAttribute("Announced", true)
		end
		rec.Parent = state
		attachPrompt(rec, origin, draft.shellSize, draft.eggName)
		if draft.ultra then
			return {
				name = draft.eggName,
				rarity = draft.nest.Rarity,
				biome = biomeName(draft.habitat),
			}
		end
		return nil
	end

	-- One nest egg, before it is placed. source: Biome / Event / Admin.
	local function makeDraft(habitat: string, eggName: string, index: number, source: string, forcedMutation: string?): any
		nextId += 1
		local egg = if eggName ~= "" then GameEgg.get(eggName) else nil
		if not egg then
			eggName = ""
		end
		local profile = GameEgg.profile(eggName)
		local alpha = EggScale.tierAlpha(profile.Class, profile.HeightMin, profile.HeightMax)
		alpha = math.clamp(alpha + rng:NextNumber(-0.06, 0.06), 0, 1)
		local nest = EggScale.nest(profile.Class, alpha, eggName, EggScale.rarityOf(eggName))
		local mutation, multiplier = EggScale.rollShell(rng)
		if forcedMutation then
			mutation = forcedMutation
			multiplier = if forcedMutation == "Rainbow" then 3 elseif forcedMutation == "Golden" then 2 elseif forcedMutation == "Silver" then 1.25 else 1
		end
		local sizeScale = EggScale.rollSize(rng, nest.Rarity)
		local body = EggScale.eggBox(eggName, sizeScale)
		local shellSize = math.max(body.X, body.Y, body.Z)
		local color = EggScale.shellColor(nest.Rarity, index)
		local tint = if mutation ~= "" then EggScale.mutationColor(mutation) else nil
		if tint then
			color = tint
		end
		return {
			id = nextId,
			habitat = habitat,
			eggName = eggName,
			source = source,
			nest = nest,
			income = profile.Income * multiplier * EggScale.sizePayout(sizeScale),
			size = sizeScale,
			bodySize = body,
			shellSize = shellSize,
			color = color,
			mutation = mutation,
			multiplier = multiplier,
			-- world announcement: top-tier rarity that was also a rare roll (EggSources.AnnounceMaxChance)
			ultra = egg ~= nil
				and EggScale.isUltraRare(nest.Rarity, eggName)
				and EggSources.nestChance(habitat, eggName, source) <= EggSources.AnnounceMaxChance,
		}
	end

	local function fillDen(den: Instance): { { name: string, rarity: string, biome: string } }
		local drafts = {}
		local spots: { BubbleLife.Spot } = {}
		local habitat = habitatOf(den)
		local luck = EggSources.spawnLuck()
		local now = os.time()
		for index = 1, BubbleConfig.PerCell do
			local eggName, source = EggSources.rollNest(habitat, rng, now, luck)
			local draft = makeDraft(habitat, eggName or "", index, source, nil)
			local nest = draft.nest
			local classRank = if nest.Class == "Small" then 1 elseif nest.Class == "Medium" then 2 elseif nest.Class == "Heavy" then 3 else 4
			local rareRank = 0
			if nest.Rarity == "Boss" or nest.Rarity == "Legendary" or nest.Rarity == "Mythic" or nest.Rarity == "Cosmic" then
				rareRank = 2
			elseif nest.Rarity == "Secret" or nest.Rarity == "Eternal" or nest.Rarity == "Divine" then
				rareRank = 4
			end
			drafts[index] = draft
			spots[index] = {
				radius = draft.shellSize * 0.5,
				rank = classRank * 10 + rareRank + nest.Scale,
			}
		end
		local origins = BubbleLife.layout(den, spots)
		local found = {}
		for index, draft in drafts do
			local origin = origins[index]
			if typeof(origin) ~= "Vector3" then
				origin = Vector3.new(0, 6, 0)
			end
			local rare = commitDraft(draft, origin)
			if rare then
				table.insert(found, rare)
			end
		end
		return found
	end

	-- Night wipes the nests; admin drops in the plaza stay until stolen or expired.
	local function clearEggs()
		for _, rec in state:GetChildren() do
			if rec:GetAttribute("AdminDrop") ~= true then
				rec:Destroy()
			end
		end
	end

	local function spawnAll(): { { name: string, rarity: string, biome: string } }
		local rares = {}
		-- every one goes out: clients queue the banners and log each line in chat
		for _, den in dens do
			for _, rare in fillDen(den) do
				table.insert(rares, rare)
			end
		end
		return rares
	end

	local collected = GameUI.ensureRemotes()
	local collectRemote = GameUI.remote("CollectBeast")
	local notice = GameUI.remote("NightNotice")
	local busy: { [Player]: boolean } = {}

	stealEgg = function(player: Player, rec: Instance)
		local adminDrop = rec:GetAttribute("AdminDrop") == true
		if (locked and not adminDrop) or busy[player] or not MommyBeasts.canCollect(player) then
			return
		end
		if holdingBeast(player) then
			-- one egg at a time: say why the prompt did nothing
			GameUI.remote("EggAnnouncement"):FireClient(player, {
				text = "You're already carrying an egg. Place it in your pen first!",
				color = Color3.fromRGB(255, 170, 140),
				small = true,
			})
			return
		end
		if not rec.Parent then
			return
		end
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
			return
		end
		local origin = rec:GetAttribute("Origin")
		if typeof(origin) ~= "Vector3" then
			return
		end
		local shell = rec:GetAttribute("ShellSize")
		if typeof(shell) ~= "number" then
			shell = 4
		end
		local reach = shell * 0.5 + 6
		if (hrp.Position - origin).Magnitude > reach then
			return
		end
		busy[player] = true
		local bodySize = rec:GetAttribute("BodySize")
		if typeof(bodySize) ~= "Vector3" then
			bodySize = GameUI.NativeSize
		end
		local habitat = rec:GetAttribute("Habitat")
		local eggName = rec:GetAttribute("EggName")
		local carriedEgg = if typeof(eggName) == "string" then eggName else nil
		local className = rec:GetAttribute("EggClass")
		local rarity = rec:GetAttribute("EggRarity")
		local penalty = rec:GetAttribute("WeightPenalty")
		local scale = rec:GetAttribute("NestScale")
		local shellMutation = rec:GetAttribute("ShellMutation")
		local sizeScale = EggScale.sizeOf(rec:GetAttribute("SizeScale"))
		local recIncome = rec:GetAttribute("EggIncome")
		local recSource = rec:GetAttribute("EggSource")
		local nest: EggScale.Nest = {
			Scale = if typeof(scale) == "number" then scale else 1,
			Height = if typeof(bodySize) == "Vector3" then bodySize.Y else EggScale.carryHeight(),
			Penalty = if typeof(penalty) == "number" then penalty else 1,
			Class = if typeof(className) == "string" then className else "Medium",
			ClassLabel = EggScale.classLabel(if typeof(className) == "string" then className else "Medium"),
			Rarity = if typeof(rarity) == "string" then rarity else "Common",
		}
		collected:FireClient(player, {
			modelId = GameUI.modelIdForLevel(GameUI.playerLevel(player)),
			size = EggScale.carryBox(carriedEgg, sizeScale),
			eggName = carriedEgg,
		})
		local tool = equipBeast(
			player,
			nest,
			carriedEgg,
			nil,
			if typeof(shellMutation) == "string" then shellMutation else nil,
			sizeScale,
			if typeof(recIncome) == "number" then recIncome else nil,
			if typeof(recSource) == "string" then recSource else nil
		)
		if tool then
			-- GameAudio: steal whoosh, and the rarity music while the egg is carried
			tool:SetAttribute("StolenAt", Workspace:GetServerTimeNow())
			if rec:GetAttribute("Announced") == true then
				tool:SetAttribute("Announced", true)
			end
		end
		local captureAt = origin
		rec:Destroy()
		-- admin drops sit in the plaza: no guardian chases those
		if typeof(habitat) == "string" and not adminDrop then
			MommyBeasts.begin(player, habitat, captureAt)
		end
		task.delay(0.35, function()
			busy[player] = nil
		end)
	end

	hooks.drop = function(eggName: string, origin: Vector3, mutation: string?, size: number?): Instance?
		local draft = makeDraft("Plaza", eggName, nextId + 1, "Admin", mutation)
		if draft.eggName == "" then
			return nil
		end
		if size then
			draft.size = EggScale.sizeOf(size)
			draft.bodySize = EggScale.eggBox(draft.eggName, draft.size)
			draft.shellSize = math.max(draft.bodySize.X, draft.bodySize.Y, draft.bodySize.Z)
			draft.income = GameEgg.profile(draft.eggName).Income * draft.multiplier * EggScale.sizePayout(draft.size)
		end
		draft.adminDrop = true
		draft.ultra = false
		-- sit the egg on the floor at the drop pad
		commitDraft(draft, origin + Vector3.new(0, draft.bodySize.Y * 0.5, 0))
		local rec = state:FindFirstChild("B" .. draft.id)
		if rec then
			task.delay(EggSources.Admin.DropLifetime, function()
				if rec.Parent then
					rec:Destroy()
				end
			end)
		end
		return rec
	end

	hooks.spawnRare = function(mutation: string?): { name: string, rarity: string, biome: string }?
		if locked then
			return nil
		end
		local pool = {}
		for _, rec in state:GetChildren() do
			if rec:GetAttribute("AdminDrop") ~= true and typeof(rec:GetAttribute("Habitat")) == "string" then
				table.insert(pool, rec)
			end
		end
		if #pool == 0 then
			return nil
		end
		local victim = pool[rng:NextInteger(1, #pool)]
		local habitat = victim:GetAttribute("Habitat") :: string
		local origin = victim:GetAttribute("Origin")
		local eggName = EggSources.rareFor(habitat, rng)
		if not eggName or typeof(origin) ~= "Vector3" then
			return nil
		end
		local draft = makeDraft(habitat, eggName, 1, "Biome", mutation)
		draft.ultra = true
		victim:Destroy()
		return commitDraft(draft, origin)
	end

	local phase, _remain = NightCycle.state(Workspace:GetServerTimeNow())
	locked = phase == "Night"
	state:SetAttribute("StealingLocked", locked)
	if locked then
		clearEggs()
	else
		spawnAll()
	end

	hooks.reset = function()
		if locked then
			return
		end
		clearEggs()
		local rares = spawnAll()
		notice:FireAllClients({
			reset = true,
			rares = rares,
		})
	end

	collectRemote.OnServerEvent:Connect(function(player: Player, bubbleId: any)
		if typeof(bubbleId) ~= "number" then
			return
		end
		local rec = state:FindFirstChild("B" .. bubbleId)
		if not rec or (locked and rec:GetAttribute("AdminDrop") ~= true) then
			return
		end
		stealEgg(player, rec)
	end)

	local lastPhase = phase
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local current = NightCycle.state(now)
		if current == lastPhase then
			return
		end
		lastPhase = current
		if current == "Night" then
			locked = true
			state:SetAttribute("StealingLocked", true)
			clearEggs()
		else
			locked = false
			state:SetAttribute("StealingLocked", false)
			clearEggs()
			local rares = spawnAll()
			notice:FireAllClients({
				reset = true,
				rares = rares,
			})
		end
	end)

	print("[BabyBeasts] Jail bubbles hold still: " .. BubbleConfig.Rows .. " rows, stolen on a half-second hold")
end

return CaveBubbles
