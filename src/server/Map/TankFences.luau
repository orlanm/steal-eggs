--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.TankFences
-- Studded pen fence. Every pen uses dark brown posts and brown rails.
-- Posts are 1 stud square and 6.9 studs tall, with three thick rails.
-- The side that shows the owner avatar is left open.

local Layout = require(script.Parent.Layout)
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)

type Theme = {
	post: Color3,
	rail: Color3,
	postH: number,
	rails: { number },
}

local THEME: Theme = {
	post = Color3.fromRGB(86, 66, 54),
	rail = Color3.fromRGB(162, 81, 0),
	postH = 6.9,
	rails = { 0.85, 2.84, 5.0 },
}
local BAY = 11
local PATH_HALF = MapConfig.CheckerSize * 1.5

local Fences = {}

local function wood(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = ""
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.Parent = parent
	return part
end

local function themeFor(_tank: Instance): Theme
	return THEME
end

local function post(parent: Instance, pos: Vector3, theme: Theme)
	wood(parent, "FencePost", Vector3.new(1, theme.postH, 1), CFrame.new(pos + Vector3.new(0, theme.postH / 2, 0)), theme.post)
end

local function rails(parent: Instance, a: Vector3, b: Vector3, span: number, theme: Theme)
	local delta = b - a
	local mid = (a + b) * 0.5
	local cf = CFrame.fromMatrix(mid, delta.Unit, Vector3.yAxis)
	for _, y in theme.rails do
		wood(parent, "FenceRail", Vector3.new(math.max(span - 0.8, 1), 1.2, 1), cf * CFrame.new(0, y, 0), theme.rail)
	end
end

local function fenceSegment(group: Instance, a: Vector3, b: Vector3, theme: Theme)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		post(group, a, theme)
		return
	end
	local dir = delta.Unit
	local bays = math.max(1, math.floor(length / BAY + 0.5))
	local step = length / bays
	post(group, a, theme)
	for i = 0, bays - 1 do
		local start = a + dir * (step * i)
		local finish = a + dir * (step * (i + 1))
		if i > 0 then
			post(group, start, theme)
		end
		rails(group, start, finish, step, theme)
	end
	post(group, b, theme)
end

local function openEdge(group: Instance, a: Vector3, b: Vector3, _out: Vector3, theme: Theme)
	local delta = b - a
	local length = delta.Magnitude
	if length <= PATH_HALF * 2 + 1 then
		fenceSegment(group, a, b, theme)
		return
	end
	local dir = delta.Unit
	local mid = (a + b) * 0.5
	local gateA = mid - dir * PATH_HALF
	local gateB = mid + dir * PATH_HALF
	fenceSegment(group, a, gateA, theme)
	fenceSegment(group, gateB, b, theme)
end

function Fences.build(tank: Instance, center: Vector3)
	local old = tank:FindFirstChild("FarmFence")
	if old then
		old:Destroy()
	end
	local pen = MapConfig.PenSize
	if typeof(pen) ~= "number" then
		pen = 80.25
	end
	local half = pen / 2
	local front = Layout.frontDir(center)
	local right = CFrame.lookAt(Vector3.zero, front).RightVector
	local corner = {
		center - right * half - front * half,
		center + right * half - front * half,
		center + right * half + front * half,
		center - right * half + front * half,
	}
	local theme = themeFor(tank)
	local group = Instance.new("Folder")
	group.Name = "FarmFence"
	for edge = 1, 4 do
		local a = corner[edge]
		local b = corner[edge % 4 + 1]
		-- Edge 3 is the front, the side the owner walks through.
		if edge == 3 then
			openEdge(group, a, b, front, theme)
		else
			fenceSegment(group, a, b, theme)
		end
	end
	group.Parent = tank
end

return Fences
