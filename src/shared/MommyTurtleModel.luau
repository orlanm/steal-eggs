-- Neon Shell Leviathan (turtle) mommy: EditableMesh from Blender mesh chunks
-- (MommyTurtleMeshData) skinned to the shared 11-bone mommy rig.
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.MommyConfig)

local template
local Model = {}

local function meshPayload()
	local folder = script.Parent:WaitForChild("MommyTurtleMeshData")
	local chunks = folder:GetChildren()
	table.sort(chunks, function(a, b)
		return a.Name < b.Name
	end)
	local strings = table.create(#chunks)
	for i, chunk in chunks do
		strings[i] = require(chunk)
	end
	return HttpService:JSONDecode(table.concat(strings))
end

-- Meshy turtle snout landed on +LookVector; yaw 180 so it faces jail bars like other mommies.
local YAW180 = CFrame.Angles(0, math.pi, 0)

local function scaledBoneCFrame(cfComponents: { number }, scale: number): CFrame
	local cf = CFrame.new(table.unpack(cfComponents))
	local scaled = CFrame.new(cf.Position * scale) * (cf - cf.Position)
	return YAW180 * scaled
end

local function buildMesh(data)
	local mesh = AssetService:CreateEditableMesh()
	assert(mesh, "Device mesh memory budget is insufficient for neon shell leviathan")

	local vertIds = table.create(#data.vertices)
	for i, v in data.vertices do
		vertIds[i] = mesh:AddVertex(Vector3.new(-v[1], v[2], -v[3]))
		if i % 400 == 0 then
			task.wait()
		end
	end

	local uvIds = table.create(#data.uvs)
	for i, uv in data.uvs do
		uvIds[i] = mesh:AddUV(Vector2.new(uv[1], 1 - uv[2]))
	end

	local normalIds = table.create(#data.normals)
	for i, n in data.normals do
		normalIds[i] = mesh:AddNormal(Vector3.new(-n[1], n[2], -n[3]))
	end

	local white = mesh:AddColor(Color3.new(1, 1, 1), 1)
	for i, face in data.faces do
		local verts = face[1]
		local uvs = face[2]
		local norms = face[4]
		-- Blender export remaps (x,y,z)->(x,z,-y) with det +1, so keep loop order
		-- (reversing verts/UVs was shattering the neon-shell texture).
		local tri = mesh:AddTriangle(vertIds[verts[1]], vertIds[verts[2]], vertIds[verts[3]])
		mesh:SetFaceUVs(tri, { uvIds[uvs[1]], uvIds[uvs[2]], uvIds[uvs[3]] })
		mesh:SetFaceNormals(tri, { normalIds[norms[1]], normalIds[norms[2]], normalIds[norms[3]] })
		mesh:SetFaceColors(tri, { white, white, white })
		if i % 400 == 0 then
			task.wait()
		end
	end

	return mesh, vertIds
end

function Model.clearCache()
	template = nil
end

function Model.template()
	if template then
		return template
	end

	local data = meshPayload()
	local mesh, vertIds = buildMesh(data)

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, vid in mesh:GetVertices() do
		local p = mesh:GetPosition(vid)
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local native = Config.TurtleNativeSize or Config.NativeSize
	local boneScale = (maxV.Y - minV.Y) / native.Y

	local meshBones = {}
	for i, b in data.bones do
		local world = scaledBoneCFrame(b.cf, boneScale)
		meshBones[i] = mesh:AddBone({
			Name = b.name,
			ParentId = if b.parent > 0 then meshBones[b.parent] else nil,
			CFrame = world,
			Virtual = false,
		})
	end

	for i, v in data.vertices do
		local boneList = v[4]
		local weightList = v[5]
		local ids = table.create(#boneList)
		local weights = table.create(#weightList)
		for k, boneIndex in boneList do
			ids[k] = meshBones[boneIndex]
			weights[k] = weightList[k]
		end
		mesh:SetVertexBones(vertIds[i], ids)
		mesh:SetVertexBoneWeights(vertIds[i], weights)
		if i % 400 == 0 then
			task.wait()
		end
	end

	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.Name = "Body"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.Plastic
	part.TextureID = Config.TurtleTextureId or ""

	local rigBones = {}
	for i, b in data.bones do
		local bone = Instance.new("Bone")
		bone.Name = b.name
		local world = scaledBoneCFrame(b.cf, boneScale)
		local parentWorld = if b.parent > 0 then scaledBoneCFrame(data.bones[b.parent].cf, boneScale) else nil
		bone.CFrame = if parentWorld then parentWorld:ToObjectSpace(world) else world
		bone.Parent = if b.parent > 0 then rigBones[b.parent] else part
		rigBones[i] = bone
	end

	template = Instance.new("Model")
	template.Name = "MommyNeonShellLeviathan"
	part.Parent = template
	template.PrimaryPart = part
	local extents = template:GetExtentsSize()
	template:ScaleTo(template:GetScale() * native.Y / math.max(extents.Y, 0.001))
	template:SetAttribute("ImportedFromBlender", true)
	template:SetAttribute("SourceMesh", "MeshyNeonShellLeviathan")
	template:SetAttribute("NeonShellLeviathan", true)
	return template
end

return Model
