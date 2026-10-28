local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local exit = shared:WaitForChild("TrainingExit")
local Movement = require(script.Parent:WaitForChild("MovementController"))
-- This place does not ship PlayerScriptsLoader, so PlayerModule never appears.
-- Do not block the treadmill visuals on it.
local controls = nil
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts")
	local playerModule = scripts:FindFirstChild("PlayerModule") or scripts:WaitForChild("PlayerModule", 5)
	if not playerModule then
		return
	end
	local ok, result = pcall(function()
		return require(playerModule):GetControls()
	end)
	if ok then
		controls = result
		if player:GetAttribute("TrainingTreadmill") and not UIS.TouchEnabled then
			controls:Disable()
		end
	end
end)
local function setControlsEnabled(enabled: boolean)
	if not controls then
		return
	end
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

-- Lightweight toast for treadmill upgrade cash / Robux feedback.
-- Wired in a spawn so missing Remotes never blocks belt animation.
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "TreadmillToast"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.DisplayOrder = 55
toastGui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 72)
toast.Size = UDim2.fromOffset(420, 44)
toast.BackgroundColor3 = Color3.fromRGB(22, 28, 48)
toast.BackgroundTransparency = 0.12
toast.Font = Enum.Font.BuilderSansBold
toast.TextSize = 18
toast.TextColor3 = Color3.fromRGB(255, 236, 210)
toast.Text = ""
toast.Visible = false
toast.Parent = toastGui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast
local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(255, 150, 70)
toastStroke.Thickness = 2
toastStroke.Parent = toast
local toastToken = 0
local function showToast(message: string, ok: boolean?)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	toastStroke.Color = if ok then Color3.fromRGB(105, 238, 168) else Color3.fromRGB(255, 150, 70)
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.12
	task.delay(2.6, function()
		if token ~= toastToken then
			return
		end
		local fade = TweenService:Create(toast, TweenInfo.new(0.35), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		if token == toastToken then
			toast.Visible = false
			toast.TextTransparency = 0
			toast.BackgroundTransparency = 0.12
		end
	end)
end
task.spawn(function()
	local remotes = shared:WaitForChild("Remotes")
	local shopResult = remotes:WaitForChild("TrailShopResult")
	shopResult.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.Action ~= "Tier" then
			return
		end
		local message = tostring(payload.Message or "")
		if message == "" then
			return
		end
		showToast(message, payload.Ok == true)
	end)
end)

local RAMP_SECONDS = 3
local ANIM_MAX = 3.4
local track, previousMode, activeAt, activeId = nil, nil, 0, nil
local lastExitAttempt = 0
local touchJumpConns: { RBXScriptConnection } = {}
local function stopTrack()
	if track then
		track:Stop(0.2)
		track:Destroy()
		track = nil
	end
end
local function rampAlpha(startedAt)
	if typeof(startedAt) ~= "number" or startedAt <= 0 then
		return 1
	end
	return math.clamp((workspace:GetServerTimeNow() - startedAt) / RAMP_SECONDS, 0, 1)
end
local function tryExitTraining()
	if not activeId or os.clock() - activeAt < 0.7 then
		return
	end
	if os.clock() - lastExitAttempt < 0.35 then
		return
	end
	lastExitAttempt = os.clock()
	exit:FireServer()
end
local function clearTouchJumpHooks()
	for _, conn in touchJumpConns do
		conn:Disconnect()
	end
	table.clear(touchJumpConns)
end
local function hookTouchJumpButton()
	clearTouchJumpHooks()
	if not activeId then
		return
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local function bindJumpButton(button: Instance)
		if not button:IsA("GuiObject") then
			return
		end
		-- controls:Disable() can hide/disable the stock jump button; keep it tappable to exit.
		button.Visible = true
		button.Active = true
		if button:IsA("ImageButton") or button:IsA("TextButton") then
			(button :: GuiButton).AutoButtonColor = true
		end
		table.insert(
			touchJumpConns,
			button.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					tryExitTraining()
				end
			end)
		)
	end
	local function scanTouchGui(touchGui: Instance)
		local frame = touchGui:FindFirstChild("TouchControlFrame")
		local jumpButton = frame and frame:FindFirstChild("JumpButton")
		if jumpButton then
			bindJumpButton(jumpButton)
		end
		table.insert(
			touchJumpConns,
			touchGui.DescendantAdded:Connect(function(child)
				if child.Name == "JumpButton" then
					bindJumpButton(child)
				end
			end)
		)
	end
	local existing = playerGui:FindFirstChild("TouchGui")
	if existing then
		scanTouchGui(existing)
	end
	table.insert(
		touchJumpConns,
		playerGui.ChildAdded:Connect(function(child)
			if child.Name == "TouchGui" then
				scanTouchGui(child)
			end
		end)
	)
end
local function trainingChanged()
	local id = player:GetAttribute("TrainingTreadmill")
	if id == activeId then
		return
	end
	activeId = id
	stopTrack()
	clearTouchJumpHooks()
	if id then
		previousMode = Movement.getMode()
		Movement.setMode("RUN")
		-- Keep touch controls enabled so the mobile jump button stays usable for exit.
		-- Desktop/gamepad still disable move controls; root is Anchored either way.
		if not UIS.TouchEnabled then
			setControlsEnabled(false)
		end
		activeAt = os.clock()
		hookTouchJumpButton()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator"))
		if animator and animator.Parent == nil and hum then
			animator.Parent = hum
		end
		local animate = char and char:FindFirstChild("Animate")
		local run = animate and animate:FindFirstChild("run")
		local animation = run and run:FindFirstChildWhichIsA("Animation")
		if animator then
			local clip = Instance.new("Animation")
			clip.AnimationId = if animation
				then animation.AnimationId
				elseif hum and hum.RigType == Enum.HumanoidRigType.R15 then "rbxassetid://507767714"
				else "rbxassetid://180426354"
			local ok, result = pcall(function()
				return animator:LoadAnimation(clip)
			end)
			clip:Destroy()
			if ok then
				track = result
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = true
				track:Play(0.2, 1, 0.35)
			else
				warn("[Training] Run animation: " .. tostring(result))
			end
		end
	else
		setControlsEnabled(true)
		if previousMode then
			Movement.setMode(previousMode)
			previousMode = nil
		end
	end
end
-- Space / gamepad. Mobile uses JumpRequest + TouchGui JumpButton (controls:Disable swallows default jump).
UIS.InputBegan:Connect(function(input, processed)
	if
		not processed
		and (
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonB
			or input.KeyCode == Enum.KeyCode.ButtonA
		)
	then
		tryExitTraining()
	end
end)
UIS.JumpRequest:Connect(tryExitTraining)
player:GetAttributeChangedSignal("TrainingTreadmill"):Connect(trainingChanged)
player.CharacterAdded:Connect(function()
	stopTrack()
	setControlsEnabled(true)
	clearTouchJumpHooks()
	activeId = nil
	previousMode = nil
end)
local gates, machines = {}, {}
-- The speed chart is the goal on the treadmill. The gate parts stay open.
local function gateUpdate(g)
	g.CanCollide = false
	g.LocalTransparencyModifier = 1
end
local function collectArrows(m: Instance): { BasePart }
	local arrows = {}
	for _, child in m:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "BeltArrow" then
			table.insert(arrows, child)
		end
	end
	return arrows
end
local function collectBeltScrolls(m: Instance): { Texture }
	local scrolls = {}
	for _, child in m:GetDescendants() do
		if child:IsA("Texture") and typeof(child:GetAttribute("BeltScrollAxis")) == "string" then
			table.insert(scrolls, child)
		end
	end
	-- Already-spawned machines may predate the scroll tag — discover flat Top belts.
	if #scrolls == 0 then
		local origin = m:GetAttribute("Origin")
		local beltDir = if typeof(origin) == "CFrame" then origin.ZVector else Vector3.zAxis
		for _, child in m:GetDescendants() do
			if not child:IsA("Texture") or child.Face ~= Enum.NormalId.Top then
				continue
			end
			local part = child.Parent
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
			child:SetAttribute("BeltScrollAxis", axis)
			child:SetAttribute("BeltScrollSign", if axisVec:Dot(beltDir) >= 0 then -1 else 1)
			table.insert(scrolls, child)
		end
	end
	return scrolls
end
local function addMachine(m)
	if not m:IsA("Model") then
		return
	end
	local arrows = collectArrows(m)
	local scrolls = collectBeltScrolls(m)
	local state = machines[m]
	if state then
		state.origin = m:GetAttribute("Origin")
		state.arrows = arrows
		state.scrolls = scrolls
		return
	end
	machines[m] = {
		origin = m:GetAttribute("Origin"),
		arrows = arrows,
		scrolls = scrolls,
	}
	m.DescendantAdded:Connect(function(child)
		if (child:IsA("BasePart") and child.Name == "BeltArrow") or child:IsA("Texture") then
			local current = machines[m]
			if current then
				current.arrows = collectArrows(m)
				current.scrolls = collectBeltScrolls(m)
			end
		end
	end)
end
for _, g in CollectionService:GetTagged("BiomeSpeedGate") do
	gates[g] = true
	gateUpdate(g)
end
CollectionService:GetInstanceAddedSignal("BiomeSpeedGate"):Connect(function(g)
	gates[g] = true
	gateUpdate(g)
end)
CollectionService:GetInstanceRemovedSignal("BiomeSpeedGate"):Connect(function(g)
	gates[g] = nil
end)
-- Connect first, then scan — avoids missing a treadmill tagged between the two.
CollectionService:GetInstanceAddedSignal("TrainingTreadmill"):Connect(addMachine)
CollectionService:GetInstanceRemovedSignal("TrainingTreadmill"):Connect(function(m)
	machines[m] = nil
end)
for _, m in CollectionService:GetTagged("TrainingTreadmill") do
	addMachine(m)
end
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local now = workspace:GetServerTimeNow()
	local myId = player:GetAttribute("TrainingTreadmill")
	local myStarted = player:GetAttribute("TrainingStartedAt")
	local myAlpha = if myId then rampAlpha(myStarted) else 0
	if track and myId then
		local animSpeed = 0.35 + (ANIM_MAX - 0.35) * (myAlpha * myAlpha)
		track:AdjustSpeed(animSpeed)
	end
	for m, d in machines do
		if not m.Parent then
			machines[m] = nil
			continue
		end
		if typeof(d.origin) ~= "CFrame" then
			d.origin = m:GetAttribute("Origin")
		end
		if typeof(d.origin) ~= "CFrame" then
			continue
		end
		if #d.arrows == 0 then
			d.arrows = collectArrows(m)
		end
		if not d.scrolls or #d.scrolls == 0 then
			d.scrolls = collectBeltScrolls(m)
		end
		local running = (m:GetAttribute("TrainingUserId") or 0) ~= 0
		local startedAt = m:GetAttribute("TrainingStartedAt")
		local alpha = if running then rampAlpha(startedAt) else 0
		local nearby = (root.Position - d.origin.Position).Magnitude < 180
		if not nearby or (#d.arrows == 0 and #(d.scrolls or {}) == 0) then
			continue
		end
		local span = m:GetAttribute("BeltSpan")
		local beltY = m:GetAttribute("BeltY")
		local count = m:GetAttribute("BeltArrowCount")
		local speedAttr = m:GetAttribute("BeltArrowSpeed")
		if typeof(span) ~= "number" then
			span = 10
		end
		if typeof(beltY) ~= "number" then
			beltY = 2
		end
		if typeof(count) ~= "number" or count < 1 then
			count = 3
		end
		if typeof(speedAttr) ~= "number" then
			-- Fallback: scale by ShownTier when build attribute is missing.
			local shown = m:GetAttribute("ShownTier")
			local tier = if typeof(shown) == "number" then math.max(1, math.floor(shown)) else 1
			speedAttr = 5 + tier * 1.5
		end
		-- Stream front (+Z) → back (-Z). Host carries soft beam chevrons.
		local speed = speedAttr * (0.12 + 0.88 * alpha * alpha)
		local phase = if running then now * speed else 0
		local step = span / count
		for _, host in d.arrows do
			if not host.Parent then
				continue
			end
			local index = host:GetAttribute("ArrowIndex")
			if typeof(index) ~= "number" then
				index = 0
			end
			local traveled = (index * step + phase) % span
			local along = span * 0.5 - traveled
			host.CFrame = d.origin * CFrame.new(0, beltY, along)
			-- Fade whole chevron when idle; full glow while training.
			local idleFade = if running then 0 else 0.35
			for _, beam in host:GetChildren() do
				if beam:IsA("Beam") then
					beam.Enabled = nearby
					if idleFade > 0 then
						beam.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, math.clamp(0.2 + idleFade, 0, 1)),
							NumberSequenceKeypoint.new(1, 1),
						})
					elseif beam.Name == "GlowL" or beam.Name == "GlowR" then
						beam.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.5),
							NumberSequenceKeypoint.new(0.45, 0.72),
							NumberSequenceKeypoint.new(0.8, 0.92),
							NumberSequenceKeypoint.new(1, 1),
						})
					else
						beam.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.15),
							NumberSequenceKeypoint.new(0.45, 0.35),
							NumberSequenceKeypoint.new(0.75, 0.7),
							NumberSequenceKeypoint.new(1, 1),
						})
					end
				end
			end
		end
		-- Slide black conveyor Top textures while training (same speed / direction as arrows).
		if running then
			for _, tex in d.scrolls or {} do
				if not tex.Parent then
					continue
				end
				local axis = tex:GetAttribute("BeltScrollAxis")
				local sign = tex:GetAttribute("BeltScrollSign")
				if typeof(sign) ~= "number" then
					sign = -1
				end
				local offset = (phase * sign) % 512
				if axis == "U" then
					local tile = tex.StudsPerTileU
					tex.OffsetStudsU = if tile > 0 then offset % tile else offset
				else
					local tile = tex.StudsPerTileV
					tex.OffsetStudsV = if tile > 0 then offset % tile else offset
				end
			end
		end
	end
end)
trainingChanged()
