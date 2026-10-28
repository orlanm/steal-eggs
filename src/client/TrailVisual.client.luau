--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.TrailVisual
-- Equipped trail visuals for every player (each client draws them all, like Steal an Egg's
-- TrailController). Attached to the avatar root:
--   ribbon   a glowing Trail behind the runner (Steal an Egg's ribbon: two attachments across the
--            root, 0.2-0.5s long), coloured by rarity
--   stream   a particle stream behind the runner while moving
--   glow     higher tiers tint the air around the avatar (PointLight)
--   stars    Galaxy: a starfield trailing behind
--   ambient  Secret / Eternal / Divine / Moonbloom: energy motes floating around the avatar

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Economy = require(ReplicatedStorage:WaitForChild("BabyBeastsShared"):WaitForChild("EconomyConfig"))

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local MOVING_SPEED = 2 -- studs/s before the stream and stars run

type Style = {
	ribbon: ColorSequence,
	ribbonFade: number, -- ribbon transparency at its head (0 = solid)
	ribbonLife: number,
	vertical: boolean?, -- Divine / Moonbloom: a tall ribbon (Steal an Egg's +-1.2 Y attachments)
	width: number, -- ribbon span across the root, studs
	brightness: number,
	stream: ColorSequence,
	streamRate: number,
	glow: Color3?, -- ambient tint around the avatar
	glowBrightness: number?,
	stars: boolean?,
	ambient: ColorSequence?,
}

local function seq(...: Color3): ColorSequence
	local colors = { ... }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(keys)
end

local rgb = Color3.fromRGB

-- Rarity colour schemes (ribbon colours are Steal an Egg's, Grey is a plain low-opacity stream).
local STYLES: { [string]: Style } = {
	-- Grey / Common: standard grey ribbon, low opacity
	Grey = { ribbon = seq(rgb(200, 200, 206), rgb(150, 150, 158)), ribbonFade = 0.55, ribbonLife = 0.2, width = 1.5, brightness = 1, stream = seq(rgb(210, 210, 216)), streamRate = 10 },
	-- Green / Uncommon: bright neon green
	Green = { ribbon = seq(rgb(0, 255, 0), rgb(0, 165, 0)), ribbonFade = 0, ribbonLife = 0.2, width = 1.5, brightness = 2, stream = seq(rgb(90, 255, 90)), streamRate = 16 },
	-- Blue / Rare: cyan / blue particle stream
	Blue = { ribbon = seq(rgb(0, 170, 255)), ribbonFade = 0, ribbonLife = 0.2, width = 1.5, brightness = 2, stream = seq(rgb(60, 230, 255), rgb(0, 140, 255)), streamRate = 22 },
	-- Purple / Epic: dark violet energy beam
	Purple = { ribbon = seq(rgb(91, 0, 103), rgb(226, 123, 255)), ribbonFade = 0, ribbonLife = 0.25, width = 1.6, brightness = 2, stream = seq(rgb(170, 60, 255), rgb(90, 0, 150)), streamRate = 26, glow = rgb(150, 60, 255), glowBrightness = 0.6 },
	-- Golden / Legendary: radiant gold / yellow light stream
	Golden = { ribbon = seq(rgb(255, 162, 0), rgb(255, 238, 0)), ribbonFade = 0, ribbonLife = 0.25, width = 1.6, brightness = 3, stream = seq(rgb(255, 236, 120), rgb(255, 170, 0)), streamRate = 30, glow = rgb(255, 210, 80), glowBrightness = 0.9 },
	-- Red / Mythic: crimson beam
	Red = { ribbon = seq(rgb(255, 0, 0), rgb(170, 0, 20)), ribbonFade = 0, ribbonLife = 0.3, width = 1.7, brightness = 3, stream = seq(rgb(255, 60, 60), rgb(150, 0, 20)), streamRate = 34, glow = rgb(255, 40, 40), glowBrightness = 1 },
	-- Galaxy / Cosmic: starfield behind the runner
	Galaxy = { ribbon = seq(rgb(75, 0, 140), rgb(186, 74, 246), rgb(134, 0, 243), rgb(189, 19, 246), rgb(69, 0, 154)), ribbonFade = 0, ribbonLife = 0.35, width = 1.8, brightness = 3, stream = seq(rgb(190, 120, 255), rgb(60, 90, 230)), streamRate = 26, glow = rgb(140, 70, 255), glowBrightness = 1.1, stars = true },
	-- Secret / Eternal / Divine / Moonbloom: high-intensity energy streams + floating ambient motes
	Secret = { ribbon = seq(rgb(255, 255, 255), rgb(20, 20, 24), rgb(255, 255, 255), rgb(20, 20, 24)), ribbonFade = 0, ribbonLife = 0.4, width = 2.2, brightness = 4, stream = seq(rgb(255, 255, 255), rgb(60, 60, 70)), streamRate = 40, glow = rgb(235, 235, 255), glowBrightness = 1.4, ambient = seq(rgb(255, 255, 255), rgb(150, 150, 170)) },
	Eternal = { ribbon = seq(rgb(238, 0, 255), rgb(255, 255, 255)), ribbonFade = 0, ribbonLife = 0.4, width = 2, brightness = 4, stream = seq(rgb(255, 120, 230), rgb(120, 240, 255)), streamRate = 42, glow = rgb(240, 90, 240), glowBrightness = 1.5, ambient = seq(rgb(255, 150, 240), rgb(130, 240, 255)) },
	Divine = { ribbon = seq(rgb(255, 0, 4), rgb(255, 72, 0), rgb(255, 255, 0), rgb(26, 255, 0), rgb(0, 255, 247), rgb(220, 6, 255)), ribbonFade = 0, ribbonLife = 0.5, vertical = true, width = 2.4, brightness = 6, stream = seq(rgb(255, 80, 80), rgb(255, 220, 70), rgb(80, 220, 140), rgb(90, 140, 255)), streamRate = 48, glow = rgb(255, 230, 140), glowBrightness = 1.8, ambient = seq(rgb(255, 240, 150), rgb(255, 255, 255)) },
	Moonbloom = { ribbon = seq(rgb(29, 255, 210), rgb(0, 174, 254)), ribbonFade = 0, ribbonLife = 0.5, vertical = true, width = 2.4, brightness = 5, stream = seq(rgb(120, 255, 220), rgb(0, 174, 254)), streamRate = 48, glow = rgb(29, 255, 210), glowBrightness = 1.8, ambient = seq(rgb(170, 255, 150), rgb(150, 230, 255)) },
}

type Rendered = {
	trailId: string,
	character: Model,
	root: BasePart,
	folder: { Instance },
	movers: { ParticleEmitter }, -- run only while the avatar is moving
}

local rendered: { [Player]: Rendered } = {}

local function clear(player: Player)
	local r = rendered[player]
	if not r then
		return
	end
	for _, inst in r.folder do
		inst:Destroy()
	end
	rendered[player] = nil
end

local function attachment(root: BasePart, name: string, position: Vector3, list: { Instance }): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = root
	table.insert(list, a)
	return a
end

local function emitter(parent: Attachment, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function build(player: Player, trailId: string, character: Model, root: BasePart)
	local style = STYLES[trailId]
	if not style then
		return
	end
	local list: { Instance } = {}
	local movers: { ParticleEmitter } = {}

	-- ribbon
	local half = style.width * 0.5
	local a0, a1
	if style.vertical then
		a0 = attachment(root, "TrailRibbonTop", Vector3.new(0, half, 0.6), list)
		a1 = attachment(root, "TrailRibbonBottom", Vector3.new(0, -half, 0.6), list)
	else
		a0 = attachment(root, "TrailRibbonLeft", Vector3.new(half, -0.4, 0.6), list)
		a1 = attachment(root, "TrailRibbonRight", Vector3.new(-half, -0.4, 0.6), list)
	end
	local ribbon = Instance.new("Trail")
	ribbon.Name = "EquippedTrailRibbon"
	ribbon.Attachment0 = a0
	ribbon.Attachment1 = a1
	ribbon.Color = style.ribbon
	ribbon.Lifetime = style.ribbonLife
	ribbon.MinLength = 0.1
	ribbon.FaceCamera = true
	ribbon.LightEmission = 1
	ribbon.LightInfluence = 0
	ribbon.Brightness = style.brightness
	ribbon.Transparency = NumberSequence.new(style.ribbonFade, 1)
	ribbon.WidthScale = NumberSequence.new(1, 0.35)
	ribbon.Parent = root
	table.insert(list, ribbon)
	if style.vertical then
		-- a second, wider and fainter ribbon layered on top (Steal an Egg's Divine / Moonbloom)
		local halo = ribbon:Clone()
		halo.Name = "EquippedTrailHalo"
		halo.Transparency = NumberSequence.new(0.55, 1)
		halo.WidthScale = NumberSequence.new(1.4, 0.2)
		halo.Lifetime = style.ribbonLife * 0.8
		halo.Parent = root
		table.insert(list, halo)
	end

	-- particle stream behind the runner
	local tail = attachment(root, "TrailStream", Vector3.new(0, -0.3, 1), list)
	table.insert(movers, emitter(tail, {
		Name = "EquippedTrailStream",
		Color = style.stream,
		Rate = style.streamRate,
		Lifetime = NumberRange.new(0.35, 0.8),
		Speed = NumberRange.new(0.3, 1.6),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 2,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.05) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
	}))

	-- starfield (Galaxy)
	if style.stars then
		table.insert(movers, emitter(tail, {
			Name = "EquippedTrailStars",
			Color = seq(rgb(255, 255, 255), rgb(200, 180, 255)),
			Rate = 30,
			Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(0.1, 0.6),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		}))
	end

	-- ambient tint / glow
	if style.glow then
		local light = Instance.new("PointLight")
		light.Name = "EquippedTrailGlow"
		light.Color = style.glow
		light.Brightness = style.glowBrightness or 1
		light.Range = 10
		light.Shadows = false
		light.Parent = root
		table.insert(list, light)
	end

	-- floating energy motes around the avatar (always on, even standing still)
	if style.ambient then
		local aura = attachment(root, "TrailAura", Vector3.new(0, 0.5, 0), list)
		emitter(aura, {
			Name = "EquippedTrailAura",
			Color = style.ambient,
			Rate = 14,
			Lifetime = NumberRange.new(1.2, 2.2),
			Speed = NumberRange.new(1.2, 2.6),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
			Acceleration = Vector3.new(0, 1.4, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		})
	end

	rendered[player] = { trailId = trailId, character = character, root = root, folder = list, movers = movers }
end

local function refresh(player: Player)
	local trailId = tostring(player:GetAttribute("EquippedTrail") or "")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local current = rendered[player]
	if current and current.trailId == trailId and current.character == character and current.root.Parent then
		return
	end
	clear(player)
	if not Economy.trail(trailId) or not character or not root or not root:IsA("BasePart") then
		return
	end
	build(player, trailId, character, root)
end

local function bind(player: Player)
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refresh(player)
	end)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	refresh(player)
end

for _, player in Players:GetPlayers() do
	task.spawn(bind, player)
end
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(clear)

-- the stream and starfield run only while moving; the ribbon fades out on its own when still
RunService.Heartbeat:Connect(function()
	for _, r in rendered do
		local velocity = r.root.AssemblyLinearVelocity
		local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED
		for _, e in r.movers do
			e.Enabled = moving
		end
	end
end)
