--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.FuseService
-- Steal an Egg fuse: three of the same pet in your tank become one egg of that pet.
-- The egg is a fresh one. Cash scales with the pet's income. There is no cooldown.

local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Build = require(script.Parent.FuseMachineBuild)
local TankBeasts = require(script.Parent.TankBeasts)
local SpeedData = require(script.Parent.SpeedDataManager)
local CaveBubbles = require(script.Parent.CaveBubbles)

local Service = {}
local NEEDED = 3

local function feeFor(income: number): number
	return math.max(25, math.floor(income * 15))
end

local function findZone(root: Instance): Instance?
	local habitats = root:FindFirstChild("BeastHabitats")
	local zone = habitats and habitats:FindFirstChild("Zone00")
	if zone then
		return zone
	end
	return root:FindFirstChild("Zone00")
end

local function roster(player: Player)
	local rows = {}
	for _, row in TankBeasts.species(player.UserId) do
		table.insert(rows, {
			name = row.Name,
			count = row.Count,
			fee = feeFor(row.Income),
			ready = row.Count >= NEEDED,
		})
	end
	return {
		cash = SpeedData.cash(player),
		rows = rows,
	}
end

local function commit(player: Player, eggName: any): (boolean, string)
	if typeof(eggName) ~= "string" or eggName == "" then
		return false, "Pick a pet"
	end
	if not SpeedData.isReady(player) then
		return false, "Cash is still loading"
	end
	local chosen = nil
	for _, row in TankBeasts.species(player.UserId) do
		if row.Name == eggName then
			chosen = row
			break
		end
	end
	if not chosen or chosen.Count < NEEDED then
		return false, "Bring 3 of the same pet. They have to be in your tank."
	end
	local price = feeFor(chosen.Income)
	if not SpeedData.trySpend(player, price) then
		return false, "Not enough cash"
	end
	local took = TankBeasts.take(player.UserId, eggName, NEEDED)
	if not took then
		SpeedData.addCash(player, price)
		return false, "Those pets are no longer in your tank"
	end
	CaveBubbles.grant(player, eggName)
	return true, "Fused a " .. eggName
end

local function remote(name: string, className: string): Instance
	local shared = game.ReplicatedStorage:FindFirstChild("BabyBeastsShared") or game.ReplicatedStorage
	local existing = shared:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = shared
	return created
end

function Service.start(root: Instance)
	local list = remote("FuseRoster", "RemoteFunction")
	local fuse = remote("FuseCommit", "RemoteFunction")
	-- Edit has no server, so the saved place keeps the machine and Play binds these.
	if list:IsA("RemoteFunction") then
		pcall(function()
			list.OnServerInvoke = function(player)
				return roster(player)
			end
		end)
	end
	if fuse:IsA("RemoteFunction") then
		pcall(function()
			fuse.OnServerInvoke = function(player, eggName)
				local ok, message = commit(player, eggName)
				return {
					ok = ok,
					message = message,
					cash = SpeedData.cash(player),
					rows = roster(player).rows,
				}
			end
		end)
	end

	local zone = findZone(root)
	if zone then
		local prism = zone:FindFirstChild("PrismFusion")
		if prism then
			prism:Destroy()
		end
		-- Plaza uses the Blender three-pod FuseMachine (KeepFinish). Never rebuild the Steal an Egg mesh over it.
		local old = zone:FindFirstChild("FuseMachine")
		if old and old:GetAttribute("KeepFinish") == true then
			if not old:FindFirstChild("FusePrompt", true) then
				local host = old:FindFirstChild("FuseFloorPad") or old.PrimaryPart or old:FindFirstChildWhichIsA("BasePart", true)
				if host then
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "FusePrompt"
					prompt.ActionText = "Fuse"
					prompt.ObjectText = "Fuse Machine"
					prompt.MaxActivationDistance = 18
					prompt.RequiresLineOfSight = false
					prompt.HoldDuration = 0
					prompt.Parent = host
				end
			end
			return
		end
		local needsBuild = not old
			or old:GetAttribute("BuildScale") ~= Build.SCALE
			or not old:FindFirstChildWhichIsA("MeshPart", true)
		if needsBuild then
			if old then
				old:Destroy()
			end
			local startZ = zone:GetAttribute("StartZ")
			local length = zone:GetAttribute("ZoneLength")
			if typeof(startZ) == "number" and typeof(length) == "number" then
				local Catalog = require(game.ReplicatedStorage.BabyBeastsShared.FuseMachine)
				local x = MapConfig.RoadWidth / 2 - Catalog.Size.X * Build.SCALE * 0.5 - 1
				local origin = CFrame.new(x, 0, startZ + length * 0.5)
				local model = Build.model(origin)
				model:SetAttribute("BuildScale", Build.SCALE)
				model.Parent = zone
			end
		end
	end
end

return Service
