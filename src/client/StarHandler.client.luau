--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.StarHandler
-- Talking to the Star Handler NPC (MountService spawns it on the plaza): Steal an Egg's dialog with a
-- typed-out speech panel, numbered choices (click / tap, or press 1-4) and "View Stars" opening the
-- Shop on its Mount Stars section. The NPC plays its Talk clip while a line is being said.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)
local MountConfig = require(Shared.MountConfig)
local Art = require(Shared.ShopArt)
local PopupLayout = require(Shared.PopupLayout)

local player = Players.LocalPlayer
local remote = GameUI.remote("StarHandler")
local H = MountConfig.Handler
local PATTERN = "rbxassetid://113404314197204"
local INK = Color3.fromRGB(14, 14, 20)
local YELLOW = MountConfig.StarColor
local WIDTH, HEIGHT = 520, 250
local WALK_AWAY = 24 -- studs from the NPC that close the dialog

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

local function stroke(o: Instance, thickness: number?)
	return new("UIStroke", o, {
		Thickness = thickness or 3,
		Color = INK,
		ApplyStrokeMode = if o:IsA("TextLabel") or o:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	})
end

local function corner(o: Instance, r: number?)
	new("UICorner", o, { CornerRadius = UDim.new(0, r or 12) })
end

local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "StarHandlerDialog",
	ResetOnSpawn = false,
	DisplayOrder = PopupLayout.DisplayOrder,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})

local root = new("Frame", gui, {
	Name = "Dialog",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 12),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundTransparency = 1,
	Visible = false,
})
local scale = new("UIScale", root, { Scale = 1 })

-- speech panel
local panel = new("TextButton", root, {
	Name = "Speech",
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, 0, 0, 100),
	BackgroundColor3 = Color3.fromRGB(52, 30, 96),
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
})
corner(panel, 14)
local edge = stroke(panel, 4)
edge.Color = YELLOW
new("ImageLabel", panel, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = PATTERN,
	ImageTransparency = 0.5,
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(48, 48),
})
new("ImageLabel", panel, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(68, 68),
	BackgroundTransparency = 1,
	Image = Art.Star,
})
local speech = new("TextLabel", panel, {
	Name = "Line",
	Position = UDim2.fromOffset(86, 12),
	Size = UDim2.new(1, -102, 1, -24),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 24,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	MaxVisibleGraphemes = 0,
})
stroke(speech, 2)
local more = new("TextLabel", panel, {
	Name = "More",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -4),
	Size = UDim2.fromOffset(26, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 22,
	TextColor3 = YELLOW,
	Text = "▼",
	Visible = false,
})
stroke(more, 2)

-- name tag on the panel's top edge
local nameTag = new("Frame", root, {
	Name = "NameTag",
	Position = UDim2.fromOffset(20, 0),
	Size = UDim2.fromOffset(180, 36),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 3,
})
corner(nameTag, 10)
stroke(nameTag, 3)
new("UIGradient", nameTag, {
	Color = ColorSequence.new(Color3.fromRGB(255, 232, 110), Color3.fromRGB(255, 166, 30)),
	Rotation = 90,
})
local nameLabel = new("TextLabel", nameTag, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = H.Name,
	ZIndex = 4,
})
stroke(nameLabel, 2)

-- numbered choices, two per row
local choices = new("Frame", root, {
	Name = "Choices",
	Position = UDim2.fromOffset(0, 132),
	Size = UDim2.new(1, 0, 0, 110),
	BackgroundTransparency = 1,
	Visible = false,
})
new("UIGridLayout", choices, {
	CellSize = UDim2.new(0.5, -8, 0, 48),
	CellPadding = UDim2.fromOffset(14, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
local CHOICE_COLORS = {
	Color3.fromRGB(255, 196, 40),
	Color3.fromRGB(150, 110, 255),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(240, 70, 60),
}
local choiceButtons: { TextButton } = {}
for i, label in H.Choices do
	local b = new("TextButton", choices, {
		Name = "Choice" .. i,
		LayoutOrder = i,
		BackgroundColor3 = CHOICE_COLORS[i] or Color3.fromRGB(90, 90, 100),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
	})
	corner(b, 12)
	stroke(b, 3)
	new("UIGradient", b, { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)), Rotation = 90 })
	local t = new("TextLabel", b, {
		Size = UDim2.new(1, -14, 1, 0),
		Position = UDim2.fromOffset(7, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 22,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = i .. ". " .. label,
	})
	new("UITextSizeConstraint", t, { MaxTextSize = 24 })
	stroke(t, 2)
	choiceButtons[i] = b
end

local function fit()
	local area = gui.AbsoluteSize
	if area.X < 1 then
		return
	end
	-- Sit lower on screen (slightly into the hotbar band) and keep the dialog compact.
	local at, free = PopupLayout.area(gui)
	scale.Scale = math.clamp(math.min(free.X / WIDTH, free.Y / HEIGHT), 0.4, 0.92)
	root.Position = UDim2.fromOffset(math.floor(at.X + free.X / 2), math.floor(at.Y + free.Y + 52))
end
PopupLayout.watch(gui, fit)

-- Dialog flow -----------------------------------------------------------------------------------------

local token = 0 -- bumps on close, cancelling a running conversation
local typing = false
local skipTyping = false
local advance: BindableEvent = Instance.new("BindableEvent")
local picked: BindableEvent = Instance.new("BindableEvent")
local met = false

local function npcPosition(): Vector3?
	local npc = Workspace:FindFirstChild("StarHandler", true)
	local anchor = npc and npc:FindFirstChild("TalkAnchor")
	return if anchor and anchor:IsA("BasePart") then anchor.Position else nil
end

-- Type a line out. waitTap: wait for a click/tap before returning.
local function say(line: string, waitTap: boolean)
	local my = token
	remote:FireServer("talk")
	speech.Text = line
	speech.MaxVisibleGraphemes = 0
	more.Visible = false
	typing = true
	skipTyping = false
	local n = utf8.len(line) or #line
	local shown = 0
	while shown < n and my == token do
		if skipTyping then
			shown = n
		else
			shown += 1
		end
		speech.MaxVisibleGraphemes = shown
		task.wait(0.022)
	end
	typing = false
	speech.MaxVisibleGraphemes = -1
	if waitTap and my == token then
		more.Visible = true
		advance.Event:Wait()
		more.Visible = false
	end
end

local function close()
	token += 1
	root.Visible = false
	choices.Visible = false
	advance:Fire()
	picked:Fire(0)
end

local openShop: () -> ()
openShop = function()
	local shopGui = player.PlayerGui:FindFirstChild("ShopGui")
	local opener = shopGui and shopGui:FindFirstChild("OpenSection")
	if opener and opener:IsA("BindableEvent") then
		opener:Fire("Mount Stars")
	end
end

local function ask(line: string): number
	say(line, false)
	choices.Visible = true
	local choice = picked.Event:Wait()
	choices.Visible = false
	return choice
end

local function lines(list: { string })
	for _, line in list do
		say(line, true)
	end
end

local function converse()
	token += 1
	local my = token
	root.Visible = true
	choices.Visible = false
	scale.Scale *= 0.9
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = scale.Scale / 0.9 }):Play()
	local first = H.Greeting
	if not met then
		met = true
		for i = 1, #H.FirstMeeting - 1 do
			say(H.FirstMeeting[i], true)
			if my ~= token then
				return
			end
		end
		first = H.FirstMeeting[#H.FirstMeeting]
	end
	local prompt = first
	while my == token do
		local choice = ask(prompt)
		if my ~= token or choice == 0 then
			return
		end
		local label = H.Choices[choice]
		if label == "View Stars" then
			say(H.ViewStars, true)
			if my == token then
				close()
				openShop()
			end
			return
		elseif label == "What is a Star?" then
			lines(H.WhatIsStar)
		elseif label == "Star Drop Event?" then
			lines(H.StarDrop)
		else
			say(H.Bye, false)
			task.wait(1.6)
			if my == token then
				close()
			end
			return
		end
		prompt = H.AnythingElse
	end
end

panel.Activated:Connect(function()
	if typing then
		skipTyping = true
	else
		advance:Fire()
	end
end)
for i, b in choiceButtons do
	b.Activated:Connect(function()
		if choices.Visible then
			picked:Fire(i)
		end
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not root.Visible or processed then
		return
	end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	local index = table.find(keys, input.KeyCode)
	if index and choices.Visible then
		picked:Fire(index)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		close()
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		if typing then
			skipTyping = true
		else
			advance:Fire()
		end
	end
end)

remote.OnClientEvent:Connect(function(what: any)
	if what == "open" and not root.Visible then
		task.spawn(converse)
	end
end)

-- walking away ends the conversation
task.spawn(function()
	while true do
		task.wait(0.5)
		if root.Visible then
			local at = npcPosition()
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if at and hrp and (hrp.Position - at).Magnitude > WALK_AWAY then
				close()
			end
		end
	end
end)
