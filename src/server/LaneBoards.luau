--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.LaneBoards
-- The portrait sits on top of that player's treadmill in zone 0.
-- The glow around the portrait is added on the client only.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Boards = {}

local function findZone(root: Instance, name: string): Instance?
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = habitats and habitats:FindFirstChild(name)
	if zone then
		return zone
	end
	return root:FindFirstChild(name)
end

local function paint(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Portrait"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.MaxDistance = 700
	gui.Parent = board

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
	card.BorderSizePixel = 0
	card.Parent = gui

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(28, 48, 72)
	avatar.AnchorPoint = Vector2.new(0.5, 0.5)
	avatar.Size = UDim2.fromScale(0.78, 0.62)
	avatar.Position = UDim2.fromScale(0.5, 0.42)
	avatar.BorderSizePixel = 0
	avatar.ScaleType = Enum.ScaleType.Crop
	avatar.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = avatar

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Size = UDim2.fromScale(0.92, 0.18)
	name.Position = UDim2.fromScale(0.5, 0.96)
	name.Font = Enum.Font.BuilderSansBold
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(236, 255, 250)
	name.TextStrokeTransparency = 0.35
	name.Text = "Open Lane"
	name.Parent = card
end

local function paintOwner(board: BasePart, player: Player?)
	local avatar = board:FindFirstChild("Avatar", true)
	local label = board:FindFirstChild("PlayerName", true)
	if not (avatar and avatar:IsA("ImageLabel") and label and label:IsA("TextLabel")) then
		return
	end
	if player then
		board:SetAttribute("OwnerUserId", player.UserId)
		label.Text = player.DisplayName
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)
			if ok and avatar.Parent then
				avatar.Image = content
			end
		end)
	else
		board:SetAttribute("OwnerUserId", 0)
		label.Text = "Open Lane"
		avatar.Image = ""
	end
end

function Boards.build(root: Instance)
	local zone = findZone(root, "Zone01")
	local old = zone and zone:FindFirstChild("LaneBoards")
	if old then
		old:Destroy()
	end
end

function Boards.mount(machine: Model, player: Player)
	local previous = machine:FindFirstChild("LaneBoard")
	if previous then
		previous:Destroy()
	end
	local origin = machine:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	local slot = machine:GetAttribute("LaneSlot")
	local top = machine:GetAttribute("DeckY")
	if typeof(top) ~= "number" then
		top = 3
	end
	for _, part in machine:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Deck" then
			local localPos = origin:PointToObjectSpace(part.Position)
			top = math.max(top, localPos.Y + part.Size.Y * 0.5)
		end
	end

	local board = Instance.new("Part")
	board.Name = "LaneBoard"
	board.Size = Vector3.new(6.2, 7.2, 0.28)
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(16, 24, 42)
	board.CFrame = origin * CFrame.new(0, top + board.Size.Y * 0.5 + 0.35, 0.4)
	if typeof(slot) == "number" then
		board:SetAttribute("LaneSlot", slot)
	end
	paint(board)
	board.Parent = machine
	CollectionService:AddTag(board, "LaneBoard")
	paintOwner(board, player)
end

function Boards.setOwner(_root: Instance, slot: number, player: Player?)
	for _, inst in CollectionService:GetTagged("LaneBoard") do
		if inst:GetAttribute("LaneSlot") == slot and inst:IsA("BasePart") then
			paintOwner(inst, player)
		end
	end
end

return Boards
