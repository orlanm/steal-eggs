-- Mommy visuals are local; pickup, tackle, and respawn timing are server-owned.
-- Visual reference: ReplicatedStorage.BabyBeastsShared.MommyAssets.MommyTrex
-- (imported Meshy_AI_Geometric_Predator mesh + SurfaceAppearance).
return table.freeze({
	Enabled = true,
	TemplateName = "MommyTrex",
	MeshId = "rbxassetid://121948111786836",
	TextureId = "rbxassetid://106402435800166",
	ColorMap = "rbxassetid://106402435800166",
	NormalMap = "rbxassetid://109578016489289",
	MetalnessMap = "rbxassetid://110179856217230",
	RoughnessMap = "rbxassetid://110957398076939",
	NativeSize = Vector3.new(2.122, 1.697, 3.325),
	-- Zone 2 (Lake) Lava Leviathan from Blender (Meshy 1019180449).
	LeviathanNativeSize = Vector3.new(1.193, 1.352, 3.325),
	LeviathanTextureId = "rbxassetid://97478111462843",
	LeviathanNormalMap = "rbxassetid://94391718844448",
	LeviathanHabitats = table.freeze({ "Zone02" }),
	-- Zone 3 (Desert) Neon Shell Leviathan / turtle from Blender (Meshy 1019213926).
	TurtleNativeSize = Vector3.new(3.579, 2.090, 3.325),
	TurtleTextureId = "rbxassetid://118977263734231",
	TurtleNormalMap = "rbxassetid://140248423198897",
	TurtleHabitats = table.freeze({ "Zone03" }),
	SnoutOffset = 1.662,
	RestInset = 18,
	RestDrop = 10,
	-- Share of the guard's height that stays under the water while it swims.
	SubmergeFraction = 0.25,
	OpeningPad = 0.72,
	ChaseSpeed = 30,
	GateSeconds = 1.0,
	ReplicationRate = 15,
	CatchReach = 8,
	-- Mommy stays home until the player is this far from the bubble capture point.
	ChaseStartDistance = 15,
	-- Brief nose-hit camera beat; mommy turns for home immediately after contact.
	TackleHoldSeconds = 0.28,
	ReturnTurnSeconds = 0.35,
	ThrowSeconds = 1.6,
	ThrowArcHeight = 18,
	-- Smooth tip onto the back (radians). Multi-axis spin was removed — it shook the avatar.
	ThrowPitch = 1.35,
	-- Loud impact hum when mommy connects (client).
	TackleHumSoundId = "rbxassetid://9120386436",
	TackleHumVolume = 2.4,
	TackleHumPlaybackSpeed = 0.55,
	-- R15 ragdoll knockdown (_blender/ragdoll/create_ragdoll_anim.py): kicked up, slow-motion spin,
	-- face-down slam at RagdollLandTime, bounce, crumple. The clip carries the body's height and tumble;
	-- the server slides the upright root along the floor until RagdollStopTime.
	RagdollAnimationId = "rbxassetid://139015953194069",
	RagdollLandTime = 1.12,
	RagdollStopTime = 1.7,
	-- share of the slide distance covered while airborne (the rest skids after landing)
	RagdollAirShare = 0.55,
	-- Wall crash knockdown (WallImpact): only a huge, near head-on hit ragdolls; anything softer just
	-- stops the player against the wall. Impact = speed into the wall (along its normal), studs/s.
	WallRagdollMinImpact = 250,
	WallRagdollMaxAngle = 30, -- degrees off head-on
	WallRagdollMinStop = 0.7, -- share of the speed lost in one frame (a dead stop, not a scrape)
	SlideDistance = 26,
	LandedHoldSeconds = 0.85,
	ReturnSeconds = 2.4,
	RespawnGraceSeconds = 2,
	FallSeconds = 0.4,
	ThrowSpeed = 72,
	ThrowUp = 48,
	StoppedSeconds = 0.85,
})
