--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.PenPanels
-- Steal an Egg style pen panels. Two square HUD buttons on the right edge (vertically centred):
--   Egg  -> "Growing Eggs": every egg growing in your pen with a progress bar + time left, a Skip
--           button (developer product, only while > PenConfig.MinSkipSeconds left), Open once ready,
--           and Grow All (developer product) in the header. Badge = eggs ready to open.
--   Paw  -> "N/M Active": the hatched pets earning in your pen, each on a sun-ray card with Unequip,
--           then "Backpack": unequipped pets with Hold (the hotbar is hidden while you hold a pet)
--           (the pet goes into your hands as a Tool; click your pen to put it back - PenPlacement),
--           "+1 EQUIP [$cost]" (cash) and Equip Best. Badge = held pets while a slot is free.
-- Panels slide in from the right edge over the buttons; their ">" tab slides them back. Server: PenPets (remotes PenPets / GrowingEggs).
-- Data comes from the pen models (TankBeasts attributes) and the StoredPets player attribute.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)
local GameEgg = require(Shared.GameEgg)
local EggVisual = require(Shared.EggVisual)
local EggScale = require(Shared.EggScale)
local PetRig = require(Shared.PetRig)
local PetCatalog = require(Shared.PetCatalog)
local Economy = require(Shared.EconomyConfig)
local PenConfig = require(Shared.PenConfig)
local PopupLayout = require(Shared.PopupLayout)
local Art = require(Shared.UIArt)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local petsRemote = GameUI.remote("PenPets")
local eggsRemote = GameUI.remote("GrowingEggs")

local PATTERN = "rbxassetid://113404314197204" -- stud texture (ShopGui / Pet Index)
local SUN_RAYS = "rbxassetid://112100775067286" -- _tools/ui/sunrays.py (white, tinted by rarity)
local ROBUX = utf8.char(0xE002)
local INK = Color3.fromRGB(14, 14, 20)
local BODY = Color3.fromRGB(43, 43, 53)
local ROW = Color3.fromRGB(62, 62, 76)
local WIDTH = 380
local HEIGHT = 330
local HEADER = 58
local ROW_HEIGHT = 70

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
	return new("UICorner", o, { CornerRadius = UDim.new(0, radius or 4) })
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

local function gradient(o: Instance, top: Color3, bottom: Color3): UIGradient
	return new("UIGradient", o, { Rotation = 90, Color = ColorSequence.new(top, bottom) })
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
	new("UIStroke", label, { Color = INK, Thickness = math.max(1.5, size / 12) })
	for k, v in props or {} do
		(label :: any)[k] = v
	end
	return label
end

-- A chunky studded button; returns the button and its label.
local function button(parent: Instance, color: Color3, caption: string, size: number, props: { [string]: any }): (TextButton, TextLabel)
	local b = new("TextButton", parent, {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 6)
	stroke(b, 2.5)
	studs(b, 0.85)
	gradient(b, color, color:Lerp(Color3.new(0, 0, 0), 0.22))
	local label = text(b, caption, size, { Size = UDim2.fromScale(1, 1), ZIndex = b.ZIndex + 1 })
	return b, label
end

local function recolor(b: GuiObject, color: Color3)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.22))
	end
end

local function shortTime(seconds: number): string
	local t = math.max(0, math.ceil(seconds))
	if t >= 3600 then
		return string.format("%dh %dm", t // 3600, (t % 3600) // 60)
	elseif t >= 60 then
		return string.format("%dm %ds", t // 60, t % 60)
	end
	return string.format("%ds", t)
end

local function displayName(eggName: string?, mutation: string?): string
	local entry = if eggName then PetCatalog.get(eggName) else nil
	local name = if entry then entry.DisplayName elseif eggName then (string.gsub(eggName, " Egg$", "")) else "Beast"
	return if mutation then mutation .. " " .. name else name
end

local function eggTitle(eggName: string?): string
	local name = if eggName and eggName ~= "" then eggName else "Egg"
	if not string.find(string.lower(name), "egg", 1, true) then
		name ..= " Egg"
	end
	return name
end

local function str(value: any): string?
	return if typeof(value) == "string" and value ~= "" then value else nil
end

-- 3D icons: one template model per pet / egg species, cloned into each row's viewport ------------

local templates: { [string]: Model | false | "building" } = {}

local function template(kind: string, name: string): Model?
	local key = kind .. ":" .. name
	while templates[key] == "building" do
		task.wait(0.1)
	end
	local cached = templates[key]
	if cached ~= nil then
		return if cached then cached :: Model else nil
	end
	templates[key] = "building"
	local ok, rig = false, nil
	if kind == "pet" then
		ok, rig = pcall(PetRig.build, name, Vector3.new(4, 4, 4))
	end
	if not (ok and rig) then
		local egg = GameEgg.get(name)
		if egg then
			ok, rig = pcall(EggVisual.build, egg, Vector3.new(4, 4, 4))
		end
	end
	if not (ok and rig) then
		templates[key] = false
		return nil
	end
	rig:place(CFrame.identity)
	local model = rig.model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	templates[key] = model
	return model
end

local function icon(parent: Instance, kind: string, name: string?): ViewportFrame
	local vp = new("ViewportFrame", parent, {
		Name = "Icon",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 175, 175),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Size = UDim2.fromOffset(ROW_HEIGHT - 12, ROW_HEIGHT - 12),
		Position = UDim2.fromOffset(6, 6),
	})
	local cam = new("Camera", vp, { FieldOfView = 30 })
	vp.CurrentCamera = cam
	local world = new("WorldModel", vp, {})
	if name then
		task.spawn(function()
			local model = template(kind, name)
			if not model or not vp.Parent then
				return
			end
			local copy = model:Clone()
			copy.Parent = world
			local cf, size = copy:GetBoundingBox()
			local reach = math.max(size.X, size.Y, size.Z)
			local dir = Vector3.new(0.62, 0.32, -1).Unit
			cam.CFrame = CFrame.lookAt(cf.Position + dir * reach * 1.7, cf.Position)
		end)
	end
	return vp
end

-- HUD buttons ---------------------------------------------------------------------------------------

local hud = new("ScreenGui", playerGui, {
	Name = "PenHud",
	ResetOnSpawn = false,
	DisplayOrder = 12,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function badge(parent: Instance, color: Color3): (Frame, TextLabel)
	local b = new("Frame", parent, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(4, 4), -- top-left: the buttons sit on the screen's right edge
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = color,
		Visible = false,
		ZIndex = 5,
	})
	new("UICorner", b, { CornerRadius = UDim.new(1, 0) })
	stroke(b, 2)
	local label = text(b, "", 15, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	return b, label
end

local function hudButton(color: Color3, art: string, slot: number): (TextButton, Frame, TextLabel)
	local b = new("TextButton", hud, {
		Name = art .. "Button",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
	})
	b:SetAttribute("Slot", slot)
	corner(b, 4)
	stroke(b, 3, Color3.fromRGB(40, 16, 10))
	studs(b, 0.8)
	gradient(b, color, color:Lerp(Color3.new(0, 0, 0), 0.25))
	new("ImageLabel", b, {
		Name = "Art",
		BackgroundTransparency = 1,
		Image = (Art :: any)[art] or "",
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.74, 0.74),
		ZIndex = 2,
	})
	local dot, label = badge(b, Color3.fromRGB(90, 220, 70))
	return b, dot, label
end

local eggButton, eggBadge, eggBadgeText = hudButton(Color3.fromRGB(236, 74, 52), "LuckyEgg", -1)
local petButton, petBadge, petBadgeText = hudButton(Color3.fromRGB(242, 150, 52), "Paw", 1)
petBadge.BackgroundColor3 = Color3.fromRGB(255, 70, 70)

local EDGE = 3 -- gap from the right edge of the safe area (tiles and open panels)

local function layoutHud()
	local side = PopupLayout.penButtonSide()
	for _, b in { eggButton, petButton } do
		b.Size = UDim2.fromOffset(side, side)
		local slot = b:GetAttribute("Slot") :: number
		b.Position = UDim2.new(1, -EDGE, 0.5, slot * (side * 0.5 + 6))
	end
end
layoutHud()
;(workspace.CurrentCamera :: Camera):GetPropertyChangedSignal("ViewportSize"):Connect(layoutHud)

-- Panels ------------------------------------------------------------------------------------------

type Panel = {
	gui: ScreenGui,
	frame: Frame,
	scale: UIScale,
	header: Frame,
	list: ScrollingFrame,
	empty: TextLabel,
	open: boolean,
	extra: number, -- design height below the panel (Equip Best)
}

local panels: { Panel } = {}
local setOpen: (p: Panel, open: boolean) -> ()
local SLIDE = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function closedPosition(p: Panel): UDim2
	return UDim2.new(1, math.ceil(WIDTH * p.scale.Scale) + 90, 0.5, 0)
end

local function openPosition(p: Panel): UDim2
	-- on the right edge (small gap), over the HUD buttons (its ">" tab closes it)
	return UDim2.new(1, -EDGE, 0.5, -math.floor(p.extra * p.scale.Scale * 0.5))
end

local function fit(p: Panel)
	local _, area = PopupLayout.area(p.gui)
	local s = math.min(area.Y / (HEIGHT + p.extra + 10), (area.X - 150) / (WIDTH + 70), 1.1)
	p.scale.Scale = math.max(s, 0.45)
	p.frame.Position = if p.open then openPosition(p) else closedPosition(p)
end

local function makePanel(name: string, title: string, extra: number): Panel
	local gui = new("ScreenGui", playerGui, {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = PopupLayout.DisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = true,
	})
	local frame = new("Frame", gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = BODY,
		Visible = false,
	})
	corner(frame, 4)
	stroke(frame, 3)
	studs(frame, 0.82)
	local scale = new("UIScale", frame, {})
	local header = new("Frame", frame, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	})
	corner(header, 4)
	stroke(header, 3)
	studs(header, 0.8)
	gradient(header, Color3.fromRGB(238, 205, 150), Color3.fromRGB(196, 150, 96))
	text(header, title, 34, {
		Name = "Title",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local list = new("ScrollingFrame", frame, {
		Name = "List",
		Position = UDim2.fromOffset(10, HEADER + 10),
		Size = UDim2.new(1, -20, 1, -HEADER - 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(150, 150, 170),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
	})
	new("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	new("UIPadding", list, { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) })
	local empty = text(frame, "", 23, {
		Name = "Empty",
		Position = UDim2.fromOffset(20, HEADER + 30),
		Size = UDim2.new(1, -40, 0, 80),
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(200, 200, 215),
		ZIndex = 3,
		Visible = false,
	})
	local p: Panel = { gui = gui, frame = frame, scale = scale, header = header, list = list, empty = empty, open = false, extra = extra }
	-- ">" slides the panel back out to the right
	local close = button(frame, Color3.fromRGB(226, 52, 44), ">", 30, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -10, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		ZIndex = 4,
	})
	close.Activated:Connect(function()
		setOpen(p, false)
	end)
	PopupLayout.watch(gui, function()
		fit(p)
	end)
	table.insert(panels, p)
	return p
end

function setOpen(p: Panel, open: boolean)
	if open then
		for _, other in panels do
			if other ~= p and other.open then
				setOpen(other, false)
			end
		end
	end
	p.open = open
	fit(p)
	if open then
		p.frame.Position = closedPosition(p)
		p.frame.Visible = true
	end
	local tween = TweenService:Create(p.frame, SLIDE, { Position = if open then openPosition(p) else closedPosition(p) })
	tween:Play()
	if not open then
		tween.Completed:Connect(function()
			if not p.open then
				p.frame.Visible = false
			end
		end)
	end
end

-- Keyed rows: reuse a row (and its 3D icon) while its item stays in the list.
type Rows = { [any]: Frame }
local function sync(list: ScrollingFrame, rows: Rows, keys: { any }, make: (key: any) -> Frame)
	local wanted: { [any]: number } = {}
	for i, key in keys do
		wanted[key] = i
	end
	for key, row in rows do
		if not wanted[key] then
			row:Destroy()
			rows[key] = nil
		end
	end
	for i, key in keys do
		local row = rows[key]
		if not row then
			row = make(key)
			row.Parent = list
			rows[key] = row
		end
		row.LayoutOrder = i * 2
		row.Name = "Row" .. i
	end
end

local function rowFrame(): Frame
	local row = new("Frame", nil, {
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = ROW,
		ZIndex = 2,
	})
	corner(row, 4)
	stroke(row, 2.5)
	new("UIGradient", row, {
		Rotation = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 180)),
	})
	return row
end

-- The pen models -----------------------------------------------------------------------------------

local map = workspace:WaitForChild("BabyBeastsMap", 60)
local beasts = map and map:WaitForChild("TankBeasts", 60)

-- stable tie-break order for rows
local serials: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextSerial = 0
local function serial(model: Instance): number
	local n = serials[model]
	if not n then
		nextSerial += 1
		n = nextSerial
		serials[model] = n
	end
	return n
end

local function mine(): { Model }
	local list = {}
	if not beasts then
		return list
	end
	for _, child in beasts:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("OwnerUserId") == player.UserId and child:GetAttribute("Showcase") ~= true then
			table.insert(list, child)
		end
	end
	return list
end

local function moneyBoost(): number
	return if player:GetAttribute("PassMoney") then 2 else 1
end

-- Growing Eggs ------------------------------------------------------------------------------------

local eggsPanel = makePanel("GrowingEggsGui", "Growing Eggs", 0)
eggsPanel.empty.Text = "No eggs growing.\nHold an egg and click your pen to place it!"
local growAll = button(eggsPanel.header, Color3.fromRGB(255, 196, 40), "Grow All", 25, {
	Name = "GrowAll",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(122, 40),
	ZIndex = 4,
})
growAll.Activated:Connect(function()
	eggsRemote:FireServer("GrowAll")
end)

local eggRows: Rows = {}

local function makeEggRow(model: Model): Frame
	local row = rowFrame()
	local eggName = str(model:GetAttribute("EggName"))
	icon(row, "egg", eggName).ZIndex = 3
	text(row, eggTitle(eggName), 21, {
		Name = "EggName",
		Position = UDim2.fromOffset(ROW_HEIGHT, 6),
		Size = UDim2.new(1, -ROW_HEIGHT - 104, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = EggScale.rarityColor(str(model:GetAttribute("Rarity")) or "Common"),
		ZIndex = 3,
	})
	local bar = new("Frame", row, {
		Name = "Bar",
		Position = UDim2.fromOffset(ROW_HEIGHT, 34),
		Size = UDim2.new(1, -ROW_HEIGHT - 104, 0, 26),
		BackgroundColor3 = Color3.fromRGB(28, 28, 36),
		ZIndex = 3,
	})
	corner(bar, 4)
	stroke(bar, 2)
	local fill = new("Frame", bar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
	})
	corner(fill, 4)
	gradient(fill, Color3.fromRGB(130, 236, 92), Color3.fromRGB(60, 176, 50))
	text(bar, "", 20, { Name = "Time", Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	local skip, skipLabel = button(row, Color3.fromRGB(176, 84, 255), "", 21, {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(88, 44),
		ZIndex = 3,
	})
	skipLabel.Name = "Price"
	skip.Activated:Connect(function()
		eggsRemote:FireServer("Skip", model)
	end)
	local open = button(row, Color3.fromRGB(110, 230, 70), "Open", 25, {
		Name = "Open",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(88, 44),
		ZIndex = 3,
		Visible = false,
	})
	open.Activated:Connect(function()
		eggsRemote:FireServer("Open", model)
	end)
	return row
end

local function updateEggRow(row: Frame, model: Model, pulse: number)
	local ready = model:GetAttribute("Ready") == true
	local total = model:GetAttribute("HatchTotal")
	local left = model:GetAttribute("HatchLeft")
	local t = if typeof(total) == "number" and total > 0 then total else 1
	local l = if typeof(left) == "number" then math.max(left, 0) else 0
	local bar = row:FindFirstChild("Bar") :: Frame
	local fill = bar:FindFirstChild("Fill") :: Frame
	local time = bar:FindFirstChild("Time") :: TextLabel
	fill.Size = UDim2.fromScale(if ready then 1 else math.clamp(1 - l / t, 0, 1), 1)
	time.Text = if ready then "Ready!" else shortTime(l)
	local skip = row:FindFirstChild("Skip") :: TextButton
	local open = row:FindFirstChild("Open") :: TextButton
	open.Visible = ready
	skip.Visible = not ready and l > PenConfig.MinSkipSeconds
	if skip.Visible then
		local tier = PenConfig.skipTier(l)
		;(skip:FindFirstChild("Price") :: TextLabel).Text = "⏩ " .. ROBUX .. tier.Robux
	end
	if ready then
		-- the Open button pulses while an egg waits to be opened
		local glow = 0.5 + 0.5 * math.sin(pulse * 11)
		recolor(open, Color3.fromRGB(110, 230, 70):Lerp(Color3.fromRGB(190, 255, 150), glow))
	end
end

local function eggModels(): { Model }
	local list = {}
	for _, model in mine() do
		if model:GetAttribute("Hatching") == true then
			table.insert(list, model)
		end
	end
	-- ready first, then the least time left
	table.sort(list, function(a, b)
		local ra, rb = a:GetAttribute("Ready") == true, b:GetAttribute("Ready") == true
		if ra ~= rb then
			return ra
		end
		local la, lb = (a:GetAttribute("HatchLeft") or 0) :: number, (b:GetAttribute("HatchLeft") or 0) :: number
		if la ~= lb then
			return la < lb
		end
		return serial(a) < serial(b)
	end)
	return list
end

local function refreshEggs(pulse: number)
	local models = eggModels()
	sync(eggsPanel.list, eggRows, models, makeEggRow)
	for _, model in models do
		updateEggRow(eggRows[model], model, pulse)
	end
	eggsPanel.empty.Visible = #models == 0
end

-- Active Pets -------------------------------------------------------------------------------------

local petsPanel = makePanel("ActivePetsGui", "0/7 Active", 64)
local title = petsPanel.header:FindFirstChild("Title") :: TextLabel
title.Size = UDim2.new(0.45, 0, 1, 0)
local buySlot, buyLabel = button(petsPanel.header, Color3.fromRGB(80, 210, 70), "+1 EQUIP", 21, {
	Name = "BuySlot",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(196, 40),
	ZIndex = 4,
})
buySlot.Activated:Connect(function()
	petsRemote:FireServer("BuySlot")
end)
local equipBest = button(petsPanel.frame, Color3.fromRGB(120, 236, 60), "Equip Best", 29, {
	Name = "EquipBest",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 1, 12),
	Size = UDim2.fromOffset(190, 50),
	ZIndex = 3,
})
equipBest.Activated:Connect(function()
	petsRemote:FireServer("EquipBest")
end)
local bestBadge, bestBadgeText = badge(equipBest, Color3.fromRGB(255, 70, 70))
bestBadgeText.Text = "!"

type StoredPet = { Id: string, Egg: string?, Mutation: string?, Rarity: string?, Income: number, Rideable: boolean? }

local function storedPets(): { StoredPet }
	local raw = player:GetAttribute("StoredPets")
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and typeof(list) == "table" then list else {}
end

local rarityRank: { [string]: number } = {}
for i, name in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Eternal", "Divine" } do
	rarityRank[name] = i
end

local function petLabel(row: Frame, eggName: string?, mutation: string?, rarity: string?): TextLabel
	return text(row, displayName(eggName, mutation), 24, {
		Name = "PetName",
		Position = UDim2.fromOffset(ROW_HEIGHT + 2, 8),
		Size = UDim2.new(1, -ROW_HEIGHT - 130, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = EggScale.rarityColor(rarity or "Common"),
		ZIndex = 3,
	})
end

local function rateLabel(row: Frame): TextLabel
	return text(row, "", 21, {
		Name = "Rate",
		Position = UDim2.fromOffset(ROW_HEIGHT + 2, 36),
		Size = UDim2.new(1, -ROW_HEIGHT - 130, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(110, 235, 90),
		ZIndex = 3,
	})
end

local activeRows: Rows = {}

local function makeActiveRow(model: Model): Frame
	local row = rowFrame()
	row.ClipsDescendants = true
	local eggName = str(model:GetAttribute("EggName"))
	local rarity = str(model:GetAttribute("Rarity")) or "Common"
	-- light burst behind the pet, in its rarity colour
	new("ImageLabel", row, {
		Name = "Rays",
		BackgroundTransparency = 1,
		Image = SUN_RAYS,
		ImageColor3 = EggScale.rarityColor(rarity),
		ImageTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(6 + (ROW_HEIGHT - 12) / 2, ROW_HEIGHT / 2),
		Size = UDim2.fromOffset(ROW_HEIGHT * 3.4, ROW_HEIGHT * 3.4),
		ZIndex = 2,
	})
	icon(row, "pet", eggName).ZIndex = 3
	petLabel(row, eggName, str(model:GetAttribute("Mutation")), str(model:GetAttribute("Rarity")))
	rateLabel(row)
	local unequip = button(row, Color3.fromRGB(226, 60, 50), "Unequip", 24, {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(112, 46),
		ZIndex = 3,
	})
	unequip.Activated:Connect(function()
		petsRemote:FireServer("Unequip", model)
	end)
	return row
end

-- The backpack: unequipped pets (no hotbar). Hold one, then click / tap your pen to place it.
local storedById: { [string]: StoredPet } = {}
local HELD_KEY = "BackpackHeader"

local function makeBackpackHeader(): Frame
	local row = new("Frame", nil, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	text(row, "Backpack", 24, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 226, 150),
	})
	return row
end

local function makeStoredRow(key: string): Frame
	local rec = storedById[string.sub(key, 3)]
	local row = rowFrame()
	row.ClipsDescendants = true
	icon(row, "pet", rec and rec.Egg).ZIndex = 3
	petLabel(row, rec and rec.Egg, rec and rec.Mutation, rec and rec.Rarity)
	rateLabel(row)
	local hold = button(row, Color3.fromRGB(60, 150, 240), "Hold", 24, {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(112, 46),
		ZIndex = 3,
	})
	hold.Activated:Connect(function()
		petsRemote:FireServer("Hold", string.sub(key, 3))
	end)
	return row
end

local function byValue(ra: string?, ia: number, rb: string?, ib: number): boolean?
	local a, b = rarityRank[ra or "Common"] or 0, rarityRank[rb or "Common"] or 0
	if a ~= b then
		return a > b
	end
	if ia ~= ib then
		return ia > ib
	end
	return nil
end

-- Returns the active count, the held (unequipped) count, and the slot count.
local function refreshPets(): (number, number, number)
	local boost = moneyBoost()
	local active = {}
	for _, model in mine() do
		if model:GetAttribute("Hatching") ~= true then
			table.insert(active, model)
		end
	end
	table.sort(active, function(a, b)
		local r = byValue(str(a:GetAttribute("Rarity")), (a:GetAttribute("Income") or 0) :: number, str(b:GetAttribute("Rarity")), (b:GetAttribute("Income") or 0) :: number)
		if r ~= nil then
			return r
		end
		return serial(a) < serial(b)
	end)
	-- unequipped pets follow under "Backpack" (the hotbar is hidden), best first
	local backpack = storedPets()
	local heldCount = #backpack
	if petsPanel.open then
		table.sort(backpack, function(a, b)
			local r = byValue(a.Rarity, a.Income or 0, b.Rarity, b.Income or 0)
			if r ~= nil then
				return r
			end
			return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
		end)
		local keys: { any } = table.clone(active)
		storedById = {}
		if #backpack > 0 then
			table.insert(keys, HELD_KEY)
			for _, rec in backpack do
				storedById[rec.Id] = rec
				table.insert(keys, "S:" .. rec.Id)
			end
		end
		sync(petsPanel.list, activeRows, keys, function(key)
			if key == HELD_KEY then
				return makeBackpackHeader()
			elseif typeof(key) == "string" then
				return makeStoredRow(key)
			end
			return makeActiveRow(key)
		end)
		local holding = player:GetAttribute("HeldPet")
		for key, row in activeRows do
			if key == HELD_KEY then
				(row:FindFirstChild("Label") :: TextLabel).Text = "Backpack (" .. heldCount .. ")"
				continue
			end
			local rec = if typeof(key) == "string" then storedById[string.sub(key, 3)] else nil
			local income = if rec then rec.Income else key:GetAttribute("Income")
			;(row:FindFirstChild("Rate") :: TextLabel).Text = Economy.formatRate((if typeof(income) == "number" then income else 0) * boost)
			if rec then
				local held = holding == rec.Id
				local action = row:FindFirstChild("Action") :: TextButton
				local label = action:FindFirstChildWhichIsA("TextLabel", true)
				if label then
					label.Text = if held then "Holding" else "Hold"
				end
				recolor(action, if held then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(60, 150, 240))
			end
		end
		petsPanel.empty.Visible = #active == 0 and heldCount == 0
	end
	local slots = player:GetAttribute("EquipSlots")
	local slotCount = if typeof(slots) == "number" then slots else PenConfig.StartSlots
	title.Text = #active .. "/" .. slotCount .. " Active"
	local levelValue = player:GetAttribute("EquipLevel")
	local level = if typeof(levelValue) == "number" then levelValue else 0
	local cost = PenConfig.nextCost(level)
	local cash = player:GetAttribute("Cash")
	if not cost then
		buyLabel.Text = "MAX EQUIP"
		recolor(buySlot, Color3.fromRGB(130, 130, 140))
		buySlot.AutoButtonColor = false
	else
		buyLabel.Text = "+1 EQUIP [" .. Economy.formatCash(cost) .. "]"
		local afford = typeof(cash) == "number" and cash >= cost
		recolor(buySlot, if afford then Color3.fromRGB(80, 210, 70) else Color3.fromRGB(226, 40, 36))
		buySlot.AutoButtonColor = true
	end
	return #active, heldCount, slotCount
end
petsPanel.empty.Text = "No pets yet.\nHatch eggs in your pen to get pets!"

-- Wiring -------------------------------------------------------------------------------------------

eggButton.Activated:Connect(function()
	setOpen(eggsPanel, not eggsPanel.open)
end)
petButton.Activated:Connect(function()
	setOpen(petsPanel, not petsPanel.open)
end)
-- other scripts (tutorials, prompts, tests) open a panel with PenHud:SetAttribute("Open", "Eggs" | "Pets")
hud:GetAttributeChangedSignal("Open"):Connect(function()
	local which = hud:GetAttribute("Open")
	if which == "Eggs" or which == "Pets" then
		setOpen(if which == "Eggs" then eggsPanel else petsPanel, true)
	end
	hud:SetAttribute("Open", nil)
end)

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.2 then
		return
	end
	local now = os.clock()
	clock = 0
	-- badges: eggs waiting to be opened; stored pets while a slot is free
	local ready = 0
	for _, model in mine() do
		if model:GetAttribute("Hatching") == true and model:GetAttribute("Ready") == true then
			ready += 1
		end
	end
	eggBadge.Visible = ready > 0
	eggBadgeText.Text = tostring(ready)
	if eggsPanel.open then
		refreshEggs(now)
	end
	local active, storedCount, slots = refreshPets()
	local waiting = storedCount > 0 and active < slots
	petBadge.Visible = waiting
	petBadgeText.Text = "!"
	bestBadge.Visible = waiting
end)
