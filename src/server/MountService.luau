--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.MountService
-- Pet mounts, after Steal an Egg's mount update (MountConfig):
--   * Mount Stars: a saved count (SpeedDataManager) shown as one "Mount Star" Tool in the backpack.
--   * Feed: holding a star near your own hatched pen pet, the client's Feed Star prompt asks to confirm,
--     then the star is spent and the pet record is Rideable for good (TankBeasts / BeastData).
--   * Ride: the pet stays in the pen (and keeps earning) while every client draws it under the rider
--     (Mounts.client). The rider's client reports the seat height; the server sets HipHeight.
--   * Star Handler NPC on the plaza (star wizard model + Idle / Talk clips from _tools/pets/blender/npc_star_handler.py, glows + sparkles in handlerVfx).
--   * Star Drop: some nights a star falls for every player in a random biome; hold to catch it.
-- Admin chat: ;stars <who> <n>, ;stardrop, ;rideable <who>, ;dismount <who>

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = game.ReplicatedStorage.BabyBeastsShared
local GameUI = require(Shared.GameUI)
local MountConfig = require(Shared.MountConfig)
local NpcAssets = require(Shared.NpcAssets)
local NightCycle = require(Shared.NightCycle)
local PetCatalog = require(Shared.PetCatalog)
local SpeedData = require(script.Parent.SpeedDataManager)
local TankBeasts = require(script.Parent.TankBeasts)
local BeastData = require(script.Parent.BeastData)
local AdminEggs = require(script.Parent.AdminEggs)

local MountService = {}

local GOOD = Color3.fromRGB(255, 226, 110)
local BAD = Color3.fromRGB(255, 120, 120)
local HANDLER_SPOT = Vector3.new(64, 0, 601) -- plaza, where the second trail shop stood (east wall)
local HANDLER_HEIGHT = 17
local HANDLER_GLOW = Color3.fromRGB(255, 214, 80)
local STAR_MOTE = "rbxassetid://15011464541" -- PetVfxPool StarSwirl
local GLIMMER = "rbxassetid://11844017484" -- PetVfxPool Glimmer

local started = false
local notice: RemoteEvent
local actionRemote: RemoteEvent
local handlerRemote: RemoteEvent
local riding: { [Player]: { pet: Model, hip: number, conns: { RBXScriptConnection } } } = {}
local starTemplate: BasePart? = nil

local function tell(player: Player, text: string, color: Color3?)
	notice:FireClient(player, { text = text, color = color or GOOD, small = true })
end

local function petName(model: Instance): string
	local egg = model:GetAttribute("EggName")
	local entry = if typeof(egg) == "string" then PetCatalog.get(egg) else nil
	local name = if entry then entry.DisplayName elseif typeof(egg) == "string" then (string.gsub(egg, " Egg$", "")) else "Pet"
	local mutation = model:GetAttribute("Mutation")
	return if typeof(mutation) == "string" and mutation ~= "" then mutation .. " " .. name else name
end

-- NPC model ------------------------------------------------------------------------------------------

local npcModel: Model? = nil
local npcLoading = false
local function loadNpc(): Model?
	while npcLoading do
		task.wait(0.1)
	end
	if npcModel then
		return npcModel
	end
	local asset = NpcAssets.StarHandler
	if not asset or asset.Model == 0 then
		return nil
	end
	npcLoading = true
	-- InsertService can fail or throttle right after a server starts: retry before giving up
	local ok, result
	for attempt = 1, 5 do
		ok, result = pcall(function()
			return InsertService:LoadAsset(asset.Model)
		end)
		if ok and result then
			break
		end
		task.wait(attempt * 2)
	end
	npcLoading = false
	if not ok or not result then
		warn("[MountService] Star Handler model: " .. tostring(result))
		return nil
	end
	local model = result:FindFirstChildWhichIsA("Model") or result
	model.Parent = nil
	local jointed: { [BasePart]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part1 then
			jointed[d.Part1] = true
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("SurfaceAppearance") then
			-- the importer's PBR copy of the atlas (its emissive map is a broken placeholder); the
			-- plain TextureID below shows the same colours
			d:Destroy()
		elseif d:IsA("BasePart") then
			if d.Name == "Star" or string.find(d.Name, "^Glow") then
				-- soft glow (Neon at reduced brightness — not full plaza flood)
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromRGB(255, 214, 80):Lerp(Color3.fromRGB(180, 140, 60), 0.35)
				d.Transparency = 0.12
				d.CastShadow = false
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			elseif d:IsA("MeshPart") then
				d.TextureID = "rbxassetid://" .. asset.Texture
			end
			d.Anchored = not jointed[d]
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	npcModel = model :: Model
	return npcModel
end

-- Star Tool -------------------------------------------------------------------------------------------

-- A small glowing star: the Star Handler's own star head mesh (falls back to a neon ball).
local function makeStar(name: string, size: number): BasePart
	local part: BasePart
	if not starTemplate then
		local npc = loadNpc()
		local source = npc and npc:FindFirstChild("Star", true)
		if source and source:IsA("MeshPart") then
			local copy = source:Clone()
			for _, child in copy:GetChildren() do
				child:Destroy()
			end
			starTemplate = copy
		end
	end
	if starTemplate then
		part = starTemplate:Clone()
		local s = starTemplate.Size
		part.Size = s * (size / math.max(s.X, s.Y, s.Z))
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * size
		part = ball
	end
	part.Name = name
	part.Color = MountConfig.StarColor
	part.Material = Enum.Material.Neon
	part.CastShadow = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	local light = Instance.new("PointLight")
	light.Color = MountConfig.StarColor
	light.Brightness = 1.4
	light.Range = size * 5
	light.Parent = part
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Rate = 10
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = part
	return part
end

local function starTool(player: Player): Tool?
	for _, holder in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = holder and holder:FindFirstChild(MountConfig.StarTool)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

local function holdingStar(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(MountConfig.StarTool)
	return tool ~= nil and tool:IsA("Tool")
end

-- One Tool while the player has stars; its tooltip shows how many.
local function syncStarTool(player: Player)
	local count = SpeedData.stars(player)
	local tool = starTool(player)
	if count <= 0 then
		if tool then
			tool:Destroy()
		end
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool then
		if not backpack or not player.Character then
			return
		end
		local t = Instance.new("Tool")
		t.Name = MountConfig.StarTool
		t.CanBeDropped = false
		t.RequiresHandle = true
		t.TextureId = "rbxassetid://107674190234622" -- ShopArt.Star
		t:SetAttribute("MountStar", true)
		local handle = makeStar("Handle", 1.6)
		handle.Parent = t
		t.Grip = CFrame.new(0, -0.2, -0.7) * CFrame.Angles(0, math.rad(180), 0)
		t.Parent = backpack
		tool = t
	end
	(tool :: Tool).ToolTip = string.format("Mount Star x%d: hold near a pet in your pen to feed it", count)
	;(tool :: Tool):SetAttribute("Stars", count)
end

-- Riding ------------------------------------------------------------------------------------------

local function dismount(player: Player)
	local ride = riding[player]
	if not ride then
		return
	end
	riding[player] = nil
	for _, c in ride.conns do
		c:Disconnect()
	end
	if ride.pet.Parent then
		ride.pet:SetAttribute("RiddenBy", nil)
	end
	player:SetAttribute("Riding", nil)
	local character = player.Character
	if character then
		for _, name in { "MountPet", "MountSize", "MountScale", "MountMutation", "MountName", "MountSeat" } do
			character:SetAttribute(name, nil)
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.HipHeight = ride.hip
		end
	end
end

local function mount(player: Player, pet: Model): (boolean, string)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and hum and hum.Health > 0) then
		return false, "You can't ride right now"
	end
	if hum.PlatformStand or player:GetAttribute("MommyState") then
		return false, "You can't ride right now"
	end
	if pet:GetAttribute("Rideable") ~= true then
		return false, "Feed this pet a Mount Star first!"
	end
	dismount(player)
	local egg = pet:GetAttribute("EggName")
	local size = pet:GetAttribute("StaticSize")
	if typeof(egg) ~= "string" or typeof(size) ~= "Vector3" then
		return false, "This pet can't be ridden"
	end
	local ride = { pet = pet, hip = hum.HipHeight, conns = {} :: { RBXScriptConnection } }
	riding[player] = ride
	pet:SetAttribute("RiddenBy", player.UserId)
	player:SetAttribute("Riding", true)
	character:SetAttribute("MountName", petName(pet))
	character:SetAttribute("MountSize", size)
	character:SetAttribute("MountScale", pet:GetAttribute("SizeScale"))
	character:SetAttribute("MountMutation", pet:GetAttribute("Mutation"))
	character:SetAttribute("MountPet", egg) -- last: clients build the mount when this appears
	table.insert(ride.conns, pet.AncestryChanged:Connect(function()
		if not pet.Parent then
			dismount(player)
		end
	end))
	table.insert(ride.conns, hum.Died:Connect(function()
		dismount(player)
	end))
	table.insert(ride.conns, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		if hum.PlatformStand then
			dismount(player) -- knocked down
		end
	end))
	table.insert(ride.conns, character.AncestryChanged:Connect(function()
		if not character.Parent then
			dismount(player)
		end
	end))
	return true, "Riding " .. petName(pet) .. "!"
end

local function nearPet(player: Player, pet: Model, extra: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local root = pet.PrimaryPart
	if not (hrp and hrp:IsA("BasePart") and root) then
		return false
	end
	local size = pet:GetAttribute("StaticSize")
	local reach = MountConfig.PromptRange + extra + (if typeof(size) == "Vector3" then math.max(size.X, size.Z) * 0.5 else 0)
	return (hrp.Position - root.Position).Magnitude <= reach
end

local busy: { [Player]: boolean } = {}
local function onAction(player: Player, action: any, arg: any)
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(function()
		if action == "feed" and typeof(arg) == "Instance" then
			local pet = TankBeasts.ownedPet(player.UserId, arg)
			if not pet then
				tell(player, "You can only feed stars to hatched pets in your own pen", BAD)
			elseif pet:GetAttribute("Rideable") == true then
				tell(player, petName(pet) .. " is already a mount!", BAD)
			elseif not holdingStar(player) or SpeedData.stars(player) < 1 then
				tell(player, "Hold a Mount Star to feed it", BAD)
			elseif not nearPet(player, pet, 6) then
				tell(player, "Get closer to " .. petName(pet), BAD)
			elseif SpeedData.useStar(player) then
				-- single use: the star is gone once fed; refunded only if the pet could not take it
				if not TankBeasts.makeRideable(player.UserId, pet) then
					SpeedData.addStars(player, 1)
					syncStarTool(player)
					tell(player, "Could not feed " .. petName(pet) .. ", your star was returned", BAD)
					return
				end
				task.spawn(BeastData.save, player)
				syncStarTool(player)
				actionRemote:FireClient(player, "fed", pet)
				tell(player, petName(pet) .. " is now a mount! Walk up and press Ride.", GOOD)
			end
		elseif action == "ride" and typeof(arg) == "Instance" then
			local pet = TankBeasts.ownedPet(player.UserId, arg)
			if not pet then
				return
			end
			if not nearPet(player, pet, 8) then
				tell(player, "Get closer to " .. petName(pet), BAD)
				return
			end
			local done, message = mount(player, pet)
			if not done then
				tell(player, message, BAD)
			end
		elseif action == "dismount" then
			dismount(player)
		elseif action == "seat" and typeof(arg) == "number" and arg == arg then
			local ride = riding[player]
			local character = player.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if ride and hum and character then
				local seat = math.clamp(arg, MountConfig.SeatMin, MountConfig.SeatMax)
				character:SetAttribute("MountSeat", seat)
				hum.HipHeight = seat
			end
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[MountService] " .. tostring(err))
	end
end

-- Star Handler NPC ------------------------------------------------------------------------------------

local function floorY(x: number, z: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else 0
end

local function ring(parent: Instance, at: Vector3, radius: number)
	local function disc(name: string, r: number, h: number, color: Color3, transparency: number, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(h, r * 2, r * 2)
		p.Color = color
		p.Material = material
		p.Transparency = transparency
		p.CFrame = CFrame.new(at + Vector3.new(0, h * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = parent
		return p
	end
	-- Soft ring (dim neon + weak fill light — was very bright on the plaza floor).
	disc("RingGlow", radius, 0.12, MountConfig.StarColor, 0.55, Enum.Material.Neon)
	disc("RingInner", radius - 0.9, 0.16, Color3.fromRGB(255, 244, 196), 0.55, Enum.Material.SmoothPlastic)
	local light = Instance.new("PointLight")
	light.Color = MountConfig.StarColor
	light.Range = radius * 1.5
	light.Brightness = 0.35
	light.Shadows = false
	light.Parent = parent:FindFirstChild("RingGlow")
end

-- Soft glows on the Star Handler: held star + eyes + a few rising motes (kept subdued).
local function handlerVfx(npc: Model, anchor: BasePart)
	local function emitter(parent: Instance, name: string, texture: string, props: { [string]: any })
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Texture = texture
		e.Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), HANDLER_GLOW)
		e.LightEmission = 0.45
		e.LightInfluence = 0.2
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = parent
		return e
	end
	local held = npc:FindFirstChild("Star", true)
	if held and held:IsA("BasePart") then
		local s = held.Size.Magnitude
		local light = Instance.new("PointLight")
		light.Color = HANDLER_GLOW
		light.Brightness = 0.45
		light.Range = s * 1.2
		light.Shadows = false
		light.Parent = held
		emitter(held, "Glimmer", GLIMMER, {
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.1), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.35),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 5,
			Speed = NumberRange.new(s * 0.15, s * 0.35),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Drag = 2,
		})
		emitter(held, "Halo", "rbxasset://textures/particles/sparkles_main.dds", {
			Size = NumberSequence.new(s * 0.55),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2),
			Rate = 1,
			Speed = NumberRange.new(0),
			LockedToPart = true,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
		})
	end
	for _, side in { "L", "R" } do
		local eye = npc:FindFirstChild("GlowEye" .. side, true)
		if eye and eye:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = HANDLER_GLOW
			light.Brightness = 0.2
			light.Range = eye.Size.Magnitude * 1.5
			light.Shadows = false
			light.Parent = eye
		end
	end
	emitter(anchor, "StarMotes", STAR_MOTE, {
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.4),
		Lifetime = NumberRange.new(1.6, 2.4),
		Rate = 2,
		Speed = NumberRange.new(0.8, 1.5),
		SpreadAngle = Vector2.new(10, 10),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

local function spawnHandler(root: Instance)
	local template = loadNpc()
	local zoneParent = root:FindFirstChild("BeastHabitats")
	local zone = zoneParent and zoneParent:FindFirstChild("Zone00") or root
	local old = zone:FindFirstChild("StarHandler")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = "StarHandler"
	holder:AddTag("StarHandlerNpc")
	local y = floorY(HANDLER_SPOT.X, HANDLER_SPOT.Z, {})
	local base = Vector3.new(HANDLER_SPOT.X, y, HANDLER_SPOT.Z)
	ring(holder, base, 7.6)
	-- faces the road centre (x = 0)
	local facing = CFrame.lookAt(base, base + Vector3.new(-math.sign(HANDLER_SPOT.X), 0, 0))

	local anchor = Instance.new("Part")
	anchor.Name = "TalkAnchor"
	anchor.Size = Vector3.new(8, HANDLER_HEIGHT, 8)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = true
	anchor.CanQuery = true
	anchor.CanTouch = false
	anchor.CFrame = facing * CFrame.new(0, HANDLER_HEIGHT * 0.5 + 1.2, 0)
	anchor.Parent = holder

	local title = Instance.new("BillboardGui")
	title.Name = "Title"
	title.Size = UDim2.fromOffset(110, 22)
	title.StudsOffset = Vector3.new(0, HANDLER_HEIGHT * 0.5 + 1, 0)
	title.MaxDistance = 120
	title.LightInfluence = 0
	title.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.TextColor3 = MountConfig.StarColor
	label.Text = MountConfig.Handler.Name
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(60, 30, 10)
	stroke.Parent = label
	label.Parent = title

	-- Prompt sits below the NPC's waist so the Talk UI doesn't float over the chest/head.
	local promptHost = Instance.new("Part")
	promptHost.Name = "PromptHost"
	promptHost.Size = Vector3.new(0.5, 0.5, 0.5)
	promptHost.Transparency = 1
	promptHost.Anchored = true
	promptHost.CanCollide = false
	promptHost.CanQuery = false
	promptHost.CanTouch = false
	promptHost.CastShadow = false
	promptHost.CFrame = facing * CFrame.new(0, 3.1, 1.2)
	promptHost.Parent = holder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = MountConfig.Handler.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 18)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = promptHost
	prompt.Triggered:Connect(function(player)
		handlerRemote:FireClient(player, "open")
	end)

	local talkTrack: AnimationTrack? = nil
	local talkUntil = 0
	if template then
		local npc = template:Clone()
		npc.Name = "Body"
		npc:ScaleTo(npc:GetScale() * HANDLER_HEIGHT / math.max(npc:GetExtentsSize().Y, 0.1))
		-- uploaded FBX models face +Z; the wizard's boots stand on the ring
		local cf, size = npc:GetBoundingBox()
		local pivotToBox = npc:GetPivot():ToObjectSpace(cf)
		local target = facing * CFrame.new(0, size.Y * 0.5 + 0.16, 0) * CFrame.Angles(0, math.pi, 0)
		npc:PivotTo(target * pivotToBox:Inverse())
		npc.Parent = holder
		handlerVfx(npc, anchor)
		local controller = npc:FindFirstChildWhichIsA("AnimationController")
		if not controller then
			controller = Instance.new("AnimationController")
			controller.Parent = npc
		end
		local animator = (controller :: AnimationController):FindFirstChildWhichIsA("Animator") or Instance.new("Animator", controller)
		local asset = NpcAssets.StarHandler
		local function load(id: number?, priority: Enum.AnimationPriority): AnimationTrack?
			if not id or id == 0 then
				return nil
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if not ok then
				warn("[MountService] Star Handler animation: " .. tostring(track))
				return nil
			end
			track.Priority = priority
			track.Looped = true
			return track
		end
		local idle = load(asset.Animations.Idle, Enum.AnimationPriority.Idle)
		talkTrack = load(asset.Animations.Talk, Enum.AnimationPriority.Action)
		holder.Parent = zone
		if idle then
			idle:Play(0)
		end
	else
		holder.Parent = zone
	end
	-- a line of dialog: talk for a few seconds
	handlerRemote.OnServerEvent:Connect(function(_player, what: any)
		if what ~= "talk" or not talkTrack then
			return
		end
		local track = talkTrack :: AnimationTrack
		talkUntil = os.clock() + 2.6
		if not track.IsPlaying then
			track:Play(0.2)
			task.spawn(function()
				while os.clock() < talkUntil do
					task.wait(0.2)
				end
				track:Stop(0.3)
			end)
		end
	end)
end

-- Star Drop ---------------------------------------------------------------------------------------

local dropFolder: Folder
local habitats: { Instance } = {}

local function dropPoint(rng: Random): (Vector3?, string)
	if #habitats == 0 then
		return nil, ""
	end
	for _ = 1, 12 do
		local zone = habitats[rng:NextInteger(1, #habitats)]
		local cells = {}
		for _, d in zone:GetDescendants() do
			if d.Name == "JailCell" then
				table.insert(cells, d)
			end
		end
		local anchor: Vector3? = nil
		if #cells > 0 then
			local cell = cells[rng:NextInteger(1, #cells)]
			if cell:IsA("Model") then
				anchor = cell:GetPivot().Position
			elseif cell:IsA("BasePart") then
				anchor = cell.Position
			end
		elseif zone:IsA("Model") then
			anchor = zone:GetPivot().Position
		end
		if anchor then
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(8, 22)
			local x, z = anchor.X + math.cos(angle) * r, anchor.Z + math.sin(angle) * r
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { dropFolder }
			local hit = Workspace:Raycast(Vector3.new(x, anchor.Y + 120, z), Vector3.new(0, -260, 0), params)
			if hit and hit.Material ~= Enum.Material.Water then
				local name = zone:GetAttribute("BiomeName")
				return hit.Position, if typeof(name) == "string" then name else zone.Name
			end
		end
	end
	return nil, ""
end

local function dropFor(player: Player, rng: Random): boolean
	local at, biome = dropPoint(rng)
	if not at then
		return false
	end
	local holder = Instance.new("Model")
	holder.Name = "StarDrop"
	holder:SetAttribute("ForUserId", player.UserId)
	holder:SetAttribute("Biome", biome)
	local star = makeStar("Star", 3)
	star.Anchored = true
	local rest = CFrame.new(at + Vector3.new(0, 3, 0))
	star.CFrame = rest + Vector3.new(0, 160, 0)
	star.Parent = holder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = star
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = star
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.9
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(MountConfig.StarColor, Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = star
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatchPrompt"
	prompt.ActionText = "Catch Star"
	prompt.ObjectText = "Your Star"
	prompt.HoldDuration = MountConfig.StarDropHold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = star
	holder.Parent = dropFolder
	TweenService:Create(star, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = rest }):Play()
	task.delay(2.4, function()
		prompt.Enabled = true
		holder:SetAttribute("Landed", true)
	end)
	local caught = false
	prompt.Triggered:Connect(function(who)
		if caught or who ~= player then
			return
		end
		caught = true
		holder:Destroy()
		if SpeedData.addStars(player, 1) then
			syncStarTool(player)
			tell(player, "You caught a Mount Star! Feed it to a pet in your pen.", GOOD)
		end
	end)
	task.delay(MountConfig.StarDropLifetime, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	tell(player, "A star fell for you in " .. biome .. "! Find it and hold to catch it.", GOOD)
	return true
end

local function starDrop(): number
	local rng = Random.new()
	notice:FireAllClients({ text = "STAR DROP! A star fell for every player. Find yours!", color = GOOD })
	local count = 0
	for _, player in Players:GetPlayers() do
		-- one waiting star per player
		local pending = false
		for _, d in dropFolder:GetChildren() do
			if d:GetAttribute("ForUserId") == player.UserId then
				pending = true
			end
		end
		if not pending and dropFor(player, rng) then
			count += 1
		end
	end
	return count
end

-- Admin ---------------------------------------------------------------------------------------------

local function adminCommands()
	AdminEggs.command("stars", ";stars <me|all|name> <n>", function(caller, words)
		local list = AdminEggs.targets(caller, words[1] or "me")
		local n = math.floor(tonumber(words[2] or "1") or 1)
		for _, player in list do
			SpeedData.addStars(player, n)
			syncStarTool(player)
		end
		return string.format("gave %d star(s) to %d player(s)", n, #list)
	end)
	AdminEggs.command("stardrop", ";stardrop", function()
		return "star drop: " .. starDrop() .. " star(s)"
	end)
	AdminEggs.command("rideable", ";rideable <me|name>: every hatched pen pet becomes a mount", function(caller, words)
		local n = 0
		for _, player in AdminEggs.targets(caller, words[1] or "me") do
			local folder = Workspace:FindFirstChild("TankBeasts", true)
			for _, model in (if folder then folder:GetChildren() else {}) do
				if TankBeasts.makeRideable(player.UserId, model) then
					n += 1
				end
			end
			task.spawn(BeastData.save, player)
		end
		return n .. " pet(s) made rideable"
	end)
	AdminEggs.command("dismount", ";dismount <me|all|name>", function(caller, words)
		local list = AdminEggs.targets(caller, words[1] or "me")
		for _, player in list do
			dismount(player)
		end
		return "dismounted " .. #list
	end)
end

-- Start -----------------------------------------------------------------------------------------------

function MountService.syncStars(player: Player)
	syncStarTool(player)
end

function MountService.start(root: Instance)
	if started then
		return
	end
	started = true
	notice = GameUI.remote("EggAnnouncement")
	actionRemote = GameUI.remote("MountAction")
	handlerRemote = GameUI.remote("StarHandler")
	actionRemote.OnServerEvent:Connect(onAction)

	dropFolder = Instance.new("Folder")
	dropFolder.Name = "StarDrops"
	dropFolder.Parent = Workspace
	local zones = root:FindFirstChild("BeastHabitats")
	for _, zone in (if zones then zones:GetChildren() else {}) do
		if zone.Name ~= "Zone00" and zone:GetAttribute("BiomeName") ~= nil then
			table.insert(habitats, zone)
		end
	end

	local function hookPlayer(player: Player)
		player:GetAttributeChangedSignal("Stars"):Connect(function()
			syncStarTool(player)
		end)
		player.CharacterAdded:Connect(function()
			dismount(player)
			player:WaitForChild("Backpack", 10)
			task.wait(0.5)
			syncStarTool(player)
		end)
		if player.Character then
			task.spawn(syncStarTool, player)
		end
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dismount(player)
		busy[player] = nil
	end)

	-- nightly Star Drop roll
	task.spawn(function()
		local last = NightCycle.state(Workspace:GetServerTimeNow())
		while true do
			task.wait(1)
			local phase = NightCycle.state(Workspace:GetServerTimeNow())
			if phase == "Night" and last ~= "Night" and math.random() < MountConfig.StarDropChance then
				starDrop()
			end
			last = phase
		end
	end)

	adminCommands()
	task.spawn(spawnHandler, root)
	print("[BabyBeasts] Mounts ready: stars, feeding, riding, Star Handler, Star Drop")
end

return MountService
