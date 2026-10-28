--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.BeastData
-- Persists each player's pen pets (with their hatch timers) and the eggs they are carrying.
-- On leave the pets are saved and taken out of the pen, so the next player in that slot starts
-- clean; on rejoin they come back into whichever pen the player is given, hatch time frozen
-- where it was left, and the eggs go back in the backpack.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local TankBeasts = require(script.Parent.TankBeasts)
local CaveBubbles = require(script.Parent.CaveBubbles)
local SpeedData = require(script.Parent.SpeedDataManager)

local BeastData = {}

local STORE_NAME = "BabyBeastsBeasts_v1"
local VERSION = 1
local MAX_PETS = 400 -- sanity cap per save (a pen holds far fewer)
local MAX_EGGS = 50

type Save = {
	Version: number,
	Pets: { TankBeasts.Record },
	Eggs: { CaveBubbles.EggRecord },
}

type Session = {
	loaded: boolean, -- false until the load finished; never save over data we failed to read
	saving: boolean,
	lastJson: string?,
	eggs: { CaveBubbles.EggRecord }, -- last egg snapshot taken while the character was alive
}

local sessions: { [Player]: Session } = {}
local started = false
local store = DataStoreService:GetDataStore(STORE_NAME)

local function key(userId: number): string
	return "u_" .. userId
end

local function hasCharacter(player: Player): boolean
	local character = player.Character
	return character ~= nil and character.Parent ~= nil
end

local function refreshEggs(player: Player)
	local session = sessions[player]
	if session and player.Parent and hasCharacter(player) then
		session.eggs = CaveBubbles.snapshot(player)
	end
end

local function snapshot(player: Player, session: Session): Save
	-- the character can already be gone while the player is leaving; use the last live view then
	local eggs = if hasCharacter(player) then CaveBubbles.snapshot(player) else session.eggs
	local pets = TankBeasts.snapshot(player.UserId)
	return {
		Version = VERSION,
		Pets = table.move(pets, 1, math.min(#pets, MAX_PETS), 1, {}),
		Eggs = table.move(eggs, 1, math.min(#eggs, MAX_EGGS), 1, {}),
	}
end

local function write(userId: number, session: Session, data: Save, reason: string)
	local json = HttpService:JSONEncode(data)
	if json == session.lastJson then
		return
	end
	while session.saving do
		task.wait(0.1)
	end
	session.saving = true
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key(userId), function()
				return data
			end)
		end)
		if ok then
			success = true
			break
		end
		warn("[BeastData] save attempt " .. attempt .. " failed for " .. userId .. ": " .. tostring(err))
		task.wait(attempt)
	end
	session.saving = false
	if success then
		session.lastJson = json
		print(string.format("[BeastData] saved %d pets, %d eggs for %d (%s)", #data.Pets, #data.Eggs, userId, reason))
	end
end

local function save(player: Player, reason: string)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	write(player.UserId, session, snapshot(player, session), reason)
end

local function waitForTank(player: Player): Instance?
	local root = workspace:FindFirstChild("BabyBeastsMap")
	local tanks = root and root:FindFirstChild("PlayerTanks")
	local deadline = os.clock() + 30
	while player.Parent and os.clock() < deadline do
		local slot = player:GetAttribute("TankSlot")
		local tank = tanks and typeof(slot) == "number" and tanks:FindFirstChild("Tank" .. slot)
		if tank then
			return tank
		end
		task.wait(0.2)
	end
	return nil
end

local function restoreEggs(player: Player, eggs: { CaveBubbles.EggRecord })
	if #eggs == 0 then
		return
	end
	local deadline = os.clock() + 30
	while player.Parent and os.clock() < deadline do
		local character = player.Character
		if character and character.Parent and character:FindFirstChildOfClass("Humanoid") and player:FindFirstChild("Backpack") then
			break
		end
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	CaveBubbles.restore(player, eggs)
	SpeedData.refreshCarry(player)
	refreshEggs(player)
end

local function loadPlayer(player: Player)
	local session: Session = { loaded = false, saving = false, lastJson = nil, eggs = {} }
	sessions[player] = session
	local data: any = nil
	local ok = false
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return store:GetAsync(key(player.UserId))
		end)
		if success then
			ok, data = true, result
			break
		end
		warn("[BeastData] load attempt " .. attempt .. " failed for " .. player.UserId .. ": " .. tostring(result))
		task.wait(attempt * 2)
	end
	if not player.Parent then
		return
	end
	if not ok then
		player:SetAttribute("BeastLoadError", true)
		warn("[BeastData] could not load pets/eggs for " .. player.UserId .. "; this session will not be saved")
		return
	end
	local pets = if typeof(data) == "table" and typeof(data.Pets) == "table" then data.Pets else {}
	local eggs = if typeof(data) == "table" and typeof(data.Eggs) == "table" then data.Eggs else {}
	local tank = waitForTank(player)
	if not player.Parent then
		return
	end
	-- equip slots (SpeedData) decide how many hatched pets go back in the pen
	local deadline = os.clock() + 30
	while player.Parent and player:GetAttribute("SpeedLoaded") ~= true and os.clock() < deadline do
		task.wait(0.2)
	end
	local restoredPets = 0
	if tank and #pets > 0 then
		restoredPets = TankBeasts.restore(player, tank, pets)
	end
	restoreEggs(player, eggs)
	-- mark loaded only after restoring, so a save can never run on a half-restored pen
	session.loaded = true
	session.lastJson = if typeof(data) == "table" then HttpService:JSONEncode(data) else nil
	player:SetAttribute("BeastsLoaded", true)
	print(string.format("[BeastData] %s: restored %d pets, %d eggs", player.Name, restoredPets, #eggs))
end

local function hookCharacter(player: Player, character: Model)
	local function changed(child: Instance)
		if child.Name == "BabyBeast" then
			task.defer(refreshEggs, player)
		end
	end
	character.ChildAdded:Connect(changed)
	character.ChildRemoved:Connect(changed)
	task.defer(refreshEggs, player)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		hookCharacter(player, character)
	end)
	if player.Character then
		hookCharacter(player, player.Character)
	end
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		backpack.ChildAdded:Connect(function(child)
			if child.Name == "BabyBeast" then
				task.defer(refreshEggs, player)
			end
		end)
		backpack.ChildRemoved:Connect(function(child)
			if child.Name == "BabyBeast" then
				task.defer(refreshEggs, player)
			end
		end)
	end
	task.spawn(loadPlayer, player)
end

-- Save now (e.g. after a big change). Safe to call any time.
function BeastData.save(player: Player)
	task.spawn(save, player, "request")
end

function BeastData.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		local userId = player.UserId
		if session and session.loaded then
			-- snapshot synchronously, before the pets leave the pen
			local data = snapshot(player, session)
			TankBeasts.release(userId)
			write(userId, session, data, "leave")
		else
			-- load never finished: leave the stored data alone, but still clear the pen
			TankBeasts.release(userId)
		end
		sessions[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Economy.SaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player, "autosave")
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player, "shutdown")
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	print("[BabyBeasts] Beast save ready")
end

return BeastData
