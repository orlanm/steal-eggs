--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local BubbleMesh = require(game.ReplicatedStorage.BabyBeastsShared.BubbleMesh)
local BubbleLife = require(game.ReplicatedStorage.BabyBeastsShared.BubbleLife)
local GameUI = require(game.ReplicatedStorage.BabyBeastsShared.GameUI)
local GameEgg = require(game.ReplicatedStorage.BabyBeastsShared.GameEgg)
local EggVisual = require(game.ReplicatedStorage.BabyBeastsShared.EggVisual)
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)

local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "LocalCaveBubbles"
folder.Parent = workspace

export type Visual = {
	model: Model,
	root: BasePart,
	body: BasePart,
	rec: Instance,
	rig: EggVisual.Rig?,
	waitingEgg: boolean,
	mutation: string,
	bases: { [BasePart]: Color3 },
}

local visuals: { [Instance]: Visual } = {}
local meshReady = false

local function applyMesh(body: MeshPart)
	local ok, template = pcall(function()
		return BubbleMesh.template()
	end)
	if ok then
		body:ApplyMesh(template)
		meshReady = true
	else
		warn(template)
	end
end

local function makeVisual(rec: Instance): Visual?
	local origin = rec:GetAttribute("Origin")
	local bodySize = rec:GetAttribute("BodySize")
	local modelId = rec:GetAttribute("ModelId")
	if typeof(origin) ~= "Vector3" then
		return nil
	end
	if typeof(bodySize) ~= "Vector3" then
		bodySize = GameUI.NativeSize
	end
	if typeof(modelId) ~= "string" then
		modelId = BubbleLife.modelId()
	end
	local eggName = rec:GetAttribute("EggName")
	local egg = if typeof(eggName) == "string" then GameEgg.get(eggName) else nil

	local model = Instance.new("Model")
	model.Name = "CaveTrexBubble"
	model:SetAttribute("ModelId", modelId)
	if egg then
		model:SetAttribute("EggName", egg.Name)
	end
	model:SetAttribute("Hidden", rec:GetAttribute("Popping") == true)
	model:SetAttribute("BubbleId", rec:GetAttribute("Id"))

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.new(origin)
	root.Parent = model
	model.PrimaryPart = root

	local body = Instance.new("MeshPart")
	body.Name = "Body"
	body.Size = bodySize
	body.TextureID = modelId
	body.Color = Color3.new(1, 1, 1)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = root.CFrame
	body.Transparency = if egg then 1 else 0
	pcall(function()
		body.DoubleSided = true
	end)
	if not egg then
		applyMesh(body)
	end
	body.Parent = model

	local mutationAttr = rec:GetAttribute("ShellMutation")
	local mutation = if typeof(mutationAttr) == "string" then mutationAttr else ""

	model.Parent = folder
	local visual: Visual = {
		model = model,
		root = root,
		body = body,
		rec = rec,
		rig = nil,
		waitingEgg = egg ~= nil,
		mutation = mutation,
		bases = {},
	}
	local function capture(rig: EggVisual.Rig)
		for _, part in rig.model:GetDescendants() do
			if part:IsA("BasePart") and not visual.bases[part] then
				visual.bases[part] = part.Color
			end
		end
	end
	local function tint(rig: EggVisual.Rig, tintColor: Color3, amount: number)
		capture(rig)
		for part, base in visual.bases do
			if part.Parent then
				part.Color = base:Lerp(tintColor, amount)
			end
		end
	end
	if egg then
		local builtEgg = egg
		local tintColor = if mutation ~= "" then EggScale.mutationColor(mutation) else nil
		task.spawn(function()
			local rig = EggVisual.build(builtEgg, body.Size)
			if not rig or not model.Parent then
				if rig then
					rig:destroy()
				end
				if model.Parent then
					applyMesh(body)
					visual.waitingEgg = false
				end
				return
			end
			rig.model.Parent = model
			rig:place(root.CFrame)
			visual.rig = rig
			visual.waitingEgg = false
			if tintColor then
				tint(rig, tintColor, 0.72)
			end
		end)
	end
	return visual
end

local function bind(rec: Instance)
	if visuals[rec] then
		return
	end
	local vis = makeVisual(rec)
	if vis then
		visuals[rec] = vis
	end
end

local function unbind(rec: Instance)
	local vis = visuals[rec]
	if vis then
		vis.model:Destroy()
		visuals[rec] = nil
	end
end

task.spawn(function()
	local map = workspace:WaitForChild("BabyBeastsMap", 30)
	if not map then
		return
	end
	local state = map:WaitForChild("CaveBubbleState", 30)
	if not state then
		return
	end
	for _, rec in state:GetChildren() do
		bind(rec)
	end
	state.ChildAdded:Connect(bind)
	state.ChildRemoved:Connect(unbind)
end)

RunService.PreRender:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local character = player.Character
	local feet = character and BubbleLife.feetY(character)
	local localLine = BubbleLife.popLine(feet or 0)
	for rec, vis in visuals do
		if not rec.Parent then
			unbind(rec)
			continue
		end
		local cf, y = BubbleLife.poseFrom(rec, now)
		local popping = rec:GetAttribute("Popping") == true
		local hideBeast = false
		if popping then
			local line = rec:GetAttribute("PopLine")
			if typeof(line) ~= "number" then
				line = localLine
			end
			local t = math.clamp((y - line) / 3, 0, 1)
			hideBeast = t > 0.35
			vis.model:SetAttribute("Hidden", hideBeast)
		else
			vis.model:SetAttribute("Hidden", false)
		end
		vis.root.CFrame = cf
		if vis.mutation == "Rainbow" and vis.rig then
			local rainbow = Color3.fromHSV((now * 0.35) % 1, 0.55, 1)
			for _, part in vis.rig.model:GetDescendants() do
				if part:IsA("BasePart") and not vis.bases[part] then
					vis.bases[part] = part.Color
				end
			end
			for part, base in vis.bases do
				if part.Parent then
					part.Color = base:Lerp(rainbow, 0.62)
				end
			end
		end
		if vis.rig then
			vis.rig:place(cf)
			vis.rig:setTransparency(if hideBeast then 1 else 0)
			vis.body.Transparency = 1
		elseif vis.waitingEgg then
			vis.body.Transparency = 1
		else
			vis.body.CFrame = cf
			vis.body.Transparency = if hideBeast then 1 else 0
		end
	end
end)

print("[BabyBeasts] Local cave bubbles ready")
