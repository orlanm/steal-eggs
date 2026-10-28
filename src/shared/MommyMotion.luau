local Players = game:GetService("Players")
local MapConfig = require(script.Parent.MapConfig)
local Config = require(script.Parent.MommyConfig)
local Biomes = require(script.Parent.BiomeConfig)
local SpeedCurve = require(script.Parent.SpeedCurve)
local GuardConfig = require(script.Parent.GuardConfig)
local Motion = {}

local GUARD_SINK = 2 -- studs of a guard's body under the water line, asleep and chasing (ground: none)
local VOXEL = 4

-- The den's guard (GuardConfig), or nil for the old swimming T-rex. Guard pivots sit on the ground.
function Motion.guard(cell)
	local _, guard = GuardConfig.forHabitat(cell.Parent and cell.Parent.Name)
	return guard
end

-- World size (W, H, L) of the den's guard.
function Motion.guardSize(cell): Vector3
	local guard = Motion.guard(cell)
	if guard then
		return guard.Size * GuardConfig.scale(guard)
	end
	return Config.NativeSize * Motion.worldScale(cell) * Vector3.new(1, Motion.nativeY(cell) / Config.NativeSize.Y, 1)
end

function Motion.guardianPoints(cell): number
	local id = cell:GetAttribute("StyleId")
	if typeof(id) ~= "number" then
		return 10
	end
	for _, biome in Biomes do
		if biome.ZoneIndex == id then
			return biome.GuardianSpeed or biome.SpeedRequirement or 0
		end
	end
	return 10
end

local function flatOf(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Motion.opening(cell)
	return cell:GetAttribute("MouthWidth") or MapConfig.CellWidth, cell:GetAttribute("MouthHeight") or MapConfig.CellHeight
end

function Motion.worldScale(cell)
	local width, height = Motion.opening(cell)
	return math.min(height * 0.53 / Config.NativeSize.Y, width * 0.70 / Config.NativeSize.X, (MapConfig.CellDepth - 18) / Config.NativeSize.Z)
end

function Motion.nativeY(cell): number
	local habitat = cell.Parent and cell.Parent.Name
	if habitat then
		for _, name in Config.TurtleHabitats do
			if name == habitat then
				return Config.TurtleNativeSize.Y
			end
		end
		for _, name in Config.LeviathanHabitats do
			if name == habitat then
				return Config.LeviathanNativeSize.Y
			end
		end
	end
	return Config.NativeSize.Y
end

function Motion.visualHeight(cell): number
	if Motion.guard(cell) then
		return Motion.guardSize(cell).Y
	end
	return Motion.worldScale(cell) * Motion.nativeY(cell)
end

-- Is this XZ over water? Dens and the route channel have floors sunk under the plaza and filled with
-- water up to WaterTop; the plaza and dry dens have floors level with it. Terrain streams on the client,
-- so this looks at the floor parts instead: the first solid, visible part below (ignoring water, guards,
-- characters and the invisible WaterWalkSupport decks). Cached per 4-stud column once a floor is found;
-- with no floor streamed in yet it falls back to the den's Dry flag.
local waterCache: { [number]: boolean } = {}
local function solidFloor(part: BasePart): boolean
	if not part.CanCollide or part.Transparency >= 0.9 or part.Name == "WaterWalkSupport" or part:GetAttribute("WaterWalkSupport") then
		return false
	end
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model.Name:match("^Guard_") or Players:GetPlayerFromCharacter(model) then
			return false
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return true
end
function Motion.inWater(pos: Vector3, cell: Instance?): boolean
	local key = math.floor(pos.X / VOXEL) * 65536 + math.floor(pos.Z / VOXEL)
	local cached = waterCache[key]
	if cached ~= nil then
		return cached
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = {}
	local from = Vector3.new(pos.X, MapConfig.WaterTop + 40, pos.Z)
	for _ = 1, 8 do
		local hit = workspace:Raycast(from, Vector3.new(0, -80, 0), params)
		if not hit then
			break
		end
		local part = hit.Instance
		if part:IsA("BasePart") and solidFloor(part) and hit.Position.Y < MapConfig.WaterTop + 1 then
			local wet = hit.Position.Y < MapConfig.WaterTop - 0.5
			waterCache[key] = wet
			return wet
		end
		params:AddToFilter(part)
	end
	local dry = cell and cell.Parent and cell.Parent:GetAttribute("Dry")
	return not dry
end

-- Where a guard's lowest point belongs at this XZ: GUARD_SINK under the water line in water, on the
-- ground (level with the plaza) everywhere else. Used asleep, chasing and returning.
function Motion.lowestY(pos: Vector3, cell: Instance?): number
	return if Motion.inWater(pos, cell) then MapConfig.WaterTop - GUARD_SINK else MapConfig.WaterTop
end

-- Guards: their pivot is their lowest point (client groundPivot), so this is Motion.lowestY at `pos`
-- (default: the den's home spot). The old swimming T-rex: pivot at the mesh centre, 25% underwater.
function Motion.swimY(cell, pos: Vector3?): number
	if Motion.guard(cell) then
		return Motion.lowestY(pos or cell:GetAttribute("HomePosition"), cell)
	end
	local fraction = Config.SubmergeFraction or 0.25
	return MapConfig.WaterTop + Motion.visualHeight(cell) * (0.5 - fraction)
end

function Motion.rest(cell)
	local p = cell:GetAttribute("HomePosition")
	if Motion.guard(cell) then
		local ground = Vector3.new(p.X, Motion.lowestY(p, cell), p.Z)
		return CFrame.lookAt(ground, ground + cell:GetAttribute("Facing"))
	end
	local dropped = Vector3.new(p.X, p.Y - Config.RestDrop, p.Z)
	return CFrame.lookAt(dropped, dropped + cell:GetAttribute("Facing"))
end

function Motion.snout(cf, cell)
	return cf.Position + cf.LookVector * Motion.snoutReach(cell)
end

function Motion.snoutReach(cell)
	if Motion.guard(cell) then
		-- thin bipeds still reach out with their arms
		return math.max(Motion.guardSize(cell).Z * 0.5, 8)
	end
	return Config.SnoutOffset * Motion.worldScale(cell)
end

-- Aim on the player's XZ so swimming height doesn't break nose contact.
function Motion.groundTarget(cf, playerPos)
	return Vector3.new(playerPos.X, cf.Position.Y, playerPos.Z)
end

-- Place the body so the nose tip sits on the target (nose tackle pose).
function Motion.aimSnout(cf, cell, target)
	local aim = Motion.groundTarget(cf, target)
	local flat = flatOf(aim - cf.Position)
	local dir = if flat.Magnitude > 0.05 then flat.Unit else flatOf(cf.LookVector)
	if dir.Magnitude < 0.05 then
		dir = Vector3.zAxis
	else
		dir = dir.Unit
	end
	local body = aim - dir * Motion.snoutReach(cell)
	body = Vector3.new(body.X, Motion.swimY(cell, body), body.Z)
	return CFrame.lookAt(body, Vector3.new(target.X, body.Y, target.Z))
end

function Motion.throwDir(cf, cell, playerPos)
	local look = flatOf(cf.LookVector)
	if look.Magnitude > 0.05 then
		return look.Unit
	end
	local snout = Motion.snout(cf, cell)
	local away = flatOf(playerPos - snout)
	if away.Magnitude > 0.05 then
		return away.Unit
	end
	return Vector3.zAxis
end

function Motion.face(home, target)
	local delta = target - home.Position
	return if delta.Magnitude < 0.01 then home else CFrame.lookAt(home.Position, target)
end

function Motion.watching(cell, home, playerPosition)
	return home
end

function Motion.exitPoint(cell)
	local front = cell:GetAttribute("FrontCenter")
	local facing = cell:GetAttribute("Facing")
	local swim = Vector3.new(front.X, Motion.swimY(cell, front), front.Z)
	return swim + facing * (Motion.guardSize(cell).Z * 0.55)
end

-- Tip the body so the nose lands on the player. The chase itself stays at swim depth.
function Motion.noseStrike(cell, swimCF: CFrame, playerPos: Vector3): CFrame
	local reach = math.max(Motion.snoutReach(cell), 0.01)
	if Motion.guard(cell) then
		-- walkers stay on their feet: just face the player with the nose on them
		return Motion.aimSnout(swimCF, cell, playerPos)
	end
	local flat = flatOf(playerPos - swimCF.Position)
	local dir = if flat.Magnitude > 0.05 then flat.Unit else flatOf(swimCF.LookVector)
	if dir.Magnitude < 0.05 then
		dir = Vector3.zAxis
	else
		dir = dir.Unit
	end
	local lookY = math.clamp((playerPos.Y - swimCF.Position.Y) / reach, -0.92, 0.92)
	local horiz = math.sqrt(math.max(1e-4, 1 - lookY * lookY))
	local look = Vector3.new(dir.X * horiz, lookY, dir.Z * horiz).Unit
	local body = playerPos - look * reach
	return CFrame.lookAt(body, playerPos)
end

function Motion.advance(cf, cell, target, dt, exiting)
	local speed = SpeedCurve.studs(Motion.guardianPoints(cell))
	local aim = if exiting then target else Motion.groundTarget(cf, target)
	local delta = flatOf(aim - cf.Position)
	if delta.Magnitude < 0.01 then
		return if exiting then cf else Motion.aimSnout(cf, cell, target)
	end
	local direction = delta.Unit

	if exiting then
		local move = aim - cf.Position
		local pos = cf.Position
		if move.Magnitude >= 0.01 then
			pos += move.Unit * math.min(speed * math.clamp(dt, 0, 0.1), move.Magnitude)
		end
		return CFrame.lookAt(pos, pos + direction)
	end

	-- Horizontal nose gap — ignore swim height so contact still works in water.
	local snoutNow = Motion.snout(cf, cell)
	local noseGap = flatOf(aim - snoutNow).Magnitude
	if noseGap <= Config.CatchReach then
		return Motion.aimSnout(cf, cell, target)
	end

	-- Desired body pose keeps the snout on the player; never step past that pose.
	local desired = aim - direction * Motion.snoutReach(cell)
	local toDesired = desired - cf.Position
	local flatDesired = flatOf(toDesired)
	if flatDesired.Magnitude < 0.05 then
		return Motion.aimSnout(cf, cell, target)
	end

	local step = math.min(speed * math.clamp(dt, 0, 0.1), flatDesired.Magnitude)
	-- Leave a tiny gap so we settle into CatchReach instead of freezing short.
	local maxStep = math.max(0, noseGap - Config.CatchReach * 0.35)
	step = math.min(step, maxStep)
	if step < 0.001 then
		return Motion.aimSnout(cf, cell, target)
	end

	local pos = cf.Position + flatDesired.Unit * step
	pos = Vector3.new(pos.X, Motion.swimY(cell, pos), pos.Z)
	-- Soft overtake guard: if this step would put the snout past the player, snap to contact.
	local nextSnout = pos + direction * Motion.snoutReach(cell)
	if flatOf(nextSnout - aim):Dot(direction) > 0.5 then
		return Motion.aimSnout(cf, cell, target)
	end
	local aimAt = Vector3.new(aim.X, pos.Y, aim.Z)
	return CFrame.lookAt(pos, aimAt)
end

function Motion.caught(cf, cell, playerPos)
	local snout = Motion.snout(cf, cell)
	local aim = Motion.groundTarget(cf, playerPos)
	return flatOf(snout - aim).Magnitude <= Config.CatchReach
end

return Motion
