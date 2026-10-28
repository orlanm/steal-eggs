--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.Map.RouteLandscape
-- Fills the sunken zone and S-curve channel with terrain water up to the plaza.
-- The one-shot shallow-route move already ran (ShallowRouteVersion=1). This only
-- refreshes water voxels and the walk supports when WaterVolume is missing.

local Shared = game.ReplicatedStorage.BabyBeastsShared
local Path = require(Shared.RoutePath)

local Landscape = {}

local CHANNEL_DEPTH = 5

local function fillChannel(size: Vector3, cf: CFrame)
	local top = 0
	local bottom = -CHANNEL_DEPTH
	local rot = cf - cf.Position
	workspace.Terrain:FillBlock(
		CFrame.new(cf.Position.X, (top + bottom) * 0.5, cf.Position.Z) * rot,
		Vector3.new(size.X, top - bottom, size.Z),
		Enum.Material.Water
	)
end

local function support(parent: Instance, size: Vector3, cf: CFrame)
	-- One walk deck per placement. Refresh an existing one instead of stacking.
	for _, child in parent:GetChildren() do
		if child:IsA("BasePart") and child.Name == "WaterWalkSupport" then
			local same = (child.Position - cf.Position).Magnitude < 2
				and math.abs(child.Size.X - size.X) < 1
				and math.abs(child.Size.Z - size.Z) < 1
			if same then
				child.Size = size
				child.CFrame = cf
				child.CanCollide = true
				child.Transparency = 1
				fillChannel(size, cf)
				return child
			end
		end
	end
	local p = Instance.new("Part")
	p.Name = "WaterWalkSupport"
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.new()
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p:SetAttribute("WaterWalkSupport", true)
	p.Parent = parent
	fillChannel(size, cf)
	return p
end

function Landscape.apply(root: Instance, config: any)
	-- Original shallow-route geometry already lives in the place.
	if root:GetAttribute("ShallowRouteVersion") == 1 and root:FindFirstChild("WaterVolume") then
		for _, zone in root.BeastHabitats:GetChildren() do
			local id = zone:GetAttribute("ZoneIndex")
			local layout = typeof(id) == "number" and Path.Zones[id] or nil
			if layout and id > 0 then
				local cell = zone:FindFirstChild("JailCell")
				if cell then
					local home = cell:GetAttribute("HomePosition")
					if typeof(home) == "Vector3" then
						fillChannel(Vector3.new(config.CellDepth, CHANNEL_DEPTH, config.CellWidth), CFrame.new(home.X, -CHANNEL_DEPTH * 0.5, home.Z))
						support(zone, Vector3.new(config.CellDepth, 0.4, config.CellWidth), CFrame.new(home.X, -0.2, home.Z))
					end
				end
				fillChannel(
					Vector3.new(config.RoadWidth, CHANNEL_DEPTH, layout.EndZ - layout.StartZ),
					CFrame.new(layout.X, -CHANNEL_DEPTH * 0.5, layout.Center.Z)
				)
				support(zone, Vector3.new(config.RoadWidth, 0.4, layout.EndZ - layout.StartZ), CFrame.new(layout.X, -0.2, layout.Center.Z))
			end
		end
		local connectors = root:FindFirstChild("CurvedConnections")
		if connectors then
			for _, model in connectors:GetChildren() do
				for _, child in model:GetChildren() do
					if child:IsA("BasePart") and child.Name == "WaterWalkSupport" then
						fillChannel(child.Size, child.CFrame)
					end
				end
			end
		end
		root:SetAttribute("WaterSurfaceY", 0)
		root:SetAttribute("ChannelDepth", CHANNEL_DEPTH)
		return
	end

	if root:GetAttribute("ShallowRouteVersion") == 1 then
		return
	end

	-- Fresh maps only: leave the legacy one-shot alone if it never ran.
	local waterFolder = root:FindFirstChild("WaterVolume")
	if not waterFolder then
		waterFolder = Instance.new("Folder")
		waterFolder.Name = "WaterVolume"
		waterFolder.Parent = root
	end
	for _, zone in root.BeastHabitats:GetChildren() do
		local id = zone:GetAttribute("ZoneIndex")
		local layout = typeof(id) == "number" and Path.Zones[id] or nil
		if layout and id > 0 then
			local cell = zone:FindFirstChild("JailCell")
			if cell then
				local home = cell:GetAttribute("HomePosition")
				if typeof(home) == "Vector3" then
					fillChannel(Vector3.new(config.CellDepth, CHANNEL_DEPTH, config.CellWidth), CFrame.new(home.X, -CHANNEL_DEPTH * 0.5, home.Z))
					support(zone, Vector3.new(config.CellDepth, 0.4, config.CellWidth), CFrame.new(home.X, -0.2, home.Z))
				end
			end
			fillChannel(
				Vector3.new(config.RoadWidth, CHANNEL_DEPTH, layout.EndZ - layout.StartZ),
				CFrame.new(layout.X, -CHANNEL_DEPTH * 0.5, layout.Center.Z)
			)
			support(zone, Vector3.new(config.RoadWidth, 0.4, layout.EndZ - layout.StartZ), CFrame.new(layout.X, -0.2, layout.Center.Z))
		end
	end
	root:SetAttribute("ShallowRouteVersion", 1)
	root:SetAttribute("WaterSurfaceY", 0)
	root:SetAttribute("ChannelDepth", CHANNEL_DEPTH)
end

return Landscape
