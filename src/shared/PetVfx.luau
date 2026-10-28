--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetVfx
-- Builds the ring of pastel ambient effects around a pet from PetVfxPool data.
-- Which effects a pet gets (and how many) is data-driven:
--   PetCatalog entry .Vfx      = { "HaloRays", ... }  explicit list (optional)
--   PetCatalog entry .VfxCount = n                     per-pet count (optional)
--   PetVfxPool.DefaultCount                            everything else (3)
-- Picks are deterministic per pet id, so a species always wears the same effects and colours.

local PetVfxPool = require(script.Parent.PetVfxPool)

local PetVfx = {}

local function hash(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local function range(v: { number }, scale: number?): NumberRange
	local k = scale or 1
	return NumberRange.new(v[1] * k, v[2] * k)
end

local function numberSeq(points: { { number } }, scale: number): NumberSequence
	local keys = table.create(#points)
	for i, p in points do
		keys[i] = NumberSequenceKeypoint.new(p[1], p[2] * scale, (p[3] or 0) * scale)
	end
	return NumberSequence.new(keys)
end

local function alphaSeq(points: { { number } }): NumberSequence
	local keys = table.create(#points)
	for i, p in points do
		keys[i] = NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)
	end
	return NumberSequence.new(keys)
end

function PetVfx.count(entry: any?): number
	if entry and typeof(entry.Vfx) == "table" and #entry.Vfx > 0 then
		return #entry.Vfx
	end
	if entry and typeof(entry.VfxCount) == "number" then
		return math.max(0, math.floor(entry.VfxCount))
	end
	return PetVfxPool.DefaultCount
end

-- Effects (and pastel colour pairs) for one pet.
function PetVfx.pick(petId: string, entry: any?): { { effect: any, colors: { Color3 } } }
	local rng = Random.new(hash(petId))
	local effects = {}
	if entry and typeof(entry.Vfx) == "table" and #entry.Vfx > 0 then
		for _, id in entry.Vfx do
			local effect = PetVfxPool.ById[id]
			if effect then
				table.insert(effects, effect)
			else
				warn("[PetVfx] unknown effect " .. tostring(id) .. " for " .. petId)
			end
		end
	else
		local n = PetVfx.count(entry)
		local order = table.clone(PetVfxPool.Effects)
		for i = #order, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for i = 1, n do
			table.insert(effects, order[((i - 1) % #order) + 1])
		end
	end
	local palette = PetVfxPool.Palette
	local out = {}
	for _, effect in effects do
		local a = palette[rng:NextInteger(1, #palette)].Color
		local b = palette[rng:NextInteger(1, #palette)].Color
		table.insert(out, { effect = effect, colors = { a, b } })
	end
	return out
end

local function makeEmitter(def: any, colors: { Color3 }, scale: number): ParticleEmitter
	local d = PetVfxPool.EmitterDefaults
	local function get(key: string): any
		local v = def[key]
		if v == nil then
			return (d :: any)[key]
		end
		return v
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = def.Name or "Vfx"
	e.Texture = def.Texture
	local sizeScale = scale * (def.SizeScale or 1)
	e.Rate = get("Rate")
	e.Lifetime = range(get("Lifetime"))
	e.Speed = range(get("Speed"), scale * (def.SpeedScale or 1))
	e.SpreadAngle = Vector2.new(get("SpreadAngle")[1], get("SpreadAngle")[2])
	e.Rotation = range(get("Rotation"))
	e.RotSpeed = range(get("RotSpeed"))
	e.Size = numberSeq(def.Size or { { 0, 1, 0 }, { 1, 1, 0 } }, sizeScale)
	e.Transparency = alphaSeq(get("Transparency"))
	e.Color = ColorSequence.new(colors[1], colors[2])
	e.LightEmission = math.clamp(get("LightEmission"), 0, 1)
	e.LightInfluence = get("LightInfluence")
	e.Brightness = math.clamp(get("Brightness"), 0.5, 3)
	e.Shape = (Enum.ParticleEmitterShape :: any)[get("Shape")]
	e.ShapeStyle = (Enum.ParticleEmitterShapeStyle :: any)[get("ShapeStyle")]
	e.Orientation = (Enum.ParticleOrientation :: any)[get("Orientation")]
	e.Drag = get("Drag")
	e.LockedToPart = get("LockedToPart")
	e.ZOffset = get("ZOffset")
	e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[get("FlipbookLayout")]
	e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[get("FlipbookMode")]
	e.FlipbookFramerate = range(get("FlipbookFramerate"))
	return e
end

export type Handle = {
	host: BasePart,
	update: (self: Handle, cf: CFrame, dt: number) -> (),
	setEnabled: (self: Handle, on: boolean) -> (),
	burst: (self: Handle, perEmitter: number) -> (),
	destroy: (self: Handle) -> (),
}

-- size = the pet's bounding box (studs).  The host part is invisible; call handle:update(cf, dt)
-- every frame with the pet's pivot so the ring follows and slowly orbits.
function PetVfx.attach(parent: Instance, petId: string, size: Vector3, entry: any?): Handle?
	local picks = PetVfx.pick(petId, entry)
	if #picks == 0 then
		return nil
	end
	local L = PetVfxPool.Layout
	local maxDim = math.max(size.X, size.Y, size.Z, 0.1)
	local scale = math.clamp(maxDim / L.SizeReference, L.SizeClamp[1], L.SizeClamp[2])
	local radius = math.max(size.X, size.Z) * L.RadiusScale + L.RadiusPad
	local rng = Random.new(hash(petId) + 7)

	local host = Instance.new("Part")
	host.Name = "PetVfxHost"
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Parent = parent

	local slots = {}
	local emitters: { ParticleEmitter } = {}
	for i, pick in picks do
		local att = Instance.new("Attachment")
		att.Name = pick.effect.Id
		att.Parent = host
		for _, def in pick.effect.Emitters do
			local e = makeEmitter(def, pick.colors, scale)
			e.Parent = att
			table.insert(emitters, e)
		end
		table.insert(slots, {
			att = att,
			angle = (i - 1) / #picks * math.pi * 2 + rng:NextNumber(-0.3, 0.3),
			height = size.Y * (L.HeightMin + (L.HeightMax - L.HeightMin) * rng:NextNumber()) - size.Y * 0.5,
			phase = rng:NextNumber(0, math.pi * 2),
		})
	end

	local clock = 0
	local handle: Handle = {
		host = host,
		update = function(_self, cf: CFrame, dt: number)
			clock += dt
			host.CFrame = cf
			for _, s in slots do
				local a = s.angle + clock * L.OrbitSpeed
				local bob = math.sin(clock * 1.3 + s.phase) * L.BobAmplitude * size.Y
				s.att.Position = Vector3.new(math.cos(a) * radius, s.height + bob, math.sin(a) * radius)
			end
		end,
		setEnabled = function(_self, on: boolean)
			for _, e in emitters do
				e.Enabled = on
			end
		end,
		burst = function(_self, perEmitter: number)
			for _, e in emitters do
				e:Emit(perEmitter)
			end
		end,
		destroy = function(_self)
			host:Destroy()
		end,
	}
	handle:update(CFrame.identity, 0)
	return handle
end

return PetVfx
