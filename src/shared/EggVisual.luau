--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.EggVisual
-- Builds a cached mesh rig for one GameEgg entry and fits it inside a target box.

local AssetService = game:GetService("AssetService")
local GameEgg = require(script.Parent.GameEgg)

local EggVisual = {}

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
		warn("[BabyBeasts] Egg mesh failed ", meshId, result)
	end
	pending[meshId] = nil
	gate:Fire()
	gate:Destroy()
	return templates[meshId]
end

function EggVisual.scaleFor(egg: GameEgg.Egg, target: Vector3): number
	local bounds = egg.Bounds
	local sx = if bounds.X > 0.01 then target.X / bounds.X else 1
	local sy = if bounds.Y > 0.01 then target.Y / bounds.Y else 1
	local sz = if bounds.Z > 0.01 then target.Z / bounds.Z else 1
	return math.min(sx, sy, sz)
end

export type Rig = {
	model: Model,
	place: (self: Rig, cf: CFrame) -> (),
	setTransparency: (self: Rig, transparency: number) -> (),
	-- refit to a new target box (same grounding), e.g. a pen egg growing while it hatches
	resize: (self: Rig, target: Vector3) -> (),
	destroy: (self: Rig) -> (),
}

local CORNERS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, 1, 1),
}

-- grounded: rest the egg on the bottom of the target box instead of centring it (pen eggs).
-- floorY: with grounded, the floor height relative to the box centre the rig is placed at
-- (default -target.Y / 2). A pen egg is placed at the pet's box centre, so it passes the pet's.
function EggVisual.build(egg: GameEgg.Egg, target: Vector3, grounded: boolean?, floorY: number?): Rig?
	local model = Instance.new("Model")
	model.Name = egg.Name
	local parts: { BasePart } = {}
	local specs: { GameEgg.EggPart } = {}
	for _, spec in egg.Parts do
		local part: BasePart
		if spec.Shape == "Block" then
			-- classic brick: Plastic, studs on top, inlets underneath, the egg's own side variant
			local block = Instance.new("Part")
			block.Material = Enum.Material.Plastic
			block.TopSurface = Enum.SurfaceType.Studs
			block.BottomSurface = Enum.SurfaceType.Inlet
			local ok, found = pcall(function()
				return (Enum.SurfaceType :: any)[spec.SideSurface or "Smooth"]
			end)
			local sides = if ok and found then found else Enum.SurfaceType.Smooth
			block.FrontSurface = sides
			block.BackSurface = sides
			block.LeftSurface = sides
			block.RightSurface = sides
			part = block
		else
			local src = template(spec.MeshId)
			if not src then
				continue
			end
			local mesh = Instance.new("MeshPart")
			mesh:ApplyMesh(src)
			if spec.TextureId then
				mesh.TextureID = spec.TextureId
			end
			mesh.Material = Enum.Material.SmoothPlastic
			part = mesh
		end
		part.Name = spec.Name
		part.Color = spec.Color
		part.Transparency = spec.Transparency
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		pcall(function()
			part.DoubleSided = true
		end)
		part.Parent = model
		table.insert(parts, part)
		table.insert(specs, spec)
	end
	if #parts == 0 then
		model:Destroy()
		return nil
	end
	local offsets: { CFrame } = {}
	local lastCFrame = CFrame.identity

	local function layout(box: Vector3)
		local scale = EggVisual.scaleFor(egg, box)
		local center = egg.Center * scale
		for index, spec in specs do
			parts[index].Size = spec.Size * scale
			offsets[index] = CFrame.new(spec.Offset.Position * scale - center) * spec.Offset.Rotation
		end
		-- a pen box is centred above the floor and sized for the hatched pet (often taller than the
		-- egg): rest the egg's lowest point on the floor
		if grounded then
			local lowest = math.huge
			for index, part in parts do
				local half = part.Size * 0.5
				for _, corner in CORNERS do
					lowest = math.min(lowest, (offsets[index] * (half * corner)).Y)
				end
			end
			local lift = (floorY or -box.Y * 0.5) - lowest
			for index, offset in offsets do
				offsets[index] = CFrame.new(0, lift, 0) * offset
			end
		end
	end
	layout(target)

	model.PrimaryPart = parts[1]
	local rig: Rig = {
		model = model,
		place = function(_self, cf: CFrame)
			lastCFrame = cf
			for index, part in parts do
				part.CFrame = cf * offsets[index]
			end
		end,
		setTransparency = function(_self, transparency: number)
			for _, part in parts do
				part.Transparency = transparency
			end
		end,
		resize = function(self, box: Vector3)
			layout(box)
			self:place(lastCFrame)
		end,
		destroy = function(_self)
			model:Destroy()
		end,
	}
	rig:place(CFrame.identity)
	return rig
end

-- Returns false when none of the egg's meshes could load (the caller shows a fallback).
function EggVisual.weld(anchor: BasePart, egg: GameEgg.Egg, target: Vector3): boolean
	local rig = EggVisual.build(egg, target)
	if not rig then
		return false
	end
	rig:place(anchor.CFrame)
	local host = anchor.Parent
	for _, child in rig.model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.Parent = host
			local weld = Instance.new("WeldConstraint")
			weld.Name = "EggWeld"
			weld.Part0 = anchor
			weld.Part1 = child
			weld.Parent = anchor
		end
	end
	rig.model:Destroy()
	return true
end

return EggVisual
