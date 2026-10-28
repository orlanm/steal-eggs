--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.PenNodes
-- Pen spots. A pet reserves a rectangle of the pen floor the size of its footprint (static size,
-- widened to its egg at full growth) plus a gap, so neighbours never overlap or clip.
-- A pet lands exactly where the owner clicked; it only moves when that spot would leave the pen
-- or overlap another pet, and then to the nearest free point (1-stud steps). Pet centres stay off
-- the spawn pad in the middle, and footprints stay inside the fence.

local PenNodes = {}

local GAP = 1 -- studs kept clear between neighbouring pets
local EDGE = 2 -- studs left free inside the fence
local SPAWN_CLEAR = 4 -- pet centres stay out of this square around the pen centre (8x8 spawn pad)
local STEP = 1 -- studs between candidate points when the clicked spot is taken
local FLOOR_FALLBACK = 0.45 -- floor height above Center.Y when the raycast misses

type Spot = { x: number, z: number, hx: number, hz: number } -- pen-local centre + half extents

type Grid = {
	tank: Instance,
	center: Vector3,
	right: Vector3,
	face: Vector3,
	half: number, -- usable half width (fence half size minus EDGE)
	used: { [Model]: Spot },
}

export type Claim = {
	cframe: CFrame, -- floor point under the pet centre, facing the pen front
}

local grids: { [Instance]: Grid } = {}

local function flatFront(tank: Instance): Vector3
	local front = tank:GetAttribute("FrontDir")
	if typeof(front) == "Vector3" then
		local flat = Vector3.new(front.X, 0, front.Z)
		if flat.Magnitude > 0.05 then
			return flat.Unit
		end
	end
	return Vector3.zAxis
end

local function grid(tank: Instance): Grid
	local g = grids[tank]
	if g then
		return g
	end
	local center = tank:GetAttribute("Center")
	local half = tank:GetAttribute("HalfSize")
	local face = flatFront(tank)
	g = {
		tank = tank,
		center = if typeof(center) == "Vector3" then center else Vector3.zero,
		face = face,
		right = Vector3.new(-face.Z, 0, face.X),
		half = math.max(1, (if typeof(half) == "number" then half else 40) - EDGE),
		used = {},
	}
	grids[tank] = g
	return g
end

local function floorAt(g: Grid, pos: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(pos.X, g.center.Y + 40, pos.Z), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else g.center.Y + FLOOR_FALLBACK
end

-- Keep a footprint inside the fence (a footprint wider than the pen is centred on that axis).
local function clampAxis(v: number, h: number, half: number): number
	local room = half - h
	return if room <= 0 then 0 else math.clamp(v, -room, room)
end

local function free(g: Grid, x: number, z: number, hx: number, hz: number): boolean
	if math.abs(x) < SPAWN_CLEAR and math.abs(z) < SPAWN_CLEAR then
		return false
	end
	for _, s in g.used do
		if math.abs(x - s.x) < hx + s.hx + GAP and math.abs(z - s.z) < hz + s.hz + GAP then
			return false
		end
	end
	return true
end

-- The free spot nearest `near` (default: the pen centre) for a footprint, in pen-local studs.
-- maxDist: give up when the nearest free spot is farther than this (flat studs) from `near`.
local function find(g: Grid, extents: Vector3, near: Vector3?, maxDist: number?): Spot?
	local hx, hz = extents.X * 0.5, extents.Z * 0.5
	local d = (near or g.center) - g.center
	local tx, tz = d:Dot(g.right), d:Dot(g.face)
	local x, z = clampAxis(tx, hx, g.half), clampAxis(tz, hz, g.half)
	local best: Spot? = nil
	local bestD = math.huge
	if free(g, x, z, hx, hz) then
		best, bestD = { x = x, z = z, hx = hx, hz = hz }, math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2)
	else
		local rx, rz = math.max(0, g.half - hx), math.max(0, g.half - hz)
		for cx = -rx, rx, STEP do
			for cz = -rz, rz, STEP do
				local dist = math.sqrt((cx - tx) ^ 2 + (cz - tz) ^ 2)
				if dist < bestD and free(g, cx, cz, hx, hz) then
					best, bestD = { x = cx, z = cz, hx = hx, hz = hz }, dist
				end
			end
		end
	end
	if maxDist and bestD > maxDist then
		return nil
	end
	return best
end

-- Is there a free spot for this footprint within maxDist of `near`?
function PenNodes.fits(tank: Instance, extents: Vector3, near: Vector3?, maxDist: number?): boolean
	return find(grid(tank), extents, near, maxDist) ~= nil
end

-- Reserve the free spot nearest `near` (default: the pen centre). ignore: instances the floor
-- raycast skips (pets, characters). Returns nil when the pen is full (or nothing is within maxDist).
function PenNodes.claim(tank: Instance, owner: Model, extents: Vector3, ignore: { Instance }, near: Vector3?, maxDist: number?): Claim?
	local g = grid(tank)
	local spot = find(g, extents, near, maxDist)
	if not spot then
		return nil
	end
	g.used[owner] = spot
	owner.Destroying:Connect(function()
		PenNodes.release(tank, owner)
	end)
	local pos = g.center + g.right * spot.x + g.face * spot.z
	local floor = Vector3.new(pos.X, floorAt(g, pos, ignore), pos.Z)
	return {
		cframe = CFrame.lookAt(floor, floor + g.face),
	}
end

-- A world point as (right, front) studs from the pen centre, so a spot survives a pen change.
function PenNodes.toLocal(tank: Instance, pos: Vector3): (number, number)
	local g = grid(tank)
	local d = pos - g.center
	return d:Dot(g.right), d:Dot(g.face)
end

function PenNodes.fromLocal(tank: Instance, x: number, z: number): Vector3
	local g = grid(tank)
	return g.center + g.right * x + g.face * z
end

function PenNodes.release(tank: Instance, owner: Model)
	local g = grids[tank]
	if g then
		g.used[owner] = nil
	end
end

return PenNodes
