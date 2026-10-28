--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.EggShopGui
-- Egg Shop (restock rotation), Event eggs, Limited (Robux) eggs and Dr. Scramble's trade-in.
-- Opened from the plaza stands (EggShopPrompt / TradeInPrompt) or the EGGS button.
-- Also shows EggAnnouncement banners (admin drops, Admin Abuse, events, purchases).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIArt = require(game.ReplicatedStorage.BabyBeastsShared:WaitForChild("UIArt")) :: any -- place-saved Blender icon set
local PopupLayout = require(game.ReplicatedStorage.BabyBeastsShared:WaitForChild("PopupLayout"))
local player = Players.LocalPlayer
local shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local Economy = require(shared:WaitForChild("EconomyConfig"))
local EggScale = require(shared:WaitForChild("EggScale"))
local GameUI = require(shared:WaitForChild("GameUI"))
local stateRemote = shared:WaitForChild("EggShopState") :: RemoteFunction
local buyRemote = shared:WaitForChild("EggShopBuy") :: RemoteFunction
local announce = GameUI.remote("EggAnnouncement")

local GOLD = Color3.fromRGB(255, 196, 64)
local INK = Color3.fromRGB(236, 244, 250)
local MUTED = Color3.fromRGB(170, 188, 210)
local GOOD = Color3.fromRGB(140, 235, 190)
local BAD = Color3.fromRGB(255, 170, 140)
local CATEGORY_COLOR: { [string]: Color3 } = {
	Biome = Color3.fromRGB(150, 220, 120),
	Event = Color3.fromRGB(255, 140, 40),
	Shop = GOLD,
	Limited = Color3.fromRGB(120, 230, 255),
	Admin = Color3.fromRGB(255, 90, 90),
	AdminOnly = Color3.fromRGB(255, 90, 90),
	TradeIn = Color3.fromRGB(110, 255, 150),
}

local playerGui = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = value
	label.Parent = parent
	return label
end

local function button(parent: Instance, value: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.BuilderSansBold
	b.TextSize = 15
	b.TextColor3 = Color3.fromRGB(20, 24, 32)
	b.Text = value
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then
		return string.format("%dd %dh", seconds // 86400, (seconds % 86400) // 3600)
	elseif seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function percent(value: number): string
	if value >= 1 then
		return string.format("%.1f%%", value)
	end
	return string.format("%.3g%%", value)
end

local function rarityOf(eggName: string): string
	return EggScale.rarityOf(eggName)
end

-- Window -------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "EggShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = PopupLayout.DisplayOrder
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "Window"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.86, 0)
card.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
card.Parent = gui
corner(card, 14)
-- studded plate like the other menus (InterfaceStyle keeps "Studs" images on the shared texture)
local studs = Instance.new("ImageLabel")
studs.Name = "Studs"
studs.BackgroundTransparency = 1
studs.Size = UDim2.fromScale(1, 1)
studs.Image = UIArt.Studs
studs.ImageTransparency = 0.62
studs.ScaleType = Enum.ScaleType.Tile
studs.TileSize = UDim2.fromOffset(48, 48)
studs.ZIndex = 0
studs.Parent = card
corner(studs, 14)
local sizeCap = Instance.new("UISizeConstraint")
sizeCap.MaxSize = Vector2.new(760, 600)
sizeCap.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Transparency = 0.35
stroke.Parent = card

local title = text(card, "Egg Shop", 22, Color3.fromRGB(255, 226, 170), true)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -70, 0, 30)
title.Position=UDim2.fromOffset(52,10);title.Size=UDim2.new(1,-106,0,32)
local titleIcon=Instance.new("ImageLabel");titleIcon.Name="PopupIcon";titleIcon.BackgroundTransparency=1;titleIcon.Image=UIArt.LuckyEgg;titleIcon.Position=UDim2.fromOffset(12,8);titleIcon.Size=UDim2.fromOffset(34,34);titleIcon.Parent=card
local header=Instance.new("ImageLabel");header.Name="HeaderArtwork";header.BackgroundTransparency=1;header.Image=UIArt.Header;header.ImageTransparency=.7;header.Size=UDim2.new(1,0,0,48);header.ZIndex=0;header.Parent=card

local close = button(card, "X", Color3.fromRGB(48, 58, 78))
close.TextColor3 = INK
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 10)
close.Size = UDim2.fromOffset(36, 32)

local info = text(card, "", 14, GOOD, true)
info.Position = UDim2.fromOffset(16, 42)
info.Size = UDim2.new(1, -32, 0, 20)

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(12, 66)
tabs.Size = UDim2.new(1, -24, 0, 34)
tabs.Parent = card
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 106)
list.Size = UDim2.new(1, -24, 1, -140)
list.BackgroundColor3 = Color3.fromRGB(12, 18, 32)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = card
corner(list, 10)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = list

local status = text(card, "", 15, INK, false)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 16, 1, -4)
status.Size = UDim2.new(1, -32, 0, 28)

local TABS = { "Shop", "Event", "Limited", "Trade-In" }
local current = "Shop"
local data: any = nil
local busy = false
local tabButtons: { [string]: TextButton } = {}

local function setStatus(message: string, ok: boolean?)
	status.Text = message
	status.TextColor3 = if ok == nil then INK elseif ok then GOOD else BAD
end

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

-- One row: egg name + tags on the left, chances below, an action button on the right.
local function row(order: number, heading: string, tagText: string, tagColor: Color3, lines: { string }, action: string?, actionColor: Color3?, onAction: (() -> ())?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(28, 40, 62)
	frame.Size = UDim2.new(1, -4, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = list
	corner(frame, 8)
	local inner = Instance.new("UIPadding")
	inner.PaddingTop = UDim.new(0, 8)
	inner.PaddingBottom = UDim.new(0, 8)
	inner.PaddingLeft = UDim.new(0, 10)
	inner.PaddingRight = UDim.new(0, 10)
	inner.Parent = frame
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, if action then -128 else 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Parent = frame
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 2)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body
	local head = text(body, heading, 17, INK, true)
	head.Size = UDim2.new(1, 0, 0, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = 1
	local tag = text(body, tagText, 13, tagColor, true)
	tag.Size = UDim2.new(1, 0, 0, 0)
	tag.AutomaticSize = Enum.AutomaticSize.Y
	tag.LayoutOrder = 2
	for index, line in lines do
		local l = text(body, line, 13, MUTED, false)
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.LayoutOrder = 2 + index
	end
	if action then
		local b = button(frame, action, actionColor or GOLD)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, 0, 0.5, 0)
		b.Size = UDim2.fromOffset(118, 40)
		if onAction then
			b.Activated:Connect(onAction)
		else
			b.AutoButtonColor = false
		end
	end
	return frame
end

local function note(order: number, message: string)
	local label = text(list, message, 14, MUTED, false)
	label.Size = UDim2.new(1, -4, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = order
end

local function dropLines(drops: { any }): { string }
	local lines = {}
	for _, drop in drops do
		table.insert(lines, string.format("%s  %s  (%s)", percent(drop.chance), drop.name, rarityOf(drop.name)))
	end
	return lines
end

local render: () -> ()

local function request(kind: string, id: any, amount: any)
	if busy then
		return
	end
	busy = true
	setStatus("...")
	local ok, result = pcall(function()
		return buyRemote:InvokeServer(kind, id, amount)
	end)
	busy = false
	if not ok or typeof(result) ~= "table" then
		setStatus("Request failed. Try again.", false)
		return
	end
	setStatus(tostring(result.message or ""), result.ok == true)
	if typeof(result.state) == "table" then
		data = result.state
		render()
	end
end

local function renderShop()
	note(0, "Stock rotates on every server at the same time. Each egg has limited stock per restock.")
	for _, offer in data.offers do
		local heading = offer.name .. (if offer.rare then "  ★ RARE SLOT" else "")
		local tag = string.format("%s  •  %s  •  %d/%d left", offer.category, if offer.container then "Mystery egg" else rarityOf(offer.name), offer.left, offer.stock)
		local lines = if offer.container then dropLines(offer.drops) else {}
		local soldOut = offer.left <= 0
		row(
			offer.slot,
			heading,
			tag,
			CATEGORY_COLOR[offer.category] or MUTED,
			lines,
			if soldOut then "SOLD OUT" else Economy.formatCash(offer.price),
			if soldOut then Color3.fromRGB(80, 88, 104) elseif offer.rare then Color3.fromRGB(255, 120, 210) else GOLD,
			if soldOut then nil else function()
				request("Stock", offer.slot)
			end
		)
	end
end

local function renderEvent()
	if #data.events == 0 then
		note(0, "No event is live right now. Event eggs are vaulted until their event returns.")
		return
	end
	for index, event in data.events do
		local lines = dropLines(event.drops)
		table.insert(lines, 1, "Also spawning in nests: " .. table.concat(event.hosts, ", ") .. " (and rarely anywhere)")
		row(index, event.egg, string.format("%s  •  ends in %s", event.name, clock(event.endsAt - os.time())), event.color, lines, Economy.formatCash(event.price), event.color, function()
			request("Event", event.id)
		end)
	end
end

local function renderLimited()
	note(0, "Limited eggs are Robux-only and leave the shop for good when their timer runs out.")
	local order = 1
	for _, item in data.limited do
		local lines = dropLines(item.drops)
		local tag = if item.live then "LIMITED  •  leaves in " .. clock(item.endsAt - os.time()) else "VAULTED"
		row(order, item.id, tag, if item.live then CATEGORY_COLOR.Limited else Color3.fromRGB(120, 120, 130), lines, nil, nil, nil)
		order += 1
		if item.live then
			for _, offer in item.offers do
				row(order, string.format("%s x%d", item.id, offer.amount), if offer.ready then "Robux" else "Not on the dashboard yet", MUTED, {}, string.format("R$ %d", offer.robux), CATEGORY_COLOR.Limited, function()
					request("Limited", item.id, offer.amount)
				end)
				order += 1
			end
		end
	end
end

local function renderTrade()
	local trade = data.trade
	note(0, "Dr. Scramble takes these three pets from your pen and gives you an egg from " .. trade.banner .. ". New recipe in " .. clock(trade.endsAt - data.now) .. ".")
	local ready = true
	for index, pet in trade.pets do
		local has = pet.have > 0
		ready = ready and has
		row(index, pet.name, if has then "In your pen (" .. pet.have .. ")" else "Not in your pen", if has then GOOD else BAD, {}, nil, nil, nil)
	end
	row(10, trade.banner, "Reward", CATEGORY_COLOR.TradeIn, dropLines(trade.drops), if ready then "TRADE" else "NEED PETS", if ready then CATEGORY_COLOR.TradeIn else Color3.fromRGB(80, 88, 104), if ready then function()
		request("Trade")
	end else nil)
end

render = function()
	clear()
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == current then GOLD else Color3.fromRGB(48, 58, 78)
		b.TextColor3 = if name == current then Color3.fromRGB(20, 24, 32) else INK
	end
	title.Text = if current == "Trade-In" then "Dr. Scramble's Trade-In" else "Egg Shop"
	if not data then
		note(0, "Loading...")
		return
	end
	if current == "Shop" then
		renderShop()
	elseif current == "Event" then
		renderEvent()
	elseif current == "Limited" then
		renderLimited()
	else
		renderTrade()
	end
end

for index, name in TABS do
	local b = button(tabs, name, Color3.fromRGB(48, 58, 78))
	b.Name = "Tab" .. string.gsub(name, "%-", "")
	b.Size = UDim2.new(0.25, -5, 1, 0)
	b.LayoutOrder = index
	tabButtons[name] = b
	b.Activated:Connect(function()
		current = name
		render()
	end)
end

local function refresh()
	local ok, result = pcall(function()
		return stateRemote:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		data = result
	else
		setStatus("Could not reach the shop.", false)
	end
	render()
end

local function open(tab: string)
	current = tab
	gui.Enabled = true
	setStatus("")
	render()
	task.spawn(refresh)
end

close.Activated:Connect(function()
	gui.Enabled = false
end)

-- fill the space between the top bar and the hotbar (capped by sizeCap on big screens)
PopupLayout.watch(gui, function()
	local at, area = PopupLayout.area(gui)
	card.Position = UDim2.fromOffset(math.floor(at.X + area.X / 2), math.floor(at.Y + area.Y / 2))
	card.Size = UDim2.fromOffset(area.X, area.Y)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "EggShopPrompt" then
		open("Shop")
	elseif prompt.Name == "TradeInPrompt" then
		open("Trade-In")
	end
end)

-- header: cash + restock countdown; refetch when the stock or recipe rotates
local lastWindow = -1
RunService.Heartbeat:Connect(function()
	if not gui.Enabled or not data then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local cash = player:GetAttribute("Cash")
	info.Text = string.format(
		"Cash %s     Restock in %s",
		Economy.formatCash(if typeof(cash) == "number" then cash else data.cash),
		clock(data.restockAt - now)
	)
	local window = math.floor(now / 30)
	if window ~= lastWindow then
		lastWindow = window
		if now >= data.restockAt or now >= data.trade.endsAt then
			task.spawn(refresh)
		end
	end
end)

-- Announcements ------------------------------------------------------------------------------------

local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "EggAnnouncements"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = true
bannerGui.DisplayOrder = 41
bannerGui.Parent = playerGui
local stack = Instance.new("Frame")
stack.Name = "Frame"
stack.BackgroundTransparency = 1
stack.Active = false
stack.AnchorPoint = Vector2.new(0.5, 0)
stack.Position = UDim2.new(0.5, 0, 0, 206) -- under the rare-spawn banners (StatusHud)
-- Height grows with banners only — a fixed 200px empty hit-box was covering the Index button.
stack.Size = UDim2.new(0.9, 0, 0, 0)
stack.AutomaticSize = Enum.AutomaticSize.Y
stack.Parent = bannerGui
local stackLayout = Instance.new("UIListLayout")
stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
stackLayout.Padding = UDim.new(0, 6)
stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
stackLayout.Parent = stack
local serial = 0

announce.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" then
		return
	end
	serial += 1
	local holder = Instance.new("Frame")
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	holder.BackgroundTransparency = 0.15
	holder.LayoutOrder = serial
	holder.Parent = stack
	corner(holder, 10)
	local inner = Instance.new("UIPadding")
	inner.PaddingTop = UDim.new(0, 8)
	inner.PaddingBottom = UDim.new(0, 8)
	inner.PaddingLeft = UDim.new(0, 14)
	inner.PaddingRight = UDim.new(0, 14)
	inner.Parent = holder
	local label = text(holder, payload.text, if payload.small then 16 else 24, if typeof(payload.color) == "Color3" then payload.color else GOLD, true)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.TextWrapped = false
	label.TextStrokeTransparency = 0.4
	task.delay(if payload.small then 6 else 5, function()
		holder:Destroy()
	end)
end)
