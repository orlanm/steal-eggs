--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.ShopServer
-- Cash purchases and Robux developer products for trails, treadmill tiers and Limited eggs.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.BabyBeastsShared.EconomyConfig)
local ProductIds = require(ReplicatedStorage.BabyBeastsShared.TrailProductIds)
local TreadmillProductIds = require(ReplicatedStorage.BabyBeastsShared.TreadmillProductIds)
local SpeedData = require(script.Parent.SpeedDataManager)
local EggShop = require(script.Parent.EggShop)
local RobuxShop = require(script.Parent.RobuxShop)
local PenPets = require(script.Parent.PenPets)

local Shop = {}
local started = false

local productToTrail: { [number]: string } = {}
for id, productId in ProductIds do
	if typeof(productId) == "number" and productId > 0 then
		productToTrail[productId] = id
	end
end

local productToTier: { [number]: number } = {}
for tier, productId in TreadmillProductIds do
	if typeof(productId) == "number" and productId > 0 then
		productToTier[productId] = tier
	end
end

local function sharedFolder(): Folder
	local shared = ReplicatedStorage:WaitForChild("BabyBeastsShared")
	local folder = shared:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end
	return folder :: Folder
end

local function remote(name: string): RemoteEvent
	local folder = sharedFolder()
	local event = folder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	return event :: RemoteEvent
end

local function tell(player: Player, ok: boolean, message: string, action: string, trailId: string?)
	remote("TrailShopResult"):FireClient(player, {
		Ok = ok,
		Message = message,
		Action = action,
		TrailId = trailId or "",
	})
end

function Shop.buyTier(player: Player): (boolean, string)
	local ok, message = SpeedData.buyTier(player)
	tell(player, ok, message, "Tier", nil)
	return ok, message
end

-- Cash if the player can afford it; otherwise prompt the matching Robux product
-- (or toast when neither cash nor a dashboard product is available).
function Shop.upgradeTreadmill(player: Player): (boolean, string)
	if not SpeedData.isReady(player) then
		tell(player, false, "Speed is still loading", "Tier", nil)
		return false, "Speed is still loading"
	end
	local tier = player:GetAttribute("TreadmillTier")
	if typeof(tier) ~= "number" then
		tier = 1
	end
	local nextTier = Economy.nextTier(tier)
	if not nextTier then
		tell(player, false, "Treadmill is fully upgraded", "Tier", nil)
		return false, "Treadmill is fully upgraded"
	end
	local cash = player:GetAttribute("Cash")
	if typeof(cash) ~= "number" then
		cash = 0
	end
	if cash + 1e-6 >= nextTier.Cost then
		return Shop.buyTier(player)
	end
	local productId = TreadmillProductIds[nextTier.Tier]
	local need = "Need "
		.. Economy.formatCash(nextTier.Cost)
		.. (if nextTier.Robux > 0 then (" or " .. tostring(nextTier.Robux) .. " Robux") else "")
	if typeof(productId) == "number" and productId > 0 then
		tell(player, false, need, "Tier", nil)
		MarketplaceService:PromptProductPurchase(player, productId)
		return false, need
	end
	tell(player, false, need, "Tier", nil)
	return false, need
end

function Shop.start()
	if started then
		return
	end
	started = true
	local buyTrail = remote("BuyTrail")
	local equipTrail = remote("EquipTrail")
	local buyTier = remote("BuyTreadmillTier")
	local upgradeTreadmill = remote("UpgradeTreadmill")
	local promptRobux = remote("PromptTrailRobux")
	remote("TrailShopResult")
	RobuxShop.start({ upgradeTreadmill = Shop.upgradeTreadmill })

	buyTrail.OnServerEvent:Connect(function(player: Player, trailId: any)
		if typeof(trailId) ~= "string" then
			return
		end
		local ok, message = SpeedData.buyTrail(player, trailId)
		tell(player, ok, message, "Buy", trailId)
	end)
	equipTrail.OnServerEvent:Connect(function(player: Player, trailId: any)
		if typeof(trailId) ~= "string" then
			return
		end
		local ok, message = SpeedData.equipTrail(player, trailId)
		tell(player, ok, message, "Equip", trailId)
	end)
	buyTier.OnServerEvent:Connect(function(player: Player)
		Shop.buyTier(player)
	end)
	upgradeTreadmill.OnServerEvent:Connect(function(player: Player)
		if player:GetAttribute("TrainingTreadmill") == nil then
			tell(player, false, "Step on your treadmill to upgrade", "Tier", nil)
			return
		end
		Shop.upgradeTreadmill(player)
	end)
	promptRobux.OnServerEvent:Connect(function(player: Player, trailId: any)
		if typeof(trailId) ~= "string" then
			return
		end
		local trail = Economy.trail(trailId)
		local productId = ProductIds[trailId]
		if not trail or trail.Robux <= 0 or typeof(productId) ~= "number" or productId <= 0 then
			tell(player, false, "Robux product is not on the dashboard yet", "Robux", trailId)
			return
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end)

	-- Single ProcessReceipt for trails, treadmill tiers and Limited eggs (do not add a second handler).
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local eggDecision = EggShop.processReceipt(player, receipt)
		if eggDecision then
			return eggDecision
		end
		local shopDecision = RobuxShop.processReceipt(player, receipt)
		if shopDecision then
			return shopDecision
		end
		local penDecision = PenPets.processReceipt(player, receipt)
		if penDecision then
			return penDecision
		end
		local trailId = productToTrail[receipt.ProductId]
		if trailId then
			local ok = SpeedData.grantTrail(player, trailId)
			if not ok then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local trail = Economy.trail(trailId)
			tell(player, true, "Unlocked " .. (trail and trail.Name or "trail"), "Robux", trailId)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local targetTier = productToTier[receipt.ProductId]
		if targetTier then
			local ok, message = SpeedData.grantTier(player, targetTier)
			if not ok then
				tell(player, false, message, "Tier", nil)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			tell(player, true, message, "Tier", nil)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Shop
