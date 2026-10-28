--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Uploaded Prismspike Dragon (Meshy 1015231004). Swap per-level entries as new beasts land.
local UPLOADED_MODEL_ID = "rbxassetid://140080853317761"
local MAX_LEVEL = 20

local LevelModelIds: { string } = table.create(MAX_LEVEL)
for level = 1, MAX_LEVEL do
	LevelModelIds[level] = UPLOADED_MODEL_ID
end

local GameUI = {
	MaxLevel = MAX_LEVEL,
	CurrentLevel = 1,
	UploadedModelId = UPLOADED_MODEL_ID,
	LevelModelIds = table.freeze(LevelModelIds),
	CollectSoundId = "rbxassetid://121076713801223",
	KickSoundId = "rbxassetid://9113524237",
	PickupPadding = 1.2,
	RevealSeconds = 2,
	NativeSize = Vector3.new(1.49478, 1.71468, 1.89981),
	NativeHeight = 1.71468,
}

function GameUI.modelIdForLevel(level: number): string
	local index = math.clamp(math.floor(level), 1, MAX_LEVEL)
	return GameUI.LevelModelIds[index] or UPLOADED_MODEL_ID
end

function GameUI.playerLevel(player: Player): number
	local value = player:GetAttribute("GameLevel")
	if typeof(value) == "number" then
		return math.clamp(math.floor(value), 1, MAX_LEVEL)
	end
	return GameUI.CurrentLevel
end

function GameUI.remote(name: string): RemoteEvent
	local shared = script.Parent
	if not shared then
		shared = ReplicatedStorage:WaitForChild("BabyBeastsShared")
	end
	local folder = shared:FindFirstChild("Remotes")
	if not folder then
		if RunService:IsServer() then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = shared
		else
			folder = shared:WaitForChild("Remotes", 15)
		end
	end
	assert(folder, "BabyBeasts remotes folder missing")
	local event = folder:FindFirstChild(name)
	if not event then
		if RunService:IsServer() then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		else
			event = folder:WaitForChild(name, 15)
		end
	end
	assert(event and event:IsA("RemoteEvent"), "BabyBeasts remote missing: " .. name)
	return event
end

function GameUI.ensureRemotes(): RemoteEvent
	GameUI.remote("CollectBeast")
	GameUI.remote("MommyEncounter")
	GameUI.remote("NightNotice")
	GameUI.remote("RagdollImpact")
	GameUI.remote("KnockdownVfx")
	GameUI.remote("MountAction")
	GameUI.remote("StarHandler")
	return GameUI.remote("BeastCollected")
end

return table.freeze(GameUI)
