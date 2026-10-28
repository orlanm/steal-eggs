--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.PenPets
-- Server side of the left-side pen panels (PenPanels.client):
--   PenPets remote:     Unequip(model) -> held pet Tool / Hold(id) a backpack pet / Place(point) it /
--                       EquipBest / BuySlot (+1 EQUIP, cash)
--   GrowingEggs remote: Open(model) / Skip(model) / GrowAll — Skip and Grow All are developer
--                       products (PenConfig); ShopServer's single ProcessReceipt calls processReceipt.
-- In Studio a product whose dashboard id is still 0 is granted for free so the flow can be tested.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local GameUI = require(Shared.GameUI)
local PenConfig = require(Shared.PenConfig)
local SpeedData = require(script.Parent.SpeedDataManager)
local TankBeasts = require(script.Parent.TankBeasts)

local PenPets = {}

local GOOD = Color3.fromRGB(110, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)

local started = false
local lastBest: { [Player]: number } = {}
local pendingSkip: { [number]: Instance } = {} -- userId -> egg model chosen for the Skip being bought

local productToSkip: { [number]: boolean } = {}
for _, tier in PenConfig.SkipTiers do
	if tier.ProductId > 0 then
		productToSkip[tier.ProductId] = true
	end
end

local function tell(player: Player, text: string, color: Color3?)
	GameUI.remote("EggAnnouncement"):FireClient(player, { text = text, color = color or GOOD, small = true })
end

local function studioFree(id: number): boolean
	return id <= 0 and RunService:IsStudio()
end

local function growAll(player: Player): number
	local count = 0
	for _, model in TankBeasts.growing(player.UserId) do
		if TankBeasts.finishGrowing(player.UserId, model) then
			count += 1
		end
	end
	return count
end

-- A paid Skip: the chosen egg, or (if it hatched meanwhile) the egg with the most time left.
local function skipOne(player: Player): boolean
	local chosen = pendingSkip[player.UserId]
	pendingSkip[player.UserId] = nil
	if chosen and TankBeasts.finishGrowing(player.UserId, chosen) then
		return true
	end
	local best: Model? = nil
	local bestLeft = -1
	for _, model in TankBeasts.growing(player.UserId) do
		local left = TankBeasts.growLeft(player.UserId, model) or 0
		if left > bestLeft then
			best, bestLeft = model, left
		end
	end
	return best ~= nil and TankBeasts.finishGrowing(player.UserId, best)
end

-- Pet actions answer through the Pets panel itself (rows, badges, the held pet), never with toasts.
local function onPets(player: Player, action: any, arg: any)
	if action == "Unequip" then
		TankBeasts.unequip(player, arg)
	elseif action == "Hold" then
		TankBeasts.hold(player, arg)
	elseif action == "Place" then
		TankBeasts.placeHeld(player, arg)
	elseif action == "EquipBest" then
		local now = os.clock()
		if lastBest[player] and now - lastBest[player] < PenConfig.EquipBestCooldown then
			return
		end
		lastBest[player] = now
		TankBeasts.equipBest(player)
	elseif action == "BuySlot" then
		SpeedData.buyEquipSlot(player)
	end
end

local function onEggs(player: Player, action: any, arg: any)
	if action == "Open" then
		TankBeasts.openEgg(player, arg)
	elseif action == "GrowAll" then
		if #TankBeasts.growing(player.UserId) == 0 then
			tell(player, "You have no growing eggs!", BAD)
		elseif PenConfig.GrowAll.ProductId > 0 then
			MarketplaceService:PromptProductPurchase(player, PenConfig.GrowAll.ProductId)
		elseif studioFree(PenConfig.GrowAll.ProductId) then
			tell(player, "Grew " .. growAll(player) .. " eggs! (Studio: free)")
		else
			tell(player, "Grow All is not on sale yet", BAD)
		end
	elseif action == "Skip" then
		local left = TankBeasts.growLeft(player.UserId, arg)
		if not left then
			return
		end
		if left <= PenConfig.MinSkipSeconds then
			tell(player, "This egg is almost ready!", BAD)
			return
		end
		local tier = PenConfig.skipTier(left)
		if tier.ProductId > 0 then
			pendingSkip[player.UserId] = arg
			MarketplaceService:PromptProductPurchase(player, tier.ProductId)
		elseif studioFree(tier.ProductId) then
			TankBeasts.finishGrowing(player.UserId, arg)
			tell(player, "Egg is ready! (Studio: free)")
		else
			tell(player, "Skipping is not on sale yet", BAD)
		end
	end
end

-- Called from ShopServer's single ProcessReceipt. Nil when the product is not a pen product.
function PenPets.processReceipt(player: Player, receipt: any): Enum.ProductPurchaseDecision?
	local id = receipt.ProductId
	local mine = (id == PenConfig.GrowAll.ProductId and id > 0) or productToSkip[id]
	if not mine then
		return nil
	end
	-- the pen comes back from the save first (BeastData)
	if player:GetAttribute("BeastsLoaded") ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if id == PenConfig.GrowAll.ProductId then
		local count = growAll(player)
		tell(player, if count > 0 then "All " .. count .. " eggs are ready to open!" else "Your eggs were already grown!")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif productToSkip[id] then
		tell(player, if skipOne(player) then "Your egg is ready to open!" else "Your eggs were already grown!")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return nil
end

function PenPets.start()
	if started then
		return
	end
	started = true
	GameUI.remote("PenPets").OnServerEvent:Connect(onPets)
	GameUI.remote("GrowingEggs").OnServerEvent:Connect(onEggs)
	GameUI.remote("EggAnnouncement")
	Players.PlayerRemoving:Connect(function(player)
		lastBest[player] = nil
		pendingSkip[player.UserId] = nil
	end)
end

return PenPets
