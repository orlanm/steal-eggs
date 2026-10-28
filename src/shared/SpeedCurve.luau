--!strict
-- Points are the trained speed stat. Studs per second is the pace at that stat.
-- The knots are the zone chart. Between knots the pace is linear. Past the last
-- zone it climbs slowly above 9,000.

local Biomes = require(script.Parent.BiomeConfig)

local SpeedCurve = {}

local knots: { { points: number, studs: number } } = {}

for _, biome in Biomes do
	if biome.ZoneIndex > 0 and typeof(biome.MoveSpeed) == "number" then
		table.insert(knots, {
			points = biome.SpeedRequirement or 0,
			studs = biome.MoveSpeed,
		})
	end
end
table.sort(knots, function(a, b)
	return a.points < b.points
end)

function SpeedCurve.studs(points: number): number
	if typeof(points) ~= "number" or points ~= points or points <= 0 then
		return 16
	end
	local previous = knots[1]
	if not previous then
		return 16
	end
	if points <= previous.points then
		return previous.studs
	end
	for index = 2, #knots do
		local knot = knots[index]
		if points < knot.points then
			local span = knot.points - previous.points
			local alpha = if span > 0 then (points - previous.points) / span else 1
			return previous.studs + (knot.studs - previous.studs) * alpha
		end
		previous = knot
	end
	local extra = math.log10(points / math.max(previous.points, 1))
	return previous.studs + extra * 1000
end

-- Roblox's stock WalkSpeed: the left end of the HUD speed slider.
SpeedCurve.Default = 16

-- The HUD slider (player attribute SpeedScale, 0..1) eases the pace from stock
-- WalkSpeed (0) up to the full trained pace (1). Missing means full pace.
function SpeedCurve.scaled(full: number, scale: any): number
	local s = if typeof(scale) == "number" and scale == scale then math.clamp(scale, 0, 1) else 1
	if full <= SpeedCurve.Default then
		return full
	end
	return SpeedCurve.Default + (full - SpeedCurve.Default) * s
end

return SpeedCurve
