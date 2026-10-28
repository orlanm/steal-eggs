--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.ShopGui
-- Robux shop popup (Steal an Egg style): green studded header, dark studded body with sections
-- (Passes, Speed + treadmill upgrade, weekly Lucky Eggs, Cash), a right-hand section bar, the green
-- Shop button above Index, and the Gift Player picker. Everything is laid out at a fixed design size
-- and fitted to the screen with a UIScale, inside the device safe area (desktop, tablet and phone).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local ShopConfig = require(Shared.ShopConfig)
local Art = require(Shared.ShopArt)
local Economy = require(Shared.EconomyConfig)
local GameUI = require(Shared.GameUI)
local PopupLayout = require(Shared.PopupLayout)

local player = Players.LocalPlayer
local buyRemote = GameUI.remote("ShopBuy")

local PATTERN = "rbxassetid://113404314197204" -- Steal an Egg stud texture (also used by the Pet Index)
local ROBUX = utf8.char(0xE002)
local INK = Color3.fromRGB(14, 14, 20)
local WIDTH, HEIGHT = 700, 540 -- design size of the panel
local MIN_HEIGHT = 360 -- short screens (phones): the panel gets this short before it scales down
local NAV = 78 -- section bar to the right of the panel
local INNER = WIDTH - 44 -- scroll content width

-- Helpers ------------------------------------------------------------------------------------------

local function new(class: string, parent: Instance?, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(o: Instance, thickness: number?, color: Color3?)
	return new("UIStroke", o, {
		Color = color or INK,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function corner(o: Instance, radius: number?)
	return new("UICorner", o, { CornerRadius = UDim.new(0, radius or 10) })
end

local function studs(o: GuiObject, transparency: number?)
	return new("ImageLabel", o, {
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = PATTERN,
		ImageTransparency = transparency or 0.5,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(48, 48),
		ZIndex = o.ZIndex,
	})
end

local function gradient(o: Instance, colors: { Color3 }, rotation: number?)
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	return new("UIGradient", o, { Color = ColorSequence.new(keys), Rotation = rotation or 90 })
end

local function text(parent: Instance, value: string, size: number, props: { [string]: any }?): TextLabel
	local label = new("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansExtraBold,
		Text = value,
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, size + 6),
	})
	new("UIStroke", label, { Color = INK, Thickness = math.max(2, size / 11) })
	for k, v in props or {} do
		(label :: any)[k] = v
	end
	return label
end

local function icon(parent: Instance, art: string, props: { [string]: any }): ImageLabel
	local image = new("ImageLabel", parent, {
		BackgroundTransparency = 1,
		Image = (Art :: any)[art] or (if string.find(art, "^rbxassetid://") then art else ""),
		ScaleType = Enum.ScaleType.Fit,
	})
	for k, v in props do
		(image :: any)[k] = v
	end
	return image
end

-- A chunky studded button with a darker bottom edge.
local function button(parent: Instance, color: Color3, props: { [string]: any }): TextButton
	local b = new("TextButton", parent, {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 10)
	stroke(b, 3)
	studs(b, 0.85)
	new("UIGradient", b, {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	})
	return b
end

local function priceButton(parent: Instance, props: { [string]: any }): (TextButton, TextLabel)
	local b = button(parent, Color3.fromRGB(70, 214, 60), props)
	local label = text(b, "", 26, { Size = UDim2.fromScale(1, 1), TextScaled = false })
	return b, label
end

local function giftButton(parent: Instance, props: { [string]: any }): TextButton
	local b = button(parent, Color3.fromRGB(176, 84, 255), props)
	icon(b, "Gift", { Size = UDim2.fromScale(0.82, 0.82), Position = UDim2.fromScale(0.09, 0.07) })
	return b
end

local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 236, 80),
	Color3.fromRGB(90, 230, 110),
	Color3.fromRGB(70, 180, 255),
	Color3.fromRGB(170, 100, 255),
}

-- Card base: rounded, outlined, studded, coloured by a gradient.
local function card(parent: Instance, size: UDim2, colors: { Color3 }, rotation: number?): Frame
	local f = new("Frame", parent, { Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	corner(f, 14)
	stroke(f, 4)
	gradient(f, colors, rotation)
	studs(f, 0.82)
	return f
end

local function formatRobux(n: number): string
	return ROBUX .. " " .. tostring(n)
end

-- Live Robux prices from the dashboard (falls back to the config price).
local priceCache: { [string]: number } = {}
local function livePrice(id: number, infoType: Enum.InfoType, fallback: number, apply: (number) -> ())
	apply(fallback)
	if id <= 0 then
		return
	end
	local key = tostring(infoType) .. id
	if priceCache[key] then
		apply(priceCache[key])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
			priceCache[key] = info.PriceInRobux
			apply(info.PriceInRobux)
		end
	end)
end

-- Screen ---------------------------------------------------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")
local gui = new("ScreenGui", nil, {
	Name = "ShopGui",
	ResetOnSpawn = false,
	DisplayOrder = PopupLayout.DisplayOrder,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})
gui.Parent = playerGui
local blur = new("BlurEffect", Lighting, { Name = "ShopBlur", Size = 0, Enabled = false })

local backdrop = new("TextButton", gui, {
	Name = "Backdrop", -- invisible: closes the shop when the world around it is tapped
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
})

local root = new("Frame", gui, {
	Name = "Popup",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(WIDTH + NAV, HEIGHT),
	BackgroundTransparency = 1,
	Visible = false,
})
local rootScale = new("UIScale", root, { Scale = 1 })

local panel = new("Frame", root, {
	Name = "Panel",
	Size = UDim2.new(0, WIDTH, 1, 0),
	BackgroundColor3 = Color3.fromRGB(46, 46, 54),
	BorderSizePixel = 0,
})
corner(panel, 16)
stroke(panel, 5)
studs(panel, 0.86)

local header = new("Frame", panel, {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 78),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
})
corner(header, 16)
stroke(header, 4)
gradient(header, { Color3.fromRGB(140, 240, 80), Color3.fromRGB(40, 176, 46) })
studs(header, 0.75)
icon(header, "Cart", { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(14, 4) })
text(header, "Shop", 48, {
	Position = UDim2.fromOffset(92, 0),
	Size = UDim2.new(0, 300, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local close = button(header, Color3.fromRGB(240, 44, 44), {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(58, 54),
})
text(close, "X", 36, { Size = UDim2.fromScale(1, 1) })

local scroll = new("ScrollingFrame", panel, {
	Name = "Sections",
	Position = UDim2.fromOffset(12, 90),
	Size = UDim2.new(1, -18, 1, -100),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = Color3.fromRGB(200, 200, 210),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
})
new("UIListLayout", scroll, {
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
new("UIPadding", scroll, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16) })

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local sectionAnchors: { [string]: GuiObject } = {}

local function sectionTitle(name: string, color: Color3): TextLabel
	local label = text(scroll, "— " .. string.upper(name) .. " —", 34, {
		Name = name .. "Title",
		LayoutOrder = nextOrder(),
		Size = UDim2.fromOffset(INNER, 40),
		TextColor3 = color,
	})
	sectionAnchors[name] = label
	return label
end

local function row(height: number, padding: number?): Frame
	local f = new("Frame", scroll, {
		LayoutOrder = nextOrder(),
		Size = UDim2.fromOffset(INNER, height),
		BackgroundTransparency = 1,
	})
	new("UIListLayout", f, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, padding or 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return f
end

local function buy(kind: string, id: string?, extra: any?)
	buyRemote:FireServer(kind, id, extra)
end

-- Gift picker (filled in below) ---------------------------------------------------------------------
local openGift: (pass: ShopConfig.Pass) -> () = function() end

-- Pass state refreshers
local refreshers: { () -> () } = {}

local function passPrice(pass: ShopConfig.Pass, label: TextLabel, b: TextButton)
	local function apply(price: number)
		if player:GetAttribute("Pass" .. pass.Id) then
			label.Text = "OWNED"
			b.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		else
			label.Text = formatRobux(price)
			b.BackgroundColor3 = Color3.fromRGB(70, 214, 60)
		end
	end
	local current = pass.Robux
	local id = if pass.GamePassId > 0 then pass.GamePassId else pass.SelfProductId
	local infoType = if pass.GamePassId > 0 then Enum.InfoType.GamePass else Enum.InfoType.Product
	livePrice(id, infoType, pass.Robux, function(price)
		current = price
		apply(price)
	end)
	table.insert(refreshers, function()
		apply(current)
	end)
	player:GetAttributeChangedSignal("Pass" .. pass.Id):Connect(function()
		apply(current)
	end)
end

-- PASSES ------------------------------------------------------------------------------------------

sectionTitle("Passes", Color3.fromRGB(255, 222, 60))
local passRow = row(266, 18)
local PASS_COLORS: { [string]: { Color3 } } = {
	Growth = RAINBOW,
	Money = { Color3.fromRGB(255, 240, 110), Color3.fromRGB(255, 186, 30) },
}
for _, pass in ShopConfig.Passes do
	if pass.Section ~= "Passes" then
		continue
	end
	local c = card(passRow, UDim2.fromOffset((INNER - 18) / 2, 266), PASS_COLORS[pass.Id] or RAINBOW, if pass.Id == "Growth" then 45 else 90)
	c.Name = pass.Id
	text(c, pass.Name, 36, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40) })
	icon(c, pass.Icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.fromOffset(112, 112) })
	text(c, pass.Blurb, 22, { Position = UDim2.fromOffset(8, 164), Size = UDim2.new(1, -16, 0, 26) })
	local gift = giftButton(c, { Position = UDim2.new(0, 14, 1, -66), Size = UDim2.fromOffset(56, 52) })
	local price, label = priceButton(c, { Position = UDim2.new(0, 80, 1, -66), Size = UDim2.new(1, -94, 0, 52) })
	passPrice(pass, label, price)
	price.Activated:Connect(function()
		buy("Pass", pass.Id)
	end)
	gift.Activated:Connect(function()
		openGift(pass)
	end)
end

-- SPEED ---------------------------------------------------------------------------------------------

sectionTitle("Speed", Color3.fromRGB(80, 190, 255))
do
	local pass = ShopConfig.pass("Speed") :: ShopConfig.Pass
	local c = card(row(150), UDim2.fromOffset(INNER, 150), { Color3.fromRGB(110, 210, 255), Color3.fromRGB(30, 120, 240) })
	c.Name = "SpeedPass"
	icon(c, "Sneaker", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(150, 130) })
	local words = text(c, "DOUBLE Your SPEED", 34, {
		Position = UDim2.fromOffset(170, 14),
		Size = UDim2.new(1, -430, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	words.TextColor3 = Color3.fromRGB(255, 240, 120)
	text(c, "x1  ▶  x2", 40, {
		Position = UDim2.fromOffset(170, 66),
		Size = UDim2.new(1, -430, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local gift = giftButton(c, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -184, 0.5, 0), Size = UDim2.fromOffset(60, 56) })
	local price, label = priceButton(c, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(160, 56) })
	passPrice(pass, label, price)
	price.Activated:Connect(function()
		buy("Pass", pass.Id)
	end)
	gift.Activated:Connect(function()
		openGift(pass)
	end)
end

-- Treadmill upgrade card
local RARITY_TINT: { [string]: Color3 } = {
	Common = Color3.fromRGB(235, 235, 240),
	Uncommon = Color3.fromRGB(120, 255, 120),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(200, 120, 255),
	Legendary = Color3.fromRGB(255, 214, 60),
	Mythic = Color3.fromRGB(255, 90, 90),
	Cosmic = Color3.fromRGB(150, 110, 255),
	Secret = Color3.fromRGB(120, 120, 130),
	Eternal = Color3.fromRGB(255, 130, 220),
	Divine = Color3.fromRGB(255, 240, 140),
}
local refreshTreadmill: () -> () = function() end
do
	local c = card(row(196), UDim2.fromOffset(INNER, 196), { Color3.fromRGB(70, 70, 86), Color3.fromRGB(34, 34, 44) })
	c.Name = "Treadmill"
	local title = text(c, "UPGRADE TREADMILL!", 36, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 42) })
	title.TextColor3 = Color3.new(1, 1, 1)
	gradient(title, RAINBOW, 0)
	local before = icon(c, "Treadmill", { Position = UDim2.fromOffset(24, 46), Size = UDim2.fromOffset(120, 100) })
	text(c, "▶", 44, { Position = UDim2.fromOffset(150, 74), Size = UDim2.fromOffset(50, 46) })
	local after = icon(c, "Treadmill", { Position = UDim2.fromOffset(204, 46), Size = UDim2.fromOffset(120, 100) })
	local beforeName = text(c, "", 18, { Position = UDim2.fromOffset(4, 150), Size = UDim2.fromOffset(160, 40), TextWrapped = true })
	local afterName = text(c, "", 18, { Position = UDim2.fromOffset(184, 150), Size = UDim2.fromOffset(160, 40), TextWrapped = true })
	local gain = text(c, "", 22, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 56),
		Size = UDim2.fromOffset(270, 26),
		TextColor3 = Color3.fromRGB(120, 255, 120),
	})
	local price, label = priceButton(c, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 92), Size = UDim2.fromOffset(270, 56) })
	local cashLine = text(c, "", 18, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 154),
		Size = UDim2.fromOffset(270, 24),
		TextColor3 = Color3.fromRGB(150, 255, 120),
	})
	refreshTreadmill = function()
		local tier = player:GetAttribute("TreadmillTier")
		local current = Economy.tier(if typeof(tier) == "number" then tier else 1)
		local nextTier = Economy.nextTier(current.Tier)
		before.ImageColor3 = RARITY_TINT[current.Rarity] or Color3.new(1, 1, 1)
		beforeName.Text = current.Name
		if not nextTier then
			after.ImageColor3 = before.ImageColor3
			afterName.Text = "MAX"
			gain.Text = "Fully upgraded!"
			label.Text = "MAXED"
			price.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
			cashLine.Text = ""
			return
		end
		after.ImageColor3 = RARITY_TINT[nextTier.Rarity] or Color3.new(1, 1, 1)
		afterName.Text = nextTier.Name
		gain.Text = "Training x" .. current.Gain .. " ▶ x" .. nextTier.Gain
		price.BackgroundColor3 = Color3.fromRGB(70, 214, 60)
		local cash = player:GetAttribute("Cash")
		local affordable = typeof(cash) == "number" and cash >= nextTier.Cost
		label.Text = if affordable then Economy.formatCash(nextTier.Cost) else formatRobux(nextTier.Robux)
		cashLine.Text = if affordable then "or " .. formatRobux(nextTier.Robux) else "or " .. Economy.formatCash(nextTier.Cost) .. " cash"
	end
	price.Activated:Connect(function()
		buy("Treadmill")
	end)
end

-- VEHICLES ------------------------------------------------------------------------------------------

sectionTitle("Vehicles", Color3.fromRGB(90, 200, 255))
local vehicleRefreshers: { () -> () } = {}
for _, vehicle in ShopConfig.Vehicles do
	local c = card(row(210), UDim2.fromOffset(INNER, 210), { Color3.fromRGB(120, 220, 255), Color3.fromRGB(20, 110, 210) })
	c.Name = vehicle.Id
	icon(c, vehicle.Image, { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(220, 200) })
	local title = text(c, string.upper(vehicle.Name) .. "!", 36, {
		Position = UDim2.fromOffset(226, 10),
		Size = UDim2.new(1, -240, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.TextColor3 = Color3.fromRGB(255, 240, 120)
	text(c, vehicle.Blurb, 20, {
		Position = UDim2.fromOffset(226, 52),
		Size = UDim2.new(1, -240, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextScaled = false,
	})
	local cashButton, cashLabel = priceButton(c, { Position = UDim2.new(0, 226, 1, -76), Size = UDim2.new(0.5, -128, 0, 58) })
	cashButton.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
	local robuxButton, robuxLabel = priceButton(c, { Position = UDim2.new(0.5, 106, 1, -76), Size = UDim2.new(0.5, -120, 0, 58) })
	local robux = vehicle.Robux
	local function refresh()
		local owned = player:GetAttribute("Owns" .. vehicle.Id) == true
		local cash = player:GetAttribute("Cash")
		local affordable = typeof(cash) == "number" and cash >= vehicle.Cash
		cashLabel.Text = if owned then "OWNED" else Economy.formatCash(vehicle.Cash)
		cashButton.BackgroundColor3 = if owned or not affordable then Color3.fromRGB(120, 120, 130) else Color3.fromRGB(255, 196, 40)
		robuxButton.Visible = not owned
		cashButton.Size = if owned then UDim2.new(1, -240, 0, 58) else UDim2.new(0.5, -128, 0, 58)
		robuxLabel.Text = formatRobux(robux)
	end
	livePrice(vehicle.ProductId, Enum.InfoType.Product, vehicle.Robux, function(p)
		robux = p
		refresh()
	end)
	cashButton.Activated:Connect(function()
		if player:GetAttribute("Owns" .. vehicle.Id) ~= true then
			buy("Vehicle", vehicle.Id, true)
		end
	end)
	robuxButton.Activated:Connect(function()
		buy("Vehicle", vehicle.Id, false)
	end)
	player:GetAttributeChangedSignal("Owns" .. vehicle.Id):Connect(refresh)
	table.insert(vehicleRefreshers, refresh)
	table.insert(refreshers, refresh)
end

-- MOUNT STARS ---------------------------------------------------------------------------------------

sectionTitle("Mount Stars", Color3.fromRGB(255, 212, 59))
local starStock = text(scroll, "", 24, { LayoutOrder = nextOrder(), Size = UDim2.fromOffset(INNER, 28) })
local starRow = row(236)
local starButtons: { { offer: ShopConfig.Offer, button: TextButton } } = {}
local function badge(parent: Instance, label: string, color: Color3)
	local ribbon = new("Frame", parent, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(140, 28),
		Rotation = -4,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 8,
	})
	stroke(ribbon, 3)
	text(ribbon, label, 18, { Size = UDim2.fromScale(1, 1), ZIndex = 9 })
end
for _, o in ShopConfig.StarOffers do
	local c = card(starRow, UDim2.fromOffset((INNER - 28) / 3, 236), { Color3.fromRGB(255, 230, 110), Color3.fromRGB(240, 140, 20) })
	c.Name = o.Id
	text(c, o.Amount .. (if o.Amount == 1 then " STAR" else " STARS"), 30, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 36) })
	local count = math.min(o.Amount, 5)
	for i = 1, count do
		local spread = (i - (count + 1) / 2)
		local size = if count == 1 then 110 else 70
		icon(c, "Star", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, spread * (if count == 5 then 24 else 38), 0, 108 + math.abs(spread) * 7),
			Size = UDim2.fromOffset(size, size),
			Rotation = spread * 10,
			ZIndex = 2 + count - math.floor(math.abs(spread)),
		})
	end
	local price, label = priceButton(c, { Position = UDim2.new(0, 12, 1, -64), Size = UDim2.new(1, -24, 0, 52) })
	label.ZIndex = 3
	livePrice(o.ProductId, Enum.InfoType.Product, o.Robux, function(p)
		label.Text = formatRobux(p)
	end)
	price.Activated:Connect(function()
		buy("Stars", o.Id)
	end)
	table.insert(starButtons, { offer = o, button = price })
	if o.Best then
		badge(c, "BEST VALUE!", Color3.fromRGB(255, 60, 60))
	elseif o.Popular then
		badge(c, "POPULAR!", Color3.fromRGB(60, 150, 255))
	end
end
local starFoot = text(scroll, "", 22, {
	LayoutOrder = nextOrder(),
	Size = UDim2.fromOffset(INNER, 52),
	TextColor3 = Color3.fromRGB(255, 80, 80),
})

local function refreshStars()
	local left = player:GetAttribute("StarStock")
	left = if typeof(left) == "number" then left else ShopConfig.StarWeeklyStock
	local have = player:GetAttribute("Stars")
	have = if typeof(have) == "number" then have else 0
	starStock.Text = (if left <= 0 then "No more stock!" else "Only " .. left .. " Stars left this week!") .. "   You have " .. have .. " ★"
	for _, entry in starButtons do
		entry.button.BackgroundColor3 = if left >= entry.offer.Amount then Color3.fromRGB(70, 214, 60) else Color3.fromRGB(120, 120, 130)
	end
	local now = workspace:GetServerTimeNow()
	starFoot.Text = "Restocks in " .. ShopConfig.formatLeft(ShopConfig.restockAt(now) - now) .. "\nFeed a star to a pet in your pen to ride it!"
end

-- LUCKY EGGS ----------------------------------------------------------------------------------------

sectionTitle("Lucky Eggs", Color3.fromRGB(205, 130, 255))
local stockLabel = text(scroll, "", 24, { LayoutOrder = nextOrder(), Size = UDim2.fromOffset(INNER, 28) })
local luckyRow = row(236)
local luckyButtons: { { offer: ShopConfig.Offer, button: TextButton, label: TextLabel } } = {}
for _, o in ShopConfig.LuckyOffers do
	local c = card(luckyRow, UDim2.fromOffset((INNER - 28) / 3, 236), { Color3.fromRGB(200, 120, 255), Color3.fromRGB(110, 40, 210) })
	c.Name = o.Id
	text(c, o.Amount .. (if o.Amount == 1 then " EGG" else " EGGS"), 30, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 36) })
	-- 1, 3 or 5 eggs fanned out
	local count = math.min(o.Amount, 5)
	for i = 1, count do
		local spread = (i - (count + 1) / 2)
		local size = if count == 1 then 110 else 74
		icon(c, "LuckyEgg", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, spread * (if count == 5 then 26 else 40), 0, 108 + math.abs(spread) * 6),
			Size = UDim2.fromOffset(size, size),
			Rotation = spread * 8,
			ZIndex = 2 + count - math.floor(math.abs(spread)),
		})
	end
	local price, label = priceButton(c, { Position = UDim2.new(0, 12, 1, -64), Size = UDim2.new(1, -24, 0, 52) })
	label.ZIndex = 3
	livePrice(o.ProductId, Enum.InfoType.Product, o.Robux, function(p)
		label.Text = formatRobux(p)
	end)
	price.Activated:Connect(function()
		buy("Lucky", o.Id)
	end)
	table.insert(luckyButtons, { offer = o, button = price, label = label })
	if o.Best then
		local ribbon = new("Frame", c, {
			Name = "BestValue",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(140, 28),
			Rotation = -4,
			BackgroundColor3 = Color3.fromRGB(255, 60, 60),
			BorderSizePixel = 0,
			ZIndex = 8,
		})
		stroke(ribbon, 3)
		text(ribbon, "BEST VALUE!", 18, { Size = UDim2.fromScale(1, 1), ZIndex = 9 })
	end
end
local restockLabel = text(scroll, "", 24, {
	LayoutOrder = nextOrder(),
	Size = UDim2.fromOffset(INNER, 28),
	TextColor3 = Color3.fromRGB(255, 80, 80),
})

local function refreshLucky()
	local left = player:GetAttribute("LuckyStock")
	left = if typeof(left) == "number" then left else ShopConfig.LuckyWeeklyStock
	stockLabel.Text = "Weekly Stock: " .. left .. "/" .. ShopConfig.LuckyWeeklyStock
	for _, entry in luckyButtons do
		entry.button.BackgroundColor3 = if left >= entry.offer.Amount then Color3.fromRGB(70, 214, 60) else Color3.fromRGB(120, 120, 130)
	end
	local now = workspace:GetServerTimeNow()
	restockLabel.Text = "Restocks in " .. ShopConfig.formatLeft(ShopConfig.restockAt(now) - now)
end

-- CASH ----------------------------------------------------------------------------------------------

sectionTitle("Cash", Color3.fromRGB(120, 255, 110))
local cashRow = row(236)
local cashLabels: { { offer: ShopConfig.Offer, label: TextLabel } } = {}
for _, o in ShopConfig.CashOffers do
	local c = card(cashRow, UDim2.fromOffset((INNER - 28) / 3, 236), { Color3.fromRGB(150, 245, 110), Color3.fromRGB(40, 170, 60) })
	c.Name = o.Id
	local amount = text(c, "", 30, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 36) })
	local stacks = if o.Amount >= 360 then 3 elseif o.Amount >= 60 then 2 else 1
	for i = 1, stacks do
		local spread = i - (stacks + 1) / 2
		icon(c, "CashStack", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, spread * 34, 0, 106 - math.abs(spread) * 4),
			Size = UDim2.fromOffset(if stacks == 1 then 120 else 96, if stacks == 1 then 120 else 96),
			ZIndex = 2 + i,
		})
	end
	local price, label = priceButton(c, { Position = UDim2.new(0, 12, 1, -64), Size = UDim2.new(1, -24, 0, 52) })
	livePrice(o.ProductId, Enum.InfoType.Product, o.Robux, function(p)
		label.Text = formatRobux(p)
	end)
	price.Activated:Connect(function()
		buy("Cash", o.Id)
	end)
	table.insert(cashLabels, { offer = o, label = amount })
	if o.Best then
		local ribbon = new("Frame", c, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(140, 28),
			Rotation = -4,
			BackgroundColor3 = Color3.fromRGB(255, 60, 60),
			BorderSizePixel = 0,
			ZIndex = 8,
		})
		stroke(ribbon, 3)
		text(ribbon, "BEST VALUE!", 18, { Size = UDim2.fromScale(1, 1), ZIndex = 9 })
	end
end

local function refreshCash()
	local income = player:GetAttribute("PenIncome")
	for _, entry in cashLabels do
		entry.label.Text = "+" .. Economy.formatCash(ShopConfig.cashFor(entry.offer, if typeof(income) == "number" then income else 0))
	end
end

-- Section bar ---------------------------------------------------------------------------------------

local nav = new("Frame", root, {
	Name = "SectionBar",
	Position = UDim2.fromOffset(WIDTH + 12, 90),
	Size = UDim2.fromOffset(NAV - 12, 6 * 76),
	BackgroundTransparency = 1,
})
new("UIListLayout", nav, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local navButtons: { GuiObject } = {}

local function scrollTo(name: string)
	local anchor = sectionAnchors[name]
	if not anchor then
		return
	end
	local scale = math.max(rootScale.Scale, 0.01)
	local y = scroll.CanvasPosition.Y + (anchor.AbsolutePosition.Y - scroll.AbsolutePosition.Y) / scale - 4
	local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y / scale - scroll.AbsoluteWindowSize.Y / scale)
	TweenService:Create(scroll, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, math.clamp(y, 0, maxY)) }):Play()
end

for i, entry in { { "Tag", "Passes", Color3.fromRGB(255, 90, 90) }, { "Sneaker", "Speed", Color3.fromRGB(70, 170, 255) }, { ShopConfig.Vehicles[1].Image, "Vehicles", Color3.fromRGB(90, 200, 255) }, { "Star", "Mount Stars", Color3.fromRGB(255, 200, 40) }, { "LuckyEgg", "Lucky Eggs", Color3.fromRGB(176, 84, 255) }, { "CashStack", "Cash", Color3.fromRGB(70, 214, 60) } } do
	local b = button(nav, Color3.fromRGB(56, 56, 66), { Name = entry[2], LayoutOrder = i, Size = UDim2.fromOffset(NAV - 12, NAV - 12) })
	local edge = b:FindFirstChildOfClass("UIStroke") :: UIStroke
	edge.Color = entry[3]
	edge.Thickness = 4
	icon(b, entry[1], { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07) })
	b.Activated:Connect(function()
		scrollTo(entry[2])
	end)
	table.insert(navButtons, b)
end

-- Gift Player popup ---------------------------------------------------------------------------------

local giftRoot = new("Frame", gui, {
	Name = "GiftPlayer",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(480, 470),
	BackgroundColor3 = Color3.fromRGB(58, 26, 96),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
})
local giftScale = new("UIScale", giftRoot, { Scale = 1 })
corner(giftRoot, 16)
stroke(giftRoot, 5)
studs(giftRoot, 0.88)
local giftHeader = new("Frame", giftRoot, {
	Size = UDim2.new(1, 0, 0, 74),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 21,
})
corner(giftHeader, 16)
stroke(giftHeader, 4)
gradient(giftHeader, { Color3.fromRGB(214, 140, 255), Color3.fromRGB(140, 60, 230) })
studs(giftHeader, 0.75)
icon(giftHeader, "Gift", { Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(66, 66), ZIndex = 22 })
text(giftHeader, "Gift Player", 40, {
	Position = UDim2.fromOffset(84, 0),
	Size = UDim2.new(1, -170, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
})
local giftClose = button(giftHeader, Color3.fromRGB(240, 44, 44), {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(56, 52),
	ZIndex = 22,
})
text(giftClose, "X", 34, { Size = UDim2.fromScale(1, 1), ZIndex = 23 })
local giftWhat = text(giftRoot, "", 22, {
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 28),
	TextColor3 = Color3.fromRGB(255, 222, 90),
	ZIndex = 21,
})
local giftList = new("ScrollingFrame", giftRoot, {
	Position = UDim2.fromOffset(14, 114),
	Size = UDim2.new(1, -24, 1, -126),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 21,
})
new("UIListLayout", giftList, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", giftList, { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })
local giftEmpty = text(giftRoot, "No other players in this server yet", 22, {
	Position = UDim2.fromOffset(20, 200),
	Size = UDim2.new(1, -40, 0, 60),
	TextWrapped = true,
	Visible = false,
	ZIndex = 21,
})

local giftPass: ShopConfig.Pass? = nil
local headshots: { [number]: string } = {}

local function closeGift()
	giftRoot.Visible = false
	giftPass = nil
end

local function giftRows()
	for _, child in giftList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local count = 0
	local others = Players:GetPlayers()
	-- Studio solo test: show yourself so the row layout can be checked (the server refuses self-gifts)
	local preview = #others == 1 and RunService:IsStudio()
	for _, other in others do
		if other == player and not preview then
			continue
		end
		count += 1
		local r = new("Frame", giftList, {
			Name = other.Name,
			LayoutOrder = count,
			Size = UDim2.new(1, 0, 0, 84),
			BackgroundColor3 = Color3.fromRGB(92, 44, 150),
			BorderSizePixel = 0,
			ZIndex = 22,
		})
		corner(r, 12)
		stroke(r, 3)
		local face = new("ImageLabel", r, {
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(70, 70),
			BackgroundColor3 = Color3.fromRGB(140, 90, 210),
			Image = headshots[other.UserId] or "",
			ZIndex = 23,
		})
		corner(face, 35)
		stroke(face, 3)
		if not headshots[other.UserId] then
			task.spawn(function()
				local ok, url = pcall(function()
					return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok then
					headshots[other.UserId] = url
					face.Image = url
				end
			end)
		end
		text(r, other.DisplayName, 26, {
			Position = UDim2.fromOffset(88, 12),
			Size = UDim2.new(1, -230, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 23,
		})
		text(r, "@" .. other.Name, 18, {
			Position = UDim2.fromOffset(88, 46),
			Size = UDim2.new(1, -230, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.fromRGB(220, 200, 255),
			ZIndex = 23,
		})
		local select = button(r, Color3.fromRGB(70, 214, 60), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(124, 54),
			ZIndex = 23,
		})
		text(select, "Select", 26, { Size = UDim2.fromScale(1, 1), ZIndex = 24 })
		select.Activated:Connect(function()
			local pass = giftPass
			if pass then
				buy("Gift", pass.Id, other.UserId)
				closeGift()
			end
		end)
	end
	giftEmpty.Visible = count == 0
end

openGift = function(pass: ShopConfig.Pass)
	giftPass = pass
	giftWhat.Text = "Gift " .. pass.Name .. " to:"
	giftRows()
	giftRoot.Visible = true
end
giftClose.Activated:Connect(closeGift)
Players.PlayerAdded:Connect(function()
	if giftRoot.Visible then
		giftRows()
	end
end)
Players.PlayerRemoving:Connect(function()
	if giftRoot.Visible then
		task.defer(giftRows)
	end
end)

-- Shop HUD button (above Index) ---------------------------------------------------------------------

local hud = new("ScreenGui", playerGui, {
	Name = "ShopButton",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
})
local shopButton = button(hud, Color3.fromRGB(70, 214, 60), { Name = "Shop", Position = UDim2.new(0, 16, 0.47, -60), Size = UDim2.fromOffset(104, 50) })
icon(shopButton, "Cart", { Position = UDim2.fromScale(0.02, 0.08), Size = UDim2.fromScale(0.28, 0.84) })
local shopLabel = text(shopButton, "Shop", 22, { Position = UDim2.fromScale(0.30, 0), Size = UDim2.fromScale(0.68, 1), TextScaled = false, TextXAlignment = Enum.TextXAlignment.Left })
new("UIPadding", shopLabel, { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) })

-- Open / close / fit ----------------------------------------------------------------------------

local ticker: thread? = nil
local function setOpen(open: boolean)
	root.Visible = open
	backdrop.Visible = open
	blur.Enabled = open
	if not open then
		closeGift()
		blur.Size = 0
		if ticker then
			task.cancel(ticker)
			ticker = nil
		end
		return
	end
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 12 }):Play()
	rootScale.Scale *= 0.9
	TweenService:Create(rootScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = rootScale.Scale / 0.9 }):Play()
	for _, refresh in refreshers do
		refresh()
	end
	refreshTreadmill()
	refreshCash()
	refreshLucky()
	refreshStars()
	ticker = task.spawn(function()
		while true do
			task.wait(1)
			refreshLucky()
			refreshStars()
		end
	end)
end

shopButton.Activated:Connect(function()
	setOpen(not root.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
backdrop.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and root.Visible then
		if giftRoot.Visible then
			closeGift()
		else
			setOpen(false)
		end
	end
end)
for _, name in { "TreadmillTier", "Cash", "PenIncome" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if root.Visible then
			refreshTreadmill()
			refreshCash()
			for _, refresh in vehicleRefreshers do
				refresh()
			end
		end
	end)
end
player:GetAttributeChangedSignal("LuckyStock"):Connect(refreshLucky)
player:GetAttributeChangedSignal("StarStock"):Connect(refreshStars)
player:GetAttributeChangedSignal("Stars"):Connect(refreshStars)

-- other scripts open the shop on a section (the Star Handler's "View Stars")
local opener = new("BindableEvent", gui, { Name = "OpenSection" })
opener.Event:Connect(function(section: any)
	if not root.Visible then
		setOpen(true)
	end
	if typeof(section) == "string" then
		task.wait(0.05)
		scrollTo(section)
	end
end)

-- Fit the popup between the top bar and the hotbar: as big as fits, taller panels on tall screens.
local function fit()
	PopupLayout.fit(gui, root, rootScale, Vector2.new(WIDTH + NAV, MIN_HEIGHT), 1.15, function(scale, area)
		local h = math.clamp(area.Y / scale, MIN_HEIGHT, HEIGHT)
		-- section buttons shrink to fit the shorter bar
		local side = math.min(NAV - 12, math.floor((h - 100 - 50) / 6))
		nav.Size = UDim2.fromOffset(NAV - 12, h - 100)
		for _, b in navButtons do
			b.Size = UDim2.fromOffset(side, side)
		end
		return Vector2.new(WIDTH + NAV, h)
	end)
	PopupLayout.fit(gui, giftRoot, giftScale, Vector2.new(480, 470), 1.15)
	-- HUD button matches Index / slider width (tight around icon + label)
	local view = workspace.CurrentCamera.ViewportSize
	local w, h = math.clamp(view.X * 0.085, 90, 104), math.clamp(view.Y * 0.065, 40, 50)
	shopButton.Size = UDim2.fromOffset(w, h)
	shopButton.Position = UDim2.new(0, PopupLayout.navLeft(), 0.47, -(h + 10))
end
PopupLayout.watch(gui, fit)
refreshLucky()
refreshStars()
