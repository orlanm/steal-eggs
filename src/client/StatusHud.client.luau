--!strict
-- Bottom corners: speed, cash, and the countdown until night.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NightCycle = require(game.ReplicatedStorage.BabyBeastsShared.NightCycle)
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local Progress = require(game.ReplicatedStorage.BabyBeastsShared.ProgressionConfig)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)
local UIArt = require(game.ReplicatedStorage.BabyBeastsShared:WaitForChild("UIArt")) :: any

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "CornerHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = playerGui

local function stroke(label: TextLabel, thickness: number)
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = thickness
	outline.Parent = label
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.AutomaticSize = Enum.AutomaticSize.XY
	item.Font = Enum.Font.BuilderSansBold
	item.TextSize = size
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = text
	stroke(item, 2)
	item.Parent = parent
	return item
end

local function hudIcon(parent: Instance, asset: string, size: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "HudIcon"
	icon.BackgroundTransparency = 1
	icon.Image = asset
	icon.Size = UDim2.fromOffset(size, size)
	icon.Parent = parent
	return icon
end

local function row(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local stack = Instance.new("Frame")
stack.Name = "LeftStack"
stack.AnchorPoint = Vector2.new(0, 1)
stack.Position = UDim2.new(0, 18, 1, -22)
stack.BackgroundTransparency = 1
stack.AutomaticSize = Enum.AutomaticSize.XY
stack.Parent = gui
local stackLayout = Instance.new("UIListLayout")
stackLayout.FillDirection = Enum.FillDirection.Vertical
stackLayout.Padding = UDim.new(0, 4)
stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
stackLayout.Parent = stack
-- phones: shrink and drop the stack so it is no taller than the backpack hotbar beside it
local stackScale = Instance.new("UIScale")
stackScale.Parent = stack
local HOTBAR = 66 -- Roblox hotbar height (PopupLayout.HotbarHeight) minus a little air
local function fitStack()
	local view = Workspace.CurrentCamera.ViewportSize
	local small = math.min(view.X, view.Y) < 600
	stack.Position = if small then UDim2.new(0, 12, 1, -2) else UDim2.new(0, 18, 1, -22)
	local natural = stack.AbsoluteSize.Y / math.max(stackScale.Scale, 0.01)
	stackScale.Scale = if small and natural > 0 then math.min(1, HOTBAR / natural) else 1
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStack)
stack:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStack)
task.defer(fitStack)

local speedRow = row(stack)
speedRow.LayoutOrder = 1
hudIcon(speedRow, UIArt.Sneaker, 42)
local speedText = label(speedRow, "0", 34, Color3.new(1, 1, 1))

local cashRow = row(stack)
cashRow.LayoutOrder = 2
hudIcon(cashRow, UIArt.CashStack, 42)
local cashText = label(cashRow, "$0", 30, Color3.fromRGB(90, 230, 70))

local nightRow = row(gui)
nightRow.Name = "NightClock"
nightRow.AnchorPoint = Vector2.new(1, 1)
nightRow.Position = UDim2.new(1, -18, 1, -22)
hudIcon(nightRow, UIArt.Moon, 38)
local nightText = label(nightRow, "in 4m 50s", 28, Color3.new(1, 1, 1))

local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes > 0 then
		return "in " .. minutes .. "m " .. secs .. "s"
	end
	return "in " .. secs .. "s"
end

local function refreshStats()
	if player:GetAttribute("SpeedLoadError") then
		speedText.Text = "—"
	elseif not player:GetAttribute("SpeedLoaded") then
		speedText.Text = "..."
	else
		speedText.Text = Progress.format(player:GetAttribute("Speed") or 0)
	end
	cashText.Text = Economy.formatCash(player:GetAttribute("Cash") or 0)
end

for _, attr in { "Speed", "SpeedLoaded", "SpeedLoadError", "Cash" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshStats)
end
refreshStats()

local lastPhase = ""
local function refreshClock()
	local now = Workspace:GetServerTimeNow()
	local phase, remain = NightCycle.state(now)
	if phase == "Night" then
		nightText.Text = "Night"
	else
		nightText.Text = clockText(remain)
	end
	if phase ~= lastPhase then
		lastPhase = phase
		if phase == "Night" then
			Lighting.ClockTime = 0.2
			Lighting.Brightness = 1
		else
			Lighting.ClockTime = 14.4
			Lighting.Brightness = 2
		end
	end
end

RunService.Heartbeat:Connect(refreshClock)

local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "NightBanner"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = true
bannerGui.DisplayOrder = 40
bannerGui.Parent = playerGui

local function showBanner(text: string, color: Color3)
	local old = bannerGui:FindFirstChild("Banner")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Banner"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 18)
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	holder.BackgroundTransparency = 0.15
	holder.Parent = bannerGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = holder
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AutomaticSize = Enum.AutomaticSize.XY
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 28
	title.TextColor3 = color
	title.Text = text
	stroke(title, 2)
	title.Parent = holder
	task.delay(4.5, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- Special egg announcements (Steal an Egg): one top-center banner per Secret / Eternal / Divine spawn.
-- Up to RARE_STACK show at once; the rest wait in a queue and cycle in, faster when it is long
-- (Admin Abuse floods). Every one is also written to the chat log, with no limit.
local RARE_STACK = 3
local RARE_HOLD = 4 -- seconds on screen
local RARE_HOLD_RUSH = 2 -- seconds on screen while more than RARE_STACK are waiting
local rareQueue: { { text: string, chat: string, color: Color3 } } = {}
local rareShowing = 0
local rareOrder = 0

local rareStack = Instance.new("Frame")
rareStack.Name = "RareSpawns"
rareStack.BackgroundTransparency = 1
rareStack.AnchorPoint = Vector2.new(0.5, 0)
rareStack.Position = UDim2.new(0.5, 0, 0, 78)
rareStack.Size = UDim2.new(0.9, 0, 0, 160)
rareStack.Parent = bannerGui
local rareLayout = Instance.new("UIListLayout")
rareLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rareLayout.Padding = UDim.new(0, 6)
rareLayout.SortOrder = Enum.SortOrder.LayoutOrder
rareLayout.Parent = rareStack

local pumpRares: () -> ()
local function showRare(item: { text: string, chat: string, color: Color3 })
	rareShowing += 1
	rareOrder += 1
	local holder = Instance.new("Frame")
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	holder.BackgroundTransparency = 0.15
	holder.LayoutOrder = rareOrder
	holder.Parent = rareStack
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = holder
	local edge = Instance.new("UIStroke")
	edge.Color = item.color
	edge.Thickness = 2
	edge.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = Enum.Font.BuilderSansBold
	-- phones: smaller, so three stacked banners still leave the view clear
	local camera = Workspace.CurrentCamera
	label.TextSize = math.clamp(math.floor((if camera then camera.ViewportSize.Y else 720) * 0.03), 14, 22)
	label.TextColor3 = item.color
	label.Text = item.text
	stroke(label, 2)
	label.Parent = holder
	local hold = if #rareQueue > 0 then RARE_HOLD_RUSH else RARE_HOLD
	task.delay(hold, function()
		holder:Destroy()
		rareShowing -= 1
		pumpRares()
	end)
end

pumpRares = function()
	while rareShowing < RARE_STACK and #rareQueue > 0 do
		showRare(table.remove(rareQueue, 1) :: any)
	end
end

local function chatLine(text: string, color: Color3)
	local rich = string.format('<font color="#%s">%s</font>', color:ToHex(), text)
	local ok = pcall(function()
		local TextChatService = game:GetService("TextChatService")
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			error("legacy chat")
		end
		local channels = TextChatService:WaitForChild("TextChannels", 5)
		local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
		;(channel :: TextChannel):DisplaySystemMessage(rich)
	end)
	if not ok then
		pcall(function()
			game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = text, Color = color, Font = Enum.Font.BuilderSansBold })
		end)
	end
end

local function announceRares(rares: any, delay: number)
	if typeof(rares) ~= "table" then
		return
	end
	local items = {}
	for _, info in ipairs(rares :: { any }) do
		if typeof(info) == "table" then
			local rarity = if typeof(info.rarity) == "string" then info.rarity else "Secret"
			local eggName = if typeof(info.name) == "string" then info.name else "Egg"
			local biome = if typeof(info.biome) == "string" then info.biome else "a biome"
			table.insert(items, {
				text = string.upper(rarity) .. "  " .. eggName .. " spawned in " .. biome .. "!",
				chat = "[" .. string.upper(rarity) .. "] " .. eggName .. " spawned in " .. biome .. "!",
				color = EggScale.rarityColor(rarity),
			})
		end
	end
	if #items == 0 then
		return
	end
	-- chat: every line at once
	for _, item in items do
		chatLine(item.chat, item.color)
	end
	task.delay(delay, function()
		for _, item in items do
			table.insert(rareQueue, item)
		end
		pumpRares()
	end)
end

local notice = GameUI.remote("NightNotice")
notice.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.reset == true then
		showBanner("ALL EGGS RESET", Color3.fromRGB(255, 244, 210))
		announceRares(payload.rares, 1.2)
	elseif payload.rares then
		announceRares(payload.rares, 0)
	end
end)
