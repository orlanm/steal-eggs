--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.PetIndexModels
-- The Pet Index renders each pet from its uploaded model. Clients ask for the species
-- of the biome they are looking at; this loads those templates into ReplicatedStorage.PetTemplates
-- (PetAssets), a few at a time so a fast scroll never floods InsertService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PetAssets = require(script.Parent:WaitForChild("PetAssets"))

local remotes = ReplicatedStorage:WaitForChild("BabyBeastsShared"):WaitForChild("Remotes")
local request = remotes:FindFirstChild("PetIndexModels") or Instance.new("RemoteEvent")
request.Name = "PetIndexModels"
request.Parent = remotes

local MAX_PER_REQUEST = 40
local queue: { string } = {}
local queued: { [string]: boolean } = {}
local lastRequest: { [Player]: number } = {}

request.OnServerEvent:Connect(function(player: Player, names: any)
	if typeof(names) ~= "table" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or -1) < 0.2 then
		return
	end
	lastRequest[player] = now
	local count = 0
	for _, name in names do
		count += 1
		if count > MAX_PER_REQUEST then
			break
		end
		if typeof(name) == "string" and #name <= 120 and not queued[name] then
			queued[name] = true
			table.insert(queue, name)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

local WORKERS = 4
for _ = 1, WORKERS do
	task.spawn(function()
		while true do
			local name = table.remove(queue, 1)
			if name then
				pcall(PetAssets.ensure, name)
			else
				task.wait(0.1)
			end
		end
	end)
end
