--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PetVisual
-- Builds a cached mesh rig for one GamePet entry (hatched Steal An Egg creature).

local AssetService = game:GetService("AssetService")
local GamePet = require(script.Parent.GamePet)

local PetVisual = {}

local templates: { [string]: MeshPart } = {}
local failed: { [string]: boolean } = {}
local pending: { [string]: BindableEvent } = {}

local function template(meshId: string): MeshPart?
	local cached = templates[meshId]
	if cached then
		return cached
	end
	if failed[meshId] then
		return nil
	end
	local gate = pending[meshId]
	if gate then
		gate.Event:Wait()
		return templates[meshId]
	end
	gate = Instance.new("BindableEvent")
	pending[meshId] = gate
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if ok and typeof(result) == "Instance" and result:IsA("MeshPart") then
		result.Anchored = true
		result.CanCollide = false
		result.CanQuery = false
		result.CanTouch = false
		result.CastShadow = true
		templates[meshId] = result
	else
		failed[meshId] = true
		warn("[BabyBeasts] Pet mesh failed ", meshId, result)
	end
	pending[meshId] = nil
	gate:Fire()
	gate:Destroy()
	return templates[meshId]
end

function PetVisual.scaleFor(pet: GamePet.Pet, target: Vector3): number
	local bounds = pet.Bounds
	local sx = if bounds.X > 0.01 then target.X / bounds.X else 1
	local sy = if bounds.Y > 0.01 then target.Y / bounds.Y else 1
	local sz = if bounds.Z > 0.01 then target.Z / bounds.Z else 1
	return math.min(sx, sy, sz)
end

export type Rig = {
	model: Model,
	place: (self: Rig, cf: CFrame) -> (),
	setTransparency: (self: Rig, transparency: number) -> (),
	setScale: (self: Rig, k: number) -> (),
	destroy: (self: Rig) -> (),
}

function PetVisual.build(pet: GamePet.Pet, target: Vector3): Rig?
	local scale = PetVisual.scaleFor(pet, target)
	local model = Instance.new("Model")
	model.Name = pet.Name
	local parts: { MeshPart } = {}
	local offsets: { CFrame } = {}
	local baseSizes: { Vector3 } = {}
	local baseAlpha: { number } = {}
	local k = 1
	-- GamePet Offsets are already relative to the AABB center (unlike GameEgg).
	for _, spec in pet.Parts do
		local src = template(spec.MeshId)
		if not src then
			continue
		end
		local part = Instance.new("MeshPart")
		part.Name = spec.Name
		part:ApplyMesh(src)
		part.Size = spec.Size * scale
		part.Color = spec.Color
		part.Transparency = spec.Transparency
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		pcall(function()
			part.DoubleSided = true
		end)
		part.Parent = model
		local pos = spec.Offset.Position * scale
		table.insert(parts, part)
		table.insert(offsets, CFrame.new(pos) * spec.Offset.Rotation)
		table.insert(baseSizes, part.Size)
		table.insert(baseAlpha, spec.Transparency)
	end
	if #parts == 0 then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = parts[1]
	local rig: Rig = {
		model = model,
		place = function(_self, cf: CFrame)
			for index, part in parts do
				local off = offsets[index]
				part.CFrame = cf * (if k == 1 then off else CFrame.new(off.Position * k) * off.Rotation)
			end
		end,
		setTransparency = function(_self, transparency: number)
			for index, part in parts do
				-- keep parts that are invisible by design (hitboxes etc.) invisible
				part.Transparency = math.max(transparency, baseAlpha[index])
			end
		end,
		setScale = function(_self, scaleFactor: number)
			k = math.max(scaleFactor, 0.001)
			for index, part in parts do
				part.Size = baseSizes[index] * k
			end
		end,
		destroy = function(_self)
			model:Destroy()
		end,
	}
	rig:place(CFrame.identity)
	return rig
end

return PetVisual
