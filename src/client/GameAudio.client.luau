--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.GameAudio
-- Music and sound effects. Ids and rules live in shared AudioConfig.
--   Music: lobby playlist. The Divine/Eternal, Secret and Mythic tracks take over while such an
--          egg is announced, near you or being carried, and the lobby fades out under them.
--          Epic / Legendary eggs get a sting on reset spawns and on pickups.
--   SFX:   steal whoosh (tool "StolenAt"), pen "secured" chime (pet "PlacedAt"), hatch crack +
--          reveal (pet "HatchedAt"), wind rush while running fast, and footsteps paced to each
--          character's speed (Roblox's default "Running" sound).
--   Settings tile above the pen buttons: Music / Sounds on-off (saved by AudioSettings.server).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local GameUI = require(Shared.GameUI)
local PopupLayout = require(Shared.PopupLayout)
local Art = require(Shared.UIArt)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local map = Workspace:WaitForChild("BabyBeastsMap")
local settingsRemote = GameUI.remote("AudioSettings")
local noticeRemote = GameUI.remote("NightNotice")

type Cue = AudioConfig.Cue

-- Sound groups (the settings tile mutes them) -------------------------------------------------------

local function group(name: string): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	return g
end
local musicGroup = group("GameMusic")
local sfxGroup = group("GameSfx")

local function isOn(key: string): boolean
	return player:GetAttribute(key) ~= false
end

local function applySettings()
	musicGroup.Volume = if isOn("MusicOn") then 1 else 0
	sfxGroup.Volume = if isOn("SfxOn") then 1 else 0
end
applySettings()
player:GetAttributeChangedSignal("MusicOn"):Connect(applySettings)
player:GetAttributeChangedSignal("SfxOn"):Connect(applySettings)

-- Helpers ----------------------------------------------------------------------------------------------

local function newSound(cue: Cue, parent: Instance, soundGroup: SoundGroup): Sound
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. cue.id
	s.Volume = cue.volume
	s.SoundGroup = soundGroup
	s.Parent = parent
	return s
end

-- One-shot: flat when `at` is nil, else 3D from that part / attachment.
local function oneShot(cue: Cue, at: Instance?, soundGroup: SoundGroup?): Sound
	local s = newSound(cue, at or SoundService, soundGroup or sfxGroup)
	if at then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = AudioConfig.HearRange
	end
	s.Ended:Connect(function()
		s:Destroy()
	end)
	Debris:AddItem(s, 30)
	s:Play()
	return s
end

-- 3D one-shot from a point in the world.
local function oneShotAt(cue: Cue, position: Vector3, soundGroup: SoundGroup?): Sound
	local anchor = Instance.new("Attachment")
	anchor.Name = "GameAudioAnchor"
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	Debris:AddItem(anchor, 30)
	return oneShot(cue, anchor, soundGroup)
end

local function rootOf(who: Player): BasePart?
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function fresh(stamp: any): boolean
	return typeof(stamp) == "number" and Workspace:GetServerTimeNow() - stamp < 3
end

-- Music ------------------------------------------------------------------------------------------------

local playlist = table.clone(AudioConfig.Lobby)
local shuffle = Random.new()
for i = #playlist, 2, -1 do
	local j = shuffle:NextInteger(1, i)
	playlist[i], playlist[j] = playlist[j], playlist[i]
end
local lobbyIndex = 1
local lobby = newSound({ id = playlist[1], volume = 0 }, SoundService, musicGroup)
lobby.Name = "LobbyMusic"
lobby.Ended:Connect(function()
	lobbyIndex = lobbyIndex % #playlist + 1
	lobby.SoundId = "rbxassetid://" .. playlist[lobbyIndex]
	lobby.TimePosition = 0
	lobby:Play()
end)

local tracks: { [string]: Sound } = {}
for name, cue in AudioConfig.Tracks do
	local s = newSound(cue, SoundService, musicGroup)
	s.Name = name .. "Music"
	s.Looped = true
	s.Volume = 0
	tracks[name] = s
end

local duckUntil = 0

-- Short sting over the music: flat when `at` is nil, else 3D (another player's pickup).
local function jingle(rarity: string, at: Instance?)
	local cue = AudioConfig.Jingles[rarity]
	if not cue then
		return
	end
	local s = oneShot(cue, at, musicGroup)
	if not at then
		duckUntil = os.clock() + (if s.TimeLength > 0 then s.TimeLength else 8)
	end
end

local stateFolder = map:WaitForChild("CaveBubbleState")

-- The track an egg (nest record or carried tool) asks for, if any.
local function trackFor(inst: Instance): string?
	local rarity = inst:GetAttribute("EggRarity")
	local name = if typeof(rarity) == "string" then AudioConfig.TrackOf[rarity] else nil
	if name and AudioConfig.NeedsAnnounce[name] and inst:GetAttribute("Announced") ~= true then
		return nil
	end
	return name
end

local function carriedTools(who: Player): { Instance }
	local list = {}
	for _, holder in { who.Character, who:FindFirstChildOfClass("Backpack") } do
		if holder then
			for _, tool in holder:GetChildren() do
				if tool:IsA("Tool") and tool.Name == "BabyBeast" and tool:GetAttribute("StolenAt") ~= nil then
					table.insert(list, tool)
				end
			end
		end
	end
	return list
end

local function wantedTrack(): string?
	local best: number? = nil
	local function offer(name: string)
		local rank = table.find(AudioConfig.Priority, name)
		if rank and (best == nil or rank < best) then
			best = rank
		end
	end
	local now = Workspace:GetServerTimeNow()
	local root = rootOf(player)
	for _, rec in stateFolder:GetChildren() do
		local name = trackFor(rec)
		if name then
			local born = rec:GetAttribute("Born")
			local origin = rec:GetAttribute("Origin")
			if typeof(born) == "number" and now - born < (AudioConfig.SpawnWindow[name] or 0) then
				offer(name)
			elseif root and typeof(origin) == "Vector3" and (root.Position - origin).Magnitude < AudioConfig.ProximityRadius then
				offer(name)
			end
		end
	end
	for _, who in Players:GetPlayers() do
		for _, tool in carriedTools(who) do
			local name = trackFor(tool)
			if name then
				offer(name)
			end
		end
	end
	return if best then AudioConfig.Priority[best] else nil
end

local current: string? = nil
local lastCheck = 0

-- Move a music channel's volume toward its target; silent channels stop (tracks) or pause (lobby).
local function fade(s: Sound, target: number, full: number, dt: number, restart: boolean)
	local step = math.max(full, 0.05) / AudioConfig.Fade * dt
	if target > 0 and not s.IsPlaying then
		if restart then
			s.TimePosition = 0
		end
		if s.IsPaused then
			s:Resume()
		else
			s:Play()
		end
	end
	if s.Volume < target then
		s.Volume = math.min(target, s.Volume + step)
	elseif s.Volume > target then
		s.Volume = math.max(target, s.Volume - step)
	end
	if target == 0 and s.Volume <= 0 and s.IsPlaying then
		if restart then
			s:Stop()
		else
			s:Pause()
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now - lastCheck > 0.25 then
		lastCheck = now
		current = wantedTrack()
	end
	local musicOn = isOn("MusicOn")
	for name, s in tracks do
		local cue = AudioConfig.Tracks[name]
		fade(s, if musicOn and current == name then cue.volume else 0, cue.volume, dt, true)
	end
	local lobbyTarget = if musicOn and current == nil then AudioConfig.LobbyVolume else 0
	if now < duckUntil then
		lobbyTarget *= AudioConfig.JingleDuck
	end
	fade(lobby, lobbyTarget, AudioConfig.LobbyVolume, dt, false)
end)

-- Reset / announcement: an Epic or Legendary sting for the fresh eggs (unless a big track is taking over).
local function bestJingle(rarities: { any }): string?
	local best: string? = nil
	for _, rarity in rarities do
		if rarity == "Legendary" then
			return rarity
		elseif rarity == "Epic" then
			best = rarity
		end
	end
	return best
end

noticeRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local rarities = {}
	if typeof(payload.rares) == "table" then
		for _, rare in payload.rares do
			if typeof(rare) == "table" then
				table.insert(rarities, rare.rarity)
			end
		end
	end
	if payload.reset ~= true and #rarities == 0 then
		return
	end
	task.delay(1.5, function()
		if wantedTrack() ~= nil then
			return
		end
		if payload.reset == true then
			local now = Workspace:GetServerTimeNow()
			for _, rec in stateFolder:GetChildren() do
				local born = rec:GetAttribute("Born")
				if typeof(born) == "number" and now - born < 10 then
					table.insert(rarities, rec:GetAttribute("EggRarity"))
				end
			end
		end
		local best = bestJingle(rarities)
		if best then
			jingle(best)
		end
	end)
end)

-- Steal / pickup -----------------------------------------------------------------------------------

local heard: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function onPickup(tool: Instance, owner: Player)
	if heard[tool] or not fresh(tool:GetAttribute("StolenAt")) then
		return
	end
	heard[tool] = true
	local mine = owner == player
	local root = rootOf(owner)
	if not mine and not root then
		return
	end
	oneShot(AudioConfig.Sfx.Steal, if mine then nil else root)
	local rarity = tool:GetAttribute("EggRarity")
	if typeof(rarity) == "string" and AudioConfig.Jingles[rarity] then
		jingle(rarity, if mine then nil else root)
	end
end

local function watchTool(tool: Instance, owner: Player)
	if not (tool:IsA("Tool") and tool.Name == "BabyBeast") or heard[tool] then
		return
	end
	if tool:GetAttribute("StolenAt") ~= nil then
		onPickup(tool, owner)
		return
	end
	-- the stamp is set right after the tool is made, so it can land a moment later
	local conn: RBXScriptConnection
	conn = tool:GetAttributeChangedSignal("StolenAt"):Connect(function()
		conn:Disconnect()
		onPickup(tool, owner)
	end)
	task.delay(3, function()
		conn:Disconnect()
	end)
end

local function watchHolder(holder: Instance, owner: Player)
	for _, child in holder:GetChildren() do
		watchTool(child, owner)
	end
	holder.ChildAdded:Connect(function(child)
		watchTool(child, owner)
	end)
end

local function watchPlayer(who: Player)
	if who.Character then
		watchHolder(who.Character, who)
	end
	who.CharacterAdded:Connect(function(character)
		watchHolder(character, who)
	end)
	local backpack = who:FindFirstChildOfClass("Backpack")
	if backpack then
		watchHolder(backpack, who)
	end
	who.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchHolder(child, who)
		end
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, who in Players:GetPlayers() do
	watchPlayer(who)
end

-- Pen: placed ("secured") and hatched ---------------------------------------------------------------

local placed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hatched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function onPlaced(model: Model)
	if placed[model] or not fresh(model:GetAttribute("PlacedAt")) then
		return
	end
	placed[model] = true
	oneShotAt(AudioConfig.Sfx.Deposit, model:GetPivot().Position)
end

local function onHatched(model: Model)
	if hatched[model] or not fresh(model:GetAttribute("HatchedAt")) then
		return
	end
	hatched[model] = true
	local mine = model:GetAttribute("OwnerUserId") == player.UserId
	local position = model:GetPivot().Position
	local function play(cue: Cue)
		if mine then
			oneShot(cue)
		else
			oneShotAt(cue, position)
		end
	end
	play(AudioConfig.Sfx.Crack)
	task.delay(0.25, function()
		play(AudioConfig.Sfx.Reveal)
		local rarity = model:GetAttribute("Rarity")
		if typeof(rarity) == "string" and AudioConfig.RareHatch[rarity] then
			play(AudioConfig.Sfx.RareReveal)
		end
	end)
end

local function watchPet(child: Instance)
	if not child:IsA("Model") then
		return
	end
	local model = child :: Model
	model:GetAttributeChangedSignal("PlacedAt"):Connect(function()
		onPlaced(model)
	end)
	model:GetAttributeChangedSignal("HatchedAt"):Connect(function()
		onHatched(model)
	end)
	onPlaced(model)
	onHatched(model)
end

task.spawn(function()
	local pens = map:WaitForChild("TankBeasts")
	for _, child in pens:GetChildren() do
		watchPet(child)
	end
	pens.ChildAdded:Connect(watchPet)
end)

-- Wind rush and footsteps -------------------------------------------------------------------------

local wind = newSound(AudioConfig.Sfx.Wind, SoundService, sfxGroup)
wind.Name = "SpeedWind"
wind.Looped = true
wind.Volume = 0

local function groundSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return Vector2.new(v.X, v.Z).Magnitude
end

local stepClock = 0
RunService.Heartbeat:Connect(function(dt)
	local root = rootOf(player)
	local speed = if root then groundSpeed(root) else 0
	local alpha = math.clamp((speed - AudioConfig.WindFrom) / (AudioConfig.WindFull - AudioConfig.WindFrom), 0, 1)
	local target = AudioConfig.Sfx.Wind.volume * alpha
	-- quick attack, quicker release: it stops almost as soon as you do
	local rate = if target > wind.Volume then 1.5 else 3
	wind.Volume += math.clamp(target - wind.Volume, -rate * dt, rate * dt)
	wind.PlaybackSpeed = 0.9 + 0.35 * alpha
	if wind.Volume > 0.005 then
		if not wind.IsPlaying then
			wind:Play()
		end
	elseif target == 0 and wind.IsPlaying then
		wind:Stop()
	end

	stepClock += dt
	if stepClock < 0.1 then
		return
	end
	stepClock = 0
	for _, who in Players:GetPlayers() do
		local body = rootOf(who)
		if body then
			for _, s in body:GetChildren() do
				if s:IsA("Sound") then
					-- the default character sounds follow the Sounds setting
					s.SoundGroup = sfxGroup
					if s.Name == "Running" then
						local pace = math.max(groundSpeed(body), 16) / 16
						s.PlaybackSpeed = math.min(AudioConfig.StepBaseRate * (1 + (pace - 1) * 0.15), AudioConfig.StepMaxRate)
						s.Volume = AudioConfig.StepVolume
					end
				end
			end
		end
	end
end)

-- Settings tile + panel ---------------------------------------------------------------------------

local INK = Color3.fromRGB(14, 14, 20)
local BODY = Color3.fromRGB(43, 43, 53)
local ON = Color3.fromRGB(92, 200, 70)
local OFF = Color3.fromRGB(222, 70, 60)
local PATTERN = "rbxassetid://113404314197204" -- stud texture (PenPanels / ShopGui)
local EDGE = 3
local SLOT = -3 -- above the pen tiles (PenPanels: egg -1, paw 1); below them sits the day clock

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function dress(o: GuiObject, color: Color3, radius: number, thickness: number)
	new("UICorner", o, { CornerRadius = UDim.new(0, radius) })
	new("UIStroke", o, {
		Color = INK,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	new("ImageLabel", o, {
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = PATTERN,
		ImageTransparency = 0.8,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(48, 48),
		ZIndex = o.ZIndex,
	})
	new("UIGradient", o, { Rotation = 90, Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.22)) })
end

local function label(parent: Instance, value: string, size: number, props: { [string]: any }?): TextLabel
	local l = new("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansExtraBold,
		Text = value,
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	})
	new("UIStroke", l, { Color = INK, Thickness = math.max(1.5, size / 12) })
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

local hud = new("ScreenGui", playerGui, {
	Name = "SoundHud",
	ResetOnSpawn = false,
	DisplayOrder = 12,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local tile = new("TextButton", hud, {
	Name = "SettingsButton",
	Text = "",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0.5),
})
dress(tile, Color3.fromRGB(110, 120, 150), 4, 3)
new("ImageLabel", tile, {
	Name = "Art",
	BackgroundTransparency = 1,
	Image = (Art :: any).Settings or "",
	ScaleType = Enum.ScaleType.Fit,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.72),
	ZIndex = 2,
})

local panel = new("Frame", hud, {
	Name = "SoundPanel",
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(200, 132),
	BackgroundColor3 = BODY,
	BorderSizePixel = 0,
	Visible = false,
})
new("UICorner", panel, { CornerRadius = UDim.new(0, 8) })
new("UIStroke", panel, { Color = INK, Thickness = 3 })
local panelScale = new("UIScale", panel, {})
label(panel, "Sound", 24, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 4) })

local function toggle(key: string, caption: string, y: number)
	local b = new("TextButton", panel, {
		Name = key,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, 38),
	})
	local text = label(b, "", 20, { ZIndex = 2 })
	local function refresh()
		for _, child in b:GetChildren() do
			if not child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local on = isOn(key)
		dress(b, if on then ON else OFF, 6, 2.5)
		text.Text = caption .. (if on then ": ON" else ": OFF")
	end
	refresh()
	player:GetAttributeChangedSignal(key):Connect(refresh)
	b.Activated:Connect(function()
		local value = not isOn(key)
		player:SetAttribute(key, value) -- instant here; the server saves it and echoes it back
		settingsRemote:FireServer(key, value)
	end)
end
toggle("MusicOn", "Music", 40)
toggle("SfxOn", "Sounds", 84)

local function layout()
	local side = PopupLayout.penButtonSide()
	local y = SLOT * (side * 0.5 + 6)
	tile.Size = UDim2.fromOffset(side, side)
	tile.Position = UDim2.new(1, -EDGE, 0.5, y)
	panelScale.Scale = side / 66
	panel.Position = UDim2.new(1, -(EDGE + side + 10), 0.5, y)
end
layout()
PopupLayout.watch(hud, layout)

tile.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
