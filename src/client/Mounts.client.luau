--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.Mounts
-- Client half of pet mounts (server: MountService, rules: MountConfig):
--   * Feed Star / Ride prompts on your own hatched pen pets (local prompts, so only you see them),
--     the "Apply Star?" confirmation and a "MOUNT" badge on rideable pets.
--   * Every rider's mount: the pet's animated rig drawn under the character, sized by MountConfig,
--     walking at the rider's speed. Your own client measures the seat and plays the riding pose.
--   * "Your mount" HUD with [F] Dismount.
--   * Star Drop stars: only yours shows (with a beacon); hold to catch it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)
local MountConfig = require(Shared.MountConfig)
local PetRig = require(Shared.PetRig)
local PetCatalog = require(Shared.PetCatalog)
local EggScale = require(Shared.EggScale)
local Economy = require(Shared.EconomyConfig)
local Art = require(Shared.ShopArt)
local PopupLayout = require(Shared.PopupLayout)

local player = Players.LocalPlayer
local actionRemote = GameUI.remote("MountAction")
local PATTERN = "rbxassetid://113404314197204"
local INK = Color3.fromRGB(14, 14, 20)
local YELLOW = MountConfig.StarColor

local mountFolder = Instance.new("Folder")
mountFolder.Name = "LocalMounts"
mountFolder.Parent = Workspace

-- GUI helpers ---------------------------------------------------------------------------------------

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function stroke(o: Instance, thickness: number?, color: Color3?)
	return new("UIStroke", o, {
		Thickness = thickness or 3,
		Color = color or INK,
		ApplyStrokeMode = if o:IsA("TextLabel") or o:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	})
end

local function corner(o: Instance, r: number?)
	new("UICorner", o, { CornerRadius = UDim.new(0, r or 12) })
end

local function text(parent: Instance, value: string, size: number, props: { [string]: any }?): TextLabel
	local label = new("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansExtraBold,
		Text = value,
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
	})
	stroke(label, 2.5)
	for k, v in props or {} do
		(label :: any)[k] = v
	end
	return label
end

local function button(parent: Instance, color: Color3, label: string, size: number, props: { [string]: any }): TextButton
	local b = new("TextButton", parent, { BackgroundColor3 = color, Text = "", AutoButtonColor = true, BorderSizePixel = 0 })
	corner(b, 12)
	stroke(b, 3)
	new("UIGradient", b, {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Rotation = 90,
	})
	text(b, label, size, { Name = "Label", Size = UDim2.fromScale(1, 1) })
	for k, v in props do
		(b :: any)[k] = v
	end
	return b
end

local function petName(model: Instance): string
	local egg = model:GetAttribute("EggName")
	local entry = if typeof(egg) == "string" then PetCatalog.get(egg) else nil
	local name = if entry then entry.DisplayName elseif typeof(egg) == "string" then (string.gsub(egg, " Egg$", "")) else "Pet"
	local mutation = model:GetAttribute("Mutation")
	return if typeof(mutation) == "string" and mutation ~= "" then mutation .. " " .. name else name
end

local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "MountGui",
	ResetOnSpawn = false,
	DisplayOrder = PopupLayout.DisplayOrder,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})

-- Apply Star? confirmation ------------------------------------------------------------------------

local CONFIRM_W, CONFIRM_H = 420, 350
local confirm = new("Frame", gui, {
	Name = "ApplyStar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIRM_W, CONFIRM_H),
	BackgroundColor3 = Color3.fromRGB(46, 30, 82),
	BorderSizePixel = 0,
	Visible = false,
})
corner(confirm, 18)
stroke(confirm, 5)
new("ImageLabel", confirm, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = PATTERN,
	ImageTransparency = 0.5,
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(48, 48),
})
local confirmScale = new("UIScale", confirm, { Scale = 1 })
local confirmHeader = new("Frame", confirm, {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
})
corner(confirmHeader, 18)
stroke(confirmHeader, 4)
new("UIGradient", confirmHeader, {
	Color = ColorSequence.new(Color3.fromRGB(255, 226, 90), Color3.fromRGB(255, 160, 30)),
	Rotation = 90,
})
text(confirmHeader, "Apply Star?", 36, { Size = UDim2.fromScale(1, 1) })
new("ImageLabel", confirm, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(86, 86),
	BackgroundTransparency = 1,
	Image = Art.Star,
})
local confirmPet = text(confirm, "", 30, { Position = UDim2.fromOffset(16, 158), Size = UDim2.new(1, -32, 0, 36), TextScaled = true })
local confirmRate = text(confirm, "", 24, {
	Position = UDim2.fromOffset(16, 192),
	Size = UDim2.new(1, -32, 0, 28),
	TextColor3 = Color3.fromRGB(110, 235, 90),
})
-- Steal an Egg's star rules: single use, a permanent buff for this pet only, no undo
text(confirm, "Uses 1 star for good. This pet stays a mount\nas long as you keep it. Can't be undone!", 16, {
	Position = UDim2.fromOffset(20, 220),
	Size = UDim2.new(1, -40, 0, 36),
	TextColor3 = Color3.fromRGB(230, 220, 255),
})
local confirmTip = text(confirm, "", 14, {
	Position = UDim2.fromOffset(20, 252),
	Size = UDim2.new(1, -40, 0, 16),
	TextColor3 = Color3.fromRGB(255, 214, 90),
})
local feedButton = button(confirm, Color3.fromRGB(70, 214, 60), "Feed Star", 28, {
	Name = "Feed",
	Position = UDim2.new(0, 20, 1, -74),
	Size = UDim2.new(0.5, -28, 0, 56),
})
local cancelButton = button(confirm, Color3.fromRGB(240, 44, 44), "Cancel", 28, {
	Name = "Cancel",
	Position = UDim2.new(0.5, 8, 1, -74),
	Size = UDim2.new(0.5, -28, 0, 56),
})
local confirmTarget: Model? = nil

local function closeConfirm()
	confirm.Visible = false
	confirmTarget = nil
end

local function openConfirm(model: Model)
	confirmTarget = model
	local rarity = model:GetAttribute("Rarity")
	confirmPet.Text = if typeof(rarity) == "string" then rarity .. " " .. petName(model) else petName(model)
	local topTier = rarity == "Secret" or rarity == "Eternal" or rarity == "Divine"
	confirmTip.Text = if topTier then "" else "Tip: save stars for Secret, Eternal and Divine pets"
	confirmPet.TextColor3 = if typeof(rarity) == "string" then EggScale.rarityColor(rarity) else Color3.new(1, 1, 1)
	local income = model:GetAttribute("Income")
	confirmRate.Text = if typeof(income) == "number" then Economy.formatRate(income) else ""
	confirm.Visible = true
	confirmScale.Scale *= 0.85
	TweenService:Create(confirmScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = confirmScale.Scale / 0.85 }):Play()
end

feedButton.Activated:Connect(function()
	local target = confirmTarget
	closeConfirm()
	if target and target.Parent then
		actionRemote:FireServer("feed", target)
	end
end)
cancelButton.Activated:Connect(closeConfirm)

-- Riding HUD ------------------------------------------------------------------------------------------

local hud = new("Frame", gui, {
	Name = "MountHud",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -60),
	Size = UDim2.fromOffset(300, 116),
	BackgroundColor3 = Color3.fromRGB(46, 30, 82),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Visible = false,
})
corner(hud, 16)
stroke(hud, 4)
local hudScale = new("UIScale", hud, { Scale = 1 })
new("ImageLabel", hud, {
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
	Image = Art.Star,
})
text(hud, "Your mount", 18, {
	Position = UDim2.fromOffset(60, 6),
	Size = UDim2.new(1, -70, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = YELLOW,
})
local hudName = text(hud, "", 26, {
	Position = UDim2.fromOffset(60, 24),
	Size = UDim2.new(1, -70, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = true,
})
local dismountButton = button(hud, Color3.fromRGB(240, 70, 60), "[F] Dismount", 24, {
	Name = "Dismount",
	Position = UDim2.new(0, 10, 1, -54),
	Size = UDim2.new(1, -20, 0, 44),
})
dismountButton.Activated:Connect(function()
	actionRemote:FireServer("dismount")
end)

local function fit()
	local area = gui.AbsoluteSize
	if area.X < 1 then
		return
	end
	PopupLayout.fit(gui, confirm, confirmScale, Vector2.new(CONFIRM_W, CONFIRM_H), 1.15)
	hudScale.Scale = math.clamp(area.Y / 720, 0.6, 1.1)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	;(dismountButton:FindFirstChild("Label") :: TextLabel).Text = if touch then "Dismount" else "[F] Dismount"
	-- bottom right above the night timer; phones: top right, clear of the jump button
	hud.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
	hud.Position = if touch then UDim2.new(1, -16, 0, 70) else UDim2.new(1, -16, 1, -60)
end
PopupLayout.watch(gui, fit)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F and player:GetAttribute("Riding") then
		actionRemote:FireServer("dismount")
	elseif input.KeyCode == Enum.KeyCode.Escape and confirm.Visible then
		closeConfirm()
	end
end)

-- Pen prompts -----------------------------------------------------------------------------------------

local function holdingStar(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild(MountConfig.StarTool) ~= nil
end

-- Pen parts stream out and back in (StreamingEnabled), so each new prompt is wired as it is made.
local function prompt(root: BasePart, name: string, action: string, objectText: string, range: number, onTrigger: () -> ()): ProximityPrompt
	local p = root:FindFirstChild(name)
	if p and p:IsA("ProximityPrompt") then
		return p
	end
	local made = new("ProximityPrompt", root, {
		Name = name,
		ActionText = action,
		ObjectText = objectText,
		HoldDuration = 0,
		MaxActivationDistance = range,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
		Enabled = false,
	}) :: ProximityPrompt
	made.Triggered:Connect(onTrigger)
	return made
end

local function badge(model: Model, root: BasePart)
	local tag = root:FindFirstChild("PetTag")
	if not (tag and tag:IsA("BillboardGui")) then
		return
	end
	local rideable = model:GetAttribute("Rideable") == true
	local mark = tag:FindFirstChild("MountBadge")
	if rideable and not mark then
		local label = text(tag, "★ MOUNT", 18, {
			Name = "MountBadge",
			Position = UDim2.new(0, 0, 0, -22),
			Size = UDim2.new(1, 0, 0, 22),
			TextColor3 = YELLOW,
			TextScaled = true,
		})
		label.ZIndex = 2
	elseif not rideable and mark then
		mark:Destroy()
	end
	-- out riding: the pen shows nothing
	tag.Enabled = model:GetAttribute("RiddenBy") == nil
end

local function wire(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local size = model:GetAttribute("StaticSize")
	local range = math.clamp((if typeof(size) == "Vector3" then math.max(size.X, size.Z) * 0.5 else 2) + 8, 10, 24)
	local name = petName(model)
	local feed = prompt(root, "FeedStarPrompt", "Feed Star", name, range, function()
		openConfirm(model)
	end)
	local ride = prompt(root, "RidePrompt", "Ride", name, range, function()
		actionRemote:FireServer("ride", model)
	end)
	local mine = model:GetAttribute("OwnerUserId") == player.UserId
	local hatched = model:GetAttribute("Hatching") ~= true
	local rideable = model:GetAttribute("Rideable") == true
	local star = holdingStar()
	feed.Enabled = mine and hatched and not rideable and star
	ride.Enabled = mine and hatched and rideable and not star and not player:GetAttribute("Riding")
	badge(model, root)
end

task.spawn(function()
	while true do
		local folder = Workspace:FindFirstChild("BabyBeastsMap")
		folder = folder and folder:FindFirstChild("TankBeasts", true)
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") and model.Name == "TankBeast" and model:GetAttribute("OwnerUserId") ~= nil then
					wire(model)
				end
			end
		end
		task.wait(0.25)
	end
end)

-- a pet just ate a star: burst of sparkles
local function starBurst(at: BasePart)
	local emitter = new("ParticleEmitter", at, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(YELLOW, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.7, 1.3),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rate = 0,
	}) :: ParticleEmitter
	emitter:Emit(70)
	task.delay(2, function()
		emitter:Destroy()
	end)
end

actionRemote.OnClientEvent:Connect(function(what: any, model: any)
	if what == "fed" and typeof(model) == "Instance" and model:IsA("Model") and model.PrimaryPart then
		starBurst(model.PrimaryPart)
	end
end)

-- Mounts under riders ---------------------------------------------------------------------------------

type Mount = {
	character: Model,
	egg: string,
	box: Vector3,
	rig: PetRig.Rig?,
	walking: boolean?,
	track: AnimationTrack?,
	seated: boolean?,
	pose: AnimationTrack?,
}
local mounts: { [Model]: Mount } = {}

local function groundOf(character: Model): (BasePart?, Humanoid?, number)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		return nil, nil, 0
	end
	return hrp, hum, hrp.Position.Y - hrp.Size.Y * 0.5 - hum.HipHeight
end

local function mountCFrame(m: Mount): CFrame?
	local hrp, _, ground = groundOf(m.character)
	if not hrp then
		return nil
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local at = Vector3.new(hrp.Position.X, ground + m.box.Y * 0.5, hrp.Position.Z)
	return CFrame.lookAt(at, at + flat.Unit)
end

-- Height of the mount's back under the rider (studs above the ground), by a ray down onto the rig.
local function measureSeat(m: Mount): number
	local rig = m.rig
	local hrp, _, ground = groundOf(m.character)
	if not (rig and hrp) then
		return m.box.Y * 0.6
	end
	local parts = {}
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true
			table.insert(parts, d)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { rig.model }
	local best: number? = nil
	-- rays along the middle of the back; the lowest hit is the back (heads, ears and tails stick up)
	for _, dz in { -0.15, -0.07, 0, 0.07, 0.15 } do
		local origin = (hrp.CFrame * CFrame.new(0, 0, dz * m.box.Z)).Position
		local hit = Workspace:Raycast(Vector3.new(origin.X, ground + m.box.Y * 2 + 5, origin.Z), Vector3.new(0, -(m.box.Y * 2 + 10), 0), params)
		if hit then
			local h = hit.Position.Y - ground
			best = if best then math.min(best, h) else h
		end
	end
	for _, p in parts do
		p.CanQuery = false
	end
	return best or m.box.Y * 0.6
end

local function stopMount(character: Model)
	local m = mounts[character]
	if not m then
		return
	end
	mounts[character] = nil
	if m.rig then
		m.rig:destroy()
	end
	if m.pose then
		m.pose:Stop(0.2)
	end
end

local function startMount(character: Model)
	stopMount(character)
	local egg = character:GetAttribute("MountPet")
	local size = character:GetAttribute("MountSize")
	if typeof(egg) ~= "string" or typeof(size) ~= "Vector3" then
		return
	end
	local m: Mount = { character = character, egg = egg, box = MountConfig.box(size, character:GetAttribute("MountScale") :: number?) }
	mounts[character] = m
	local isMine = character == player.Character
	if isMine then
		local hum = character:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator and MountConfig.RiderAnimation ~= 0 then
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. MountConfig.RiderAnimation
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = true
				track:Play(0.25)
				m.pose = track
			end
		end
	end
	task.spawn(function()
		local rig = PetRig.build(egg, m.box)
		if mounts[character] ~= m then
			if rig then
				rig:destroy()
			end
			return
		end
		if not rig then
			warn("[Mounts] no rig for " .. egg)
			return
		end
		m.rig = rig
		rig.model.Name = "Mount_" .. character.Name
		rig.model.Parent = mountFolder
		local cf = mountCFrame(m)
		if cf then
			rig:place(cf)
		end
		rig:play("Idle", 0)
		if isMine then
			task.wait() -- let the rig settle in its Idle pose before measuring
			if mounts[character] ~= m then
				return
			end
			local cf2 = mountCFrame(m)
			if cf2 then
				rig:place(cf2)
			end
			local seat = math.clamp(measureSeat(m), MountConfig.SeatMin, MountConfig.SeatMax)
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.HipHeight = seat
			end
			m.seated = true
			actionRemote:FireServer("seat", seat)
		end
	end)
end

local function hookCharacter(character: Model)
	local function refresh()
		if character:GetAttribute("MountPet") ~= nil then
			startMount(character)
		else
			stopMount(character)
		end
	end
	character:GetAttributeChangedSignal("MountPet"):Connect(refresh)
	character.Destroying:Connect(function()
		stopMount(character)
	end)
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			stopMount(character)
		end
	end)
	refresh()
end

local function hookPlayer(other: Player)
	other.CharacterAdded:Connect(hookCharacter)
	if other.Character then
		hookCharacter(other.Character)
	end
end
for _, other in Players:GetPlayers() do
	hookPlayer(other)
end
Players.PlayerAdded:Connect(hookPlayer)

RunService.PreRender:Connect(function()
	for character, m in mounts do
		local rig = m.rig
		if not rig then
			continue
		end
		local cf = mountCFrame(m)
		if not cf then
			continue
		end
		rig:place(cf)
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local v = if hrp then hrp.AssemblyLinearVelocity else Vector3.zero
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local walking = speed > 1.5
		if walking ~= m.walking then
			m.walking = walking
			m.track = rig:play(if walking then "Walk" else "Idle", 0.2)
		end
		if walking and m.track then
			m.track:AdjustSpeed(math.clamp(speed / MountConfig.WalkRateDivisor, MountConfig.WalkRateMin, MountConfig.WalkRateMax))
		end
	end
	-- HUD
	local character = player.Character
	local riding = player:GetAttribute("Riding") == true and character ~= nil and character:GetAttribute("MountPet") ~= nil
	if riding ~= hud.Visible then
		hud.Visible = riding
	end
	if riding and character then
		local name = character:GetAttribute("MountName")
		hudName.Text = if typeof(name) == "string" then name else ""
	end
end)

-- Star Drop --------------------------------------------------------------------------------------------

local function hideDrop(holder: Instance)
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
			d:GetPropertyChangedSignal("Enabled"):Connect(function()
				d.Enabled = false
			end)
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			(d :: any).Enabled = false
		end
	end
end

local function showDrop(holder: Model)
	local star = holder:WaitForChild("Star", 5) :: BasePart?
	if not star then
		return
	end
	local beacon = new("Part", mountFolder, {
		Name = "StarBeacon",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = YELLOW,
		Transparency = 0.6,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(120, 1.2, 1.2),
	}) :: Part
	local tag = new("BillboardGui", star, {
		Name = "YourStar",
		Size = UDim2.fromOffset(150, 52),
		StudsOffset = Vector3.new(0, 3.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 2000,
	})
	text(tag, "Your Star!", 24, { Size = UDim2.new(1, 0, 0.55, 0), TextColor3 = YELLOW, TextScaled = true })
	local dist = text(tag, "", 18, { Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.45, 0), TextScaled = true })
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		if not holder.Parent or not star.Parent then
			conn:Disconnect()
			beacon:Destroy()
			return
		end
		local landed = holder:GetAttribute("Landed") == true
		local base = star.Position
		beacon.Transparency = if landed then 0.55 else 1
		beacon.CFrame = CFrame.new(base + Vector3.new(0, 57, 0)) * CFrame.Angles(0, 0, math.rad(90))
		if landed then
			local t = os.clock() - t0
			star.CFrame = CFrame.new(star.Position) * CFrame.Angles(0, t * 2, 0)
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		dist.Text = if hrp then string.format("%d studs", math.floor((hrp.Position - base).Magnitude)) else ""
	end)
end

local function watchDrop(holder: Instance)
	if not holder:IsA("Model") then
		return
	end
	if holder:GetAttribute("ForUserId") == player.UserId then
		task.spawn(showDrop, holder)
	else
		hideDrop(holder)
		holder.DescendantAdded:Connect(function()
			hideDrop(holder)
		end)
	end
end

task.spawn(function()
	local drops = Workspace:WaitForChild("StarDrops", 60)
	if not drops then
		return
	end
	for _, holder in drops:GetChildren() do
		watchDrop(holder)
	end
	drops.ChildAdded:Connect(watchDrop)
end)
