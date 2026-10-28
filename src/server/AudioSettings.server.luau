--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.AudioSettings
-- Music / sound effects on-off, saved per player. GameAudio.client reads the player attributes
-- MusicOn / SfxOn and flips them through the AudioSettings remote (settings tile).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared.GameUI)

local KEYS = { MusicOn = true, SfxOn = true }

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("BabyBeastsAudio_v1")
end)
local remote = GameUI.remote("AudioSettings")
local dirty: { [Player]: boolean } = {}

local function load(player: Player)
	local data: any = nil
	if okStore then
		local ok, result = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		data = if ok then result else nil
	end
	for key in KEYS do
		-- a choice made before the load finished wins
		if player:GetAttribute(key) == nil then
			player:SetAttribute(key, not (typeof(data) == "table" and data[key] == false))
		end
	end
end

local function save(player: Player)
	if not (okStore and dirty[player]) then
		return
	end
	dirty[player] = nil
	local data = {}
	for key in KEYS do
		data[key] = player:GetAttribute(key) ~= false
	end
	pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
end

remote.OnServerEvent:Connect(function(player: Player, key: any, value: any)
	if typeof(key) ~= "string" or not KEYS[key] or typeof(value) ~= "boolean" then
		return
	end
	player:SetAttribute(key, value)
	dirty[player] = true
end)

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	dirty[player] = nil
end)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(save, player)
	end
	task.wait(2)
end)
