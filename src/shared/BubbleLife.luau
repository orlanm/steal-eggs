--!strict
local MapConfig = require(script.Parent.MapConfig)
local BubbleConfig = require(script.Parent.BubbleConfig)
local GameUI = require(script.Parent.GameUI)
local MommyMotion = require(script.Parent.MommyMotion)

local BubbleLife = {}
local NATIVE = Vector3.new(1.49478, 1.71468, 1.89981)

function BubbleLife.pastel(index: number): Color3
	local colors = BubbleConfig.Pastels
	return colors[((index - 1) % #colors) + 1]
end

function BubbleLife.caveFloor(den: Instance): (Vector3, Vector3, number, number)
	local front = den:GetAttribute("FrontCenter")
	local facing = den:GetAttribute("Facing")
	local depth = den:GetAttribute("Depth")
	local mouth = den:GetAttribute("MouthWidth")
	if typeof(front) ~= "Vector3" then
		front = (den :: Model):GetBoundingBox().Position
	end
	if typeof(facing) ~= "Vector3" or (facing :: Vector3).Magnitude < 0.05 then
		facing = Vector3.new(0, 0, 1)
	end
	if typeof(depth) ~= "number" then
		depth = 70
	end
	if typeof(mouth) ~= "number" then
		mouth = 50
	end
	return front :: Vector3, (facing :: Vector3).Unit, depth :: number, mouth :: number
end

export type Spot = {
	radius: number,
	rank: number,
}

-- Half the guardian's length (into the cell) and width (across the mouth).
local function guardianHalf(den: Instance): (number, number)
	local size = MommyMotion.guardSize(den)
	return size.Z * 0.5, size.X * 0.5
end

-- Light eggs take the mouth. Heavy eggs sit beside and behind the guardian.
-- Each egg keeps its own node. Nothing is stacked.
function BubbleLife.layout(den: Instance, spots: { Spot }): { Vector3 }
	local n = #spots
	local positions = table.create(n)
	if n == 0 then
		return positions
	end
	local front, facing, depth, mouth = BubbleLife.caveFloor(den)
	local right = Vector3.new(-facing.Z, 0, facing.X)
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local inward = -facing
	local half = mouth * 0.5
	local inset = BubbleConfig.MouthInset
	local gap = BubbleConfig.NeighborGap
	local bar = BubbleConfig.BarClearance
	local backLimit = math.max(depth - 4, bar + 4)

	local guardU = depth * 0.5
	local home = den:GetAttribute("HomePosition")
	if typeof(home) == "Vector3" then
		local along = (home - front):Dot(inward)
		if along > 1 then
			guardU = along
		end
	end
	local halfU, halfV = guardianHalf(den)

	local radius = table.create(n)
	local rank = table.create(n)
	local order = table.create(n)
	for index, spot in spots do
		radius[index] = math.max(spot.radius, 0.6)
		rank[index] = spot.rank
		order[index] = index
	end
	table.sort(order, function(a, b)
		if rank[a] ~= rank[b] then
			return rank[a] < rank[b]
		end
		return a < b
	end)

	local u = table.create(n, 0)
	local v = table.create(n, 0)
	local placed = table.create(n, false)

	local function hitsGuardian(uu: number, vv: number, r: number): boolean
		local nearestU = math.clamp(uu, guardU - halfU, guardU + halfU)
		local nearestV = math.clamp(vv, -halfV, halfV)
		local du = uu - nearestU
		local dv = vv - nearestV
		local need = r + gap * 0.65
		return du * du + dv * dv < need * need
	end

	local function hitsEgg(uu: number, vv: number, r: number, selfIndex: number): boolean
		for other = 1, n do
			if other ~= selfIndex and placed[other] then
				local du = uu - u[other]
				local dv = vv - v[other]
				local need = r + radius[other] + gap
				if du * du + dv * dv < need * need then
					return true
				end
			end
		end
		return false
	end

	local function inBounds(uu: number, vv: number, r: number): boolean
		if uu - r < bar - 0.2 then
			return false
		end
		if uu + r > backLimit + 0.2 then
			return false
		end
		if math.abs(vv) + r > half - inset + 0.2 then
			return false
		end
		return true
	end

	local function fits(uu: number, vv: number, r: number, selfIndex: number): boolean
		return inBounds(uu, vv, r) and not hitsGuardian(uu, vv, r) and not hitsEgg(uu, vv, r, selfIndex)
	end

	local function commit(index: number, uu: number, vv: number)
		local r = radius[index]
		local limit = math.max(half - inset - r, 0)
		vv = math.clamp(vv, -limit, limit)
		local uMin = bar + r
		local uMax = math.max(backLimit - r, uMin)
		uu = math.clamp(uu, uMin, uMax)
		u[index] = uu
		v[index] = vv
		placed[index] = true
	end

	local frontCount = math.min(3, n)
	local rowOrder = table.create(frontCount)
	if frontCount == 1 then
		rowOrder[1] = order[1]
	elseif frontCount == 2 then
		rowOrder[1] = order[1]
		rowOrder[2] = order[2]
	else
		-- Lightest eggs on the two outer corners. The next one stays at the front center.
		rowOrder[1] = order[1]
		rowOrder[2] = order[3]
		rowOrder[3] = order[2]
	end
	local sumDiameter = 0
	for _, index in rowOrder do
		sumDiameter += radius[index] * 2
	end
	local available = math.max((half - inset) * 2, 4)
	local gapCount = #rowOrder - 1
	local useGap = gap
	if gapCount > 0 then
		useGap = (available - sumDiameter) / gapCount
		if useGap < 1 then
			useGap = 1
		end
	end
	local width = sumDiameter + useGap * math.max(gapCount, 0)
	if width > available and width > 0 then
		local fit = available / width
		useGap *= fit
		width = available
	end
	local cursor = -width / 2
	local frontBack = bar
	for _, index in rowOrder do
		local r = radius[index]
		commit(index, bar + r, cursor + r)
		cursor += r * 2 + useGap
		frontBack = math.max(frontBack, u[index] + r)
	end

	for slot = 4, math.min(5, n) do
		local index = order[slot]
		local r = radius[index]
		local sign = if slot == 4 then -1 else 1
		local limit = math.max(half - inset - r, 0)
		local uu = frontBack + gap + r
		local vv = sign * limit
		if not fits(uu, vv, r, index) then
			for step = 1, 18 do
				local tryU = uu + step * (r * 0.3 + 1.2)
				if fits(tryU, vv, r, index) then
					uu = tryU
					break
				end
			end
		end
		commit(index, uu, vv)
		frontBack = math.max(frontBack, u[index] + r)
	end

	for slot = 6, n do
		local index = order[slot]
		local r = radius[index]
		local sign = if slot % 2 == 0 then -1 else 1
		local behindU = guardU + halfU + gap + r
		local aheadU = guardU - halfU - gap - r
		local besideV = sign * (halfV + gap + r)
		local sideV = sign * math.max(half - inset - r, 0)
		local candidates: { { number } } = {}
		if slot == n then
			table.insert(candidates, { behindU, 0 })
			table.insert(candidates, { behindU, sideV * 0.42 })
			table.insert(candidates, { behindU, -sideV * 0.42 })
		elseif slot >= n - 2 then
			table.insert(candidates, { guardU, besideV })
			table.insert(candidates, { guardU, sideV })
			table.insert(candidates, { behindU, besideV * 0.5 })
			table.insert(candidates, { aheadU, 0 })
		else
			table.insert(candidates, { aheadU, 0 })
			table.insert(candidates, { guardU, besideV })
			table.insert(candidates, { behindU, besideV * 0.5 })
			table.insert(candidates, { aheadU, sideV * 0.35 })
		end
		local chosenU = candidates[1][1]
		local chosenV = candidates[1][2]
		local found = false
		for _, candidate in candidates do
			if fits(candidate[1], candidate[2], r, index) then
				chosenU = candidate[1]
				chosenV = candidate[2]
				found = true
				break
			end
		end
		if not found then
			for step = 0, 26 do
				local tryU = frontBack + gap + r + step * (gap + 1.25)
				local lane = step % 3
				local tryV = if lane == 0 then sideV * 0.2 elseif lane == 1 then sideV else besideV
				if fits(tryU, tryV, r, index) then
					chosenU = tryU
					chosenV = tryV
					found = true
					break
				end
			end
		end
		commit(index, chosenU, chosenV)
	end

	for _ = 1, 8 do
		local moved = false
		for aIndex = 1, n do
			for bIndex = aIndex + 1, n do
				local du = u[bIndex] - u[aIndex]
				local dv = v[bIndex] - v[aIndex]
				local dist = math.sqrt(du * du + dv * dv)
				local need = radius[aIndex] + radius[bIndex] + gap
				if dist < need - 0.05 then
					local push = (need - dist) * 0.5
					local dirU = 1
					local dirV = 0
					if dist >= 0.05 then
						dirU = du / dist
						dirV = dv / dist
					end
					local lighter = if rank[aIndex] <= rank[bIndex] then aIndex else bIndex
					local heavier = if lighter == aIndex then bIndex else aIndex
					u[lighter] -= math.abs(dirU) * push
					v[lighter] -= dirV * push * 0.35
					u[heavier] += math.abs(dirU) * push
					v[heavier] += dirV * push * 0.35
					moved = true
				end
			end
		end
		for index = 1, n do
			local r = radius[index]
			if hitsGuardian(u[index], v[index], r) then
				local sign = if v[index] < 0 then -1 else 1
				local side = sign * (halfV + gap + r)
				if not hitsGuardian(u[index], side, r) then
					v[index] = side
				else
					u[index] = guardU + halfU + gap + r
				end
				moved = true
			end
			commit(index, u[index], v[index])
		end
		if not moved then
			break
		end
	end

	for index = 1, n do
		local flat = front + inward * u[index] + right * v[index]
		local y = MapConfig.WaterTop + BubbleConfig.BottomClearance + radius[index]
		positions[index] = Vector3.new(flat.X, y, flat.Z)
	end
	return positions
end

function BubbleLife.slotOrigin(den: Instance, row: number, col: number, shellSize: number): Vector3
	local spots: { Spot } = table.create(BubbleConfig.PerCell)
	for index = 1, BubbleConfig.PerCell do
		spots[index] = { radius = 2, rank = index }
	end
	local index = (row - 1) * BubbleConfig.Columns + col
	spots[index] = { radius = math.max(shellSize, 1) * 0.5, rank = 100 }
	local placed = BubbleLife.layout(den, spots)
	return placed[index]
end

function BubbleLife.spawnPoint(den: Instance, _rng: Random, shellSize: number): Vector3
	return BubbleLife.slotOrigin(den, 1, 2, shellSize)
end

function BubbleLife.bodySize(meshScale: number): Vector3
	return NATIVE * meshScale
end

function BubbleLife.shellSize(meshScale: number): number
	local body = BubbleLife.bodySize(meshScale)
	return math.max(body.X, body.Y, body.Z) * 1.22
end

export type Pose = {
	origin: Vector3,
	rise: number,
	spin: number,
	yaw: number,
	phase: number,
	born: number,
}

function BubbleLife.age(born: number, now: number): number
	return math.max(0, now - born)
end

function BubbleLife.pose(origin: Vector3, _rise: number, _spin: number, _yaw0: number, _phase: number, _age: number): (CFrame, number)
	return CFrame.new(origin), origin.Y
end

function BubbleLife.poseFrom(inst: Instance, now: number): (CFrame, number)
	local origin = inst:GetAttribute("Origin")
	local rise = inst:GetAttribute("Rise")
	local spin = inst:GetAttribute("Spin")
	local yaw = inst:GetAttribute("Yaw")
	local phase = inst:GetAttribute("Phase")
	local born = inst:GetAttribute("Born")
	if typeof(origin) ~= "Vector3" then
		origin = Vector3.zero
	end
	if typeof(rise) ~= "number" then
		rise = BubbleConfig.RiseMin
	end
	if typeof(spin) ~= "number" then
		spin = BubbleConfig.SpinMin
	end
	if typeof(yaw) ~= "number" then
		yaw = 0
	end
	if typeof(phase) ~= "number" then
		phase = 0
	end
	if typeof(born) ~= "number" then
		born = now
	end
	return BubbleLife.pose(origin, rise, spin, yaw, phase, BubbleLife.age(born, now))
end

function BubbleLife.waterLine(): number
	return (MapConfig.BubbleCeiling or MapConfig.WaterTop) - BubbleConfig.PopSurface
end

function BubbleLife.feetY(character: Model): number?
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid and humanoid.HipHeight > 0 then humanoid.HipHeight else 2
	return hrp.Position.Y - hrp.Size.Y * 0.5 - hip
end

function BubbleLife.popLine(standY: number): number
	return standY + BubbleConfig.PlayerHeight * BubbleConfig.PopHeights
end

function BubbleLife.modelId(): string
	return GameUI.modelIdForLevel(GameUI.CurrentLevel)
end

return BubbleLife
