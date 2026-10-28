--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.PetAssets
-- Lazily loads uploaded pet models (PetCatalog .Model asset ids) with InsertService and parks one
-- clean template per species in ReplicatedStorage.PetTemplates for clients to clone.
-- Only species that actually appear get loaded, so this scales to thousands of catalog entries.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetCatalog = require(ReplicatedStorage.BabyBeastsShared.PetCatalog)

local PetAssets = {}

local folder = ReplicatedStorage:FindFirstChild("PetTemplates") :: Folder?
if not folder then
	local f = Instance.new("Folder")
	f.Name = "PetTemplates"
	f.Parent = ReplicatedStorage
	folder = f
end
local templates = folder :: Folder

local inflight: { [string]: BindableEvent } = {}
local failed: { [string]: boolean } = {}

local function clean(model: Model, entry: PetCatalog.Entry)
	-- Rigid pieces import as MeshParts driven by Motor6Ds; a jointed part must stay unanchored for the
	-- Animator to move it, so only the parts nothing holds (the RootPart) are anchored.
	local jointed: { [BasePart]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part1 and d.Part0 then
			jointed[d.Part1] = true
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			if d:IsA("MeshPart") and d.TextureID == "" and entry.Texture ~= 0 then
				d.TextureID = "rbxassetid://" .. entry.Texture
			end
			d.Anchored = not jointed[d]
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	if not model:FindFirstChildWhichIsA("AnimationController") then
		local controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local controller = model:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	if not controller:FindFirstChildWhichIsA("Animator") then
		Instance.new("Animator").Parent = controller
	end
	model.Name = entry.Id
	model:SetAttribute("PetId", entry.Id)
	model:SetAttribute("GameName", entry.GameName)
end

-- Returns the template (loading it on first use); nil if the pet has no uploaded model.
function PetAssets.ensure(name: string): Model?
	local entry = PetCatalog.get(name)
	if not entry or not PetCatalog.hasModel(entry) or failed[entry.Id] then
		return nil
	end
	local existing = templates:FindFirstChild(entry.Id)
	if existing and existing:IsA("Model") then
		return existing
	end
	local gate = inflight[entry.Id]
	if gate then
		gate.Event:Wait()
		return templates:FindFirstChild(entry.Id) :: Model?
	end
	gate = Instance.new("BindableEvent")
	inflight[entry.Id] = gate
	local ok, result = pcall(function()
		return InsertService:LoadAsset(entry.Model)
	end)
	local model: Model? = nil
	if ok and result then
		local inner = result:FindFirstChildWhichIsA("Model")
		if inner then
			inner.Parent = nil
			result:Destroy()
			model = inner
		else
			model = result :: any
		end
	end
	if model then
		clean(model, entry)
		model.Parent = templates
	else
		failed[entry.Id] = true
		warn("[PetAssets] could not load model for " .. entry.Id .. " (" .. tostring(entry.Model) .. "): " .. tostring(result))
	end
	inflight[entry.Id] = nil
	gate:Fire()
	gate:Destroy()
	return model
end

local function watchModel(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local name = inst:GetAttribute("EggName")
	if typeof(name) == "string" and name ~= "" then
		task.spawn(PetAssets.ensure, name)
	end
end

-- Preload templates for every pet that shows up in the pens (deposits + showcase).
function PetAssets.start(root: Instance)
	local function hook(folder: Instance)
		for _, child in folder:GetChildren() do
			watchModel(child)
		end
		folder.ChildAdded:Connect(watchModel)
	end
	local beasts = root:FindFirstChild("TankBeasts")
	if beasts then
		hook(beasts)
	else
		root.ChildAdded:Connect(function(child)
			if child.Name == "TankBeasts" then
				hook(child)
			end
		end)
	end
	print("[PetAssets] ready - " .. #PetCatalog.all() .. " pets in catalog")
end

return PetAssets
