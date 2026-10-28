--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.MeshArchive
-- Mesh templates live in ServerStorage so a join clones them instead of
-- downloading every mesh again. Rojo leaves this folder alone.

local ServerStorage = game:GetService("ServerStorage")

local Archive = {}

local function folder(): Folder
	local existing = ServerStorage:FindFirstChild("BakedMeshTemplates")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "BakedMeshTemplates"
	created.Parent = ServerStorage
	return created
end

function Archive.key(meshId: string): string
	return string.match(meshId, "%d+") or "mesh"
end

function Archive.find(meshId: string): MeshPart?
	local stored = folder():FindFirstChild(Archive.key(meshId))
	if stored and stored:IsA("MeshPart") then
		return stored
	end
	return nil
end

function Archive.keep(meshId: string, part: MeshPart): MeshPart
	local parent = folder()
	local name = Archive.key(meshId)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("MeshPart") then
		if existing ~= part then
			part:Destroy()
		end
		return existing
	end
	part.Name = name
	part.Archivable = true
	part.Parent = parent
	return part
end

return Archive
