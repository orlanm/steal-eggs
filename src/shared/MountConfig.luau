--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.MountConfig
-- Pet mounts, after Steal an Egg's mount update: feed a Mount Star to a hatched pet in your pen and
-- it can be ridden for good. The ridden pet keeps earning in the pen, and the mount moves at your
-- own speed. Stars come from the Shop (weekly stock), the nightly Star Drop and the Star Handler NPC.

local MountConfig = {}

MountConfig.StarTool = "Mount Star" -- backpack Tool name (one Tool, Stars attribute = count)
MountConfig.StarColor = Color3.fromRGB(255, 212, 59)

-- Mount size (studs tall), from the pet's rolled egg size: Steal an Egg keeps every mount between
-- 0.8x and 4x a 5-stud character.
MountConfig.ReferenceHeight = 5
MountConfig.MinHeightRatio = 0.8
MountConfig.MaxHeightRatio = 4
MountConfig.BaseHeightRatio = 1.5 -- a 1x egg's mount (ears and tails included)
MountConfig.MaxLengthRatio = 2.6 -- long pets (snakes, eels) are shortened to this x height

function MountConfig.height(sizeScale: number?): number
	local s = if typeof(sizeScale) == "number" and sizeScale == sizeScale and sizeScale > 0 then sizeScale else 1
	local ratio = math.clamp(MountConfig.BaseHeightRatio * s, MountConfig.MinHeightRatio, MountConfig.MaxHeightRatio)
	return MountConfig.ReferenceHeight * ratio
end

-- Box the mount rig is fitted into: the pet's pen box scaled to the mount height.
function MountConfig.box(staticSize: Vector3, sizeScale: number?): Vector3
	local h = MountConfig.height(sizeScale)
	local k = h / math.max(staticSize.Y, 0.1)
	local box = staticSize * k
	local longest = math.max(box.X, box.Z)
	if longest > h * MountConfig.MaxLengthRatio then
		box *= h * MountConfig.MaxLengthRatio / longest
	end
	return box
end

-- Walk animation speed follows the rider's speed (16 studs/s plays at 1x).
MountConfig.WalkRateDivisor = 16
MountConfig.WalkRateMin = 0.3
MountConfig.WalkRateMax = 5
MountConfig.SeatMin = 1.2 -- HipHeight bounds while riding
MountConfig.SeatMax = 60
MountConfig.PromptRange = 12

-- R15 riding pose (KeyframeSequence built by _tools/mounts/rider_pose.py)
MountConfig.RiderAnimation = 121783898335988

-- Star Drop: when night falls there is a chance a star falls for every player, in a random biome.
MountConfig.StarDropChance = 0.12
MountConfig.StarDropLifetime = 180 -- seconds a fallen star waits to be caught
MountConfig.StarDropHold = 1.5 -- hold the prompt this long to catch it

-- The Star Handler (Steal an Egg's StarHandlerController lines).
MountConfig.Handler = {
	Name = "Star Handler",
	FirstMeeting = {
		"Oh! Hello there, little egg-snatcher!",
		"I'm the Star Handler. I look after the stars that fall from the night sky.",
		"Feed one of my stars to a pet and it grows into a powerful mount!",
		"What can I do for you?",
	},
	Greeting = "Welcome back, starlight! What can I do for you?",
	Choices = { "View Stars", "What is a Star?", "Star Drop Event?", "Bye!" },
	ViewStars = "Ooh, good eye! Every one of these was caught by hand~",
	WhatIsStar = {
		"Stars are little pieces of the night sky!",
		"Hold one near a pet in your base and feed it to them.",
		"Your pet grows into a mount, so you can hop on and ride it!",
	},
	StarDrop = {
		"Every night there's a rare chance of a Star Drop!",
		"When it happens, a little star falls for every player in the server.",
		"Find yours, hold on tight to catch it, and it's yours for free!",
		"Keep your eyes on the sky after dark~",
	},
	AnythingElse = "Anything else, starlight?",
	Bye = "Come back anytime! The stars will be waiting~",
}

return MountConfig
