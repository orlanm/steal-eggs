local Biomes = require(script.Parent.BiomeConfig)
local Map = require(script.Parent.MapConfig)
local C = {
	SecondsPerTier = 180,
	MinimumGainPerSecond = 2,
	MaximumSpeed = 1e12,
	SaveInterval = 60,
	DataStoreName = "BabyBeastsTrainingSpeed_v1",
	Zones = {},
}
local z = Map.RouteStart
for _, b in Biomes do
	local len = b.Length or Map.ZoneLength * (if b.HalfLength then 0.5 else 1)
	if b.ZoneIndex > 0 then
		table.insert(C.Zones, {
			Index = b.ZoneIndex,
			Name = b.Name,
			Requirement = b.SpeedRequirement or 0,
			StartZ = z,
			EndZ = z + len,
		})
	end
	z += len
end
function C.format(n)
	if n >= 1e15 then
		return string.format("%.2fQa", n / 1e15)
	elseif n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end
function C.nextZone(speed)
	for _, b in C.Zones do
		if speed < b.Requirement then
			return b
		end
	end
	return nil
end
function C.rate(speed)
	local last = 0
	for _, b in C.Zones do
		if speed < b.Requirement then
			return math.max(C.MinimumGainPerSecond, (b.Requirement - last) / C.SecondsPerTier)
		end
		last = b.Requirement
	end
	return math.max(C.MinimumGainPerSecond, last / C.SecondsPerTier)
end
return C
