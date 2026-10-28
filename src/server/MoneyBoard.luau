--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.MoneyBoard
-- "Most Money" leaderboard on the spawn plaza's right wall, between the two trail stalls (Steal an
-- Egg puts its trail shop by its Most Money board). Global top ten by Cash from an
-- OrderedDataStore, refreshed every minute; falls back to the players in this server.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)

local MoneyBoard = {}

local STORE_NAME = "BabyBeastsMostMoney_v1"
local REFRESH = 60
local ROWS = 10
local BOARD_SIZE = Vector3.new(14, 14, 0.8)
local MOUNT_HEIGHT = 28 -- board bottom above the floor (clears the 2x fuse machine and its sign; wall top is 35)
local GOLD = Color3.fromRGB(255, 206, 60)
local NAVY = Color3.fromRGB(20, 28, 52)

type Row = { name: string, cash: number }

local names: { [number]: string } = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and typeof(name) == "string" then name else "Player"
	names[userId] = result
	return result
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function build(zone: Instance): { TextLabel }?
	local startZ = zone:GetAttribute("StartZ")
	local length = zone:GetAttribute("ZoneLength")
	if typeof(startZ) ~= "number" or typeof(length) ~= "number" then
		return nil
	end
	local old = zone:FindFirstChild("MostMoneyBoard")
	if old then
		old:Destroy()
	end
	-- mounted on the right wall halfway between the trail stalls (Map.TrailShops), above the fuse
	-- machine, its front (-Z) facing into the road
	local origin = CFrame.new(MapConfig.RoadWidth / 2 - 0.6, 0, startZ + length * 0.5) * CFrame.Angles(0, math.rad(90), 0)
	local model = Instance.new("Model")
	model.Name = "MostMoneyBoard"
	local panel = part(model, "Panel", BOARD_SIZE, origin * CFrame.new(0, MOUNT_HEIGHT + BOARD_SIZE.Y * 0.5, 0), NAVY)
	part(model, "Frame", BOARD_SIZE + Vector3.new(0.8, 0.8, -0.3), panel.CFrame * CFrame.new(0, 0, 0.2), GOLD).Material = Enum.Material.Neon
	model.PrimaryPart = panel

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.92, 0, 0, 52)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansExtraBold
	title.Text = "MOST MONEY"
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.TextStrokeTransparency = 0
	title.LayoutOrder = 0
	title.Parent = gui
	local labels: { TextLabel } = {}
	for i = 1, ROWS do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.Size = UDim2.new(0.92, 0, 0, 30)
		row.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(30, 42, 76) else Color3.fromRGB(38, 52, 92)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.BuilderSansBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then GOLD elseif i <= 3 then Color3.fromRGB(230, 230, 240) else Color3.new(1, 1, 1)
		row.Text = ""
		row.LayoutOrder = i
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		local inset = Instance.new("UIPadding")
		inset.PaddingLeft = UDim.new(0, 12)
		inset.PaddingRight = UDim.new(0, 12)
		inset.Parent = row
		table.insert(labels, row)
	end
	model.Parent = zone
	return labels
end

local function serverRows(): { Row }
	local rows: { Row } = {}
	for _, player in Players:GetPlayers() do
		local cash = player:GetAttribute("Cash")
		table.insert(rows, { name = player.DisplayName, cash = if typeof(cash) == "number" then cash else 0 })
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	return rows
end

function MoneyBoard.start(root: Instance)
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = (habitats and habitats:FindFirstChild("Zone00")) or root:FindFirstChild("Zone00")
	if not zone then
		return
	end
	local labels = build(zone)
	if not labels then
		return
	end
	local store = DataStoreService:GetOrderedDataStore(STORE_NAME)
	local function render(rows: { Row })
		for i, label in labels do
			local row = rows[i]
			label.Text = if row then string.format("#%d  %s   %s", i, row.name, Economy.formatCash(row.cash)) else ""
		end
	end
	task.spawn(function()
		while true do
			-- publish everyone's cash, then read the global top ten
			for _, player in Players:GetPlayers() do
				local cash = player:GetAttribute("Cash")
				if typeof(cash) == "number" and player:GetAttribute("SpeedLoaded") == true then
					pcall(function()
						store:SetAsync(tostring(player.UserId), math.floor(cash))
					end)
				end
			end
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, ROWS)
			end)
			local rows: { Row } = {}
			if ok and pages then
				for _, entry in (pages :: DataStorePages):GetCurrentPage() do
					local userId = tonumber(entry.key)
					if userId then
						table.insert(rows, { name = nameOf(userId), cash = entry.value })
					end
				end
			end
			render(if #rows > 0 then rows else serverRows())
			task.wait(REFRESH)
		end
	end)
end

return MoneyBoard
