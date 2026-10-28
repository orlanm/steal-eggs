--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.RobuxShop
-- Shop popup purchases (ShopConfig): passes bought as Game Passes or gifted to another player with a
-- developer product, vehicles (cash or a developer product), weekly Lucky Eggs and cash packs. ShopServer's ProcessReceipt calls
-- RobuxShop.processReceipt. In Studio, an offer whose dashboard id is still 0 is granted for free so
-- the flow can be tested.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local ShopConfig = require(Shared.ShopConfig)
local GameUI = require(Shared.GameUI)
local Economy = require(Shared.EconomyConfig)
local SpeedData = require(script.Parent.SpeedDataManager)
local EggShop = require(script.Parent.EggShop)

local RobuxShop = {}

type Hooks = { upgradeTreadmill: (Player) -> (boolean, string) }

local started = false
local hooks: Hooks? = nil
local inbox = DataStoreService:GetDataStore("BB_ShopGifts")
local pendingGift: { [number]: { pass: string, to: number, at: number } } = {}
local GIFT_WINDOW = 600 -- seconds a chosen gift recipient is remembered for the receipt

local GOOD = Color3.fromRGB(110, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local GIFT = Color3.fromRGB(214, 140, 255)

local function tell(player: Player, text: string, color: Color3?)
	GameUI.remote("EggAnnouncement"):FireClient(player, { text = text, color = color or GOOD })
end

local function studioFree(id: number): boolean
	return id <= 0 and RunService:IsStudio()
end

local function offer(list: { ShopConfig.Offer }, id: any): ShopConfig.Offer?
	for _, o in list do
		if o.Id == id then
			return o
		end
	end
	return nil
end

local productToGift: { [number]: string } = {}
local productToSelf: { [number]: string } = {}
local productToLucky: { [number]: ShopConfig.Offer } = {}
local productToCash: { [number]: ShopConfig.Offer } = {}
local productToStars: { [number]: ShopConfig.Offer } = {}
local productToVehicle: { [number]: string } = {}
for _, v in ShopConfig.Vehicles do
	if v.ProductId > 0 then
		productToVehicle[v.ProductId] = v.Id
	end
end
for _, o in ShopConfig.StarOffers do
	if o.ProductId > 0 then
		productToStars[o.ProductId] = o
	end
end
for _, pass in ShopConfig.Passes do
	if pass.GiftProductId > 0 then
		productToGift[pass.GiftProductId] = pass.Id
	end
	if pass.SelfProductId > 0 then
		productToSelf[pass.SelfProductId] = pass.Id
	end
end
for _, o in ShopConfig.LuckyOffers do
	if o.ProductId > 0 then
		productToLucky[o.ProductId] = o
	end
end
for _, o in ShopConfig.CashOffers do
	if o.ProductId > 0 then
		productToCash[o.ProductId] = o
	end
end

-- Grants -------------------------------------------------------------------------------------------

local function givePass(to: Player, passId: string, from: Player?)
	local pass = ShopConfig.pass(passId)
	if not pass then
		return
	end
	SpeedData.grantPass(to, passId, true)
	if from and from ~= to then
		tell(to, from.DisplayName .. " gifted you " .. pass.Name .. "!", GIFT)
		tell(from, "You gifted " .. pass.Name .. " to " .. to.DisplayName .. "!", GIFT)
	else
		tell(to, "Unlocked " .. pass.Name .. "!")
	end
end

-- The recipient left: keep the gift in their inbox for their next join.
local function mail(userId: number, passId: string): boolean
	local ok = pcall(function()
		inbox:UpdateAsync("u_" .. userId, function(old)
			local list = if typeof(old) == "table" then old else {}
			table.insert(list, passId)
			return list
		end)
	end)
	return ok
end

local function claimInbox(player: Player)
	local got: { string } = {}
	local ok = pcall(function()
		inbox:UpdateAsync("u_" .. player.UserId, function(old)
			got = if typeof(old) == "table" then old else {}
			return if #got > 0 then {} else nil
		end)
	end)
	if not ok then
		return
	end
	for _, passId in got do
		if typeof(passId) == "string" and ShopConfig.pass(passId) then
			SpeedData.grantPass(player, passId, true)
			tell(player, "Someone gifted you " .. (ShopConfig.pass(passId) :: ShopConfig.Pass).Name .. "!", GIFT)
		end
	end
end

local function giftReceipt(buyer: Player, passId: string): boolean
	local pending = pendingGift[buyer.UserId]
	pendingGift[buyer.UserId] = nil
	if not pending or pending.pass ~= passId then
		-- recipient forgotten (server restarted): the buyer keeps it
		givePass(buyer, passId, nil)
		return true
	end
	local to = Players:GetPlayerByUserId(pending.to)
	if to then
		givePass(to, passId, buyer)
		return true
	end
	if mail(pending.to, passId) then
		local pass = ShopConfig.pass(passId) :: ShopConfig.Pass
		tell(buyer, "Gift sent! " .. pass.Name .. " is waiting for them next time they join.", GIFT)
		return true
	end
	pendingGift[buyer.UserId] = pending
	return false
end

local function giveLucky(player: Player, o: ShopConfig.Offer)
	SpeedData.takeLucky(player, o.Amount)
	local names = EggShop.give(player, ShopConfig.LuckyEgg, o.Amount, "Lucky")
	tell(player, "Lucky Egg: " .. EggShop.summary(names) .. "!", Color3.fromRGB(255, 214, 90))
end

local function giveCash(player: Player, o: ShopConfig.Offer)
	local income = player:GetAttribute("PenIncome")
	local amount = ShopConfig.cashFor(o, if typeof(income) == "number" then income else 0)
	SpeedData.addCash(player, amount)
	tell(player, "+" .. Economy.formatCash(amount) .. " Cash!")
end

-- Boats.server gives the hotbar Tool when the OwnsBoat attribute turns on.
local function giveVehicle(player: Player, vehicleId: string)
	local vehicle = ShopConfig.vehicle(vehicleId)
	if vehicle and SpeedData.grantPass(player, vehicle.Id, true) then
		tell(player, "You got the " .. vehicle.Name .. "! Equip it from your hotbar while in the water.")
	end
end

-- Requests ---------------------------------------------------------------------------------------

local function buyPass(player: Player, passId: any)
	local pass = ShopConfig.pass(passId)
	if not pass then
		return
	end
	if SpeedData.hasPass(player, pass.Id) then
		tell(player, "You already own " .. pass.Name, BAD)
	elseif pass.GamePassId > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	elseif pass.SelfProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, pass.SelfProductId)
	elseif studioFree(pass.SelfProductId) then
		givePass(player, pass.Id, nil)
	else
		tell(player, pass.Name .. " is not on sale yet", BAD)
	end
end

local function giftPass(player: Player, passId: any, userId: any)
	local pass = ShopConfig.pass(passId)
	local to = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if not pass then
		return
	end
	if not to or to == player then
		tell(player, "Pick a player in this server to gift", BAD)
		return
	end
	if SpeedData.hasPass(to, pass.Id) then
		tell(player, to.DisplayName .. " already owns " .. pass.Name, BAD)
		return
	end
	if pass.GiftProductId > 0 then
		pendingGift[player.UserId] = { pass = pass.Id, to = to.UserId, at = os.clock() }
		MarketplaceService:PromptProductPurchase(player, pass.GiftProductId)
	elseif studioFree(pass.GiftProductId) then
		givePass(to, pass.Id, player)
	else
		tell(player, "Gifting " .. pass.Name .. " is not on sale yet", BAD)
	end
end

local function buyLucky(player: Player, offerId: any)
	local o = offer(ShopConfig.LuckyOffers, offerId)
	if not o then
		return
	end
	local left = SpeedData.luckyLeft(player)
	if left < o.Amount then
		local wait = ShopConfig.formatLeft(ShopConfig.restockAt(os.time()) - os.time())
		tell(player, (if left == 0 then "Sold out!" else "Only " .. left .. " left this week.") .. " Restocks in " .. wait, BAD)
	elseif o.ProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, o.ProductId)
	elseif studioFree(o.ProductId) then
		giveLucky(player, o)
	else
		tell(player, "Lucky Eggs are not on sale yet", BAD)
	end
end

local function giveStars(player: Player, o: ShopConfig.Offer): boolean
	if not SpeedData.addStars(player, o.Amount, true) then
		return false
	end
	tell(player, string.format("+%d Mount Star%s! Hold it near a pet in your pen to feed it.", o.Amount, if o.Amount == 1 then "" else "s"), Color3.fromRGB(255, 214, 90))
	return true
end

local function buyStars(player: Player, offerId: any)
	local o = offer(ShopConfig.StarOffers, offerId)
	if not o then
		return
	end
	local left = SpeedData.starsLeft(player)
	if left < o.Amount then
		local wait = ShopConfig.formatLeft(ShopConfig.restockAt(os.time()) - os.time())
		tell(player, (if left == 0 then "No more stock!" else "Only " .. left .. " Stars left this week!") .. " Restocks in " .. wait, BAD)
	elseif o.ProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, o.ProductId)
	elseif studioFree(o.ProductId) then
		giveStars(player, o)
	else
		tell(player, "Mount Stars are not on sale yet", BAD)
	end
end

local function buyCash(player: Player, offerId: any)
	local o = offer(ShopConfig.CashOffers, offerId)
	if not o then
		return
	end
	if o.ProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, o.ProductId)
	elseif studioFree(o.ProductId) then
		giveCash(player, o)
	else
		tell(player, "Cash packs are not on sale yet", BAD)
	end
end

-- withCash: pay the cash price, otherwise prompt the Robux developer product.
local function buyVehicle(player: Player, vehicleId: any, withCash: any)
	local vehicle = ShopConfig.vehicle(vehicleId)
	if not vehicle then
		return
	end
	if SpeedData.hasPass(player, vehicle.Id) then
		tell(player, "You already own the " .. vehicle.Name, BAD)
	elseif withCash == true then
		if SpeedData.trySpend(player, vehicle.Cash) then
			giveVehicle(player, vehicle.Id)
		else
			tell(player, "Need " .. Economy.formatCash(vehicle.Cash) .. " cash for the " .. vehicle.Name, BAD)
		end
	elseif vehicle.ProductId > 0 then
		MarketplaceService:PromptProductPurchase(player, vehicle.ProductId)
	elseif studioFree(vehicle.ProductId) then
		giveVehicle(player, vehicle.Id)
	else
		tell(player, vehicle.Name .. " is not on sale yet", BAD)
	end
end

-- Called from ShopServer's single ProcessReceipt. Nil when the product is not a shop product.
function RobuxShop.processReceipt(player: Player, receipt: any): Enum.ProductPurchaseDecision?
	local id = receipt.ProductId
	local passId = productToGift[id]
	local selfPass = productToSelf[id]
	local lucky = productToLucky[id]
	local cash = productToCash[id]
	local stars = productToStars[id]
	local vehicle = productToVehicle[id]
	if not (passId or selfPass or lucky or cash or stars or vehicle) then
		return nil
	end
	if not SpeedData.isReady(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if passId then
		if not giftReceipt(player, passId) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	elseif selfPass then
		givePass(player, selfPass, nil)
	elseif lucky then
		local character = player.Character
		if not (character and character:FindFirstChildOfClass("Humanoid") and player:FindFirstChild("Backpack")) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		giveLucky(player, lucky)
	elseif cash then
		giveCash(player, cash)
	elseif stars then
		if not giveStars(player, stars) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	elseif vehicle then
		giveVehicle(player, vehicle)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkGamePasses(player: Player)
	local deadline = os.clock() + 60
	while player.Parent and not SpeedData.isReady(player) and os.clock() < deadline do
		task.wait(0.5)
	end
	if not player.Parent then
		return
	end
	for _, pass in ShopConfig.Passes do
		if pass.GamePassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			if ok and owns then
				SpeedData.grantPass(player, pass.Id, false)
			end
		end
	end
	claimInbox(player)
end

function RobuxShop.start(given: Hooks)
	if started then
		return
	end
	started = true
	hooks = given
	GameUI.remote("ShopBuy").OnServerEvent:Connect(function(player: Player, kind: any, id: any, extra: any)
		if kind == "Pass" then
			buyPass(player, id)
		elseif kind == "Gift" then
			giftPass(player, id, extra)
		elseif kind == "Lucky" then
			buyLucky(player, id)
		elseif kind == "Cash" then
			buyCash(player, id)
		elseif kind == "Stars" then
			buyStars(player, id)
		elseif kind == "Vehicle" then
			buyVehicle(player, id, extra)
		elseif kind == "Treadmill" and hooks then
			local ok, message = hooks.upgradeTreadmill(player)
			if ok then
				tell(player, message)
			elseif not string.find(message, "^Need") then
				tell(player, message, BAD)
			end
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, purchased: boolean)
		if not purchased then
			return
		end
		for _, pass in ShopConfig.Passes do
			if pass.GamePassId == gamePassId then
				SpeedData.grantPass(player, pass.Id, false)
				tell(player, "Unlocked " .. pass.Name .. "!")
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkGamePasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkGamePasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local pending = pendingGift[player.UserId]
		if pending and os.clock() - pending.at > GIFT_WINDOW then
			pendingGift[player.UserId] = nil
		end
	end)
end

return RobuxShop
