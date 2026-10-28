-- Dumps every guard rig in ServerStorage.GuardImports (or GUARD_SOURCE) to the receiver (receiver.py).
-- Everything is in the rig's root-part frame: parts (size, cf), Motor6D joints (c0/c1), welds, bones
-- (local cf to their parent part/bone, world cf), and the outer guard's HumanoidRootPart + HipHeight.
local Http = game:GetService("HttpService")
local PORT = 8804
local source = _G.GUARD_SOURCE or game.ServerStorage.GuardImports
local only = _G.GUARD_ONLY

local function cfList(cf: CFrame)
	return { cf:GetComponents() }
end

local function rootOf(rig: Model): BasePart?
	local driven = {}
	for _, m in rig:GetDescendants() do
		if m:IsA("Motor6D") and m.Part1 then
			driven[m.Part1] = true
		end
	end
	local best, bestCount = nil, -1
	for _, m in rig:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and not driven[m.Part0] and m.Part0:IsDescendantOf(rig) then
			local count = 0
			for _, o in rig:GetDescendants() do
				if o:IsA("Motor6D") and o.Part0 == m.Part0 then
					count += 1
				end
			end
			if count > bestCount then
				best, bestCount = m.Part0, count
			end
		end
	end
	if best then
		return best
	end
	return rig:FindFirstChild("RootPart") or rig:FindFirstChild("Root") or rig:FindFirstChild("HumanoidRootPart")
end

local out = {}
for _, guard in source:GetChildren() do
	if only and guard.Name ~= only then
		continue
	end
	local rig: Model? = nil
	for _, c in guard:GetChildren() do
		if c:IsA("Model") and c:FindFirstChildOfClass("AnimationController") then
			rig = c
		end
	end
	if not rig then
		out[guard.Name] = "no rig"
		continue
	end
	local root = rootOf(rig)
	if not root then
		out[guard.Name] = "no root"
		continue
	end
	local base = root.CFrame
	local data = { name = guard.Name, root = root.Name, parts = {}, joints = {}, welds = {}, bones = {} }
	local names = {}
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			names[p.Name] = (names[p.Name] or 0) + 1
			table.insert(data.parts, {
				name = p.Name,
				class = p.ClassName,
				size = { p.Size.X, p.Size.Y, p.Size.Z },
				cf = cfList(base:ToObjectSpace(p.CFrame)),
				transparency = p.Transparency,
				parent = p.Parent.Name,
			})
		elseif p:IsA("Motor6D") and p.Part0 and p.Part1 then
			table.insert(data.joints, {
				name = p.Name,
				part0 = p.Part0.Name,
				part1 = p.Part1.Name,
				c0 = cfList(p.C0),
				c1 = cfList(p.C1),
			})
		elseif (p:IsA("Weld") or p:IsA("WeldConstraint") or p:IsA("RigidConstraint")) then
			local a = if p:IsA("RigidConstraint") then (p.Attachment0 and p.Attachment0.Parent) else p.Part0
			local b = if p:IsA("RigidConstraint") then (p.Attachment1 and p.Attachment1.Parent) else p.Part1
			if a and b then
				table.insert(data.welds, { a = a.Name, b = b.Name })
			end
		elseif p:IsA("Bone") then
			table.insert(data.bones, {
				name = p.Name,
				parent = p.Parent.Name,
				parentIsBone = p.Parent:IsA("Bone"),
				cf = cfList(p.CFrame),
				world = cfList(base:ToObjectSpace(p.WorldCFrame)),
			})
		end
	end
	local dup = {}
	for n, c in names do
		if c > 1 then
			table.insert(dup, n)
		end
	end
	data.duplicateParts = dup
	local hrp = guard:FindFirstChild("HumanoidRootPart")
	local hum = guard:FindFirstChildOfClass("Humanoid")
	data.hrp = if hrp then { size = { hrp.Size.X, hrp.Size.Y, hrp.Size.Z }, cf = cfList(base:ToObjectSpace(hrp.CFrame)) } else nil
	data.hipHeight = if hum then hum.HipHeight else nil
	-- animation translations are multiplied by the animated model's scale
	data.scale = rig:GetScale()
	local bbcf, bbsize = rig:GetBoundingBox()
	data.bbox = { cf = cfList(base:ToObjectSpace(bbcf)), size = { bbsize.X, bbsize.Y, bbsize.Z } }
	local body = Http:JSONEncode(data)
	Http:PostAsync("http://127.0.0.1:" .. PORT .. "/rig/" .. Http:UrlEncode(guard.Name), body)
	out[guard.Name] = string.format("parts=%d joints=%d bones=%d dup=%d root=%s", #data.parts, #data.joints, #data.bones, #dup, root.Name)
end
local lines = {}
for k, v in out do
	table.insert(lines, k .. ": " .. v)
end
table.sort(lines)
return table.concat(lines, "\n")
