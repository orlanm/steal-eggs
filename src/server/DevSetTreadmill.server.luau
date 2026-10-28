--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.DevSetTreadmill
-- ONE-SHOT: set a player's personal treadmill by username.
--
-- How to use (Studio Edit or Play):
-- 1. Select this script in Explorer.
-- 2. Set attributes:
--      Username = exact Roblox username (string)
--      Tier     = level number from the list below (number)
--      Run      = true
-- 3. The script applies once, prints the result, then sets Run = false.
--
-- TARGET TREADMILL OPTIONS (Tier attribute)
--   1  = Default Treadmill       Common     ×2      Free
--   2  = Sci-Fi Treadmill        Uncommon   ×5      15K / 19 R$
--   3  = Flame Treadmill         Rare       ×12     250K / 39 R$
--   4  = Celebrity Treadmill     Epic       ×30     5M / 69 R$
--   5  = Golden Treadmill        Legendary  ×80     120M / 119 R$
--   6  = The Freeze Treadmill    Mythic     ×100    3B / 199 R$
--   7  = Lucky Block Treadmill   Cosmic     ×200    75B / 299 R$
--   8  = Hacker Treadmill        Secret     ×500    2T / 499 R$
--   9  = Demonic Treadmill       Eternal    ×1000   50T / 799 R$
--   10 = Angelic Treadmill MAX   Divine     ×2000   1Qa / 1299 R$

local Players = game:GetService("Players")
local Economy = require(game.ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local SpeedData = require(script.Parent.SpeedDataManager)

local function optionsText(): string
	local lines = { "[DevSetTreadmill] Valid Tier values:" }
	for _, info in Economy.Tiers do
		local robux = if info.Robux > 0 then (tostring(info.Robux) .. " R$") else "—"
		table.insert(
			lines,
			string.format(
				"  %d = %s  [%s]  ×%s  / %s",
				info.Tier,
				info.Name,
				info.Rarity,
				tostring(info.Gain),
				robux
			)
		)
	end
	return table.concat(lines, "\n")
end

if script:GetAttribute("Username") == nil then
	script:SetAttribute("Username", "")
end
if script:GetAttribute("Tier") == nil then
	script:SetAttribute("Tier", 1)
end
if script:GetAttribute("Run") == nil then
	script:SetAttribute("Run", false)
end

local function apply()
	if script:GetAttribute("Run") ~= true then
		return
	end
	script:SetAttribute("Run", false)

	local username = script:GetAttribute("Username")
	local tier = script:GetAttribute("Tier")
	if typeof(username) ~= "string" or username == "" then
		warn("[DevSetTreadmill] Set attribute Username to a player name")
		return
	end
	if typeof(tier) ~= "number" or tier ~= tier then
		warn("[DevSetTreadmill] Set attribute Tier to a level number.\n" .. optionsText())
		return
	end
	local level = math.floor(tier)
	if level < 1 or level > #Economy.Tiers then
		warn("[DevSetTreadmill] Tier " .. tostring(tier) .. " is out of range.\n" .. optionsText())
		return
	end

	local player: Player? = nil
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == string.lower(username) then
			player = p
			break
		end
	end
	if not player then
		warn("[DevSetTreadmill] Player not in server: " .. username)
		return
	end

	local ok, message = SpeedData.setTier(player, level)
	local info = Economy.tier(level)
	if ok then
		print(
			"[DevSetTreadmill] "
				.. player.Name
				.. " -> level "
				.. tostring(info.Tier)
				.. " "
				.. info.Name
				.. " ("
				.. message
				.. ")"
		)
	else
		warn("[DevSetTreadmill] Failed: " .. message)
	end
end

script:GetAttributeChangedSignal("Run"):Connect(function()
	if script:GetAttribute("Run") == true then
		task.defer(apply)
	end
end)

-- Also run once on boot if Run was left true.
task.defer(apply)
