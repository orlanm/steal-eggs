--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.KnockdownVfx
-- Plays the knockdown effects the server asks for (server Knockdown -> KnockdownVfx remote).
local Shared = game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local GameUI = require(Shared:WaitForChild("GameUI"))
local KnockdownVfx = require(Shared:WaitForChild("KnockdownVfx"))

GameUI.remote("KnockdownVfx").OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "Impact" and typeof(a) == "Vector3" then
		KnockdownVfx.impact(a)
	elseif kind == "Landing" and typeof(a) == "Vector3" then
		KnockdownVfx.landing(a)
	elseif kind == "Dizzy" and typeof(a) == "Instance" and a:IsA("Model") then
		KnockdownVfx.dizzy(a, if typeof(b) == "number" then b else 2)
	elseif kind == "DizzyStop" and typeof(a) == "Instance" and a:IsA("Model") then
		KnockdownVfx.dizzyStop(a)
	end
end)
