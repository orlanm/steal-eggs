--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.FuseGui
-- Three matching tank pets become one egg of that pet. The fee is shown before you pay.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UIArt = require(game.ReplicatedStorage.BabyBeastsShared:WaitForChild("UIArt")) :: any
local PopupLayout = require(game.ReplicatedStorage.BabyBeastsShared:WaitForChild("PopupLayout"))
local player = Players.LocalPlayer
local shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local Economy = require(shared:WaitForChild("EconomyConfig"))
local rosterRemote = shared:WaitForChild("FuseRoster")
local commitRemote = shared:WaitForChild("FuseCommit")

local gui = Instance.new("ScreenGui")
gui.Name = "FuseGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = PopupLayout.DisplayOrder
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(440, 520)
card.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
card.Parent = gui
-- between the top bar and the hotbar: scaled to fit, the recipe list takes any spare height
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
PopupLayout.watch(gui, function()
	PopupLayout.fit(gui, card, cardScale, Vector2.new(440, 300), 1.15, function(scale, area)
		return Vector2.new(440, math.clamp(area.Y / scale, 300, 520))
	end)
end)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card
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
corner:Clone().Parent = studs
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 186, 72)
stroke.Transparency = 0.35
stroke.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -70, 0, 32)
title.Position=UDim2.fromOffset(52,10);title.Size=UDim2.new(1,-106,0,32)
local titleIcon=Instance.new("ImageLabel");titleIcon.Name="PopupIcon";titleIcon.BackgroundTransparency=1;titleIcon.Image=UIArt.Fuse;titleIcon.Position=UDim2.fromOffset(12,8);titleIcon.Size=UDim2.fromOffset(34,34);titleIcon.Parent=card
local header=Instance.new("ImageLabel");header.Name="HeaderArtwork";header.BackgroundTransparency=1;header.Image=UIArt.Header;header.ImageTransparency=.7;header.Size=UDim2.new(1,0,0,48);header.ZIndex=0;header.Parent=card
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 226, 170)
title.Text = "Fuse Machine"
title.Parent = card

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 32)
close.BackgroundColor3 = Color3.fromRGB(48, 58, 78)
close.Text = "X"
close.Font = Enum.Font.BuilderSansBold
close.TextSize = 18
close.TextColor3 = Color3.fromRGB(240, 244, 250)
close.Parent = card
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = close

local blurb = Instance.new("TextLabel")
blurb.BackgroundTransparency = 1
blurb.Position = UDim2.fromOffset(18, 48)
blurb.Size = UDim2.new(1, -36, 0, 48)
blurb.Font = Enum.Font.BuilderSans
blurb.TextSize = 15
blurb.TextWrapped = true
blurb.TextXAlignment = Enum.TextXAlignment.Left
blurb.TextYAlignment = Enum.TextYAlignment.Top
blurb.TextColor3 = Color3.fromRGB(198, 214, 230)
blurb.Text = "Bring 3 of the same pet from your tank. They are spent, and you get one new egg of that pet."
blurb.Parent = card

local cashLabel = Instance.new("TextLabel")
cashLabel.BackgroundTransparency = 1
cashLabel.Position = UDim2.fromOffset(18, 98)
cashLabel.Size = UDim2.new(1, -36, 0, 22)
cashLabel.Font = Enum.Font.BuilderSansBold
cashLabel.TextSize = 16
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.TextColor3 = Color3.fromRGB(140, 235, 190)
cashLabel.Text = ""
cashLabel.Parent = card

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(16, 128)
list.Size = UDim2.new(1, -32, 1, -196)
list.BackgroundColor3 = Color3.fromRGB(12, 18, 32)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = card
local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent = list
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = list

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 18, 1, -16)
status.Size = UDim2.new(1, -36, 0, 36)
status.Font = Enum.Font.BuilderSans
status.TextSize = 15
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(230, 236, 245)
status.Text = ""
status.Parent = card

local selected: string? = nil
local busy = false

local function clearRows()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function show(data)
	cashLabel.Text = "Cash  " .. Economy.formatCash(data.cash or 0)
	clearRows()
	local rows = data.rows or {}
	if #rows == 0 then
		status.Text = "No pets in your tank yet."
		return
	end
	for index, row in rows do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -8, 0, 54)
		button.BackgroundColor3 = if row.name == selected
			then Color3.fromRGB(72, 58, 28)
			else Color3.fromRGB(28, 40, 62)
		button.Text = ""
		button.LayoutOrder = index
		button.Parent = list
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, 4)
		label.Size = UDim2.new(1, -24, 1, -8)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextColor3 = Color3.fromRGB(236, 244, 250)
		label.Text = string.format("%s    %d/3    %s", row.name, row.count, Economy.formatCash(row.fee or 0))
		label.Parent = button
		button.Activated:Connect(function()
			if busy then
				return
			end
			selected = row.name
			if row.count < 3 then
				status.Text = "Need 3 " .. row.name .. "."
				show(data)
				return
			end
			busy = true
			status.Text = "Fusing..."
			local ok, result = pcall(function()
				return commitRemote:InvokeServer(row.name)
			end)
			busy = false
			if not ok or typeof(result) ~= "table" then
				status.Text = "Fuse failed. Try again."
				return
			end
			status.Text = tostring(result.message or "")
			status.TextColor3 = if result.ok then Color3.fromRGB(140, 235, 190) else Color3.fromRGB(255, 170, 140)
			selected = nil
			show(result)
		end)
	end
end

local function open()
	gui.Enabled = true
	status.Text = "Loading pets..."
	status.TextColor3 = Color3.fromRGB(230, 236, 245)
	local ok, data = pcall(function()
		return rosterRemote:InvokeServer()
	end)
	if not ok or typeof(data) ~= "table" then
		status.Text = "Could not read your tank."
		return
	end
	show(data)
end

close.Activated:Connect(function()
	gui.Enabled = false
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FusePrompt" then
		open()
	end
end)
