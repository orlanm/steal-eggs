--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.AudioConfig
-- Music and sound effects (GameAudio.client). Every id is from Roblox's licensed libraries
-- (APM Music / Pro Sound Effects), so they play in any experience.
--
-- Music, highest priority first:
--   Divine  - a Divine or Eternal egg is on the map (announced) or being carried
--   Secret  - same for a Secret egg
--   Mythic  - a Mythic egg just spawned, is near you, or is being carried
--   Lobby   - the background playlist; it fades out under the tracks above
-- An announced / Mythic nest egg plays its track for SpawnWindow seconds after the reset, then
-- only while you are within ProximityRadius of it. A stolen egg plays it until it is placed in a
-- pen (or dropped / reset). Epic and Legendary eggs get a short jingle instead of a track.

export type Cue = { id: number, volume: number }

local AudioConfig = {}

AudioConfig.Lobby = {
	1844592742, -- Action Kids
	1835450912, -- Crazy Games
	1836299848, -- Video Cartoon (A)
}
AudioConfig.LobbyVolume = 0.32

AudioConfig.Tracks = {
	Divine = { id = 1836707211, volume = 0.55 }, -- Hall Of Souls (choir)
	Secret = { id = 1847062058, volume = 0.6 }, -- Mysterious Suspense
	Mythic = { id = 9045941477, volume = 0.45 }, -- Mission Danger - Underscore (drums + brass)
} :: { [string]: Cue }
AudioConfig.Priority = { "Divine", "Secret", "Mythic" }
-- egg rarity -> its track
AudioConfig.TrackOf = {
	Divine = "Divine",
	Eternal = "Divine",
	Secret = "Secret",
	Mythic = "Mythic",
} :: { [string]: string }
-- these only count once the server announced them (CaveBubbles "Announced": rare roll of a top tier)
AudioConfig.NeedsAnnounce = { Divine = true, Secret = true } :: { [string]: boolean }

AudioConfig.SpawnWindow = { Divine = 45, Secret = 45, Mythic = 20 } :: { [string]: number }
AudioConfig.ProximityRadius = 90
AudioConfig.Fade = 1.6 -- seconds to cross-fade between music tracks

-- short stings: reset spawns (global) and pickups (the carrier hears it flat, others in 3D)
AudioConfig.Jingles = {
	Legendary = { id = 1836632906, volume = 0.6 }, -- Hollywood Fanfare 6
	Epic = { id = 9038916885, volume = 0.5 }, -- Up For Anything - Tag3
} :: { [string]: Cue }
AudioConfig.JingleDuck = 0.3 -- lobby volume scale while a jingle plays

AudioConfig.Sfx = {
	Steal = { id = 9114373678, volume = 0.9 }, -- Fast Pass By Airy Whoosh
	Deposit = { id = 1848281810, volume = 0.65 }, -- Everything Works Out - Tag2
	Crack = { id = 9113959343, volume = 1 }, -- Crack Egg Crunchy
	Reveal = { id = 1839901334, volume = 0.55 }, -- Space Chimes
	RareReveal = { id = 1836473422, volume = 0.5 }, -- Victory Fanfare Sting
	Wind = { id = 9125742262, volume = 0.55 }, -- Plasma Trails airy whoosh (looped)
} :: { [string]: Cue }
-- hatching one of these adds the fanfare to the crack + chimes
AudioConfig.RareHatch = {
	Legendary = true,
	Mythic = true,
	Secret = true,
	Divine = true,
	Eternal = true,
	Boss = true,
	Cosmic = true,
} :: { [string]: boolean }

-- 3D one-shots fade out over this distance (studs)
AudioConfig.HearRange = 140

-- wind rush while running fast (studs/s, ground speed)
AudioConfig.WindFrom = 40
AudioConfig.WindFull = 160

-- Roblox's default footsteps (RbxCharacterSounds "Running") follow the character's speed
AudioConfig.StepBaseRate = 1.85 -- its stock PlaybackSpeed at walk speed 16
AudioConfig.StepMaxRate = 3
AudioConfig.StepVolume = 0.55

return AudioConfig
