--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.EggShop
-- Eggs that do not come from biome nests, as in Steal an Egg (see EggSources):
--   Shop     - restock rotation, cash. Same stock on every server; per-player stock per window.
--   Event    - the live event's egg (Halloween Dimension Egg...) for cash until the event ends.
--   Limited  - Robux offers x1/x3/x10/x50 until EndsAt, then vaulted.
--   Trade-In - Dr. Scramble's machine: the three recipe pets from your pen for a banner egg.
-- Two stands in the plaza open it (EggShopPrompt / TradeInPrompt).

local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local EggSources = require(Shared.EggSources)
local EggProductIds = require(Shared.EggProductIds)
local GameEgg = require(Shared.GameEgg)
local GameUI = require(Shared.GameUI)
local SpeedData = require(script.Parent.SpeedDataManager)
local TankBeasts = require(script.Parent.TankBeasts)
local CaveBubbles = require(script.Parent.CaveBubbles)

local EggShop = {}
local started = false

-- bought[userId]["<restock index>:<slot>"] = count
local bought: { [number]: { [string]: number } } = {}
local busy: { [Player]: boolean } = {}

local productToOffer: { [number]: { limited: string, amount: number } } = {}
for limitedId, offers in EggProductIds do
	for amount, productId in offers do
		if typeof(productId) == "number" and productId > 0 then
			productToOffer[productId] = { limited = limitedId, amount = amount }
		end
	end
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function drops(name: string): { any }
	local container = EggSources.container(name)
	if not container then
		return {}
	end
	local list = {}
	for _, row in container.DropTable do
		table.insert(list, { name = row[1], chance = EggSources.chance(container.DropTable, row[1]) })
	end
	return list
end

local function limitedById(id: string): EggSources.Limited?
	for _, limited in EggSources.Limited do
		if limited.Id == id then
			return limited
		end
	end
	return nil
end

-- Grant a shop egg (container eggs roll their drop table first). Returns the egg names granted.
local function give(player: Player, name: string, count: number, source: string): { string }
	local rng = Random.new()
	local names = {}
	for _ = 1, count do
		local eggName = EggSources.open(name, rng)
		if CaveBubbles.grant(player, eggName, { source = source }) then
			table.insert(names, eggName)
		end
	end
	return names
end
EggShop.give = give

local function summary(names: { string }): string
	if #names == 1 then
		return names[1]
	end
	local counts: { [string]: number } = {}
	local order = {}
	for _, name in names do
		if not counts[name] then
			table.insert(order, name)
		end
		counts[name] = (counts[name] or 0) + 1
	end
	local parts = {}
	for _, name in order do
		table.insert(parts, if counts[name] > 1 then name .. " x" .. counts[name] else name)
	end
	return table.concat(parts, ", ")
end
EggShop.summary = summary

local function penCounts(player: Player): { [string]: number }
	local counts = {}
	for _, row in TankBeasts.species(player.UserId) do
		counts[row.Name] = row.Count
	end
	return counts
end

local function state(player: Player)
	local t = now()
	local index = EggSources.restockIndex(t)
	local mine = bought[player.UserId] or {}
	local offers = {}
	for _, offer in EggSources.shopStock(index) do
		local used = mine[index .. ":" .. offer.Slot] or 0
		table.insert(offers, {
			slot = offer.Slot,
			name = offer.Name,
			model = if offer.IsContainer then (EggSources.container(offer.Name) :: any).Model else offer.Name,
			container = offer.IsContainer,
			price = offer.Price,
			left = math.max(offer.Stock - used, 0),
			stock = offer.Stock,
			rare = offer.Rare,
			category = EggSources.category(offer.Name),
			drops = drops(offer.Name),
		})
	end
	local events = {}
	for _, event in EggSources.liveEvents(os.time()) do
		local container = EggSources.container(event.Container)
		table.insert(events, {
			id = event.Id,
			name = event.DisplayName,
			endsAt = event.EndsAt,
			egg = event.Container,
			model = container and container.Model or event.Container,
			price = EggSources.price(event.Container),
			color = event.Color,
			drops = drops(event.Container),
			hosts = event.HostBiomes,
		})
	end
	local limited = {}
	for _, item in EggSources.Limited do
		local container = EggSources.container(item.Container)
		local offerRows = {}
		for _, amount in item.Offers do
			local ids = EggProductIds[item.Id]
			local productId = ids and ids[amount] or 0
			table.insert(offerRows, { amount = amount, robux = item.RobuxPerEgg * amount, ready = productId > 0 })
		end
		table.insert(limited, {
			id = item.Id,
			model = container and container.Model or item.Container,
			endsAt = item.EndsAt,
			live = EggSources.limitedLive(item, os.time()),
			offers = offerRows,
			drops = drops(item.Container),
		})
	end
	local recipe = EggSources.recipe(EggSources.recipeIndex(t))
	local have = penCounts(player)
	local recipeRows = {}
	for _, pet in recipe.Pets do
		table.insert(recipeRows, { name = pet, have = have[pet] or 0 })
	end
	return {
		now = t,
		cash = SpeedData.cash(player),
		restockAt = EggSources.restockAt(index),
		offers = offers,
		events = events,
		limited = limited,
		trade = {
			banner = recipe.Banner,
			model = (EggSources.container(recipe.Banner) :: any).Model,
			pets = recipeRows,
			endsAt = recipe.EndsAt,
			drops = drops(recipe.Banner),
		},
	}
end

local function buyStock(player: Player, slot: number): (boolean, string)
	local index = EggSources.restockIndex(now())
	local offer = nil
	for _, row in EggSources.shopStock(index) do
		if row.Slot == slot then
			offer = row
		end
	end
	if not offer then
		return false, "That egg is no longer in stock"
	end
	local mine = bought[player.UserId]
	if not mine then
		mine = {}
		bought[player.UserId] = mine
	end
	local key = index .. ":" .. slot
	if (mine[key] or 0) >= offer.Stock then
		return false, "Sold out. Check the restock timer!"
	end
	if not SpeedData.trySpend(player, offer.Price) then
		return false, "Not enough cash"
	end
	mine[key] = (mine[key] or 0) + 1
	local names = give(player, offer.Name, 1, "Shop")
	return true, "Bought " .. summary(names)
end

local function buyEvent(player: Player, eventId: string): (boolean, string)
	local event = EggSources.Events[eventId]
	if not event or not EggSources.eventLive(eventId, os.time()) then
		return false, "That event has ended. Its eggs are vaulted."
	end
	local price = EggSources.price(event.Container)
	if not SpeedData.trySpend(player, price) then
		return false, "Not enough cash"
	end
	local names = give(player, event.Container, 1, "Event")
	return true, "Hatched from " .. event.Container .. ": " .. summary(names)
end

local function promptLimited(player: Player, limitedId: string, amount: number): (boolean, string)
	local item = limitedById(limitedId)
	if not item then
		return false, "Unknown egg"
	end
	if not EggSources.limitedLive(item, os.time()) then
		return false, item.Id .. " is vaulted"
	end
	local ids = EggProductIds[item.Id]
	local productId = ids and ids[amount]
	if typeof(productId) ~= "number" or productId <= 0 then
		return false, "Robux product is not on the dashboard yet"
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true, "Opening purchase..."
end

local function trade(player: Player): (boolean, string)
	local recipe = EggSources.recipe(EggSources.recipeIndex(now()))
	local have = penCounts(player)
	for _, pet in recipe.Pets do
		if (have[pet] or 0) < 1 then
			return false, "You need a " .. pet .. " in your pen"
		end
	end
	local taken = {}
	for _, pet in recipe.Pets do
		local ok = TankBeasts.take(player.UserId, pet, 1)
		if not ok then
			-- someone else's action raced us; hand back what we took as fresh eggs
			for _, back in taken do
				CaveBubbles.grant(player, back, { source = "Biome" })
			end
			return false, pet .. " is no longer in your pen"
		end
		table.insert(taken, pet)
	end
	local names = give(player, recipe.Banner, 1, "TradeIn")
	return true, "Traded in for " .. summary(names)
end

-- Called from ShopServer's single ProcessReceipt. Nil when the product is not an egg.
function EggShop.processReceipt(player: Player, receipt: any): Enum.ProductPurchaseDecision?
	local offer = productToOffer[receipt.ProductId]
	if not offer then
		return nil
	end
	local item = limitedById(offer.limited)
	if not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local character = player.Character
	if not (character and character:FindFirstChildOfClass("Humanoid") and player:FindFirstChild("Backpack")) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- paid is paid: grant even if the window closed between prompt and receipt
	local names = give(player, item.Container, offer.amount, "Limited")
	GameUI.remote("EggAnnouncement"):FireClient(player, {
		text = "Got " .. summary(names),
		color = Color3.fromRGB(255, 214, 90),
	})
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Stands -----------------------------------------------------------------------------------------

local function floorY(x: number, z: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else 0
end

local function stand(parent: Instance, name: string, title: string, color: Color3, at: Vector3, promptName: string, action: string)
 local templates=game.ServerStorage:WaitForChild("codex_PlazaStallTemplates")
 local source=templates:FindFirstChild(if name=="TradeInStand" then "TradeWorkshop" else "EggBoutique")
 assert(source,"Missing saved plaza stall template")
 local model=source:Clone();model.Name=name
 -- Ground pivot and front face point towards the plaza pathway.
 model:PivotTo(CFrame.new(at)*CFrame.Angles(0,-math.pi/2,0))
 local base=Instance.new("Part");base.Name="Interaction";base.Size=Vector3.new(12,4,3);base.Transparency=1;base.Anchored=true;base.CanCollide=true;base.CanTouch=false
 base.CFrame=model:GetPivot()*CFrame.new(0,2,-1.7);base.Parent=model
 local prompt=Instance.new("ProximityPrompt");prompt.Name=promptName;prompt.ActionText=action;prompt.ObjectText=title;prompt.HoldDuration=0;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.Parent=base
 model:SetAttribute("BlenderStallVersion",1);model.Parent=parent
 return model
end

local function remoteFunction(name: string): RemoteFunction
	local existing = Shared:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = Shared
	return created
end

-- Where admin drops land (left of the plaza road; no floor marker). Also used by AdminEggs.
function EggShop.dropPoint(): Vector3
	local pad = Workspace:FindFirstChild("AdminEggDrop", true)
	if pad and pad:IsA("BasePart") then
		return pad.Position + Vector3.new(0, pad.Size.Y * 0.5, 0)
	end
	return Vector3.new(-30, 0, 564)
end

function EggShop.start(root: Instance)
	if started then
		return
	end
	started = true
	GameUI.remote("EggAnnouncement")
	local stateRemote = remoteFunction("EggShopState")
	local buyRemote = remoteFunction("EggShopBuy")
	stateRemote.OnServerInvoke = function(player)
		return state(player)
	end
	buyRemote.OnServerInvoke = function(player, kind: any, id: any, amount: any)
		if busy[player] then
			return { ok = false, message = "One moment...", state = state(player) }
		end
		if not SpeedData.isReady(player) then
			return { ok = false, message = "Cash is still loading", state = state(player) }
		end
		busy[player] = true
		local ok, message = false, "Unknown request"
		local success, err = pcall(function()
			if kind == "Stock" and typeof(id) == "number" then
				ok, message = buyStock(player, id)
			elseif kind == "Event" and typeof(id) == "string" then
				ok, message = buyEvent(player, id)
			elseif kind == "Limited" and typeof(id) == "string" and typeof(amount) == "number" then
				ok, message = promptLimited(player, id, amount)
			elseif kind == "Trade" then
				ok, message = trade(player)
			end
		end)
		busy[player] = nil
		if not success then
			warn("[EggShop] " .. tostring(err))
			ok, message = false, "Something went wrong"
		end
		return { ok = ok, message = message, state = state(player) }
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = habitats and habitats:FindFirstChild("Zone00") or root:FindFirstChild("Zone00")
	if zone then
		for _, name in { "EggShopStand", "TradeInStand", "AdminEggDrop" } do
			local old = zone:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		-- The Egg Shop and Dr. Scramble Trade-In stalls were removed from the plaza (2026-10-27).
		-- To bring them back:
		-- stand(zone, "EggShopStand", "EGG SHOP", Color3.fromRGB(255, 196, 64), Vector3.new(-62, floorY(-62, 527, {}), 527), "EggShopPrompt", "Shop")
		-- stand(zone, "TradeInStand", "DR. SCRAMBLE TRADE-IN", Color3.fromRGB(110, 255, 150), Vector3.new(-62, floorY(-62, 601, {}), 601), "TradeInPrompt", "Trade")
	end
	-- container cards draw this egg; flag any that has no model
	for _, container in EggSources.Containers do
		if not GameEgg.get(container.Model) then
			warn("[EggShop] no egg model for " .. container.Id .. " (" .. container.Model .. ")")
		end
	end
	print("[BabyBeasts] Egg shop ready: rotation, events, limited, trade-in")
end

return EggShop
