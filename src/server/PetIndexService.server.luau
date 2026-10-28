-- Pet Index remotes: snapshot + claim, and hatch discovery backfill.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local Manager = require(script.Parent.SpeedDataManager)
local remotes = Shared:WaitForChild("Remotes")

local function remote(name: string): RemoteFunction
	local existing = remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = remotes
	return created
end

local snapshot = remote("PetIndexSnapshot")
local claim = remote("PetIndexClaim")
local last = setmetatable({}, { __mode = "k" })

snapshot.OnServerInvoke = function(player)
	return Manager.indexSnapshot(player)
end

claim.OnServerInvoke = function(player, id)
	if typeof(id) ~= "string" or #id > 120 then
		return { Ok = false, Message = "Invalid pet" }
	end
	local now = os.clock()
	if now - (last[player] or -10) < 0.25 then
		return { Ok = false, Message = "Please wait" }
	end
	last[player] = now
	local ok, message = Manager.claimIndex(player, id)
	return { Ok = ok, Message = message, State = Manager.indexSnapshot(player) }
end

-- Backfill existing hatched pets, and catch new hatches even when data loads later.
local TankBeasts = require(script.Parent.TankBeasts)
task.spawn(function()
	while true do
		task.wait(3)
		for _, player in Players:GetPlayers() do
			if Manager.isReady(player) then
				for _, rec in TankBeasts.snapshot(player.UserId) do
					if rec.Hatched == true and rec.Egg then
						Manager.discoverPet(player, rec.Egg)
					end
				end
			end
		end
	end
end)
