--!strict
local AssetService = game:GetService("AssetService")
local BubbleConfig = require(script.Parent.BubbleConfig)
local BubbleMesh = {}

local building = false
local source: MeshPart? = nil
local failed = false

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup: { [number]: number } = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end

local function b64decode(data: string): buffer
	data = string.gsub(data, "%s", "")
	if string.sub(data, -2) == "==" then
		data = string.sub(data, 1, -3)
	elseif string.sub(data, -1) == "=" then
		data = string.sub(data, 1, -2)
	end
	local out = buffer.create(math.floor(#data * 3 / 4))
	local o = 0
	for i = 1, #data, 4 do
		local n = 0
		for j = 0, 3 do
			n = bit32.lshift(n, 6) + (lookup[string.byte(data, i + j)] or 0)
		end
		buffer.writeu8(out, o, bit32.band(bit32.rshift(n, 16), 255))
		o += 1
		if o < buffer.len(out) then
			buffer.writeu8(out, o, bit32.band(bit32.rshift(n, 8), 255))
			o += 1
		end
		if o < buffer.len(out) then
			buffer.writeu8(out, o, bit32.band(n, 255))
			o += 1
		end
	end
	return out
end

local function payload(): string
	local folder = script.Parent:FindFirstChild("TrexBubbleBin")
	assert(folder, "TrexBubbleBin missing")
	local parts = folder:GetChildren()
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	local chunks = table.create(#parts)
	for i, inst in parts do
		chunks[i] = (inst :: StringValue).Value
	end
	return table.concat(chunks)
end

function BubbleMesh.template(): MeshPart
	if source then
		return source
	end
	if failed then
		error("Bubble mesh unavailable")
	end
	while building do
		task.wait()
		if source then
			return source
		end
		if failed then
			error("Bubble mesh unavailable")
		end
	end
	building = true
	local ok, result = pcall(function()
		local buf = b64decode(payload())
		local nv = buffer.readu16(buf, 6)
		local nt = buffer.readu32(buf, 8)
		local em = AssetService:CreateEditableMesh()
		local ids = table.create(nv)
		local off = 12
		for i = 1, nv do
			ids[i] = em:AddVertex(Vector3.new(buffer.readf32(buf, off), buffer.readf32(buf, off + 4), buffer.readf32(buf, off + 8)))
			off += 12
			if i % 2500 == 0 then
				task.wait()
			end
		end
		local faces = table.create(nt)
		local corners = table.create(nt)
		for i = 1, nt do
			local a = buffer.readu32(buf, off) + 1
			local b = buffer.readu32(buf, off + 4) + 1
			local c = buffer.readu32(buf, off + 8) + 1
			off += 12
			faces[i] = em:AddTriangle(ids[a], ids[b], ids[c])
			corners[i] = { a, b, c }
			if i % 2500 == 0 then
				task.wait()
			end
		end
		local uvs = table.create(nv)
		for i = 1, nv do
			uvs[i] = em:AddUV(Vector2.new(buffer.readf32(buf, off), 1 - buffer.readf32(buf, off + 4)))
			off += 8
		end
		for i = 1, nt do
			em:SetFaceUVs(faces[i], { uvs[corners[i][1]], uvs[corners[i][2]], uvs[corners[i][3]] })
			if i % 2500 == 0 then
				task.wait()
			end
		end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		part.Name = "PrismspikeBubbleMesh"
		part.TextureID = BubbleConfig.TextureId
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		pcall(function()
			part.DoubleSided = true
		end)
		return part
	end)
	building = false
	if not ok then
		failed = true
		error(result)
	end
	source = result
	return source
end

return BubbleMesh
