--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.ConsoleVfx
-- Codex show-and-fade sunburst, remapped onto the upright treadmill console face.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "TreadmillConsoleVfx"
local MAX_DIST = 260
local IN_SPAN, IN_STAG = 0.20, 0.15
local HOLD_END, OUT_SPAN, OUT_STAG = 0.62, 0.18, 0.15
local GONE = 0.96

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function backOut(x: number): number
	x = math.clamp(x, 0, 1)
	local c1 = 1.5
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

type PartData = {
	part: BasePart,
	isBar: boolean,
	a: Vector2,
	ang: number,
	size: Vector3,
	layer: number,
	delay: number,
	baseT: number,
	lastT: number,
}

type Effect = {
	model: Model,
	period: number,
	phase: number,
	speeds: { number },
	outFirst: boolean,
	radius: number,
	scale: number,
	parts: { PartData },
	partsArr: { BasePart },
	cfs: { CFrame },
	hidden: boolean,
}

local effects: { [Model]: Effect } = {}

local function readVector2(value: unknown, fallback: Vector2): Vector2
	if typeof(value) == "Vector2" then
		return value
	elseif typeof(value) == "Vector3" then
		local v = value :: Vector3
		return Vector2.new(v.X, v.Y)
	end
	return fallback
end

local function readVector3(value: unknown, fallback: Vector3): Vector3
	if typeof(value) == "Vector3" then
		return value
	end
	return fallback
end

-- Upright console face: Right along screen X, Up along screen Y, Look toward the runner.
local function consoleFace(model: Model): CFrame?
	local parent = model.Parent
	if not parent then
		return nil
	end
	local screen = parent:FindFirstChild("VideoFeedScreen")
	if not (screen and screen:IsA("BasePart")) then
		screen = parent:FindFirstChild("VideoDecorationPart")
	end
	if not (screen and screen:IsA("BasePart")) then
		local attr = model:GetAttribute("FaceCFrame")
		if typeof(attr) == "CFrame" then
			return attr
		end
		return nil
	end

	-- Prefer the side that faces the treadmill deck / runner.
	local originAttr = parent:GetAttribute("Origin")
	local towardRunner = if typeof(originAttr) == "CFrame"
		then (originAttr.Position - screen.Position)
		else -screen.CFrame.LookVector
	if towardRunner.Magnitude < 1e-4 then
		towardRunner = -screen.CFrame.LookVector
	else
		towardRunner = towardRunner.Unit
	end
	local depth = screen.Size.Z * 0.5 + 0.06
	local pos = screen.Position + towardRunner * depth
	-- Standing upright on the console: look at the runner, world up.
	return CFrame.lookAt(pos, pos + towardRunner, Vector3.yAxis)
end

local function bind(model: Model)
	if effects[model] then
		return
	end
	local shape = model:FindFirstChild("Shape")
	if not shape then
		return
	end
	local period = model:GetAttribute("Period")
	if typeof(period) ~= "number" then
		warn("[ConsoleVfx] Missing Period on", model:GetFullName())
		return
	end

	local speedsAttr = readVector3(model:GetAttribute("Speeds"), Vector3.new(0.55, -0.6, 0.2))
	local scaleAttr = model:GetAttribute("VfxScale")
	local radiusAttr = model:GetAttribute("Radius")
	local phaseAttr = model:GetAttribute("Phase")

	local effect: Effect = {
		model = model,
		period = period,
		phase = if typeof(phaseAttr) == "number" then phaseAttr else 0,
		speeds = { speedsAttr.X, speedsAttr.Y, speedsAttr.Z },
		outFirst = model:GetAttribute("OutFirst") == true,
		radius = if typeof(radiusAttr) == "number" then radiusAttr else 6.5,
		scale = if typeof(scaleAttr) == "number" then scaleAttr else 1,
		parts = {},
		partsArr = {},
		cfs = {},
		hidden = false,
	}

	for _, p in shape:GetChildren() do
		if p:IsA("BasePart") then
			local size0 = readVector3(p:GetAttribute("Size0"), p.Size)
			local ang = p:GetAttribute("Ang")
			local layer = p:GetAttribute("Layer")
			local delay = p:GetAttribute("Delay")
			local baseT = p:GetAttribute("BaseT")
			table.insert(effect.parts, {
				part = p,
				isBar = p:GetAttribute("Kind") == "bar",
				a = readVector2(p:GetAttribute("A"), Vector2.zero),
				ang = if typeof(ang) == "number" then ang else 0,
				size = size0,
				layer = if typeof(layer) == "number" then layer else 0,
				delay = if typeof(delay) == "number" then delay else 0,
				baseT = if typeof(baseT) == "number" then baseT else 0.16,
				lastT = -1,
			})
			table.insert(effect.partsArr, p)
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = false
			p.Transparency = 1
		end
	end

	if #effect.parts == 0 then
		warn("[ConsoleVfx] No shape parts on", model:GetFullName())
		return
	end
	effects[model] = effect
end

local function unbind(model: Model)
	effects[model] = nil
end

local function discover(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and (d.Name == "ConsoleVfx" or CollectionService:HasTag(d, TAG)) then
			if not CollectionService:HasTag(d, TAG) then
				CollectionService:AddTag(d, TAG)
			end
			bind(d)
		end
	end
end

for _, model in CollectionService:GetTagged(TAG) do
	if model:IsA("Model") then
		bind(model)
	end
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		bind(inst)
	end
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		unbind(inst)
	end
end)

-- Personal treadmills can spawn after this script; also watch the map folder.
task.defer(function()
	discover(workspace)
end)
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and (inst.Name == "ConsoleVfx" or CollectionService:HasTag(inst, TAG)) then
		if not CollectionService:HasTag(inst, TAG) then
			CollectionService:AddTag(inst, TAG)
		end
		bind(inst)
	end
end)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()

	for model, f in effects do
		if not model.Parent then
			effects[model] = nil
			continue
		end

		local face = consoleFace(model)
		if not face then
			continue
		end
		if (face.Position - camPos).Magnitude > MAX_DIST then
			if not f.hidden then
				f.hidden = true
				for _, pd in f.parts do
					pd.part.Transparency = 1
					pd.lastT = 1
				end
			end
			continue
		end

		local tt = (now + f.phase) / f.period
		local t = tt - math.floor(tt)
		if t >= GONE then
			if not f.hidden then
				f.hidden = true
				for _, pd in f.parts do
					pd.part.Transparency = 1
					pd.lastT = 1
				end
			end
			continue
		end

		f.hidden = false
		local R = f.radius * f.scale
		local sIn = 0.5 + 0.5 * backOut(t / 0.22)
		local expand = 0.15 * smooth((t - HOLD_END) / 0.33)
		local s = sIn * (1 + expand) * (1 + 0.03 * math.sin(now * 2 + f.phase))

		for i, pd in f.parts do
			local d = pd.delay
			local dOut = if f.outFirst then (1 - d) else d
			local aIn = smooth((t - d * IN_STAG) / IN_SPAN)
			local aOut = smooth((t - HOLD_END - dOut * OUT_STAG) / OUT_SPAN)
			local alpha = aIn * (1 - aOut)

			local rho = 0
			if pd.layer > 0 then
				rho = now * (f.speeds[pd.layer] or 0)
			end
			local cr, sr = math.cos(rho), math.sin(rho)
			local a = pd.a
			-- Pattern axes: px along console right, py along console up (standing image).
			local px = (a.X * cr - a.Y * sr) * R * s
			local py = (a.X * sr + a.Y * cr) * R * s
			local pos = face:PointToWorldSpace(Vector3.new(px, py, 0))

			if pd.isBar then
				local th = pd.ang + rho
				-- Neon bar lies in the upright console plane; length along th.
				local along = face.RightVector * math.cos(th) + face.UpVector * math.sin(th)
				local thin = face.LookVector -- depth into / out of the screen
				local barUp = thin:Cross(along)
				if barUp.Magnitude < 1e-4 then
					barUp = face.UpVector
				else
					barUp = barUp.Unit
				end
				along = barUp:Cross(thin).Unit
				f.cfs[i] = CFrame.fromMatrix(pos, along, barUp, -thin)
				pd.part.Size = Vector3.new(pd.size.X * s * f.scale, pd.size.Y * f.scale, pd.size.Z * f.scale)
			else
				-- Dot / backdrop: thin axis into the screen, square standing on the console.
				f.cfs[i] = CFrame.fromMatrix(pos, face.LookVector, face.UpVector)
				pd.part.Size = Vector3.new(pd.size.X * f.scale, pd.size.Y * s * f.scale, pd.size.Z * s * f.scale)
			end

			local tr = 1 - (1 - pd.baseT) * alpha
			if math.abs(tr - pd.lastT) > 0.004 then
				pd.part.Transparency = tr
				pd.lastT = tr
			end
		end
		workspace:BulkMoveTo(f.partsArr, f.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
