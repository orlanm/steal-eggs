--!strict
local G = require(script.Parent.Geometry)
local Layout = require(script.Parent.Layout)
local Tanks = {}

function Tanks.build(root, config, centers)
	local group = G.folder(root, "PlayerTanks")
	local pen = config.PenSize
	for id, center in ipairs(centers) do
		local tank = G.folder(group, "Tank" .. id)
		tank:SetAttribute("Slot", id)
		tank:SetAttribute("Center", center)
		tank:SetAttribute("HalfSize", pen / 2)
		tank:SetAttribute("FrontDir", Layout.frontDir(center))
		-- Invisible volume so reaching your own pen still ends a chase. No glass.
		local bounds = G.part(
			tank,
			"PenBounds",
			Vector3.new(pen - 2, 8, pen - 2),
			CFrame.new(center + Vector3.new(0, 4, 0)),
			Color3.new(1, 1, 1),
			false
		)
		bounds.Transparency = 1
		bounds.CanTouch = true
		bounds.CanCollide = false
		bounds.CanQuery = false
		bounds.CastShadow = false
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "PlayerSpawn"
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0))
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.Material = Enum.Material.Plastic
		spawn.MaterialVariant = "Universal"
		spawn.Parent = tank
		tank.Parent = group
		task.wait()
	end
end

return Tanks
