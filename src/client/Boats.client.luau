--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.Boats
-- Drives your own boat (workspace.Boats, spawned by Boats.server, network-owned by you).
-- Only while you sit on the red chair does the move input steer it: the boat turns toward the
-- camera-relative direction and sails forward, held on the water surface. Jump to get up: the boat
-- coasts to a stop, you land beside the chair (not on it) and walk the deck (kept inside it: trained players run fast enough to pass
-- straight through the template's thin BoatBarrier walls). Walk back up to the chair
-- and you sit down again (after stepping away from it once, so a jump off doesn't re-seat you).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)

local player = Players.LocalPlayer
local sitRemote = GameUI.remote("BoatSit")
local folder = Workspace:WaitForChild("Boats")

local MAX_SPEED = 70 -- studs/s
local ACCEL = 30
local BRAKE = 45
local TURN = 1.7 -- rad/s at full input
local BOW = 13 -- studs from the boat's centre to its bow
local BOB = 0.15
local SIT_REACH = 2.6 -- studs from the chair (flat) that sit you down
local STEP_ASIDE = 3 -- getting up lands you this far to the chair's side
local REARM = 4.5 -- after getting up, step this far from the chair before it seats you again

-- deck outline in the boat's local X/Z (same as _blender/fishing_boat.py), shrunk by a body width
local DECK_OUTLINE = {
	Vector2.new(-5, 12), Vector2.new(5, 12), Vector2.new(5, -2.5), Vector2.new(3.4, -8.6),
	Vector2.new(1, -12.2), Vector2.new(-1, -12.2), Vector2.new(-3.4, -8.6), Vector2.new(-5, -2.5),
}
local DECK_INSET = 1.6
local ABOARD_RANGE = 40 -- further than this from the boat (respawn, teleport): no longer aboard
local edges: { { normal: Vector2, limit: number } } = {}
for i, a in DECK_OUTLINE do
	local b = DECK_OUTLINE[i % #DECK_OUTLINE + 1]
	local along = (b - a).Unit
	local normal = Vector2.new(along.Y, -along.X)
	if normal:Dot(a) < 0 then
		normal = -normal -- point away from the middle of the deck
	end
	table.insert(edges, { normal = normal, limit = normal:Dot(a) - DECK_INSET })
end

-- Keep a deck walker inside the outline (convex: push back across every edge it crossed).
local function keepAboard(root: BasePart, rootPart: BasePart)
	local here = root.CFrame:PointToObjectSpace(rootPart.Position)
	local p = Vector2.new(here.X, here.Z)
	local moved = false
	for _ = 1, 2 do
		for _, edge in edges do
			local over = edge.normal:Dot(p) - edge.limit
			if over > 0 then
				p -= edge.normal * over
				moved = true
			end
		end
	end
	if moved then
		local inside = root.CFrame:PointToWorldSpace(Vector3.new(p.X, here.Y, p.Y))
		rootPart.CFrame = rootPart.CFrame.Rotation + inside
		local boatVelocity = root.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(boatVelocity.X, rootPart.AssemblyLinearVelocity.Y, boatVelocity.Z)
	end
end

local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.FilterDescendantsInstances = { Workspace.Terrain }
waterParams.IgnoreWater = false

local function waterSurface(position: Vector3): number?
	local hit = Workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), waterParams)
	if hit and hit.Material == Enum.Material.Water then
		return hit.Position.Y
	end
	return nil
end

local boat: Model? = nil
local heading = 0
local speed = 0
local lastSit = 0
local armed = false -- may the chair seat us when we walk up to it
local aboard = false -- got up from the chair: walking the deck
local wasDriving = false

local function track(child: Instance)
	if child:IsA("Model") and child:GetAttribute("Owner") == player.UserId then
		boat = child
		speed = 0
		aboard = false
		wasDriving = false
		local root = child.PrimaryPart or child:WaitForChild("BoatRoot", 5) :: BasePart?
		if root then
			local _, yaw = root.CFrame:ToEulerAnglesYXZ()
			heading = yaw
		end
	end
end
folder.ChildAdded:Connect(track)
folder.ChildRemoved:Connect(function(child)
	if child == boat then
		boat = nil
	end
end)
for _, child in folder:GetChildren() do
	task.spawn(track, child)
end

-- the move input as a flat world direction (length 0..1), camera-relative like walking. The place has
-- no PlayerModule, but the seated Humanoid's MoveDirection still follows the controls.
local function steerInput(humanoid: Humanoid): Vector3
	local move = humanoid.MoveDirection
	local dir = Vector3.new(move.X, 0, move.Z)
	if dir.Magnitude < 0.05 then
		return Vector3.zero
	end
	return if dir.Magnitude > 1 then dir.Unit else dir
end

local function angleTo(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

-- Standing on the deck: walking right up to the chair sits you on it.
local function maybeSit(seat: Seat, humanoid: Humanoid, rootPart: BasePart)
	local offset = rootPart.Position - seat.Position
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if flat > REARM then
		armed = true
	end
	if armed and flat < SIT_REACH and math.abs(offset.Y) < 5 and os.clock() - lastSit > 0.5 then
		lastSit = os.clock()
		sitRemote:FireServer()
	end
end

RunService.PreSimulation:Connect(function(dt)
	local own = boat
	if not (own and own.Parent) then
		return
	end
	local root = own.PrimaryPart
	local drive = root and root:FindFirstChild("Drive") :: LinearVelocity?
	local upright = root and root:FindFirstChild("Upright") :: AlignOrientation?
	local seat = own:FindFirstChild("Seat") :: Seat?
	if not (root and drive and upright and seat) then
		return
	end
	dt = math.min(dt, 0.1)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local driving = humanoid ~= nil and seat.Occupant == humanoid

	local turning = 0
	local target = 0
	if driving and humanoid then
		local dir = steerInput(humanoid)
		if dir.Magnitude > 0 then
			local diff = angleTo(heading, math.atan2(-dir.X, -dir.Z))
			turning = math.clamp(diff * 3, -1, 1)
			heading += math.clamp(diff, -TURN * dt, TURN * dt)
			-- full ahead when facing the input, slow while swinging round
			target = MAX_SPEED * dir.Magnitude * math.max(0.25, math.cos(diff))
		end
		armed = false
		aboard = true
	elseif humanoid and rootPart then
		if wasDriving then
			-- just jumped up: come down on the deck beside the chair instead of back on it
			local here = root.CFrame:PointToObjectSpace(rootPart.Position)
			local chair = root.CFrame:PointToObjectSpace(seat.Position)
			local beside = root.CFrame:PointToWorldSpace(Vector3.new(chair.X + STEP_ASIDE, here.Y, chair.Z))
			rootPart.CFrame = rootPart.CFrame.Rotation + beside
		end
		if aboard and (rootPart.Position - root.Position).Magnitude > ABOARD_RANGE then
			aboard = false
		end
		if aboard and humanoid.Health > 0 then
			keepAboard(root, rootPart)
		end
		maybeSit(seat, humanoid, rootPart)
	end
	wasDriving = driving
	speed += math.clamp(target - speed, -BRAKE * dt, ACCEL * dt)

	local forward = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
	-- no water ahead (shore, plaza): stop at the edge
	if speed > 0 and not waterSurface(root.Position + forward * (BOW + speed * 0.25)) then
		speed = 0
	end
	local surface = waterSurface(root.Position) or root.Position.Y
	local height = surface + math.sin(os.clock() * 1.6) * BOB
	local rise = math.clamp((height - root.Position.Y) * 4, -20, 20)
	drive.VectorVelocity = forward * speed + Vector3.new(0, rise, 0)
	-- lean into turns, pitch the bow up a little with speed
	local lean = -turning * math.clamp(speed / MAX_SPEED, 0, 1) * math.rad(8)
	local pitch = math.clamp(speed / MAX_SPEED, 0, 1) * math.rad(3)
	upright.CFrame = CFrame.Angles(0, heading, 0) * CFrame.Angles(pitch, 0, lean)
end)
