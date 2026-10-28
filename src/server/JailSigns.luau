--!strict
-- Zone name board standing on each jail cell roof, facing the road.
-- Styled from the zone's own BiomeSign so it matches the entrance banner.
-- The cell roof (top y≈30) sits below the road wall (35 + teeth), so the
-- board is raised on posts to clear the wall line seen from the road.
local JailSigns = {}

local BOARD = Vector3.new(66, 14, 2)
local BOARD_BOTTOM = 44
local INSET = 12 -- studs behind the cell mouth, over the roof

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function labelText(zone: Instance): string
	local id = zone:GetAttribute("ZoneIndex")
	local name = zone:GetAttribute("BiomeName")
	if typeof(id) ~= "number" or typeof(name) ~= "string" then
		return ""
	end
	return string.format("%d %s", id, string.upper(name))
end

local function decorate(zone: Instance)
	local cell = zone:FindFirstChild("JailCell")
	if not cell then
		return
	end
	local front = cell:GetAttribute("FrontCenter")
	local facing = cell:GetAttribute("Facing")
	if typeof(front) ~= "Vector3" or typeof(facing) ~= "Vector3" then
		return
	end
	local old = cell:FindFirstChild("ZoneNameSign")
	if old then
		old:Destroy()
	end
	local roof = cell:FindFirstChild("CellRoof")
	local roofTop = if roof and roof:IsA("BasePart") then roof.Position.Y + roof.Size.Y * 0.5 else 30
	local banner = zone:FindFirstChild("BiomeSign")
	local color = if banner and banner:IsA("BasePart") then banner.Color else Color3.fromRGB(48, 36, 76)
	local material = if banner and banner:IsA("BasePart") then banner.Material else Enum.Material.Plastic

	local folder = Instance.new("Model")
	folder.Name = "ZoneNameSign"
	local base = front - facing * INSET
	local center = Vector3.new(base.X, BOARD_BOTTOM + BOARD.Y * 0.5, base.Z)
	local look = CFrame.lookAt(center, center + facing)
	local board = part(folder, "Board", BOARD, look, color, material)
	local postHeight = BOARD_BOTTOM - roofTop
	for _, e in { -1, 1 } do
		local offset = look.RightVector * e * (BOARD.X * 0.5 - 6)
		local post = Vector3.new(center.X + offset.X, roofTop + postHeight * 0.5, center.Z + offset.Z)
		part(folder, "Post", Vector3.new(2, postHeight, 2), CFrame.lookAt(post, post + facing), color, material)
	end

	local template = banner and banner:FindFirstChild("FrontLabel")
	local gui: SurfaceGui
	if template and template:IsA("SurfaceGui") then
		gui = template:Clone()
	else
		gui = Instance.new("SurfaceGui")
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 250, 229)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
	end
	gui.Name = "NameLabel"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(660, 140)
	local label = gui:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = labelText(zone)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.9, 0.8)
	end
	gui.Parent = board
	folder.Parent = cell
end

function JailSigns.build(root: Instance)
	local habitats = root:FindFirstChild("BeastHabitats")
	if not habitats then
		return
	end
	for _, zone in habitats:GetChildren() do
		decorate(zone)
	end
end

return JailSigns
