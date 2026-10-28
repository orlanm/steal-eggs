--!strict
-- Five-minute clock. Day is the steal window. Night is the short reset.

local NightCycle = {}

NightCycle.Cycle = 300
NightCycle.DayLength = 290
NightCycle.NightLength = 10
NightCycle.GrowthMultiplier = 30

function NightCycle.state(now: number): (string, number)
	local t = now % NightCycle.Cycle
	if t < NightCycle.DayLength then
		return "Day", NightCycle.DayLength - t
	end
	return "Night", NightCycle.Cycle - t
end

function NightCycle.untilNight(now: number): number
	local phase, remain = NightCycle.state(now)
	if phase == "Night" then
		return 0
	end
	return remain
end

return NightCycle
