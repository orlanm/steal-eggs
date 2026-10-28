-- Studio Edit (MCP execute_luau or command bar): build ServerStorage.FishingBoat from the uploaded
-- Blender model (_blender/fishing_boat.py -> _tools/boat/upload_boat.py). Save the place afterwards.
-- Model space: bow toward -Z, waterline at Y = 0, deck top at Y = 1.6, chair cushion top at Y = 3.75.
local ASSET = 78259234163669 -- _tools/boat/uploaded.json
local DECK = 1.6
local BARRIER_TOP = DECK + 8 -- higher than a jump: you can't leave the boat
-- deck outline pushed 0.4 studs outside the rim (same outline as the Blender script)
local BARRIER = {
	Vector2.new(-5.4, 12.4), Vector2.new(5.4, 12.4), Vector2.new(5.4, -2.55), Vector2.new(3.77, -8.77),
	Vector2.new(1.21, -12.6), Vector2.new(-1.21, -12.6), Vector2.new(-3.77, -8.77), Vector2.new(-5.4, -2.55),
}
local STYLE = {
	Red = { Color3.fromRGB(205, 42, 42), 0 },
	White = { Color3.fromRGB(242, 242, 242), 0 },
	Blue = { Color3.fromRGB(40, 112, 222), 0 },
	Deck = { Color3.fromRGB(192, 194, 200), 0 },
	Dark = { Color3.fromRGB(64, 66, 74), 0 },
	-- not Enum.Material.Glass: it hides transparent parts behind it
	Glass = { Color3.fromRGB(150, 212, 255), 0.55 },
	Navy = { Color3.fromRGB(30, 42, 92), 0 },
	Grey = { Color3.fromRGB(150, 152, 160), 0 },
	Black = { Color3.fromRGB(26, 26, 30), 0 },
	Seat = { Color3.fromRGB(222, 40, 40), 0 },
}
local COLLIDE = {
	Red_Hull = Enum.CollisionFidelity.Hull,
	Blue_Rim = Enum.CollisionFidelity.PreciseConvexDecomposition,
	Deck_Floor = Enum.CollisionFidelity.Hull,
	Glass_Tank = Enum.CollisionFidelity.Hull,
	Grey_TankRim = Enum.CollisionFidelity.Hull,
	White_Console = Enum.CollisionFidelity.Box,
	Seat_Back = Enum.CollisionFidelity.Box,
}

local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("FishingBoatTemplate")
local raw = game:GetService("InsertService"):LoadAsset(ASSET)
local old = game.ServerStorage:FindFirstChild("FishingBoat")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "FishingBoat"
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model:SetAttribute("KeepFinish", true)
model:SetAttribute("SourceAsset", ASSET)

-- invisible root at the waterline: carries the mass and Boats.client's drive constraints
local root = Instance.new("Part")
root.Name = "BoatRoot"
root.Size = Vector3.new(9, 1, 22)
root.CFrame = CFrame.new()
root.Transparency = 1
root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
root.Parent = model
model.PrimaryPart = root
local att = Instance.new("Attachment")
att.Name = "Root"
att.Parent = root
local drive = Instance.new("LinearVelocity")
drive.Name = "Drive"
drive.Attachment0 = att
drive.RelativeTo = Enum.ActuatorRelativeTo.World
drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
drive.MaxForce = 400000
drive.VectorVelocity = Vector3.zero
drive.Parent = root
local upright = Instance.new("AlignOrientation")
upright.Name = "Upright"
upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
upright.Attachment0 = att
upright.MaxTorque = 4000000
upright.Responsiveness = 25
upright.CFrame = CFrame.new()
upright.Parent = root

local function attach(part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

for _, p in raw:GetDescendants() do
	if p:IsA("MeshPart") then
		local n = p:Clone()
		local g = STYLE[p.Name:match("^(%a+)_")] or STYLE.Grey
		n.Color, n.Material, n.MaterialVariant, n.Transparency = g[1], Enum.Material.SmoothPlastic, "", g[2]
		if p.Name:match("^Glass_") then
			n.Reflectance = 0.15
		end
		local fidelity = COLLIDE[p.Name]
		n.CanCollide = fidelity ~= nil
		n.CanQuery = fidelity ~= nil
		n.CanTouch = false
		if fidelity then
			n.CollisionFidelity = fidelity
		end
		attach(n)
	end
end
raw:Destroy()

-- the red chair: Boats.client asks the server to Sit you when you walk up to it (no touch-sitting)
local seat = Instance.new("Seat")
seat.Name = "Seat"
seat.Size = Vector3.new(2.4, 0.4, 2.2)
seat.CFrame = CFrame.new(0, 3.95, 8.9)
seat.Transparency = 1
seat.CanCollide = false
seat.CanTouch = false
attach(seat)

for i, a in BARRIER do
	local b = BARRIER[i % #BARRIER + 1]
	local mid = (a + b) / 2
	local wall = Instance.new("Part")
	wall.Name = "BoatBarrier"
	wall.Size = Vector3.new(0.5, BARRIER_TOP - 0.5, (b - a).Magnitude + 0.5)
	wall.CFrame = CFrame.lookAt(Vector3.new(mid.X, (BARRIER_TOP + 0.5) / 2, mid.Y), Vector3.new(b.X, (BARRIER_TOP + 0.5) / 2, b.Y))
	wall.Transparency = 1
	wall.CanQuery, wall.CanTouch = false, false
	attach(wall)
end

model.Parent = game.ServerStorage
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return #model:GetChildren()
