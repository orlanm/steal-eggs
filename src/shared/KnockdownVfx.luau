-- Explorer: ReplicatedStorage.BabyBeastsShared.KnockdownVfx
-- Client-side effects for a player knockdown (server Knockdown fires the KnockdownVfx remote; the
-- client script BabyBeastsClient.KnockdownVfx plays them): a spark burst where the player is hit, a
-- dust ring when the body slams onto the floor, and stars circling the head while they lie there.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local KnockdownVfx = {}

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0.3
	e.LockedToPart = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function anchorAt(position: Vector3, life: number): (Part, Attachment)
	local holder = Instance.new("Part")
	holder.Name = "KnockdownVfx"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local att = Instance.new("Attachment")
	att.Parent = holder
	Debris:AddItem(holder, life)
	return holder, att
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- Hit: a burst of warm sparks and stars where the player was struck.
function KnockdownVfx.impact(position: Vector3)
	local _, att = anchorAt(position, 2)
	emitter(att, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 214, 110), Color3.fromRGB(255, 140, 90)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(16, 28),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 7,
		LightEmission = 0.35,
	}):Emit(22)
	emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(255, 205, 150)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5) }),
		Lifetime = NumberRange.new(0.15, 0.25),
		Speed = NumberRange.new(0, 1),
		LightEmission = 0.2,
	}):Emit(2)
end

-- Landing: a dust ring along the floor plus a few pebbles bouncing up.
function KnockdownVfx.landing(position: Vector3)
	local holder, att = anchorAt(position + Vector3.yAxis * 0.4, 3)
	holder.Size = Vector3.new(3, 0.2, 3)
	-- flat ring: a disc around the impact, every puff pushed outward along the floor
	emitter(holder, {
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(226, 208, 172), Color3.fromRGB(196, 186, 160)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 4) }),
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(10, 15),
		Drag = 3.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 0,
	}):Emit(30)
	emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(220, 205, 175)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0,
	}):Emit(8)
	emitter(att, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(190, 170, 140)),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -60, 0),
		LightEmission = 0,
	}):Emit(12)
end

-- Lying: three little stars orbiting over the head, each trailing sparkles, until the player gets up
-- (or respawns).
local STAR_COLORS = { Color3.fromRGB(255, 232, 120), Color3.fromRGB(150, 210, 255), Color3.fromRGB(255, 170, 215) }

function KnockdownVfx.dizzy(character: Model, seconds: number)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	KnockdownVfx.dizzyStop(character)
	local folder = Instance.new("Folder")
	folder.Name = "KnockdownDizzy"
	local stars = {}
	for i, color in STAR_COLORS do
		local star = Instance.new("Part")
		star.Name = "Star" .. i
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.one * 0.42
		star.Material = Enum.Material.SmoothPlastic -- neon washes out to white in daylight
		star.Color = color
		star.Anchored = true
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.CastShadow = false
		local att = Instance.new("Attachment")
		att.Parent = star
		local trail = emitter(att, {
			Texture = SPARKLE,
			Color = ColorSequence.new(color),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.3, 0.45),
			Speed = NumberRange.new(0, 0.3),
			Rate = 20,
			LightEmission = 0.6,
		})
		trail.Enabled = true
		star.Parent = folder
		table.insert(stars, star)
	end
	folder.Parent = character
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if not folder.Parent or not head.Parent or t > seconds then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		local centre = head.Position + Vector3.new(0, 1.15, 0)
		for i, star in stars do
			local a = t * 2 * math.pi * 0.9 + (i - 1) * 2 * math.pi / #stars
			local bob = math.sin(t * 5 + i) * 0.12
			star.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * 1.05, bob, math.sin(a) * 1.05))
		end
	end)
end

-- Stop the stars when the player gets up.
function KnockdownVfx.dizzyStop(character: Model)
	local folder = character:FindFirstChild("KnockdownDizzy")
	if folder then
		folder:Destroy()
	end
end

return KnockdownVfx
