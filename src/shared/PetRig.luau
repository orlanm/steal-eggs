--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetRig
-- Client-side pet rig with one API for both kinds of pet:
--   * animated: clone of the uploaded model in ReplicatedStorage.PetTemplates (PetAssets loads it),
--     played with the catalog's Idle / Walk / Hatch animation assets;
--   * static fallback: the old GamePet multi-mesh (PetVisual) for pets not uploaded yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetCatalog = require(script.Parent.PetCatalog)
local PetVisual = require(script.Parent.PetVisual)
local GamePet = require(script.Parent.GamePet)

local PetRig = {}

export type Rig = {
	model: Model,
	animated: boolean,
	entry: PetCatalog.Entry?,
	size: Vector3, -- fitted bounding box (studs) at scale 1
	place: (self: Rig, cf: CFrame) -> (),
	setScale: (self: Rig, k: number) -> (),
	setTransparency: (self: Rig, t: number) -> (),
	play: (self: Rig, clip: string, fade: number?) -> AnimationTrack?,
	clipLength: (self: Rig, clip: string) -> number,
	destroy: (self: Rig) -> (),
}

local TEMPLATE_WAIT = 30 -- many species appearing at once queue up behind the server's InsertService loads
-- Uploaded FBX pets import facing +Z; Roblox's forward (LookVector) is -Z.
local FACE = CFrame.Angles(0, math.pi, 0)

local function fitScale(bounds: Vector3, target: Vector3): number
	local sx = if bounds.X > 0.01 then target.X / bounds.X else 1
	local sy = if bounds.Y > 0.01 then target.Y / bounds.Y else 1
	local sz = if bounds.Z > 0.01 then target.Z / bounds.Z else 1
	return math.min(sx, sy, sz)
end

-- Box of the parts you can see, in the model's pivot frame. The invisible RootPart sits half
-- below the feet, so GetBoundingBox would leave the pet hovering above the floor.
local function visibleBox(model: Model): (CFrame, Vector3)
	local pivot = model:GetPivot()
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local h = d.Size * 0.5
			for _, c in { Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1) } do
				local p = rel:PointToWorldSpace(h * c)
				lo = lo:Min(p)
				hi = hi:Max(p)
			end
		end
	end
	if lo.X > hi.X then
		return model:GetBoundingBox()
	end
	return pivot * CFrame.new((lo + hi) * 0.5), hi - lo
end

local function buildAnimated(entry: PetCatalog.Entry, target: Vector3): Rig?
	local folder = ReplicatedStorage:WaitForChild("PetTemplates", TEMPLATE_WAIT)
	local template = folder and folder:WaitForChild(entry.Id, TEMPLATE_WAIT)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local model = template:Clone()
	-- fit the visible parts, not the full box: the invisible RootPart would shrink the pet
	local bboxCf, bboxSize = visibleBox(model)
	local baseScale = fitScale(bboxSize, target)
	model:ScaleTo(model:GetScale() * baseScale)
	bboxCf, bboxSize = visibleBox(model)
	-- offset from the model pivot to the bounding-box centre (pets are placed by their box centre)
	local pivotToCenter = model:GetPivot():ToObjectSpace(bboxCf)
	-- the target box is the pet's static size, centred half its height above the floor: when the
	-- fitted mesh is shorter than the box, drop it so its feet still sit on the box floor
	local drop = math.max(0, (target.Y - bboxSize.Y) * 0.5)
	local scale0 = model:GetScale()
	local k = 1
	local animator: Animator? = nil
	local controller = model:FindFirstChildWhichIsA("AnimationController")
	if controller then
		animator = controller:FindFirstChildWhichIsA("Animator")
	end
	local tracks: { [string]: AnimationTrack } = {}
	local current: AnimationTrack? = nil
	local alpha: { [BasePart]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			alpha[d] = d.Transparency
		end
	end

	local rig: Rig
	rig = {
		model = model,
		animated = true,
		entry = entry,
		size = bboxSize,
		place = function(_self, cf: CFrame)
			local off = if k == 1 then pivotToCenter else CFrame.new(pivotToCenter.Position * k) * pivotToCenter.Rotation
			model:PivotTo(cf * CFrame.new(0, -drop * k, 0) * FACE * off:Inverse())
		end,
		setScale = function(_self, factor: number)
			k = math.max(factor, 0.001)
			model:ScaleTo(scale0 * k)
		end,
		setTransparency = function(_self, t: number)
			for part, base in alpha do
				part.Transparency = math.max(t, base)
			end
		end,
		play = function(_self, clip: string, fade: number?): AnimationTrack?
			if not animator then
				return nil
			end
			local track = tracks[clip]
			if not track then
				local id = PetCatalog.animationId(entry, clip)
				if not id then
					return nil
				end
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local ok, loaded = pcall(function()
					return (animator :: Animator):LoadAnimation(anim)
				end)
				if not ok then
					warn("[PetRig] " .. entry.Id .. " " .. clip .. ": " .. tostring(loaded))
					return nil
				end
				track = loaded
				track.Looped = clip ~= "Hatch"
				track.Priority = if clip == "Hatch" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Idle
				tracks[clip] = track
			end
			if current and current ~= track then
				current:Stop(fade or 0.2)
			end
			track:Play(fade or 0.2)
			current = track
			return track
		end,
		clipLength = function(_self, clip: string): number
			local t = tracks[clip]
			return if t then t.Length else 0
		end,
		destroy = function(_self)
			for _, t in tracks do
				t:Stop(0)
				t:Destroy()
			end
			model:Destroy()
		end,
	}
	return rig
end

local function buildStatic(gameName: string, target: Vector3): Rig?
	local catalogEntry = PetCatalog.get(gameName)
	local pet = GamePet.get(gameName) or (catalogEntry and GamePet.get(catalogEntry.GameName))
	if not pet then
		return nil
	end
	local inner = PetVisual.build(pet, target)
	if not inner then
		return nil
	end
	local fitted = pet.Bounds * PetVisual.scaleFor(pet, target)
	local rig: Rig = {
		model = inner.model,
		animated = false,
		entry = PetCatalog.get(gameName),
		size = fitted,
		place = function(_self, cf: CFrame)
			inner:place(cf)
		end,
		setScale = function(_self, k: number)
			inner:setScale(k)
		end,
		setTransparency = function(_self, t: number)
			inner:setTransparency(t)
		end,
		play = function(_self, _clip: string, _fade: number?): AnimationTrack?
			return nil
		end,
		clipLength = function(_self, _clip: string): number
			return 0
		end,
		destroy = function(_self)
			inner:destroy()
		end,
	}
	return rig
end

-- gameName: the TankBeast EggName.  target: box the pet must fit (studs).  Yields.
function PetRig.build(gameName: string, target: Vector3): Rig?
	local entry = PetCatalog.get(gameName)
	if entry and PetCatalog.hasModel(entry) then
		local rig = buildAnimated(entry, target)
		if rig then
			return rig
		end
	end
	return buildStatic(gameName, target)
end

return PetRig
