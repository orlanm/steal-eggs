--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetScale
-- Static pet sizing, matching Steal an Egg (AssetRigFactory.RigScale = AssetScale x BaseModelScale):
--
--     StaticScale = SizeScale * BaseScale        (then capped so the pet fits inside a pen)
--
-- Biomes in MIN_HEIGHT_BY_BIOME raise BaseScale so their pets stand at least that share of a player.
--
-- It never changes after hatching (no growth over time, no level scaling).
--   native size  the species' Steal An Egg model size (PetCatalog Bounds, studs). Every Steal An
--                Egg species has BaseModelScale 1, so the catalog's optional BaseScale defaults to 1.
--   SizeScale    the egg's rolled size (EggScale.rollSize: ~1x, or HUGE_SCALE on a rare Huge roll).
--   Rarity and mutations do not change size in Steal an Egg; they change income and colour.

local PetCatalog = require(script.Parent.PetCatalog)
local EggSources = require(script.Parent.EggSources)

local PetScale = {}

-- Largest footprint (studs across X/Z) a pet may have in an 80-stud pen; bigger rolls are
-- scaled down to this so they still stand inside the fence.
PetScale.MAX_FOOTPRINT = 60

-- UI tags float this far above the top of the pet.
PetScale.UI_GAP = 1.2

-- Standing height of a default R15 player (studs).
PetScale.PLAYER_HEIGHT = 5.5

-- Biomes whose pets stand at least this fraction of a player's height; smaller species are
-- scaled up proportionately.
PetScale.MIN_HEIGHT_BY_BIOME = {
	["Cozy Backyard"] = 0.5,
}

local minHeightOf: { [string]: number } = {}
for biome, fraction in PetScale.MIN_HEIGHT_BY_BIOME do
	local rows = EggSources.Biomes[biome]
	for _, row in rows or {} do
		local species = row[1]
		minHeightOf[species] = math.max(minHeightOf[species] or 0, fraction * PetScale.PLAYER_HEIGHT)
	end
end

local DEFAULT_BOUNDS = Vector3.new(4, 5, 4)

-- Authored size of the species mesh (studs, Y up) and its per-species tuning factor.
function PetScale.speciesBounds(species: string, fallback: Vector3?): (Vector3, number)
	local entry = PetCatalog.get(species)
	if entry then
		return entry.Bounds, entry.BaseScale or 1
	end
	return fallback or DEFAULT_BOUNDS, 1
end

export type Static = {
	Scale: number, -- applied to the native mesh
	Extents: Vector3, -- static bounding box in studs (X, Y up, Z)
	Size: number, -- the egg's size scale it was built from
}

-- The one static size lookup. bounds/tuning come from speciesBounds(); minHeight (studs) raises
-- short species to at least that height.
function PetScale.compute(bounds: Vector3, size: number?, tuning: number?, minHeight: number?): Static
	local sizeScale = if typeof(size) == "number" and size == size and size > 0 then size else 1
	local scale = sizeScale * (tuning or 1)
	if minHeight and bounds.Y > 0.01 then
		scale = math.max(scale, minHeight / bounds.Y)
	end
	local across = math.max(bounds.X, bounds.Z, 0.01) * scale
	if across > PetScale.MAX_FOOTPRINT then
		scale *= PetScale.MAX_FOOTPRINT / across
	end
	return {
		Scale = scale,
		Extents = bounds * scale,
		Size = sizeScale,
	}
end

function PetScale.forSpecies(species: string, size: number?, fallback: Vector3?): Static
	local bounds, tuning = PetScale.speciesBounds(species, fallback)
	local minHeight = minHeightOf[species]
	if minHeight then
		-- raise the base size, then apply the rolled size on top so big rolls stay bigger
		tuning = math.max(tuning, minHeight / math.max(bounds.Y, 0.01))
	end
	return PetScale.compute(bounds, size, tuning, minHeight)
end

-- Root CFrame for a box-centred pet standing flush on a floor point: up by half its height.
function PetScale.floorCFrame(nodeCFrame: CFrame, extents: Vector3): CFrame
	return CFrame.new(nodeCFrame.Position + Vector3.new(0, extents.Y * 0.5, 0)) * nodeCFrame.Rotation
end

-- BillboardGui StudsOffset.Y for a tag on the box-centred root.
function PetScale.uiOffset(extents: Vector3): number
	return extents.Y * 0.5 + PetScale.UI_GAP
end

-- For a real Model (e.g. a pet loaded directly into the workspace): scale it once.
function PetScale.InitializePetScale(petModel: Model, size: number?, baseMeshScale: number?): number
	local finalStaticScale = (baseMeshScale or 1) * (if typeof(size) == "number" and size > 0 then size else 1)
	petModel:ScaleTo(finalStaticScale)
	return finalStaticScale
end

-- For a real Model: stand it flush on a pen node and lift its tag above its head.
function PetScale.SnapToPenFloor(petModel: Model, targetNodeCFrame: CFrame)
	local extentsSize = petModel:GetExtentsSize()
	local boxCf = petModel:GetBoundingBox()
	-- the pivot need not be the box centre: move the box centre to half-height above the node
	local pivotFromBox = boxCf:ToObjectSpace(petModel:GetPivot())
	local target = PetScale.floorCFrame(targetNodeCFrame, extentsSize)
	petModel:PivotTo(target * pivotFromBox)
	local headOrRoot = petModel:FindFirstChild("Head") or petModel.PrimaryPart
	if headOrRoot then
		local billboard = headOrRoot:FindFirstChildOfClass("BillboardGui")
		if billboard then
			billboard.StudsOffset = Vector3.new(0, PetScale.uiOffset(extentsSize), 0)
		end
	end
end

return PetScale
