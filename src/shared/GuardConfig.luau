-- Zone guards: which creature guards each den, how big it is, and its animations.
-- Rigs live in ReplicatedStorage.GuardTemplates (saved in the place). The client re-pivots each clone onto the
-- ground under its visible body, looking along the rig's forward (ForwardZ: -1 = root -Z, reference rigs; 1 = +Z, pets).
-- Reference guards (Steal an Egg) were animated in _blender/guards (guardanim.py); pet guards in
-- _tools/pets/blender/guard_clips.py. All animations are private assets of the game owner.
local GuardConfig = {}

-- Fit inside the den mouth (72 x 28) and depth (96).
GuardConfig.MaxHeight = 24
GuardConfig.MaxLength = 80
GuardConfig.MaxWidth = 60
GuardConfig.TemplateFolder = "GuardTemplates"

local function anims(sleep, wake, run, idle)
	return table.freeze({ Sleep = sleep, Wake = wake, Run = run, Idle = idle })
end

-- Native sizes (studs, W x H x L) of the visible parts at rest, as the joints place them, in the guard's own frame.
-- Swim: no longer used for height (every guard sinks MommyMotion GUARD_SINK = 1 stud in water, none on ground).
GuardConfig.Guards = table.freeze({
	Forest = {
		Size = Vector3.new(2.37, 3.94, 3.98),
		Anims = anims(123987398257038, 115533963222303, 115354186201040, 98522283072392),
	},
	Lake = {
		Size = Vector3.new(3.02, 4.53, 5.16),
		Anims = anims(78682711123518, 112241859444594, 73918077511950, 82962168725639),
	},
	Desert = {
		Size = Vector3.new(8.65, 7.27, 11.75),
		Anims = anims(125448824104642, 114251716957545, 78693626676914, 92064258396751),
	},
	Jungle = {
		Size = Vector3.new(4.12, 6.11, 13.48),
		Anims = anims(86552172477481, 95708653069693, 119282141301757, 88555768578089),
	},
	Snow = {
		Size = Vector3.new(13.82, 13.70, 6.86),
		Anims = anims(78851880215603, 122857677936900, 109603260930019, 72118033541429),
	},
	Volcano = {
		Size = Vector3.new(18.69, 20.21, 34.34),
		Anims = anims(80618314047041, 124376439834147, 117721924343020, 97818704530556),
	},
	["Abyss Ocean"] = {
		Size = Vector3.new(12.75, 11.66, 37.09),
		Swim = 0.1,
		Anims = anims(84246481072931, 135904880407302, 74564842371182, 92264390014100),
	},
	Prehistoric = {
		Size = Vector3.new(15.93, 28.16, 77.55),
		Anims = anims(118332321304473, 105727852285103, 126770957590185, 98117906134773),
	},
	Cosmic = {
		Size = Vector3.new(17.77, 17.37, 10.42),
		Anims = anims(92305697524819, 132275891059020, 104787458468810, 86173998878987),
	},
	["Cherry Blossom"] = {
		Size = Vector3.new(16.14, 20.17, 38.07),
		Anims = anims(123691130051776, 78041287025645, 115993250822667, 138324243254430),
	},
	["Titan Temple"] = {
		Size = Vector3.new(30.47, 33.31, 12.49),
		Anims = anims(109764295925766, 93049499250728, 133449091701100, 130708779599960),
	},
	["Light Dark"] = {
		Size = Vector3.new(49.14, 38.02, 36.63),
		Anims = anims(108135208209524, 102030872625837, 115646027925729, 83774200357489),
	},
	["Light Dark Demon"] = {
		Size = Vector3.new(49.14, 38.02, 36.63),
		Anims = anims(108135208209524, 102030872625837, 115646027925729, 83774200357489),
	},
	["Enchanted Forest"] = {
		Size = Vector3.new(24.85, 32.66, 54.54),
		Anims = anims(123476575283829, 117198637817252, 119246732511104, 72611807542419),
	},
	Werewolf = {
		Size = Vector3.new(14.67, 14.81, 24.00),
		ForwardZ = 1,
		Anims = anims(104994880719499, 114988349212067, 78499475580963, 100609845059413),
	},
	Spirit_Panda = {
		Size = Vector3.new(14.55, 19.84, 26.42),
		ForwardZ = 1,
		Anims = anims(107925953205760, 76539689125453, 94226280805288, 81043370065127),
	},
	Toxic_Crocodile = {
		Size = Vector3.new(7.99, 9.27, 27.44),
		ForwardZ = 1,
		Anims = anims(83007056253924, 133694732435798, 123918207176712, 135591597881954),
	},
	Shattered_Colossus = {
		Size = Vector3.new(15.88, 24.83, 9.47),
		ForwardZ = 1,
		Anims = anims(135531870788852, 103778428018373, 104835522679262, 138004994289191),
	},
	Kraken = {
		Size = Vector3.new(38.12, 23.32, 37.09),
		ForwardZ = 1,
		Swim = 0.15,
		Anims = anims(116544172401476, 95798487280447, 113397513308539, 77551741681696),
	},
	Mecha_Crocodon = {
		Size = Vector3.new(14.81, 17.63, 26.93),
		ForwardZ = 1,
		Anims = anims(113546549719460, 76042428104111, 119863962027656, 121624108606896),
	},
	Mosasaurus = {
		Size = Vector3.new(25.37, 17.20, 78.62),
		ForwardZ = 1,
		Swim = 0.25,
		Anims = anims(89133861881682, 85223707787164, 123859607345017, 86890347435685),
	},
	Ghost_Reaper = {
		Size = Vector3.new(18.14, 19.22, 10.05),
		ForwardZ = 1,
		Anims = anims(93976318144664, 108061972457315, 89527029673060, 103082486040556),
	},
	Strawberry_Elephant = {
		Size = Vector3.new(20.75, 22.33, 24.52),
		ForwardZ = 1,
		Anims = anims(71410136335322, 91315944561598, 97844928583560, 97501870050050),
	},
	Eternal_Lunar_Dragon = {
		Size = Vector3.new(18.59, 20.61, 74.73),
		ForwardZ = 1,
		Anims = anims(135899437395445, 94267274832486, 123883532165606, 110044903405905),
	},
})

-- Den (BeastHabitats.ZoneNN) -> guard. Odd zones that Steal an Egg has no guard for use a big pet.
GuardConfig.Zones = table.freeze({
	Zone01 = "Werewolf",
	Zone02 = "Forest",
	Zone03 = "Spirit_Panda",
	Zone04 = "Lake",
	Zone05 = "Toxic_Crocodile",
	Zone06 = "Desert",
	Zone07 = "Shattered_Colossus",
	Zone08 = "Jungle",
	Zone09 = "Kraken",
	Zone10 = "Snow",
	Zone11 = "Mecha_Crocodon",
	Zone12 = "Volcano",
	Zone13 = "Mosasaurus",
	Zone14 = "Abyss Ocean",
	Zone15 = "Ghost_Reaper",
	Zone16 = "Prehistoric",
	Zone17 = "Strawberry_Elephant",
	Zone18 = "Cosmic",
	Zone19 = "Cherry Blossom",
	Zone20 = "Eternal_Lunar_Dragon",
	Zone21 = "Titan Temple",
	Zone22 = "Light Dark Demon",
	Zone23 = "Enchanted Forest",
})

-- Played over the clips.
GuardConfig.FadeSeconds = 0.25
GuardConfig.RunSpeedForFullRate = 60 -- studs/s at which Run plays at 1x (faster guards speed it up)
GuardConfig.MaxRunRate = 2.2

function GuardConfig.forHabitat(habitat: string?)
	local name = habitat and GuardConfig.Zones[habitat]
	local guard = name and GuardConfig.Guards[name]
	return name, guard
end

-- World scale of a guard: as big as the den allows.
function GuardConfig.scale(guard): number
	local size = guard.Size
	return math.min(GuardConfig.MaxHeight / size.Y, GuardConfig.MaxLength / size.Z, GuardConfig.MaxWidth / size.X)
end

return table.freeze(GuardConfig)
