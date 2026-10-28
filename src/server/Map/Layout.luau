--!strict
-- Five pens on the back row face the plaza. Two pens by the entrance sit at the
-- outer corners and face each other.

local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)

local Layout = {}

local function geometry()
	local pen = MapConfig.PenSize
	local width = MapConfig.PenAreaWidth
	local depth = MapConfig.PenAreaDepth
	local center = MapConfig.PenAreaCenter
	local gap = MapConfig.PenGap
	local span = 5 * pen + 4 * gap
	local rowSpan = 2 * pen + gap
	local marginX = (width - span) / 2
	local marginZ = (depth - rowSpan) / 2
	local backX = table.create(5)
	local x0 = center.X - width / 2 + marginX + pen / 2
	for i = 0, 4 do
		backX[i + 1] = x0 + i * (pen + gap)
	end
	local backZ = center.Z - depth / 2 + marginZ + pen / 2
	local frontZ = backZ + pen + gap
	return {
		pen = pen,
		half = pen / 2,
		backZ = backZ,
		frontZ = frontZ,
		backX = backX,
		gap = gap,
	}
end

function Layout.geometry()
	return geometry()
end

function Layout.tanks(): { Vector3 }
	local g = geometry()
	local centers = table.create(7)
	for _, x in g.backX do
		table.insert(centers, Vector3.new(x, 0, g.backZ))
	end
	table.insert(centers, Vector3.new(g.backX[1], 0, g.frontZ))
	table.insert(centers, Vector3.new(g.backX[5], 0, g.frontZ))
	return centers
end

function Layout.onBackRow(center: Vector3): boolean
	local g = geometry()
	return math.abs(center.Z - g.backZ) < 8
end

function Layout.frontDir(center: Vector3): Vector3
	if Layout.onBackRow(center) then
		return Vector3.new(0, 0, 1)
	end
	if center.X < 0 then
		return Vector3.new(1, 0, 0)
	end
	return Vector3.new(-1, 0, 0)
end

return Layout
