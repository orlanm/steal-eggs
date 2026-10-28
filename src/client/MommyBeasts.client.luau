local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local Config = require(Shared:WaitForChild("MommyConfig"))
local Motion = require(Shared:WaitForChild("MommyMotion"))
local GameUI = require(Shared:WaitForChild("GameUI"))
local GuardConfig = require(Shared:WaitForChild("GuardConfig"))
if not Config.Enabled then return end
game.ReplicatedStorage:WaitForChild(GuardConfig.TemplateFolder, 10)
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local map = workspace:WaitForChild("BabyBeastsMap", 60)
local ok, template = pcall(function() return require(Shared:WaitForChild("MommyModel")).template() end)
if not map or not ok or not template then warn("[MommyBeasts] Model load failed: " .. tostring(template)); return end
local leviathanTemplate = nil
local leviOk, leviResult = pcall(function()
	return require(Shared:WaitForChild("MommyLeviathanModel")).template()
end)
if leviOk then
	leviathanTemplate = leviResult
else
	warn("[MommyBeasts] Lava Leviathan load failed: " .. tostring(leviResult))
end
local turtleTemplate = nil
local turtleOk, turtleResult = pcall(function()
	return require(Shared:WaitForChild("MommyTurtleModel")).template()
end)
if turtleOk then
	turtleTemplate = turtleResult
else
	warn("[MommyBeasts] Neon Shell Leviathan load failed: " .. tostring(turtleResult))
end
local clips = require(Shared.MommyClips)
local leviathanClips = if Shared:FindFirstChild("MommyLeviathanClips") then require(Shared.MommyLeviathanClips) else clips
local turtleClips = if Shared:FindFirstChild("MommyTurtleClips") then require(Shared.MommyTurtleClips) else clips
local boneNames = {"Root", "Head", "Body", "Rear", "TailBase", "TailFan", "RearFin.L", "RearFin.R", "Jaw", "FrontFin.L", "FrontFin.R"}
local leviathanHabitats = {}
for _, name in Config.LeviathanHabitats or {} do
	leviathanHabitats[name] = true
end
local turtleHabitats = {}
for _, name in Config.TurtleHabitats or {} do
	turtleHabitats[name] = true
end
local old = workspace:FindFirstChild("LocalMommyBeasts")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "LocalMommyBeasts", workspace
local beasts = {}
local controlledCharacter, controls
local cameraMode = "Default" -- Default | Impact | Follow | Landed
local cameraToken = 0
local followThrowDir = Vector3.zAxis
local tumbleActive = false
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 20)
	if module then controls = require(module):GetControls(); if controlledCharacter then controls:Disable() end end
end)

local function flankSplash(part: BasePart, name: string, at: Vector3, outward: number, scale: number): { ParticleEmitter }
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	local tilt = if outward >= 0 then math.rad(-48) else math.rad(48)
	-- Throw up and outward so the spray clears the flank instead of hiding in the body.
	attachment.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(12), 0, tilt)
	attachment.Parent = part
	local emitters = {}
	local sheet = Instance.new("ParticleEmitter")
	sheet.Name = "Sheet"
	sheet.Texture = "rbxasset://textures/particles/smoke_main.dds"
	sheet.Color = ColorSequence.new(Color3.fromRGB(246, 252, 255), Color3.fromRGB(176, 220, 232))
	sheet.LightEmission = 0.18
	sheet.LightInfluence = 0.35
	sheet.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, scale * 0.7),
		NumberSequenceKeypoint.new(0.25, scale * 1.35),
		NumberSequenceKeypoint.new(1, scale * 2.1),
	})
	sheet.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.4, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})
	sheet.Lifetime = NumberRange.new(0.4, 0.75)
	sheet.Speed = NumberRange.new(scale * 2.4, scale * 4.2)
	sheet.SpreadAngle = Vector2.new(22, 16)
	sheet.Acceleration = Vector3.new(0, -scale * 7.5, 0)
	sheet.Drag = 1.6
	sheet.Rate = 36
	sheet.Rotation = NumberRange.new(-25, 25)
	sheet.RotSpeed = NumberRange.new(-35, 35)
	sheet.Enabled = false
	sheet.Parent = attachment
	table.insert(emitters, sheet)
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Drops"
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(186, 226, 232))
	drops.LightEmission = 0.35
	drops.LightInfluence = 0.2
	drops.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, scale * 0.16),
		NumberSequenceKeypoint.new(1, scale * 0.05),
	})
	drops.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	drops.Lifetime = NumberRange.new(0.28, 0.55)
	drops.Speed = NumberRange.new(scale * 2.8, scale * 4.8)
	drops.SpreadAngle = Vector2.new(34, 24)
	drops.Acceleration = Vector3.new(0, -scale * 11, 0)
	drops.Drag = 0.8
	drops.Rate = 18
	drops.Enabled = false
	drops.Parent = attachment
	table.insert(emitters, drops)
	return emitters
end

local function jailBars(den)
	local bars = {}
	local barsFolder = den:FindFirstChild("JailBars")
	if barsFolder then
		for _, part in barsFolder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(bars, { part = part, closed = part:GetAttribute("ClosedCFrame") or part.CFrame })
			end
		end
	end
	return bars
end

-- Floating "Z z z" over a sleeping guard (and "!" when it wakes).
local function sleepMarks(parent: BasePart, offset: Vector3, height: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "GuardSleepMarks"
	attachment.Position = offset
	attachment.Parent = parent
	local board = Instance.new("BillboardGui")
	board.Name = "GuardSleepGui"
	board.Size = UDim2.fromScale(height * 0.5, height * 0.6)
	board.LightInfluence = 0
	board.AlwaysOnTop = false
	board.MaxDistance = 260
	board.Adornee = attachment
	board.Parent = attachment
	local labels = {}
	for i = 1, 3 do
		local z = Instance.new("TextLabel")
		z.BackgroundTransparency = 1
		z.Font = Enum.Font.BuilderSansExtraBold
		z.Text = "Z"
		z.TextScaled = true
		z.TextColor3 = Color3.fromRGB(235, 245, 255)
		z.TextStrokeColor3 = Color3.fromRGB(40, 50, 90)
		z.TextStrokeTransparency = 0.2
		z.AnchorPoint = Vector2.new(0.5, 0.5)
		z.Size = UDim2.fromScale(0.28 + 0.08 * i, 0.22 + 0.06 * i)
		z.Parent = board
		labels[i] = z
	end
	local alert = Instance.new("TextLabel")
	alert.BackgroundTransparency = 1
	alert.Font = Enum.Font.BuilderSansExtraBold
	alert.Text = "!"
	alert.TextScaled = true
	alert.TextColor3 = Color3.fromRGB(255, 70, 60)
	alert.TextStrokeColor3 = Color3.fromRGB(60, 10, 10)
	alert.TextStrokeTransparency = 0
	alert.AnchorPoint = Vector2.new(0.5, 0.5)
	alert.Position = UDim2.fromScale(0.5, 0.55)
	alert.Size = UDim2.fromScale(0.7, 0.7)
	alert.Visible = false
	alert.Parent = board
	return { board = board, labels = labels, alert = alert }
end

local function loadTracks(animator: Animator, ids)
	local tracks = {}
	if not ids then return tracks end
	for name, id in ids do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			track.Looped = name ~= "Wake"
			track.Priority = if name == "Wake" then Enum.AnimationPriority.Action
				elseif name == "Run" then Enum.AnimationPriority.Movement
				else Enum.AnimationPriority.Idle
			tracks[name] = track
		else
			warn("[MommyBeasts] guard animation " .. name .. " failed: " .. tostring(track))
		end
	end
	return tracks
end

-- Zone guard from ReplicatedStorage.GuardTemplates (see GuardConfig). Returns nil to fall back to the old T-rex.
-- Upright pivot on the ground under the visible body, looking where the rig looks
-- (reference rigs face -Z of their root, pet rigs +Z).
-- Where the joints put each part (saved part positions can be stale: the joints snap them on the first step).
local function jointPose(model: Model, root: BasePart): { [BasePart]: CFrame }
	local links = {}
	for _, joint in model:GetDescendants() do
		if joint:IsA("JointInstance") and joint.Part0 and joint.Part1 then
			table.insert(links, { joint.Part0, joint.Part1, joint.C0 * joint.C1:Inverse() })
		elseif joint:IsA("WeldConstraint") and joint.Part0 and joint.Part1 then
			table.insert(links, { joint.Part0, joint.Part1, joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame) })
		end
	end
	local world = { [root] = root.CFrame }
	local changed = true
	while changed do
		changed = false
		for _, link in links do
			local a, b, offset = link[1], link[2], link[3]
			if world[a] and not world[b] then
				world[b], changed = world[a] * offset, true
			elseif world[b] and not world[a] then
				world[a], changed = world[b] * offset:Inverse(), true
			end
		end
	end
	return world
end

local function groundPivot(model: Model, root: BasePart, guard): CFrame
	local world = jointPose(model, root)
	local lo, minX, maxX, minZ, maxZ = math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			local half = part.Size / 2
			local cf = world[part] or part.CFrame
			for _, corner in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local p = cf:PointToWorldSpace(half * corner)
				lo, minX, maxX, minZ, maxZ = math.min(lo, p.Y), math.min(minX, p.X), math.max(maxX, p.X), math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
	end
	if lo == math.huge then
		return root.CFrame
	end
	local look = root.CFrame.LookVector * (guard.ForwardZ or -1) * -1
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	local ground = Vector3.new((minX + maxX) / 2, lo, (minZ + maxZ) / 2)
	return CFrame.lookAt(ground, ground + look.Unit)
end

local function addGuard(den, habitat): boolean
	local name, guard = GuardConfig.forHabitat(habitat)
	local templates = game.ReplicatedStorage:FindFirstChild(GuardConfig.TemplateFolder)
	local template = templates and name and templates:FindFirstChild(name)
	if not guard or not template then return false end
	local model = template:Clone()
	model.Name = "Guard_" .. habitat
	model:SetAttribute("Habitat", habitat)
	model:SetAttribute("MommyKind", name)
	local root = model:FindFirstChild(model:GetAttribute("RootPartName") or "RootPart", true)
	if not (root and root:IsA("BasePart")) then
		root = model:FindFirstChildWhichIsA("BasePart", true)
	end
	model.PrimaryPart = nil
	model.WorldPivot = groundPivot(model, root, guard)
	model:PivotTo(CFrame.identity)
	model:ScaleTo(model:GetScale() * GuardConfig.scale(guard))
	local size = Motion.guardSize(den)
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide, obj.CanTouch, obj.CanQuery = false, false, false
			obj.Massless = true
			-- Shadows on a belly that skims water strobe; skip them for guards.
			obj.CastShadow = false
		elseif obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		end
	end
	-- Only the root stays anchored; everything jointed to it follows the Animator.
	-- (GetConnectedParts needs the model in the Workspace.)
	model.Parent = folder
	for _, part in root:GetConnectedParts(true) do
		if part ~= root and part:IsDescendantOf(model) then
			part.Anchored = false
		end
	end
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	-- sleep marks just above the head end, set up while the model sits at the origin
	local markAt = root.CFrame:PointToObjectSpace(Vector3.new(0, size.Y * 0.95, -size.Z * 0.32))
	local marks = sleepMarks(root, markAt, size.Y)
	local accent = den:GetAttribute("AccentColor")
	if typeof(accent) ~= "Color3" then
		accent = Color3.fromRGB(140, 220, 255)
	end
	local light = Instance.new("PointLight")
	light.Name = "MommyAuraLight"
	light.Color = if name == "Light Dark Demon" then Color3.fromRGB(255, 60, 40) else accent
	light.Brightness = 0.6
	light.Range = math.max(18, size.Y)
	light.Shadows = false
	light.Parent = root
	local home = Motion.rest(den)
	model:PivotTo(home)
	model.Parent = folder
	local tracks = loadTracks(animator, guard.Anims)
	if tracks.Sleep then
		tracks.Sleep:Play(0)
	end
	local visible = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			table.insert(visible, part)
		end
	end
	beasts[habitat] = {
		model = model, den = den, mode = "Watch", bars = jailBars(den), gate = 0,
		cf = home, returnAt = 0, returnFrom = home, animTime = 0,
		impactUntil = 0, impactCF = home, accent = accent, splashes = {},
		guard = guard, tracks = tracks, anim = "Sleep", animUntil = 0, marks = marks,
		lastPos = home.Position, speed = 0, visible = visible, lowOffset = 0, light = light,
	}
	return true
end

local function addDen(den)
	local habitat = den.Parent and den.Parent.Name
	if not habitat or beasts[habitat] then return end
	local front, facing, homePos = den:GetAttribute("FrontCenter"), den:GetAttribute("Facing"), den:GetAttribute("HomePosition")
	if typeof(front) ~= "Vector3" or typeof(facing) ~= "Vector3" or typeof(homePos) ~= "Vector3" then return end
	local guardOk, guardErr = pcall(addGuard, den, habitat)
	if guardOk and guardErr then return end
	if not guardOk then
		warn("[MommyBeasts] guard for " .. habitat .. " failed: " .. tostring(guardErr))
	end
	local useLeviathan = leviathanHabitats[habitat] == true and leviathanTemplate ~= nil
	local useTurtle = turtleHabitats[habitat] == true and turtleTemplate ~= nil
	local source = if useTurtle then turtleTemplate elseif useLeviathan then leviathanTemplate else template
	local animClips = if useTurtle then turtleClips elseif useLeviathan then leviathanClips else clips
	local nativeY = if useTurtle then (Config.TurtleNativeSize or Config.NativeSize).Y
		elseif useLeviathan then (Config.LeviathanNativeSize or Config.NativeSize).Y
		else Config.NativeSize.Y
	local model = source:Clone()
	model.Name = "Mommy_" .. habitat
	model:SetAttribute("Habitat", habitat)
	model:SetAttribute("MommyKind", if useTurtle then "NeonShellLeviathan" elseif useLeviathan then "LavaLeviathan" else "Trex")
	local size = model:GetExtentsSize()
	model:ScaleTo(model:GetScale() * (Motion.worldScale(den) * nativeY) / math.max(size.Y, 0.001))
	local bones = {}
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.Anchored, obj.CanCollide, obj.CanTouch, obj.CanQuery = true, false, false, false
			obj.CastShadow = true
		elseif obj:IsA("Bone") then
			bones[obj.Name] = obj
		end
	end
	model.Parent = folder
	local id = den:GetAttribute("StyleId") or 1
	local bars = {}
	local barsFolder = den:FindFirstChild("JailBars")
	if barsFolder then
		for _, part in barsFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(bars, { part = part, closed = part:GetAttribute("ClosedCFrame") or part.CFrame })
			end
		end
	end
	local home = Motion.rest(den)
	model:PivotTo(home)
	local accent = den:GetAttribute("AccentColor")
	if typeof(accent) ~= "Color3" then
		accent = Color3.fromRGB(140, 220, 255)
	end
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local splashes = {}
	if body then
		local light = Instance.new("PointLight")
		light.Name = "MommyAuraLight"
		light.Color = accent
		light.Brightness = 0.35
		light.Range = 18
		light.Shadows = false
		light.Parent = body
		local _, bounds = model:GetBoundingBox()
		local height = bounds.Y
		local side = bounds.X * 0.52
		local waterY = -height * (Config.SubmergeFraction or 0.25)
		local scale = math.clamp(height * 0.2, 4.5, 11)
		for _, station in {
			{ -bounds.Z * 0.2, "Front" },
			{ bounds.Z * 0.14, "Rear" },
		} do
			for _, sign in { -1, 1 } do
				local made = flankSplash(
					body,
					"Splash" .. station[2] .. if sign < 0 then "L" else "R",
					Vector3.new(sign * side, waterY, station[1]),
					sign,
					scale
				)
				for _, emitter in made do
					table.insert(splashes, emitter)
				end
			end
		end
	end
	beasts[habitat] = {
		model = model, bones = bones, den = den, mode = "Watch", bars = bars, gate = 0,
		cf = home, returnAt = 0, returnFrom = home, animTime = id * 1.7,
		impactUntil = 0, impactCF = home, clips = animClips, accent = accent,
		splashes = splashes,
	}
end
for _, obj in map:GetDescendants() do if obj.Name == "JailCell" then addDen(obj) end end
map.DescendantAdded:Connect(function(obj) if obj.Name == "JailCell" then task.defer(addDen, obj) end end)
local remote = GameUI.remote("MommyEncounter")

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MommyEncounterHUD", false, 75
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.AnchorPoint, label.Position = Vector2.new(.5, 0), UDim2.fromScale(.5, .13)
label.Size = UDim2.fromScale(.7, .07)
label.BackgroundTransparency = 1
label.Font = Enum.Font.BuilderSansBold
label.TextColor3 = Color3.fromRGB(255, 210, 120)
label.TextStrokeColor3, label.TextStrokeTransparency = Color3.fromRGB(48, 27, 45), .15
label.TextScaled, label.Visible, label.Parent = true, false, gui
local limit = Instance.new("UITextSizeConstraint")
limit.MinTextSize, limit.MaxTextSize, limit.Parent = 16, 32, label
local flash = Instance.new("Frame")
flash.Name = "ImpactFlash"
flash.BackgroundColor3 = Color3.fromRGB(255, 230, 200)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Size = UDim2.fromScale(1, 1)
flash.ZIndex = 20
flash.Parent = gui

local function bodyPart(character: Model?): BasePart?
	if not character then return nil end
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
end

local function restoreCamera()
	cameraToken += 1
	cameraMode = "Default"
	tumbleActive = false
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
end

local function unlockControls()
	ContextActionService:UnbindAction("MommyTumbleLock")
	controlledCharacter = nil
	if controls then controls:Enable() end
	label.Visible = false
end

local function unlock()
	unlockControls()
	restoreCamera()
end

player.CharacterAdded:Connect(function(character)
	unlockControls()
	-- Attach to the fresh spawn outside the megatank; don't leave Scriptable aiming at a dead body.
	task.defer(function()
		local hum = character:WaitForChild("Humanoid", 5)
		cameraToken += 1
		cameraMode = "Default"
		tumbleActive = false
		camera.CameraType = Enum.CameraType.Custom
		if hum then
			camera.CameraSubject = hum
		end
	end)
end)

player:GetAttributeChangedSignal("MommyState"):Connect(function()
	if not player:GetAttribute("MommyState") and not tumbleActive then
		unlock()
	end
end)

local function impactBurst(position)
	local host = Instance.new("Part")
	host.Name, host.Size, host.Position = "MommySandPuff", Vector3.one, position
	host.Transparency, host.Anchored, host.CanCollide, host.CanTouch, host.CanQuery = 1, true, false, false, false
	host.Parent = folder
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 203, 146))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.35, 7),
		NumberSequenceKeypoint.new(1, 11),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime, dust.Speed = NumberRange.new(0.5, 1.1), NumberRange.new(10, 28)
	dust.SpreadAngle, dust.Rate, dust.Parent = Vector2.new(110, 110), 0, host
	dust:Emit(40)
	Debris:AddItem(host, 2.4)
end

local function lookBackAtBeast(root: BasePart, beastCF: CFrame): CFrame
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.05 then look.Unit else Vector3.zAxis
	local right = Vector3.new(-look.Z, 0, look.X)
	local camPos = root.Position + look * 7 + right * 3.5 + Vector3.yAxis * 5.5
	return CFrame.lookAt(camPos, beastCF.Position + Vector3.yAxis * 6)
end

local function followBodyCamera(part: BasePart, throwDir: Vector3): CFrame
	local flat = Vector3.new(throwDir.X, 0, throwDir.Z)
	flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local focus = part.Position
	local camPos = focus - flat * 12 + right * 4 + Vector3.yAxis * 8
	return CFrame.lookAt(camPos, focus + Vector3.yAxis * 1.2)
end

local function playTackleHum(at: Vector3)
	local sound = Instance.new("Sound")
	sound.Name = "MommyTackleHum"
	sound.SoundId = Config.TackleHumSoundId
	sound.Volume = Config.TackleHumVolume
	sound.PlaybackSpeed = Config.TackleHumPlaybackSpeed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = 120
	sound.RollOffMinDistance = 8
	local holder = Instance.new("Part")
	holder.Name = "MommyTackleHumAnchor"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = at
	holder.Parent = workspace
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 4)
end

local function beginImpactCamera(beast, payload)
	cameraToken += 1
	local token = cameraToken
	tumbleActive = true
	camera.CameraType = Enum.CameraType.Scriptable
	cameraMode = "Impact"
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local beastCF = if typeof(payload) == "table" and typeof(payload.beastCF) == "CFrame" then payload.beastCF else beast.cf
	followThrowDir = if typeof(payload) == "table" and typeof(payload.throwDir) == "Vector3" then payload.throwDir else Vector3.zAxis
	if root then
		camera.CFrame = lookBackAtBeast(root, beastCF)
	end
	flash.BackgroundTransparency = 0.25
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	local hitPos = if typeof(payload) == "table" and typeof(payload.origin) == "Vector3" then payload.origin else beastCF.Position
	impactBurst(hitPos)
	playTackleHum(hitPos)

	task.spawn(function()
		local holdUntil = os.clock() + Config.TackleHoldSeconds
		while cameraToken == token and os.clock() < holdUntil do
			local liveRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if liveRoot then
				camera.CFrame = camera.CFrame:Lerp(lookBackAtBeast(liveRoot, beast.cf), 0.28)
			end
			RunService.RenderStepped:Wait()
		end
		if cameraToken ~= token then return end
		cameraMode = "Follow"
	end)
end

local function handleEncounter(action, habitat, value)
	local beast = beasts[habitat]
	if action == "Chase" then
		if beast then beast.mode = "Chase" end
		label.Text, label.Visible = "GET TO YOUR TANK!", true
	elseif action == "Tackle" then
		if beast then
			-- Freeze at nose contact, then immediately turn and retreat to the cage.
			local contact = if typeof(value) == "table" and typeof(value.beastCF) == "CFrame" then value.beastCF else beast.cf
			beast.cf = contact
			beast.impactCF = contact
			beast.returnFrom = contact
			beast.returnAt = os.clock()
			beast.mode = "Return"
			beginImpactCamera(beast, value)
		end
		controlledCharacter = player.Character
		ContextActionService:BindActionAtPriority("MommyTumbleLock", function()
			return Enum.ContextActionResult.Sink
		end, false, 10000, table.unpack(Enum.PlayerActions:GetEnumItems()))
		if controls then controls:Disable() end
		local hum = controlledCharacter and controlledCharacter:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
			hum.PlatformStand = true
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end
		label.Text = "TACKLED!"
	elseif action == "Landed" then
		cameraMode = "Landed"
		local pos = if typeof(value) == "Vector3" then value else nil
		if pos then impactBurst(pos) end
		label.Text = "TACKLED!"
	elseif action == "Respawning" then
		label.Text = "GETTING UP..."
	elseif action == "Return" then
		if beast and beast.mode == "Chase" then
			beast.mode, beast.returnAt, beast.returnFrom = "Return", os.clock(), beast.cf
		end
		-- Tackled players get up where they landed: undo the local ragdoll lock and give the camera back.
		local hum = controlledCharacter and controlledCharacter:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
			hum.PlatformStand = false
			if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end
		unlock()
	end
end
remote.OnClientEvent:Connect(handleEncounter)
if player:GetAttribute("MommyState") == "Chase" then
	handleEncounter("Chase", player:GetAttribute("MommyHabitat"), player:GetAttribute("MommyDeadline"))
end

local function playAnim(beast, name: string, speed: number?)
	local track = beast.tracks[name]
	if beast.anim == name then
		if track and speed then track:AdjustSpeed(speed) end
		return
	end
	for other, t in beast.tracks do
		if other ~= name and t.IsPlaying then t:Stop(GuardConfig.FadeSeconds) end
	end
	beast.anim = name
	if track then track:Play(GuardConfig.FadeSeconds, 1, speed or 1) end
end

local function oneShotLength(track): number
	return if track and track.Length > 0 then track.Length else 2
end

-- Sleep in the den, get up when the chase starts, run / stand while out, lie back down at home.
local function updateGuardAnimation(beast, dt: number, pending: boolean)
	local now = os.clock()
	local moved = beast.cf.Position - beast.lastPos
	beast.lastPos = beast.cf.Position
	local instant = if dt > 0 then Vector3.new(moved.X, 0, moved.Z).Magnitude / dt else 0
	beast.speed += (instant - beast.speed) * math.clamp(dt * 8, 0, 1)
	local busy = now < beast.animUntil
	local wake = beast.tracks.Wake
	if beast.mode == "Watch" then
		if beast.anim == "LieDown" then
			if not busy then playAnim(beast, "Sleep") end
		elseif beast.anim ~= "Sleep" then
			-- lying down is the get-up clip played backwards
			if wake then
				for other, t in beast.tracks do
					if other ~= "Wake" and t.IsPlaying then t:Stop(GuardConfig.FadeSeconds) end
				end
				beast.anim = "LieDown"
				wake:Play(GuardConfig.FadeSeconds, 1, -1)
				wake.TimePosition = math.max(0, wake.Length - 0.02)
				beast.animUntil = now + oneShotLength(wake) - 0.15
			else
				playAnim(beast, "Sleep")
			end
		end
	elseif beast.anim == "Sleep" or beast.anim == "LieDown" then
		playAnim(beast, "Wake")
		beast.animUntil = now + oneShotLength(wake) - 0.15
		beast.alertUntil = now + 1.6
	elseif not (beast.anim == "Wake" and busy) then
		if beast.speed > 3 and not pending then
			playAnim(beast, "Run", math.clamp(beast.speed / GuardConfig.RunSpeedForFullRate, 0.8, GuardConfig.MaxRunRate))
		else
			playAnim(beast, "Idle")
		end
	end
	local marks = beast.marks
	if marks then
		local asleep = beast.anim == "Sleep"
		for i, label in marks.labels do
			local phase = (now * 0.4 + i / 3) % 1
			label.Visible = asleep
			label.Position = UDim2.fromScale(0.35 + 0.35 * phase + 0.06 * math.sin(now * 2 + i), 1 - phase)
			label.TextTransparency = phase * phase
			label.TextStrokeTransparency = 0.2 + 0.8 * phase * phase
			label.Rotation = -12 + 24 * phase
		end
		marks.alert.Visible = now < (beast.alertUntil or 0)
	end
end

-- Lowest point of the guard's visible parts as the Animator posed them last frame.
local function lowestPoint(parts: { BasePart }): number?
	local lo = math.huge
	for _, part in parts do
		local cf, half = part.CFrame, part.Size * 0.5
		local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
		local reach = math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z
		lo = math.min(lo, cf.Y - reach)
	end
	return if lo < math.huge then lo else nil
end

-- Where to draw a guard: beast.cf moved up or down so its animated lowest point (feet standing, belly
-- lying asleep, a dangling tail) sits on the right height. Chase/return sink 1 stud under the water
-- line; watching sleeps on the walk deck so a flat belly does not strobe through the water surface.
-- Only the drawn model moves; beast.cf (and the server's chase pose) keep their XZ.
local function guardDisplay(beast, dt: number): CFrame
	local lo = lowestPoint(beast.visible)
	if lo then
		local offset = lo - beast.model:GetPivot().Y
		beast.lowOffset += (offset - beast.lowOffset) * math.clamp(dt * 12, 0, 1)
	end
	local baseY = if beast.mode == "Watch"
		then Motion.watchLowestY(beast.cf.Position, beast.den)
		else Motion.lowestY(beast.cf.Position, beast.den)
	local y = baseY - beast.lowOffset
	beast.drawY = if beast.drawY then beast.drawY + (y - beast.drawY) * math.clamp(dt * 10, 0, 1) else y
	if beast.light then
		-- Green aura + water plane strobes on flat sleepers (Bamboo Spirit Panda).
		beast.light.Enabled = beast.mode ~= "Watch"
	end
	return beast.cf + Vector3.new(0, beast.drawY - beast.cf.Y, 0)
end

RunService.PreRender:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, beast in beasts do
		local home = Motion.rest(beast.den)
		local fast = beast.mode == "Chase"
		if fast and root then
			local pending = player:GetAttribute("MommyPending") == true
			local replicated = player:GetAttribute("MommyCF")
			if pending then
				beast.cf = beast.cf:Lerp(home, math.clamp(dt * 8, 0, 1))
			elseif typeof(replicated) == "CFrame" then
				if player:GetAttribute("MommySnap") == true then
					beast.cf = replicated
				else
					beast.cf = beast.cf:Lerp(replicated, math.clamp(dt * 15, 0, 1))
				end
			else
				beast.cf = Motion.advance(beast.cf, beast.den, root.Position, dt, false)
			end
		elseif beast.mode == "Return" then
			-- 1) Spin toward the cage  2) walk inside  3) face the bars again.
			local elapsed = os.clock() - beast.returnAt
			local turnDur = Config.ReturnTurnSeconds
			local moveDur = math.max(0.05, Config.ReturnSeconds - turnDur)
			local from = beast.returnFrom
			local retreat = home.Position - from.Position
			retreat = Vector3.new(retreat.X, 0, retreat.Z)
			local retreatDir = if retreat.Magnitude > 0.1 then retreat.Unit else -from.LookVector
			if elapsed < turnDur then
				local turnT = math.clamp(elapsed / turnDur, 0, 1)
				local ease = turnT * turnT * (3 - 2 * turnT)
				local facingHome = CFrame.lookAt(from.Position, from.Position + retreatDir)
				beast.cf = from:Lerp(facingHome, ease)
			else
				local moveT = math.clamp((elapsed - turnDur) / moveDur, 0, 1)
				local ease = moveT * moveT * (3 - 2 * moveT)
				local pos = from.Position:Lerp(home.Position, ease)
				local swimY = Motion.swimY(beast.den, pos)
				if moveT < 0.85 then
					pos = Vector3.new(pos.X, swimY, pos.Z)
				else
					local rise = (moveT - 0.85) / 0.15
					pos = Vector3.new(pos.X, swimY + (home.Position.Y - swimY) * rise, pos.Z)
				end
				local look = if moveT < 0.8 then retreatDir else retreatDir:Lerp(home.LookVector, (moveT - 0.8) / 0.2)
				if typeof(look) ~= "Vector3" or look.Magnitude < 0.05 then
					look = home.LookVector
				else
					look = look.Unit
				end
				beast.cf = CFrame.lookAt(pos, pos + look)
				if moveT >= 1 then
					beast.cf = home
					beast.mode = "Watch"
				end
			end
		else
			local goal = if root then Motion.watching(beast.den, home, root.Position) else home
			beast.cf = beast.cf:Lerp(goal, math.clamp(dt * 3, 0, 1))
		end
		-- Keep bars shut while mommy is waiting for the player to leave the capture zone.
		local pending = player:GetAttribute("MommyPending") == true
		local splashing = beast.mode == "Chase" and not pending
		for _, emitter in beast.splashes do
			emitter.Enabled = splashing
		end
		local gateGoal = if (beast.mode == "Chase" and not pending) or beast.mode == "Return" then 1 else 0
		beast.gate += math.clamp(gateGoal - beast.gate, -dt / Config.GateSeconds, dt / Config.GateSeconds)
		for _, bar in beast.bars do
			bar.part.CFrame = bar.closed + Vector3.new(0, -((beast.den:GetAttribute("MouthHeight") or 72) + 6) * beast.gate, 0)
			bar.part.CanCollide = false
		end
		if beast.guard then
			beast.model:PivotTo(guardDisplay(beast, dt))
		else
			beast.model:PivotTo(beast.cf)
		end
		if beast.guard then
			updateGuardAnimation(beast, dt, pending)
			continue
		end
		local set = beast.clips or clips
		local clipName = if fast then "fastSwim" elseif beast.mode == "Return" then "swim" else "idle"
		local clip = set[clipName] or set.swim or set.idle
		local animRate = if fast then 1.85 elseif beast.mode == "Return" then 1.45 else 1
		beast.animTime += dt * animRate
		local t = beast.animTime
		local sample = (t % clip.duration) * clip.fps
		local index = math.floor(sample) + 1
		local first = clip.samples[index]
		local second = clip.samples[math.min(index + 1, #clip.samples)]
		for i, name in boneNames do
			local bone = beast.bones[name]
			if bone and first and second and first[i] and second[i] then
				local a, b = first[i], second[i]
				bone.Transform = CFrame.new(0, 0, 0, a[2], a[3], a[4], a[1]):Lerp(
					CFrame.new(0, 0, 0, b[2], b[3], b[4], b[1]),
					sample % 1
				)
			end
		end
	end

	-- During chase the player keeps normal camera control so they can run to the tank.
	-- Scriptable follow is only used for the tackle throw / landing.
	if cameraMode == "Follow" or cameraMode == "Landed" then
		local part = bodyPart(character)
		if part then
			local goal = followBodyCamera(part, followThrowDir)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = camera.CFrame:Lerp(goal, if cameraMode == "Landed" then 0.12 else math.clamp(dt * 14, 0, 1))
		end
	elseif cameraMode == "LookBack" then
		restoreCamera()
	end
end)

script.Destroying:Connect(function() unlock(); folder:Destroy(); gui:Destroy() end)
