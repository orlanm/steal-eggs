--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetHatch
-- Client hatch sequence: the egg wobbles harder and harder, cracks with a pastel flash, shell
-- shards fly out, and the pet pops out (squash & stretch) playing its Hatch animation, then
-- settles into Idle with its ambient VFX ring.  All timings / sizes / colours are in Config.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PetVfxPool = require(script.Parent.PetVfxPool)

local PetHatch = {}

PetHatch.Config = {
	WobbleTime = 1.0, -- egg anticipation before it cracks
	WobbleAngle = math.rad(14), -- max tilt at the end of the wobble
	WobbleHz = { 5, 13 }, -- wobble speed ramps between these
	CrackPulses = { 0.35, 0.7 }, -- little sparkle puffs before the break
	ShardCount = 14,
	ShardLife = 0.9,
	FlashTime = 0.35,
	PopTime = 0.55, -- pet scale-in (squash & stretch) after the crack
	PopFrom = 0.15,
	PopOvershoot = 1.14,
	SettleIdleFade = 0.35,
	HatchLoadWait = 3, -- max seconds to wait for a not-yet-loaded Hatch clip before settling to Idle
	SparkleTexture = "rbxasset://textures/particles/sparkles_main.dds",
}

type EggRig = {
	model: Model,
	place: (any, CFrame) -> (),
	setTransparency: (any, number) -> (),
	destroy: (any) -> (),
}

local function pastel(rng: Random): Color3
	local p = PetVfxPool.Palette
	return p[rng:NextInteger(1, #p)].Color
end

local function sparkle(parent: Instance, at: CFrame, size: number, count: number, rng: Random)
	local host = Instance.new("Part")
	host.Name = "HatchSparkle"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6)
	host.CFrame = at
	host.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = PetHatch.Config.SparkleTexture
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Speed = NumberRange.new(size * 1.2, size * 3)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.LightEmission = 0.8
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.06),
		NumberSequenceKeypoint.new(0.35, size * 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.05, 1)
	e.Color = ColorSequence.new(pastel(rng), pastel(rng))
	e.Parent = host
	e:Emit(count)
	Debris:AddItem(host, 1.5)
end

local function flashRing(parent: Instance, at: CFrame, size: number, rng: Random)
	local ring = Instance.new("Part")
	ring.Name = "HatchRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = pastel(rng)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.08, size * 0.5, size * 0.5)
	ring.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = parent
	local t = PetHatch.Config.FlashTime * 1.6
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, size * 2.4, size * 2.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.1)
	local light = Instance.new("PointLight")
	light.Color = pastel(rng)
	light.Range = size * 3
	light.Brightness = 4
	light.Shadows = false
	light.Parent = ring
	TweenService:Create(light, TweenInfo.new(PetHatch.Config.FlashTime), { Brightness = 0 }):Play()
end

local function shards(parent: Instance, at: CFrame, size: Vector3, rng: Random)
	local cfg = PetHatch.Config
	local s = math.max(size.X, size.Z) * 0.18
	for i = 1, cfg.ShardCount do
		local shard = Instance.new("WedgePart")
		shard.Name = "EggShard"
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.Material = Enum.Material.SmoothPlastic
		shard.Color = pastel(rng)
		shard.Size = Vector3.new(s * rng:NextNumber(0.15, 0.35), s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.5, 1))
		local a = (i / cfg.ShardCount) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local start = at * CFrame.new(math.cos(a) * size.X * 0.25, rng:NextNumber(-0.1, 0.35) * size.Y, math.sin(a) * size.Z * 0.25)
		shard.CFrame = start * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		shard.Parent = parent
		local out = Vector3.new(math.cos(a), 0, math.sin(a)) * math.max(size.X, size.Z) * rng:NextNumber(0.6, 1.1)
		local up = size.Y * rng:NextNumber(0.25, 0.6)
		local t0 = os.clock()
		local p0 = shard.Position
		local w = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		local rot = shard.CFrame - shard.CFrame.Position
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt)
			local t = os.clock() - t0
			if t >= cfg.ShardLife or not shard.Parent then
				conn:Disconnect()
				shard:Destroy()
				return
			end
			local u = t / cfg.ShardLife
			local pos = p0 + out * u + Vector3.new(0, up * 4 * u * (1 - u) - size.Y * 0.4 * u * u, 0)
			rot = rot * CFrame.Angles(w.X * dt, w.Y * dt, w.Z * dt)
			shard.CFrame = CFrame.new(pos) * rot
			shard.Transparency = math.clamp((u - 0.55) / 0.45, 0, 1)
		end)
	end
end

local function backOut(u: number, over: number): number
	-- 0 -> over -> 1 squash/stretch curve
	if u < 0.6 then
		local v = u / 0.6
		return v * v * (3 - 2 * v) * over
	end
	local v = (u - 0.6) / 0.4
	return over + (1 - over) * (v * v * (3 - 2 * v))
end

export type Options = {
	root: BasePart, -- server TankBeast root (pivot of the pet / egg)
	parent: Instance, -- where temporary effects go
	egg: EggRig?,
	pet: any, -- PetRig.Rig
	size: Vector3, -- pet box (studs)
	vfx: any?, -- PetVfx.Handle
	onDone: (() -> ())?,
}

-- Runs the sequence; drives egg/pet placement itself until it finishes (then calls onDone).
function PetHatch.play(o: Options)
	local cfg = PetHatch.Config
	local rng = Random.new()
	local pet = o.pet
	local start = os.clock()
	local cracked = false
	local popStart = 0
	local pulses = table.clone(cfg.CrackPulses)
	pet:setScale(cfg.PopFrom)
	pet:setTransparency(1)
	if o.vfx then
		o.vfx:setEnabled(false)
	end
	local hatchTrack: AnimationTrack? = nil
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if not o.root.Parent then
			conn:Disconnect()
			return
		end
		local cf = o.root.CFrame
		local t = os.clock() - start
		if not cracked then
			local u = math.clamp(t / cfg.WobbleTime, 0, 1)
			local hz = cfg.WobbleHz[1] + (cfg.WobbleHz[2] - cfg.WobbleHz[1]) * u
			local ang = cfg.WobbleAngle * u * u * math.sin(t * hz * math.pi * 2)
			local hop = math.abs(math.sin(t * hz * math.pi)) * o.size.Y * 0.03 * u
			if o.egg then
				o.egg:place(cf * CFrame.new(0, hop - o.size.Y * 0.5, 0) * CFrame.Angles(0, 0, ang) * CFrame.new(0, o.size.Y * 0.5, 0))
			end
			if pulses[1] and t >= pulses[1] then
				table.remove(pulses, 1)
				sparkle(o.parent, cf, math.max(o.size.X, o.size.Z), 12, rng)
			end
			if t >= cfg.WobbleTime then
				cracked = true
				popStart = os.clock()
				if o.egg then
					o.egg:setTransparency(1)
				end
				flashRing(o.parent, cf * CFrame.new(0, -o.size.Y * 0.35, 0), math.max(o.size.X, o.size.Z), rng)
				sparkle(o.parent, cf, math.max(o.size.X, o.size.Z), 40, rng)
				shards(o.parent, cf, o.size, rng)
				pet:setTransparency(0)
				hatchTrack = pet:play("Hatch", 0)
				if o.vfx then
					o.vfx:setEnabled(true)
					o.vfx:burst(3)
				end
			end
		else
			local u = math.clamp((os.clock() - popStart) / cfg.PopTime, 0, 1)
			local k = cfg.PopFrom + (backOut(u, cfg.PopOvershoot) * (1 - cfg.PopFrom))
			pet:setScale(k)
			pet:place(cf)
			if o.vfx then
				o.vfx:update(cf, dt)
			end
			-- Length stays 0 until the clip asset has loaded; wait for it (bounded) so the clip isn't cut short
			local loading = hatchTrack ~= nil and hatchTrack.Length == 0 and os.clock() - popStart < cfg.HatchLoadWait
			local animDone = not loading
				and ((hatchTrack == nil) or (not hatchTrack.IsPlaying) or (hatchTrack.TimePosition >= hatchTrack.Length - cfg.SettleIdleFade))
			if u >= 1 and animDone then
				conn:Disconnect()
				pet:setScale(1)
				pet:play("Idle", cfg.SettleIdleFade)
				if o.egg then
					o.egg:destroy()
				end
				if o.onDone then
					o.onDone()
				end
			end
		end
	end)
end

return PetHatch
