--!strict
-- One-shot dress of the saved route: clearer water, themed ground, curve
-- boundaries, and Blender rocks / seaweed. Not called on every server start.

local AssetService = game:GetService("AssetService")
local Biomes = require(game.ReplicatedStorage.BabyBeastsShared.BiomeConfig)
local Path = require(game.ReplicatedStorage.BabyBeastsShared.RoutePath)
local MeshData = require(script.Parent.UnderwaterMeshes)

local Dress = {}

local MATERIALS: { [string]: Enum.Material } = {
	Backyard = Enum.Material.Grass,
	Forest = Enum.Material.Grass,
	Bamboo = Enum.Material.LeafyGrass,
	Lake = Enum.Material.Sand,
	Toxic = Enum.Material.Mud,
	Desert = Enum.Material.Sand,
	Crystal = Enum.Material.Slate,
	Jungle = Enum.Material.LeafyGrass,
	Pirate = Enum.Material.Sand,
	Snow = Enum.Material.Snow,
	Cyber = Enum.Material.DiamondPlate,
	Volcano = Enum.Material.Basalt,
	Atlantis = Enum.Material.Limestone,
	Abyss = Enum.Material.Rock,
	Haunted = Enum.Material.Slate,
	Prehistoric = Enum.Material.Sandstone,
	Candy = Enum.Material.SmoothPlastic,
	Cosmic = Enum.Material.SmoothPlastic,
	Cherry = Enum.Material.Grass,
	Celestial = Enum.Material.Marble,
	Temple = Enum.Material.Sandstone,
}

local function biomeAt(id: number): any
	for _, biome in Biomes :: { any } do
		if biome.ZoneIndex == id then
			return biome
		end
	end
	return nil
end

local function materialFor(biome: any): Enum.Material
	return MATERIALS[biome.Theme] or Enum.Material.SmoothPlastic
end

-- The zone floor stays the checker. This only reads its top for prop placement.
local function floorTop(folder: Instance): number?
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "CheckerTile" or descendant.Name == "PathTile") then
			return descendant.Position.Y + descendant.Size.Y * 0.5
		end
	end
	return nil
end

local function buildMesh(data: any): MeshPart
	local editable = AssetService:CreateEditableMesh()
	local ids = {}
	for index, vert in data.verts do
		ids[index] = editable:AddVertex(Vector3.new(vert[1], vert[2], vert[3]))
	end
	for _, face in data.faces do
		editable:AddTriangle(ids[face[1]], ids[face[2]], ids[face[3]])
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(editable))
	part.Anchored = true
	part.DoubleSided = true
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function placeMesh(template: MeshPart, parent: Instance, position: Vector3, size: Vector3, yaw: number, color: Color3, collide: boolean)
	local part = template:Clone()
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = collide
	part.CFrame = CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)) * CFrame.Angles(0, yaw, 0)
	part.Parent = parent
end

function Dress.apply(root: Instance): string
	if root:GetAttribute("ChannelDress") == 1 then
		return "already dressed"
	end
	local stale = root:FindFirstChild("UnderwaterPropTemplates")
	if stale then
		stale:Destroy()
	end
	local templates = Instance.new("Folder")
	templates.Name = "UnderwaterPropTemplates"
	templates.Parent = root
	local small = buildMesh(MeshData.rock_small)
	small.Name = "RockSmall"
	small.Parent = templates
	local large = buildMesh(MeshData.rock_large)
	large.Name = "RockLarge"
	large.Parent = templates
	local weed = buildMesh(MeshData.seaweed)
	weed.Name = "Seaweed"
	weed.Parent = templates

	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(72, 148, 162)
	terrain.WaterTransparency = 0.78
	terrain.WaterReflectance = 0.01
	terrain.WaterWaveSize = 0.04
	terrain.WaterWaveSpeed = 3

	local habitats = root:WaitForChild("BeastHabitats")
	local curves = root:WaitForChild("CurvedConnections")
	local groundTops: { [number]: number } = {}
	local replaced = 0
	for _, zone in habitats:GetChildren() do
		local id = zone:GetAttribute("ZoneIndex")
		if typeof(id) ~= "number" or id < 1 then
			continue
		end
		local biome = biomeAt(id)
		if not biome then
			continue
		end
		local path = zone:FindFirstChild("PathFloor")
		if path then
			local top = floorTop(path)
			if top then
				groundTops[id] = top
				replaced += 1
			end
		end
		-- Jail / side walls and toppings stay this zone's Wall color so the
		-- S-curve attached to the north edge matches them.
		for _, part in zone:GetDescendants() do
			if
				part:IsA("BasePart")
				and (
					part.Name == "SideWall"
					or part.Name == "GateLintel"
					or part.Name == "BackWall"
					or part.Name == "CellSide"
					or part.Name == "CellRoof"
					or part.Name == "WallTooth"
					or part.Name == "ReferenceWallCap"
				)
			then
				part.Color = biome.Wall
			end
		end
		task.wait()
	end

	local curveLength = Path.CurveLength or 288
	local curveParts = 0
	for id = 6, 21 do
		local model = curves:FindFirstChild("CurveToZone" .. id)
		local zone = habitats:FindFirstChild(string.format("Zone%02d", id))
		local biome = biomeAt(id)
		local previous = biomeAt(id - 1)
		if not (model and zone and biome and previous) then
			continue
		end
		local startZ = zone:GetAttribute("StartZ")
		if typeof(startZ) ~= "number" then
			continue
		end
		local curveStart = startZ - curveLength
		local midZ = startZ - curveLength * 0.5
		local seabed = model:FindFirstChild("CheckerSeabed")
		if seabed then
			seabed:Destroy()
		end
		local oldGround = model:FindFirstChild("CurveGround")
		if oldGround then
			oldGround:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "CurveGround"
		folder.Parent = model
		local function curveStrip(fromZ: number, toZ: number, owner: any)
			local mesh = AssetService:CreateEditableMesh()
			local minV = Vector3.new(math.huge, math.huge, math.huge)
			local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
			local function vert(v: Vector3)
				minV = Vector3.new(math.min(minV.X, v.X), math.min(minV.Y, v.Y), math.min(minV.Z, v.Z))
				maxV = Vector3.new(math.max(maxV.X, v.X), math.max(maxV.Y, v.Y), math.max(maxV.Z, v.Z))
				return mesh:AddVertex(v)
			end
			local rings = {}
			local z = fromZ
			while true do
				local pos, direction = Path.atZ(z)
				local right = Vector3.new(-direction.Z, 0, direction.X)
				if right.Magnitude < 0.05 then
					right = Vector3.xAxis
				else
					right = right.Unit
				end
				local center = Vector3.new(pos.X, 0, pos.Z)
				local left = center - right * 72
				local rightPoint = center + right * 72
				table.insert(rings, {
					vert(left + Vector3.new(0, -1.15, 0)),
					vert(rightPoint + Vector3.new(0, -1.15, 0)),
					vert(left + Vector3.new(0, -2.4, 0)),
					vert(rightPoint + Vector3.new(0, -2.4, 0)),
				})
				if z >= toZ - 0.05 then
					break
				end
				z = math.min(z + 18, toZ)
			end
			for index = 1, #rings - 1 do
				local a = rings[index]
				local b = rings[index + 1]
				mesh:AddTriangle(a[1], b[1], b[2])
				mesh:AddTriangle(a[1], b[2], a[2])
				mesh:AddTriangle(a[3], b[4], b[3])
				mesh:AddTriangle(a[3], a[4], b[4])
			end
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
			part.Name = "ZoneGround"
			part.Color = owner.Floor
			part.Material = materialFor(owner)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.DoubleSided = true
			part.CFrame = CFrame.new((minV + maxV) * 0.5)
			part.Parent = folder
			curveParts += 1
		end
		-- Floor strips still blend at mid. CurveToZone N sits on the north side
		-- of zone N-1 (jail south of the bend), so wall + topping colors match
		-- that southern zone for the whole S-curve.
		curveStrip(curveStart, midZ, previous)
		curveStrip(midZ, startZ, biome)
		model:SetAttribute("CurveWallBiome", previous.Name)
		for _, wall in model:GetDescendants() do
			if wall:IsA("BasePart") and (wall.Name == "CurveWall" or wall.Name == "WallTooth") then
				wall.Color = previous.Wall
				wall:SetAttribute("BiomeOwner", previous.Name)
			end
		end
		task.wait()
	end

	-- BiomeSign at the start of each zone. For zones with an S-curve, StartZ is
	-- also where reverse travel enters that curve (owned by the previous zone).
	for _, zone in habitats:GetChildren() do
		local id = zone:GetAttribute("ZoneIndex")
		local startZ = zone:GetAttribute("StartZ")
		local sign = zone:FindFirstChild("BiomeSign")
		if typeof(id) ~= "number" or id < 1 or typeof(startZ) ~= "number" then
			continue
		end
		if not (sign and sign:IsA("BasePart")) then
			continue
		end
		local placeZ = startZ + 5
		local pos, direction = Path.atZ(placeZ)
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.zAxis
		else
			flat = flat.Unit
		end
		sign.Size = Vector3.new((Path.HalfWidth or 72) * 2 + 6, sign.Size.Y, sign.Size.Z)
		local height = sign.Position.Y
		sign.CFrame = CFrame.lookAt(
			Vector3.new(pos.X, height, pos.Z),
			Vector3.new(pos.X - flat.X, height, pos.Z - flat.Z)
		)
	end

	local props = 0
	for _, zone in habitats:GetChildren() do
		local id = zone:GetAttribute("ZoneIndex")
		if typeof(id) ~= "number" or id < 1 or zone:FindFirstChild("UnderwaterExtra") then
			continue
		end
		local biome = biomeAt(id)
		local center = zone:GetAttribute("Center")
		local startZ = zone:GetAttribute("StartZ")
		local endZ = zone:GetAttribute("EndZ")
		local ground = groundTops[id]
		if not (biome and typeof(center) == "Vector3" and typeof(startZ) == "number" and typeof(endZ) == "number" and ground) then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = "UnderwaterExtra"
		folder.Parent = zone
		local rng = Random.new(4000 + id)
		local stone = biome.Wall:Lerp(Color3.fromRGB(120, 118, 112), 0.55)
		local kelp = biome.Accent:Lerp(Color3.fromRGB(46, 140, 78), 0.35)
		for _ = 1, 5 do
			local lateral = rng:NextNumber(-58, 58)
			local height = rng:NextNumber(1.4, 3.2)
			placeMesh(
				small,
				folder,
				Vector3.new(center.X + lateral, ground, startZ + rng:NextNumber(12, endZ - startZ - 12)),
				Vector3.new(height * 1.5, height, height * 1.4),
				rng:NextNumber(0, math.pi * 2),
				stone,
				false
			)
			props += 1
		end
		for side = -1, 1, 2 do
			local height = rng:NextNumber(13, 16)
			local width = height * 1.7
			placeMesh(
				large,
				folder,
				Vector3.new(center.X + side * rng:NextNumber(38, 58), ground, startZ + rng:NextNumber(30, endZ - startZ - 30)),
				Vector3.new(width, height, width * 0.85),
				rng:NextNumber(0, math.pi * 2),
				stone:Lerp(Color3.new(0, 0, 0), 0.15),
				true
			)
			props += 1
		end
		for _ = 1, 7 do
			local height = rng:NextNumber(3.2, 5.4)
			placeMesh(
				weed,
				folder,
				Vector3.new(center.X + rng:NextNumber(-60, 60), ground, startZ + rng:NextNumber(8, endZ - startZ - 8)),
				Vector3.new(height * 0.55, height, height * 0.4),
				rng:NextNumber(0, math.pi * 2),
				kelp,
				false
			)
			props += 1
		end
		for _ = 1, 5 do
			local glow = Instance.new("Part")
			glow.Name = "UnderwaterGlow"
			glow.Shape = Enum.PartType.Ball
			glow.Size = Vector3.new(1, 1, 1) * rng:NextNumber(2.2, 3.4)
			glow.Color = biome.Accent
			glow.Material = Enum.Material.Neon
			glow.Transparency = 0.4
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CanTouch = false
			glow.CastShadow = false
			glow.CFrame = CFrame.new(center.X + rng:NextNumber(-55, 55), ground + rng:NextNumber(1.2, 4.2), startZ + rng:NextNumber(10, endZ - startZ - 10))
			local light = Instance.new("PointLight")
			light.Color = biome.Accent
			light.Brightness = 1.5
			light.Range = 26
			light.Shadows = false
			light.Parent = glow
			glow.Parent = folder
			props += 1
		end
		task.wait()
	end

	for id = 6, 21 do
		local model = curves:FindFirstChild("CurveToZone" .. id)
		local biome = biomeAt(id)
		local zone = habitats:FindFirstChild(string.format("Zone%02d", id))
		if not (model and biome and zone) or model:FindFirstChild("UnderwaterExtra") then
			continue
		end
		local startZ = zone:GetAttribute("StartZ")
		if typeof(startZ) ~= "number" then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = "UnderwaterExtra"
		folder.Parent = model
		local rng = Random.new(9000 + id)
		local stone = biome.Wall:Lerp(Color3.fromRGB(120, 118, 112), 0.55)
		local curveStart = startZ - curveLength
		for n = 1, 8 do
			local sampleZ = curveStart + (n / 9) * curveLength
			local pos, direction = Path.atZ(sampleZ)
			local right = Vector3.new(-direction.Z, 0, direction.X)
			if right.Magnitude < 0.05 then
				right = Vector3.xAxis
			else
				right = right.Unit
			end
			local owner = if sampleZ < startZ - curveLength * 0.5 then biomeAt(id - 1) or biome else biome
			local lateral = right * rng:NextNumber(34, 60) * (if n % 2 == 0 then 1 else -1)
			if n % 4 == 0 then
				local height = rng:NextNumber(13, 16)
				placeMesh(large, folder, Vector3.new(pos.X, -6, pos.Z) + lateral, Vector3.new(height * 1.7, height, height * 1.45), rng:NextNumber(0, math.pi * 2), stone:Lerp(Color3.new(0, 0, 0), 0.15), true)
			elseif n % 2 == 0 then
				local height = rng:NextNumber(3.2, 5.2)
				placeMesh(weed, folder, Vector3.new(pos.X, -6, pos.Z) + right * rng:NextNumber(-55, 55), Vector3.new(height * 0.55, height, height * 0.4), rng:NextNumber(0, math.pi * 2), owner.Accent:Lerp(Color3.fromRGB(46, 140, 78), 0.35), false)
			else
				local height = rng:NextNumber(1.6, 3)
				placeMesh(small, folder, Vector3.new(pos.X, -6, pos.Z) + right * rng:NextNumber(-55, 55), Vector3.new(height * 1.5, height, height * 1.4), rng:NextNumber(0, math.pi * 2), stone, false)
			end
			props += 1
		end
		for _ = 1, 3 do
			local sampleZ = curveStart + rng:NextNumber(0.1, 0.9) * curveLength
			local pos, direction = Path.atZ(sampleZ)
			local right = Vector3.new(-direction.Z, 0, direction.X)
			if right.Magnitude < 0.05 then
				right = Vector3.xAxis
			else
				right = right.Unit
			end
			local owner = if sampleZ < startZ - curveLength * 0.5 then biomeAt(id - 1) or biome else biome
			local glow = Instance.new("Part")
			glow.Name = "UnderwaterGlow"
			glow.Shape = Enum.PartType.Ball
			glow.Size = Vector3.one * rng:NextNumber(2.2, 3.2)
			glow.Color = owner.Accent
			glow.Material = Enum.Material.Neon
			glow.Transparency = 0.4
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CanTouch = false
			glow.CastShadow = false
			glow.CFrame = CFrame.new(Vector3.new(pos.X, -3.2, pos.Z) + right * rng:NextNumber(-40, 40))
			local light = Instance.new("PointLight")
			light.Color = owner.Accent
			light.Brightness = 1.5
			light.Range = 26
			light.Shadows = false
			light.Parent = glow
			glow.Parent = folder
			props += 1
		end
		task.wait()
	end

	root:SetAttribute("ChannelDress", 1)
	return string.format("floors=%d curveSlabs=%d props=%d", replaced, curveParts, props)
end

return Dress
