-- Studio (Edit) QA stage for guard animations. Load with loadstring(HttpGet(".../file/qa_stage.luau"))().
-- _G.GQA.stage(sourceFolder?)       clone every guard rig into workspace.GuardQA on its own floor plate
-- _G.GQA.pose(name, clip, t)        play out/<name>_<clip>.rbxmx (fetched fresh) at time t (seconds)
-- _G.GQA.cam(name, view)            frame the camera on one guard ("side", "front", "three")
local Http = game:GetService("HttpService")
local KSP = game:GetService("KeyframeSequenceProvider")
local SS = game:GetService("SerializationService")
local BASE = "http://127.0.0.1:8804/file/"
local GQA = _G.GQA or {}
_G.GQA = GQA
GQA.guards = GQA.guards or {}
GQA.tracks = GQA.tracks or {}

local function rigOf(guard: Instance): Model?
	for _, c in guard:GetChildren() do
		if c:IsA("Model") and c:FindFirstChildOfClass("AnimationController") then
			return c
		end
	end
	return nil
end
GQA.rigOf = rigOf

function GQA.stage(source: Instance?, names: { string }?)
	source = source or game.ServerStorage.GuardImports
	local old = workspace:FindFirstChild("GuardQA")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "GuardQA"
	folder.Parent = workspace
	GQA.guards = {}
	GQA.tracks = {}
	local list = {}
	for _, g in source:GetChildren() do
		if not names or table.find(names, g.Name) then
			table.insert(list, g)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for i, g in list do
		local clone = g:Clone()
		local rig = rigOf(clone)
		if not rig then
			continue
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("AlignOrientation") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
			end
		end
		local root = _G.GQA_ROOTS and _G.GQA_ROOTS[g.Name] and rig:FindFirstChild(_G.GQA_ROOTS[g.Name], true)
			or rig:FindFirstChild("RootPart") or rig:FindFirstChild("Root") or rig:FindFirstChild("HumanoidRootPart")
		local origin = Vector3.new((i - 1) * 160 - 1000, 400, -2400)
		local _, size = rig:GetBoundingBox()
		local offset = origin - root.Position
		clone:PivotTo(clone:GetPivot() + offset)
		root.Anchored = true
		clone.Parent = folder
		local cf, bb = rig:GetBoundingBox()
		local plate = Instance.new("Part")
		plate.Name = "Floor_" .. g.Name
		plate.Anchored = true
		plate.Size = Vector3.new(140, 1, 140)
		plate.Color = Color3.fromRGB(90, 150, 90)
		plate.Material = Enum.Material.SmoothPlastic
		plate.CFrame = CFrame.new(origin.X, cf.Position.Y - bb.Y / 2 - 0.5, origin.Z)
		plate.Parent = folder
		GQA.guards[g.Name] = { model = clone, rig = rig, root = root, origin = origin, size = size, floorY = plate.Position.Y + 0.5 }
	end
	return #list
end

function GQA.track(name: string, clip: string, fresh: boolean?)
	local key = name .. "_" .. clip
	if GQA.tracks[key] and not fresh then
		return GQA.tracks[key]
	end
	local g = GQA.guards[name]
	local body = Http:GetAsync(BASE .. "out/" .. Http:UrlEncode(key) .. ".rbxmx", true)
	local ks = SS:DeserializeInstancesAsync(buffer.fromstring(body))[1]
	local anim = Instance.new("Animation")
	anim.AnimationId = KSP:RegisterKeyframeSequence(ks)
	local animator = g.rig:FindFirstChildWhichIsA("Animator", true)
	local tr = animator:LoadAnimation(anim)
	local t0 = os.clock()
	while tr.Length == 0 and os.clock() - t0 < 8 do
		task.wait(0.05)
	end
	GQA.tracks[key] = tr
	return tr
end

function GQA.pose(name: string, clip: string, t: number, fresh: boolean?)
	local g = GQA.guards[name]
	local animator = g.rig:FindFirstChildWhichIsA("Animator", true)
	for _, other in animator:GetPlayingAnimationTracks() do
		other:Stop(0)
	end
	local tr = GQA.track(name, clip, fresh)
	tr:Play(0)
	tr:AdjustSpeed(0)
	tr.TimePosition = math.min(t, math.max(tr.Length - 1e-3, 0))
	animator:StepAnimations(0)
	return tr.Length
end

function GQA.cam(name: string, view: string?, zoom: number?)
	local g = GQA.guards[name]
	local cf, size = g.rig:GetBoundingBox()
	local d = math.max(size.X, size.Y, size.Z) * (zoom or 1.35)
	local c = Vector3.new(g.origin.X, g.floorY + size.Y * 0.45, g.origin.Z)
	local dir = if view == "front" then Vector3.new(0, 0.25, -1)
		elseif view == "side" then Vector3.new(1, 0.15, 0)
		elseif view == "top" then Vector3.new(0.05, 1, 0.05)
		else Vector3.new(0.8, 0.35, -0.7)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(c + dir.Unit * d, c)
end

return "GQA ready"
