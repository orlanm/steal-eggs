--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.SurfaceFinish
-- Bright yellow on the plaza and zone 0 road. Floors keep Plastic with an
-- empty material variant so the Universal surface studs show, same as the walls.
-- Happy-green checker covers only the pen area. The rest of the plaza ground is the road yellow.
-- Yellow roads stay outside that rectangle. Pen fences keep their own colors.

local Biomes = require(game.ReplicatedStorage.BabyBeastsShared.BiomeConfig)
local MapConfig = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)

local Finish = {}

local YELLOW = Biomes[1].Floor
local YELLOW_ALT = Biomes[1].Alternate
local YARD_A = Color3.fromRGB(105, 208, 20)
local YARD_B = Color3.fromRGB(97, 186, 18)

local function insidePenArea(position: Vector3): boolean
	local center = MapConfig.PenAreaCenter
	local halfW = MapConfig.PenAreaWidth / 2
	local halfD = MapConfig.PenAreaDepth / 2
	return math.abs(position.X - center.X) <= halfW and math.abs(position.Z - center.Z) <= halfD
end

local function plastic(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = "Universal"
end

local function studs(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = ""
	part.TopSurface = Enum.SurfaceType.Universal
	part.BottomSurface = Enum.SurfaceType.Universal
	part.LeftSurface = Enum.SurfaceType.Universal
	part.RightSurface = Enum.SurfaceType.Universal
	part.FrontSurface = Enum.SurfaceType.Universal
	part.BackSurface = Enum.SurfaceType.Universal
end

local function yellow(part: BasePart)
	local ix = math.floor(part.Position.X / 12)
	local iz = math.floor(part.Position.Z / 12)
	part.Color = if (ix + iz) % 2 == 0 then YELLOW else YELLOW_ALT
end

local function smooth(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = ""
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
end

local function yardPaint(part: BasePart)
	smooth(part)
	local ix = math.floor((part.Position.X + 480) / 12)
	local iz = math.floor((part.Position.Z + 480) / 12)
	part.Color = if (ix + iz) % 2 == 0 then YARD_A else YARD_B
end

local function fenceStuds(part: BasePart)
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = ""
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
end

function Finish.start(root: Instance)
	local zone0 = root:FindFirstChild("BeastHabitats")
	zone0 = zone0 and zone0:FindFirstChild("Zone00")
	local zonePath = zone0 and zone0:FindFirstChild("PathFloor")
	local grounds = root:FindFirstChild("GroundAndPaths")

	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") and (inst.Name == "CheckerTile" or inst.Name == "PathTile") then
			if grounds and inst:IsDescendantOf(grounds) and insidePenArea(inst.Position) then
				inst.Name = "CheckerTile"
				yardPaint(inst)
			elseif grounds and inst:IsDescendantOf(grounds) and inst.Name == "CheckerTile" then
				studs(inst)
				yellow(inst)
			else
				studs(inst)
				if inst.Name == "PathTile" or (zonePath and inst:IsDescendantOf(zonePath)) then
					yellow(inst)
				end
			end
		end
	end

	for _, inst in root:GetDescendants() do
		if inst.Name == "FarmFence" then
			for _, part in inst:GetDescendants() do
				if part:IsA("BasePart") then
					fenceStuds(part)
				end
			end
		elseif
			(inst.Name == "FuseMachine" and inst:GetAttribute("KeepFinish") ~= true)
			or inst:GetAttribute("TrailShop") == true
		then
			-- KeepFinish: the Blender fuse machine keeps its own Neon/Glass materials.
			for _, part in inst:GetDescendants() do
				if part:IsA("BasePart") then
					plastic(part)
				end
			end
		end
	end
end

return Finish
