--!strict
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local BubbleMesh = require(game.ReplicatedStorage.BabyBeastsShared.BubbleMesh)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local GameEgg = require(game.ReplicatedStorage.BabyBeastsShared.GameEgg)
local EggVisual = require(game.ReplicatedStorage.BabyBeastsShared.EggVisual)

local player = Players.LocalPlayer
local remotes = game.ReplicatedStorage.BabyBeastsShared:WaitForChild("Remotes")
local collected = remotes:WaitForChild("BeastCollected") :: RemoteEvent

local function playCollectSound()
	local sound = Instance.new("Sound")
	sound.Name = "BeastCollect"
	sound.SoundId = GameUI.CollectSoundId
	sound.Volume = 0.9
	sound.PlaybackSpeed = 1.05
	sound.Parent = player:WaitForChild("PlayerGui")
	SoundService:PlayLocalSound(sound)
	sound:Play()
	task.delay(0.45, function()
		if sound.Parent and sound.TimeLength == 0 then
			sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
			SoundService:PlayLocalSound(sound)
			sound:Play()
		end
	end)
	Debris:AddItem(sound, 4)
end

local function halfPlayerPixels(): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local character = player.Character
	local playerHeight = 5
	if character then
		local ok, extents = pcall(function()
			return character:GetExtentsSize()
		end)
		if ok and typeof(extents) == "Vector3" then
			playerHeight = math.max(3, extents.Y)
		end
	end
	-- Character is roughly 40% of screen height in third person; show half that.
	local playerPx = viewport.Y * math.clamp(playerHeight / 12, 0.28, 0.48)
	return math.clamp(playerPx * 0.5, 110, viewport.Y * 0.42)
end

local function spawnRingSparks(parent: Frame, duration: number)
	local count = 18
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local dot = Instance.new("Frame")
		dot.Name = "Spark"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(255, 228, 120) else Color3.fromRGB(255, 170, 230)
		dot.BackgroundTransparency = 0.05
		dot.BorderSizePixel = 0
		dot.ZIndex = 5
		dot.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 1
		stroke.Transparency = 0.35
		stroke.Parent = dot
		local radius = 0.42 + (i % 3) * 0.05
		TweenService:Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius),
			Size = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(dot, duration + 0.05)
	end
end

local function showReveal(modelId: string, bodySize: Vector3, eggName: string?)
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BeastReveal")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BeastReveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80
	gui.Parent = playerGui

	local targetPx = math.floor(halfPlayerPixels())
	local holder = Instance.new("Frame")
	holder.Name = "RevealHolder"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -18, 0, 18)
	holder.Size = UDim2.fromOffset(18, 18)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local vp = Instance.new("ViewportFrame")
	vp.Name = "BeastView"
	vp.BackgroundColor3 = Color3.fromRGB(18, 28, 42)
	vp.BackgroundTransparency = 0.35
	vp.BorderSizePixel = 0
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(220, 220, 220)
	vp.LightColor = Color3.fromRGB(255, 240, 210)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.35)
	vp.ZIndex = 2
	vp.Parent = holder
	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0.18, 0)
	vpCorner.Parent = vp
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 214, 120)
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = vp

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local vis = Instance.new("MeshPart")
	local ok, template = pcall(function()
		return BubbleMesh.template()
	end)
	if ok then
		vis:ApplyMesh(template)
	end
	vis.Name = "RevealBeast"
	vis.TextureID = modelId
	vis.Color = Color3.new(1, 1, 1)
	vis.Material = Enum.Material.SmoothPlastic
	vis.Anchored = true
	vis.CanCollide = false
	vis.CanQuery = false
	vis.CanTouch = false
	vis.Size = if bodySize.Magnitude > 0.05 then bodySize else GameUI.NativeSize
	pcall(function()
		vis.DoubleSided = true
	end)
	vis.CFrame = CFrame.new()
	vis.Parent = world
	local revealRig: EggVisual.Rig? = nil
	local revealEgg = if typeof(eggName) == "string" then GameEgg.get(eggName) else nil
	if revealEgg then
		local builtEgg = revealEgg
		task.spawn(function()
			local rig = EggVisual.build(builtEgg, if bodySize.Magnitude > 0.05 then bodySize else GameUI.NativeSize)
			if not rig or not world.Parent then
				if rig then
					rig:destroy()
				end
				return
			end
			rig.model.Parent = world
			vis.Transparency = 1
			revealRig = rig
		end)
	end

	local sparkHost = Instance.new("Part")
	sparkHost.Name = "SparkHost"
	sparkHost.Anchored = true
	sparkHost.CanCollide = false
	sparkHost.Transparency = 1
	sparkHost.Size = Vector3.new(0.2, 0.2, 0.2)
	sparkHost.CFrame = CFrame.new()
	sparkHost.Parent = world
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CircleSparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.SpreadAngle = Vector2.new(0, 0)
	emitter.Rate = 70
	emitter.Speed = NumberRange.new(3.5, 6.5)
	emitter.Lifetime = NumberRange.new(0.35, 0.75)
	emitter.Rotation = NumberRange.new(0, 180)
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.LightEmission = 0.65
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.4, 0.28),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 230, 255)),
	})
	emitter.Parent = sparkHost

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vp
	vp.CurrentCamera = camera
	local maxDim = math.max(vis.Size.X, vis.Size.Y, vis.Size.Z)
	local distance = maxDim * 1.85
	camera.CFrame = CFrame.new(Vector3.new(distance * 0.55, distance * 0.28, distance), Vector3.zero)

	spawnRingSparks(holder, GameUI.RevealSeconds)

	local grow = TweenService:Create(holder, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(targetPx, targetPx),
	})
	grow:Play()

	local elapsed = 0
	local shakeConn: RBXScriptConnection? = nil
	shakeConn = RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then
			if shakeConn then
				shakeConn:Disconnect()
			end
			return
		end
		elapsed += dt
		local wobble = math.sin(elapsed * 38) * 7
		local wobbleY = math.cos(elapsed * 33) * 6
		holder.Position = UDim2.new(1, -18 + wobble, 0, 18 + wobbleY)
		holder.Rotation = math.sin(elapsed * 26) * 6
		local spin = CFrame.Angles(math.sin(elapsed * 10) * 0.12, elapsed * 1.7, math.cos(elapsed * 14) * 0.1)
		if revealRig then
			revealRig:place(spin)
		else
			vis.CFrame = spin
		end
		sparkHost.CFrame = CFrame.Angles(math.rad(90), elapsed * 2.4, 0)
	end)

	task.delay(GameUI.RevealSeconds - 0.28, function()
		emitter.Enabled = false
		TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(8, 8),
			Rotation = 0,
		}):Play()
		TweenService:Create(vp, TweenInfo.new(0.28), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(GameUI.RevealSeconds, function()
		if shakeConn then
			shakeConn:Disconnect()
		end
		gui:Destroy()
	end)
end

collected.OnClientEvent:Connect(function(payload)
	playCollectSound()
	local modelId = GameUI.UploadedModelId
	local size = GameUI.NativeSize
	local eggName: string? = nil
	if typeof(payload) == "table" then
		if typeof(payload.modelId) == "string" then
			modelId = payload.modelId
		end
		if typeof(payload.size) == "Vector3" then
			size = payload.size
		end
		if typeof(payload.eggName) == "string" then
			eggName = payload.eggName
		end
	elseif typeof(payload) == "string" then
		modelId = payload
	end
	showReveal(modelId, size, eggName)
end)
