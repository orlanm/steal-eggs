-- Local distance culling keeps far-away lights and particles off on phones.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage:WaitForChild("BabyBeastsShared"):WaitForChild("BiomeLandmarkConfig"))
local particles, lights = {}, {}

local function watch(tag, list)
	for _, v in CollectionService:GetTagged(tag) do
		list[v] = true
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(v)
		list[v] = true
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
		list[v] = nil
	end)
end

watch("BiomeAmbientParticle", particles)
watch("BiomeAmbientLight", lights)

local function position(v)
	local p = v.Parent
	if p and p:IsA("Attachment") then
		return p.WorldPosition
	end
	if p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local origin = if root then root.Position elseif camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	for e in particles do
		local pos = position(e)
		local distance = if pos then (pos - origin).Magnitude else math.huge
		e.Enabled = distance < Config.EffectDistance
		if e.Enabled then
			e.Rate = (e:GetAttribute("BaseRate") or 3) * math.clamp(1 - distance / Config.EffectDistance, 0.25, 1)
		end
	end
	for l in lights do
		local pos = position(l)
		local distance = if pos then (pos - origin).Magnitude else math.huge
		l.Enabled = distance < Config.LightDistance
		if l.Enabled and pos then
			l.Brightness = (l:GetAttribute("BaseBrightness") or 0.5) * (0.92 + 0.08 * math.sin(t * 0.8 + pos.Z * 0.03))
		end
	end
end)
