-- Yellow-trex mommy: copies MeshId geometry from the Meshy Workspace reference
-- (or MommyAssets.MommyTrex), keeps its SurfaceAppearance, and auto-skins to
-- MommyMeshData bones so MommyClips still drive idle/swim.
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.MommyConfig)

local template
local Model = {}

local REF_NAME = "Meshy_AI_Geometric_Predator_1018145446_texture"

local function boneData()
	local chunks = script.Parent.MommyMeshData:GetChildren()
	table.sort(chunks, function(a, b)
		return a.Name < b.Name
	end)
	local strings = {}
	for _, chunk in chunks do
		table.insert(strings, require(chunk))
	end
	return HttpService:JSONDecode(table.concat(strings)).bones
end

local function scaledBoneCFrame(cfComponents: { number }, scale: number): CFrame
	local cf = CFrame.new(table.unpack(cfComponents))
	return CFrame.new(cf.Position * scale) * (cf - cf.Position)
end

local function findReferenceModel(): Model?
	local ws = workspace:FindFirstChild(REF_NAME)
	if ws and ws:IsA("Model") then
		return ws
	end
	local assets = script.Parent:FindFirstChild("MommyAssets")
	local stored = assets and assets:FindFirstChild("MommyTrex")
	if stored and stored:IsA("Model") then
		return stored
	end
	return nil
end

local function referenceMaps(ref: Model?): (string, string)
	local meshId = Config.MeshId
	local colorMap = Config.TextureId
	if ref then
		local attrMesh = ref:GetAttribute("MommyMeshId")
		local attrColor = ref:GetAttribute("MommyColorMap")
		if typeof(attrMesh) == "string" and attrMesh ~= "" then
			meshId = attrMesh
		else
			local part = ref:FindFirstChildWhichIsA("MeshPart", true)
			if part and part.MeshId ~= "" then
				meshId = part.MeshId
			end
		end
		if typeof(attrColor) == "string" and attrColor ~= "" then
			colorMap = attrColor
		end
	end
	return meshId, colorMap
end

-- Published MeshId EditableMeshes are fixed-size in-experience (no AddBone).
local function copyPublishedMesh(meshId: string): EditableMesh
	local src = AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
	local dst = AssetService:CreateEditableMesh()
	assert(dst, "Device mesh memory budget is insufficient for mommy beast")

	local vmap = {}
	for i, vid in src:GetVertices() do
		vmap[vid] = dst:AddVertex(src:GetPosition(vid))
		if i % 800 == 0 then
			task.wait()
		end
	end

	local uvmap = {}
	for _, uvid in src:GetUVs() do
		uvmap[uvid] = dst:AddUV(src:GetUV(uvid))
	end

	local nmap = {}
	for _, nid in src:GetNormals() do
		nmap[nid] = dst:AddNormal(src:GetNormal(nid))
	end

	local white = dst:AddColor(Color3.new(1, 1, 1), 1)
	for i, fid in src:GetFaces() do
		local fv = src:GetFaceVertices(fid)
		local fuv = src:GetFaceUVs(fid)
		local fn = src:GetFaceNormals(fid)
		local tri = dst:AddTriangle(vmap[fv[1]], vmap[fv[2]], vmap[fv[3]])
		dst:SetFaceUVs(tri, { uvmap[fuv[1]], uvmap[fuv[2]], uvmap[fuv[3]] })
		dst:SetFaceNormals(tri, { nmap[fn[1]], nmap[fn[2]], nmap[fn[3]] })
		dst:SetFaceColors(tri, { white, white, white })
		if i % 800 == 0 then
			task.wait()
		end
	end

	src:Destroy()
	return dst
end

local function autoSkin(mesh: EditableMesh, bones: { any }, boneWorld: { Vector3 })
	local verts = mesh:GetVertices()
	for i, vid in verts do
		local p = mesh:GetPosition(vid)
		local ranked = table.create(#boneWorld)
		for boneIndex, origin in boneWorld do
			ranked[boneIndex] = { boneIndex, (p - origin).Magnitude }
		end
		table.sort(ranked, function(a, b)
			return a[2] < b[2]
		end)
		local ids = table.create(4)
		local weights = table.create(4)
		local sum = 0
		for k = 1, math.min(4, #ranked) do
			local w = 1 / math.max(ranked[k][2], 0.08) ^ 2
			ids[k] = bones[ranked[k][1]]
			weights[k] = w
			sum += w
		end
		for k = 1, #weights do
			weights[k] /= sum
		end
		mesh:SetVertexBones(vid, ids)
		mesh:SetVertexBoneWeights(vid, weights)
		if i % 400 == 0 then
			task.wait()
		end
	end
end

local function applyReferenceLook(part: MeshPart, colorMap: string)
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.Plastic
	-- Clients cannot create/write SurfaceAppearance maps (Plugin capability).
	-- TextureID with the Meshy ColorMap id + the published mesh UVs matches the reference albedo.
	part.TextureID = colorMap
end

function Model.template()
	if template then
		return template
	end

	local ref = findReferenceModel()
	local meshId, colorMap = referenceMaps(ref)
	local bonesData = boneData()
	local mesh = copyPublishedMesh(meshId)

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, vid in mesh:GetVertices() do
		local p = mesh:GetPosition(vid)
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local boneScale = (maxV.Y - minV.Y) / Config.NativeSize.Y

	local meshBones = {}
	local boneWorld = {}
	for i, b in bonesData do
		local world = scaledBoneCFrame(b.cf, boneScale)
		meshBones[i] = mesh:AddBone({
			Name = b.name,
			ParentId = if b.parent > 0 then meshBones[b.parent] else nil,
			CFrame = world,
			Virtual = false,
		})
		boneWorld[i] = world.Position
	end
	autoSkin(mesh, meshBones, boneWorld)

	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.Name = "Body"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	applyReferenceLook(part, colorMap)

	local rigBones = {}
	for i, b in bonesData do
		local bone = Instance.new("Bone")
		bone.Name = b.name
		local world = scaledBoneCFrame(b.cf, boneScale)
		local parentWorld = if b.parent > 0 then scaledBoneCFrame(bonesData[b.parent].cf, boneScale) else nil
		bone.CFrame = if parentWorld then parentWorld:ToObjectSpace(world) else world
		bone.Parent = if b.parent > 0 then rigBones[b.parent] else part
		rigBones[i] = bone
	end

	template = Instance.new("Model")
	template.Name = Config.TemplateName
	part.Parent = template
	template.PrimaryPart = part
	local extents = template:GetExtentsSize()
	template:ScaleTo(template:GetScale() * Config.NativeSize.Y / math.max(extents.Y, 0.001))
	template:SetAttribute("ImportedFromBlender", true)
	template:SetAttribute("SourceMesh", "MeshyGeometricPredator")
	template:SetAttribute("ReferenceMeshId", meshId)
	template:SetAttribute("YellowTrex", true)
	return template
end

return Model
