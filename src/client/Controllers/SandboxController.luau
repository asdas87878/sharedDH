--!strict
-- The movement sandbox, client side (Studio only; docs/sandbox.md): for play-testing the ride, the jump and the camera
-- against the reference.
--   N: the tuning panel. Every number of the hop, the lock, Oxygen by land, crashes, props, the herd, the ride and the
--      camera, changed while playing (- and +, or type a value). A changed number turns yellow. "Copy changes" lists them, in the panel and in the Output, to paste
--      to Claude, who writes them into Config: nothing here outlives the play session.
--   V: the side view, square on to the way you are headed, to judge the arc.
--   R: back to the start of the lane, onto a fish.
--   F: back to the start, onto the next fish of the try-out list (TRY_OUT: one of each passive archetype, a combo, a
--      giant with no archetype, a plain Common, a Gold and a Rainbow), put there for you. For the props: the Humphead
--      Wrasse, Steller's Sea Cow, the megalodons and the Blue Whale break them; the rest go through and see them fade.
--   The arc trace: a dot every 0.04 s of the flight, left in the water until the next jump.
--   After each jump, its numbers: time in the air, height, distance, the speed it came down at.
-- The switches (no fail, endless air) are the server's (SandboxService); the rest is local.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local SandboxController = {}

-- F: the fish to try, in turn (fish id, variant): one of each passive archetype, a combo, a plain Common, the variants
local TRY_OUT: { { string } } = {
	{ "ReefShark", "" }, -- Predator (goes through props)
	{ "HumpheadWrasse", "" }, -- Breaker: breaks props, and is paid for it
	{ "Swordfish", "" }, -- Fast
	{ "Dolphin", "" }, -- Leaper
	{ "StellersSeaCow", "" }, -- Tank: breaks props, for a small crash
	{ "Megalodon", "" }, -- Predator, Frenzy; and a giant: breaks props
	{ "MoltenMegalodon", "" }, -- no archetype, a giant: breaks props
	{ "BlueWhale", "" }, -- Tank, Breaker
	{ "Clownfish", "" }, -- none: goes through props, which fade as it comes up to them
	{ "Clownfish", "Gold" },
	{ "Clownfish", "Rainbow" },
}
local tryOut = 0

-- group, key, step
local TUNABLES: { { any } } = {
	{ "Jump", "Window", 0.1 },
	{ "Jump", "Warn", 0.1 },
	{ "Jump", "AutoGrab", 1 },
	{ "Jump", "MinFlight", 0.05 },
	{ "Jump", "Cooldown", 0.05 },
	{ "Jump", "StrainLock", 0.05 },
	{ "Jump", "InputGap", 0.05 },
	{ "Jump", "LaunchTime", 0.05 },
	{ "Jump", "Launch", 0.05 },
	{ "Jump", "HopBoost", 2 },
	{ "Jump", "BoostFloor", 2 },
	{ "Jump", "AirShare", 0.05 },
	{ "Jump", "SpeedHalf", 0.1 },
	{ "Jump", "SpeedTail", 0.25 },
	{ "Jump", "StopTime", 0.1 },
	{ "Jump", "StopShare", 0.05 },
	{ "Jump", "FallSpeed", 5 },
	{ "Jump", "SinkCurve", 0.25 },
	{ "Jump", "AirSlowSpeed", 5 },
	{ "Jump", "AirFastSpeed", 5 },
	{ "Jump", "AirSlow", 0.05 },
	{ "Jump", "AirFast", 0.05 },
	{ "Jump", "AirLeast", 0.1 },
	{ "Jump", "RehookGuard", 0.05 },
	{ "Jump", "LandWait", 0.05 },
	{ "Jump", "HopGuard", 0.05 },
	{ "Jump", "MashMost", 0.1 },
	{ "Jump", "FreeLaunch", 5 },
	{ "Jump", "Apex", 1 },
	{ "Jump", "Ceiling", 1 },
	{ "Jump", "SeatRoom", 1 },
	{ "Jump", "FloatTime", 0.1 },
	{ "Jump", "FloatRise", 1 },
	{ "Jump", "Tilt", 5 },
	{ "Jump", "TiltFrom", 0.1 },
	{ "Jump", "TiltTo", 0.1 },
	{ "Jump", "DropTilt", 2 },
	{ "Jump", "DropTiltTime", 0.05 },
	{ "Jump", "Bank", 2 },
	{ "Jump", "FloorClearance", 1 },
	{ "Jump", "GrabRange", 5 },
	{ "Jump", "GrabNear", 5 },
	{ "Lock", "LastChance", 1 },
	{ "Jump", "GrabFullSpeed", 5 },
	{ "Net", "ReachLag", 0.05 },
	{ "Jump", "GrabSpeed", 10 },
	{ "Jump", "ReelTime", 0.02 },
	{ "Jump", "ReelCurve", 0.1 },
	{ "Jump", "ReelMin", 0.01 },
	{ "Jump", "ReelMax", 0.05 },
	{ "Jump", "ReelSwoop", 0.1 },
	{ "Jump", "ReelFov", 1 },
	{ "Jump", "LandFov", 1 },
	{ "Jump", "LandFovTime", 0.05 },
	{ "Jump", "LandKick", 0.05 },
	{ "Jump", "LandKickRate", 1 },
	{ "Jump", "LandKickDamp", 0.05 },
	{ "Jump", "LandShake", 0.1 },
	{ "Jump", "LandShakeTime", 0.02 },
	{ "Jump", "LandShakeRate", 1 },
	{ "Jump", "LandShakeRoll", 0.2 },
	{ "Jump", "LandShakeAt", 5 },
	{ "Jump", "LandShakeBySpeed", 0.05 },
	{ "Jump", "ReelTip", 5 },
	{ "Jump", "ReelTurnEnd", 0.05 },
	{ "Jump", "ReelSitStart", 0.05 },
	{ "Jump", "ReelFovCurve", 0.1 },
	{ "Jump", "TrailEvery", 0.005 },
	{ "Jump", "TrailLife", 0.05 },
	{ "Jump", "RingRadius", 1 },
	{ "Jump", "RingGrow", 5 },
	{ "Jump", "RingFar", 0.1 },
	{ "Jump", "RingFarFace", 0.05 },
	{ "Jump", "RingFollow", 1 },
	{ "Jump", "RingSpin", 5 },
	{ "Jump", "RingFace", 0.05 },
	{ "Jump", "RingPreview", 0.05 },
	{ "Jump", "RingEdge", 0.05 },
	{ "Jump", "FlyGlow", 0.05 },
	{ "Jump", "PreviewGlow", 0.05 },
	{ "Jump", "GlowFade", 0.05 },
	{ "Jump", "AckTime", 0.1 },
	{ "Jump", "RefusedTime", 0.1 },
	{ "Jump", "Slack", 0.1 },
	{ "Jump", "LandSlack", 2 },
	{ "Jump", "CameraPitch", 2 },
	{ "Jump", "CameraZoom", 0.05 },
	{ "Lock", "Cone", 2 },
	{ "Lock", "AimRadius", 1 },
	{ "Lock", "MaxAngle", 5 },
	{ "Lock", "AngleWeight", 0.05 },
	{ "Lock", "DistanceWeight", 0.01 },
	{ "Lock", "FarAim", 1 },
	{ "Lock", "LeftPenalty", 0.1 },
	{ "Lock", "Sticky", 0.05 },
	{ "Lock", "MinHold", 0.05 },
	{ "Lock", "KeepCone", 0.1 },
	{ "Lock", "SwitchTime", 0.05 },
	{ "Lock", "EdgeAim", 1 },
	{ "Lock", "FallbackRadius", 1 },
	{ "Lock", "Preview", 1 },
	-- Oxygen a second on a Common, land by land (the list Config.ZoneDrain)
	{ "ZoneDrain", 1, 2 },
	{ "ZoneDrain", 2, 10 },
	{ "ZoneDrain", 3, 20 },
	{ "ZoneDrain", 4, 100 },
	{ "ZoneDrain", 5, 500 },
	{ "ZoneDrain", 6, 1000 },
	{ "ZoneDrain", 7, 5000 },
	{ "ZoneDrain", 8, 10000 },
	{ "ZoneDrain", 9, 50000 },
	{ "ZoneDrain", 10, 200000 },
	-- (StartMax is live: the server reads every player's max again when it changes. Workspace's TestMaxOxygen
	-- attribute, when above 0, still wins over it.)
	{ "Oxygen", "StartMax", 10 },
	{ "Train", "Rate", 1 },
	{ "Train", "Share", 0.001 },
	{ "Train", "Radius", 1 },
	{ "Oxygen", "Refill", 0.05 },
	{ "Oxygen", "KeepUp", 0.25 },
	{ "Oxygen", "StrainTime", 0.05 },
	{ "Tame", "On", 1 },
	{ "Tame", "Time", 0.25 },
	{ "Tame", "Carry", 1 },
	-- how many times a Common's Oxygen a rarity takes a second (Config.RarityDrain)
	{ "RarityDrain", "Common", 0.05 },
	{ "RarityDrain", "Uncommon", 0.05 },
	{ "RarityDrain", "Rare", 0.1 },
	{ "RarityDrain", "Epic", 0.1 },
	{ "RarityDrain", "Legendary", 0.5 },
	{ "RarityDrain", "Mythic", 1 },
	{ "RarityDrain", "Secret", 1 },
	{ "Oxygen", "FreeDrain", 1 },
	{ "Oxygen", "FloatSpeed", 1 },
	{ "Oxygen", "SwimSpeed", 1 },
	{ "Oxygen", "DockRadius", 10 },
	{ "Oxygen", "DockWait", 0.5 },
	{ "Crash", "Slow", 0.05 },
	{ "Crash", "Recover", 0.1 },
	{ "Crash", "Cost", 0.01 },
	{ "Crash", "Floor", 1 },
	{ "Crash", "Cooldown", 0.1 },
	{ "Crash", "HeadOn", 0.05 },
	{ "Crash", "MinSpeed", 2 },
	{ "Crash", "Reach", 1 },
	{ "Crash", "Every", 0.05 },
	{ "Crash", "Kick", 0.05 },
	{ "Props", "GiantVolume", 500 },
	{ "Props", "WildBreaks", 1 },
	{ "Props", "Reach", 1 },
	{ "Props", "Topple", 2 },
	{ "Props", "MaxLoose", 5 },
	{ "Props", "Throw", 0.05 },
	{ "Props", "Scatter", 2 },
	{ "Props", "Pop", 1 },
	{ "Props", "Drag", 0.2 },
	{ "Props", "Sink", 2 },
	{ "Props", "Spin", 20 },
	{ "Props", "Hang", 0.1 },
	{ "Props", "FadeOut", 0.1 },
	{ "Props", "MaxDebris", 20 },
	{ "Props", "DebrisRange", 50 },
	{ "Props", "BreakBubbles", 2 },
	{ "Props", "BreakSound", 0.05 },
	{ "Props", "RegenRadius", 20 },
	{ "Props", "RegenDelay", 0.5 },
	{ "Props", "RegenEvery", 0.1 },
	{ "Props", "RebuildTime", 0.1 },
	{ "Props", "RebuildStagger", 0.1 },
	{ "Props", "FadeTo", 0.05 },
	{ "Props", "FadeEase", 1 },
	{ "Props", "FadeEvery", 0.05 },
	{ "Props", "FadeForBreakers", 1 },
	{ "Props", "PathWidth", 1 },
	{ "Props", "PathSlack", 1 },
	{ "Props", "TouchEase", 2 },
	{ "Props", "TouchSlack", 1 },
	{ "Props", "Shake", 0.1 },
	{ "Props", "ShakeTime", 0.05 },
	{ "Props", "ShakeAt", 5 },
	{ "Props", "ShakeBySpeed", 0.1 },
	{ "Props", "ShakeGap", 0.1 },
	{ "Props", "ShakeMin", 2 },
	{ "Props", "TouchBubbles", 2 },
	{ "Props", "TouchSound", 0.05 },
	{ "Props", "SideNear", 2 },
	{ "Props", "SideSlack", 1 },
	{ "Props", "ViewNear", 1 },
	{ "Props", "DebrisNear", 2 },
	{ "Props", "DebrisFar", 2 },
	{ "Props", "Slow", 0.05 },
	{ "Props", "Cost", 0.01 },
	{ "Props", "WildEvery", 0.1 },
	{ "Herd", "SpeedShare", 0.05 },
	{ "Herd", "RideHeight", 1 },
	{ "Herd", "RideHeightGain", 0.1 },
	{ "Herd", "RideHeightPitch", 5 },
	{ "Herd", "Ahead", 10 },
	{ "Herd", "Turn", 0.1 },
	{ "Herd", "DodgeShare", 0.05 },
	{ "Herd", "DodgeGap", 1 },
	{ "Herd", "DodgeLength", 1 },
	{ "Herd", "SmashLength", 2 },
	{ "Herd", "StraightShare", 0.05 },
	{ "Herd", "BreakLength", 2 },
	{ "Herd", "GiveSide", 1 },
	{ "Herd", "GiveAlong", 2 },
	{ "Herd", "GiveRate", 0.5 },
	{ "Ride", "RampTime", 0.1 },
	{ "Ride", "Surge", 0.05 },
	{ "Ride", "SurgeTime", 0.1 },
	{ "Ride", "CameraSteer", 1 },
	{ "Ride", "SteerEase", 1 },
	{ "Ride", "SteerRate", 10 },
	{ "Ride", "YawRate", 5 },
	{ "Ride", "TurnEase", 1 },
	{ "Ride", "Response", 2 },
	{ "Ride", "LandSteerTime", 0.05 },
	{ "Ride", "Bank", 2 },
	{ "Ride", "BankEase", 1 },
	{ "Ride", "MaxPitch", 5 },
	{ "Ride", "LaneMargin", 5 },
	{ "Ride", "SlowDownTime", 0.1 },
	{ "Ride", "SeatHeight", 0.1 },
	{ "Ride", "FloorClearance", 1 },
	{ "Ride", "Ceiling", 1 },
	{ "Ride", "SpeedSlack", 0.1 },
	-- The landing's slow-down (Hugo, 2026-11-12)
	{ "Ride", "Startle", 1 },
	{ "Ride", "StartleBrake", 0.05 },
	{ "Ride", "StartleSlow", 0.05 },
	{ "Ride", "StartleHold", 0.05 },
	{ "Ride", "StartleRecover", 0.1 },
	-- Angry mode (Config.Angry; the styles' own numbers are in Shared/AngryStyles). Test above 0 makes every fish
	-- you ride angry, with endless air on: 0.01 is the meter just turned red, 1 is empty
	{ "Angry", "Test", 0.25 },
	{ "Angry", "On", 1 },
	-- The wall ride (Config.Wall): the edge of the map and any wall
	{ "Wall", "On", 1 },
	{ "Wall", "Loss", 0.05 },
	{ "Wall", "Curve", 0.25 },
	{ "Wall", "Ease", 1 },
	{ "Wall", "Look", 0.05 },
	{ "Wall", "Gap", 0.5 },
	{ "Wall", "Soft", 1 },
	{ "Wall", "Feelers", 5 },
	{ "Wall", "Band", 0.5 },
	{ "Wall", "HeadOn", 1 },
	{ "Wall", "Blend", 1 },
	{ "Wall", "SwingKick", 0.05 },
	{ "Wall", "SwingMost", 1 },
	{ "Wall", "SwingRate", 0.05 },
	{ "Wall", "SwingDamp", 0.02 },
	{ "Wall", "SwingPitch", 5 },
	{ "Wall", "Lean", 1 },
	{ "Wall", "EdgeCost", 0.01 },
	{ "Wall", "EdgeBand", 1 },
	{ "Oxygen", "AngryAt", 0.05 },
	{ "Angry", "Tamed", 1 },
	{ "Angry", "Motion", 0.25 },
	{ "Angry", "EaseIn", 0.1 },
	{ "Angry", "EaseOut", 0.1 },
	{ "Angry", "Floor", 0.05 },
	{ "Angry", "HeatFrom", 0.05 },
	{ "Angry", "GiantLength", 2 },
	{ "Angry", "PulseSlow", 0.2 },
	{ "Angry", "PulseFast", 0.5 },
	{ "Angry", "PulseLow", 0.02 },
	{ "Angry", "PulseHigh", 0.05 },
	{ "Angry", "PulseEdge", 0.1 },
	{ "Angry", "PulseFade", 0.05 },
	-- The passive archetypes (Config.Archetype, by id; docs/design/archetypes.md) and how their moments feel
	-- (Config.ArchetypeFeel). F rides the next fish of the try-out list below.
	{ "Fast", "Surge", 0.05 },
	{ "Fast", "SurgeTime", 0.25 },
	{ "Predator", "Prey", 0.05 },
	{ "Predator", "Reach", 1 },
	{ "Predator", "Burst", 0.05 },
	{ "Predator", "BurstTime", 0.25 },
	{ "Predator", "Oxygen", 0.01 },
	{ "Predator", "Cooldown", 0.25 },
	{ "Frenzy", "Window", 0.5 },
	{ "Frenzy", "Stacks", 1 },
	{ "Frenzy", "BurstPer", 0.02 },
	{ "Frenzy", "TimePer", 0.1 },
	{ "Frenzy", "Cooldown", 0.1 },
	{ "Breaker", "Reach", 1 },
	{ "Breaker", "Burst", 0.02 },
	{ "Breaker", "BurstTime", 0.25 },
	{ "Breaker", "Oxygen", 0.01 },
	{ "Breaker", "Cooldown", 0.25 },
	{ "Breaker", "Crash", 0.1 },
	{ "Tank", "Drain", 0.05 },
	{ "Tank", "AngryAt", 0.05 },
	{ "Leaper", "Apex", 0.05 },
	{ "Leaper", "Air", 0.05 },
	{ "Leaper", "FloatTime", 0.1 },
	{ "ArchetypeFeel", "Motion", 0.25 },
	{ "ArchetypeFeel", "Lunge", 1 },
	{ "ArchetypeFeel", "LungeTime", 0.02 },
	{ "ArchetypeFeel", "Shudder", 1 },
	{ "ArchetypeFeel", "ShudderTime", 0.05 },
	{ "ArchetypeFeel", "BoostIn", 0.02 },
	{ "ArchetypeFeel", "BoostLines", 0.05 },
	{ "ArchetypeFeel", "EatFov", 1 },
	{ "ArchetypeFeel", "EatKick", 0.05 },
	{ "ArchetypeFeel", "EatBubbles", 2 },
	{ "ArchetypeFeel", "EatReach", 1 },
	{ "ArchetypeFeel", "EatSound", 0.1 },
	{ "ArchetypeFeel", "FrenzyFov", 1 },
	{ "ArchetypeFeel", "SmashFov", 1 },
	{ "ArchetypeFeel", "SmashShake", 0.1 },
	{ "ArchetypeFeel", "SmashBubbles", 2 },
	{ "ArchetypeFeel", "SmashReach", 1 },
	{ "ArchetypeFeel", "SmashSound", 0.1 },
	{ "ArchetypeFeel", "LaunchFov", 1 },
	{ "ArchetypeFeel", "LaunchLines", 0.1 },
	{ "ArchetypeFeel", "LeapFov", 1 },
	{ "ArchetypeFeel", "LeapBubbles", 2 },
	{ "ArchetypeFeel", "Words", 1 },
	{ "ArchetypeFeel", "WordTime", 0.1 },
	{ "ArchetypeFeel", "WordRise", 2 },
	{ "ArchetypeFeel", "Tags", 1 },
	{ "AngryTier", "Common", 0.02 },
	{ "AngryTier", "Uncommon", 0.02 },
	{ "AngryTier", "Rare", 0.02 },
	{ "AngryTier", "Epic", 0.02 },
	{ "AngryTier", "Legendary", 0.02 },
	{ "AngryTier", "Mythic", 0.02 },
	{ "AngryTier", "Secret", 0.02 },
	-- The rider's poses (Config.Pose) and the juice (Config.Feel)
	{ "Pose", "Blend", 1 },
	{ "Pose", "CrawlRate", 0.1 },
	{ "Pose", "CrawlKick", 0.5 },
	{ "Pose", "CrawlRoll", 2 },
	{ "Pose", "BreastRate", 0.05 },
	{ "Pose", "FloatTilt", 5 },
	{ "Pose", "PopTuck", 0.01 },
	{ "Pose", "Flip", 1 },
	{ "Pose", "FlipStart", 0.05 },
	{ "Pose", "FlipMin", 0.05 },
	{ "Pose", "RideCrouch", 2 },
	{ "Pose", "RideLean", 2 },
	{ "Pose", "BraceLean", 2 },
	{ "Feel", "PopFov", 1 },
	{ "Feel", "PopBurst", 2 },
	{ "Feel", "PopLines", 0.1 },
	{ "Feel", "ReelLines", 0.1 },
	{ "Feel", "BoltLines", 0.1 },
	{ "Feel", "BoltFov", 1 },
	{ "Feel", "LinesFade", 0.05 },
	{ "Feel", "LinesInner", 0.05 },
	{ "Feel", "Trail", 10 },
	{ "Feel", "Whoosh", 0.05 },
	{ "Feel", "WhooshPitch", 0.1 },
	{ "Feel", "Swish", 0.05 },
	{ "Feel", "Splash", 0.05 },
	{ "Feel", "SplashCount", 2 },
	{ "Feel", "SplashReach", 1 },
	{ "Camera", "Fov", 2 },
	{ "Camera", "SpeedFov", 2 },
	{ "Camera", "SpeedFovFrom", 5 },
	{ "Camera", "SpeedFovTo", 5 },
	{ "Camera", "Distance", 1 },
	{ "Camera", "Height", 0.5 },
	{ "Camera", "FocusHeight", 0.05 },
	{ "Camera", "ArmHeight", 0.05 },
	{ "Camera", "FocusTime", 0.02 },
	{ "Camera", "TurnTime", 0.01 },
	{ "Camera", "ZoomTime", 0.05 },
	{ "Camera", "FovTime", 0.05 },
	{ "Camera", "AutoRecentre", 1 },
	{ "Camera", "Recentre", 0.1 },
	{ "Camera", "LookBack", 0.5 },
	{ "Camera", "AirRest", 1 },
	{ "Camera", "StickSensitivity", 0.2 },
	{ "Camera", "AirMouseLook", 1 },
	{ "Camera", "MouseSensitivity", 0.001 },
	{ "Camera", "TouchSensitivity", 0.001 },
	{ "Camera", "RestPitch", 2 },
	{ "Camera", "PitchFollow", 0.5 },
	{ "Camera", "AirPitchFollow", 0.5 },
	{ "Camera", "PitchMin", 5 },
	{ "Camera", "PitchMax", 5 },
	{ "Camera", "WallGap", 0.1 },
	-- The look of the light (Config.Look; docs/design/lighting.md)
	{ "Look", "On", 1 },
	{ "Look", "Sky", 1 },
	{ "Look", "Brightness", 0.25 },
	{ "Look", "Exposure", 0.1 },
	{ "Look", "Contrast", 0.05 },
	{ "Look", "Saturation", 0.05 },
	{ "Look", "ColourBrightness", 0.05 },
	{ "Look", "BloomIntensity", 0.1 },
	{ "Look", "BloomSize", 4 },
	{ "Look", "BloomThreshold", 0.1 },
	{ "Look", "ShadowSoftness", 0.1 },
	{ "Look", "ClockTime", 0.5 },
	{ "Look", "Latitude", 5 },
	{ "Look", "EnvDiffuse", 0.1 },
	{ "Look", "EnvSpecular", 0.1 },
	{ "Look", "AmbientR", 5 },
	{ "Look", "AmbientG", 5 },
	{ "Look", "AmbientB", 5 },
	{ "Look", "OutdoorR", 5 },
	{ "Look", "OutdoorG", 5 },
	{ "Look", "OutdoorB", 5 },
	{ "Look", "TintR", 5 },
	{ "Look", "TintG", 5 },
	{ "Look", "TintB", 5 },
	{ "Animation", "Effort", 0.25 },
	{ "Animation", "EffortAccel", 0.005 },
	{ "Animation", "EffortBeat", 0.1 },
	{ "Animation", "LandEffort", 0.1 },
	{ "Animation", "LandEffortTime", 0.1 },
	{ "Animation", "CrashFlinch", 0.05 },
	{ "Animation", "Turn", 0.25 },
	{ "Animation", "TurnLead", 0.01 },
	{ "Animation", "TurnBend", 0.01 },
	{ "Animation", "TurnMax", 1 },
	{ "Animation", "TurnTotal", 5 },
	{ "Animation", "WildBank", 0.05 },
	{ "Animation", "WildBankMax", 2 },
	{ "Animation", "FinTurn", 0.1 },
	{ "Animation", "Body", 0.25 },
	{ "Animation", "Cadence", 1 },
	{ "Animation", "Jaw", 1 },
	{ "Animation", "Wave", 0.1 },
	{ "Animation", "LandDip", 0.1 },
	{ "Animation", "LandNod", 1 },
	{ "Animation", "LandDipTime", 0.1 },
	{ "Animation", "Wild", 0.1 },
	{ "Animation", "LandingMix", 1 },
	{ "Animation", "RiderFollow", 1 },
	{ "Animation", "RiderCalm", 0.1 },
	{ "Animation", "Brace", 0.05 },
	{ "Camera", "WheelStep", 0.5 },
	{ "Camera", "ZoomMin", 1 },
	{ "Camera", "ZoomMax", 2 },
	{ "Camera", "Submerge", 1 },
	{ "Camera", "WaterTop", 0.5 },
	{ "Camera", "SurfaceMargin", 0.5 },
	{ "Camera", "LightMargin", 0.5 },
	{ "Camera", "SurfaceKnee", 0.5 },
	{ "Camera", "SurfaceTime", 0.1 },
	{ "Camera", "FloatAbove", 1 },
	{ "Camera", "AirMargin", 0.5 },
	{ "Camera", "LightLayer", 0.5 },
	{ "Camera", "SurfaceTilt", 0.1 },
	{ "AimHud", "RefusedTime", 0.05 },
	{ "AimHud", "FollowRate", 2 },
	{ "AimHud", "PreviewTransparency", 0.05 },
	{ "AimHud", "PulsePeriod", 0.05 },
	{ "AimHud", "PulseWhiten", 0.05 },
	{ "AimHud", "PulseScale", 0.02 },
	{ "Net", "RangeSlack", 0.05 },
	{ "Switch", "HandBack", 0.1 },
	{ "Burst", "Count", 5 },
	{ "Burst", "Time", 0.1 },
	{ "Burst", "Reach", 1 },
	{ "Spawn", "PerThousand", 2 },
	{ "Spawn", "HeightMin", 2 },
	{ "Spawn", "HeightMax", 2 },
	{ "Spawn", "HeightFloor", 1 },
	{ "Spawn", "BigRise", 1 },
	{ "Spawn", "Space", 2 },
	{ "Spawn", "SpaceByLength", 0.1 },
	-- The tuning rows (docs/design/progression.md). Every fish's speed: wild fish, the glide and the server's speed
	-- check all follow at once.
	-- (Hugo, 2026-11-12, the reset: every fish has its own hand-set speed in Config.FishStats, no rarity or land
	-- factor; only the variant's comes on top, the same for every fish)
	{ "Speed", "Gold", 0.02 },
	{ "Speed", "Rainbow", 0.02 },
	-- the variants' chances (new fish only: the ones swimming keep theirs)
	{ "Variant", "Silver", 0.01 },
	{ "Variant", "Gold", 0.005 },
	{ "Variant", "Rainbow", 0.002 },
	-- the sizes' chances (new fish only; Normal is the rest), and how big each is
	{ "SizeChance", "Tiny", 0.01 },
	{ "SizeChance", "Big", 0.01 },
	{ "SizeChance", "Giant", 0.01 },
	{ "SizeChance", "Huge", 0.005 },
	{ "SizeChance", "Colossal", 0.005 },
	{ "SizeScale", "Tiny", 0.05 },
	{ "SizeScale", "Big", 0.05 },
	{ "SizeScale", "Giant", 0.05 },
	{ "SizeScale", "Huge", 0.1 },
	{ "SizeScale", "Colossal", 0.1 },
	-- grand fish: how many in every stretch of lane, and how long a stretch is (new fish only)
	{ "Grand", "Span", 50 },
	{ "Grand", "Least", 1 },
	{ "Grand", "Most", 1 },
	{ "Spawn", "KindTries", 1 },
	-- The share of spawns by rarity, land by land (Config.ZoneMix, one group a land). A changed share shows in the fish
	-- spawned from then on, not in the ones already swimming. A row whose rarity the land's mix doesn't have is left out.
	{ "MixShallows", "Common", 1 },
	{ "MixShallows", "Uncommon", 1 },
	{ "MixShallows", "Rare", 0.2 },
	{ "MixShallows", "Epic", 0.1 },
	{ "MixShallows", "Legendary", 0.1 },
	{ "MixCoralReef", "Common", 1 },
	{ "MixCoralReef", "Uncommon", 1 },
	{ "MixCoralReef", "Rare", 1 },
	{ "MixCoralReef", "Epic", 0.5 },
	{ "MixCoralReef", "Legendary", 0.2 },
	{ "MixKelpForest", "Uncommon", 1 },
	{ "MixKelpForest", "Rare", 1 },
	{ "MixKelpForest", "Epic", 1 },
	{ "MixKelpForest", "Legendary", 0.5 },
	{ "MixShipwrecks", "Uncommon", 1 },
	{ "MixShipwrecks", "Rare", 1 },
	{ "MixShipwrecks", "Epic", 1 },
	{ "MixShipwrecks", "Legendary", 0.5 },
	{ "MixOpenBlue", "Uncommon", 1 },
	{ "MixOpenBlue", "Rare", 1 },
	{ "MixOpenBlue", "Epic", 1 },
	{ "MixOpenBlue", "Legendary", 1 },
	{ "MixOpenBlue", "Mythic", 0.2 },
	{ "MixTwilight", "Rare", 1 },
	{ "MixTwilight", "Epic", 1 },
	{ "MixTwilight", "Legendary", 1 },
	{ "MixTwilight", "Mythic", 0.2 },
	{ "MixMidnight", "Rare", 1 },
	{ "MixMidnight", "Epic", 1 },
	{ "MixMidnight", "Legendary", 1 },
	{ "MixMidnight", "Mythic", 0.5 },
	{ "MixVents", "Epic", 1 },
	{ "MixVents", "Legendary", 1 },
	{ "MixVents", "Mythic", 0.5 },
	{ "MixBoneGraveyard", "Epic", 1 },
	{ "MixBoneGraveyard", "Legendary", 1 },
	{ "MixBoneGraveyard", "Mythic", 0.5 },
	{ "MixUnderworld", "Legendary", 1 },
	{ "MixUnderworld", "Mythic", 0.5 },
}

type Row = { Path: string, Group: string, Key: string, Step: number, Start: number, Box: TextBox }

local FONT = Enum.Font.GothamMedium
local DARK = Color3.fromRGB(26, 31, 41)
local MID = Color3.fromRGB(62, 72, 90)
local AMBER = Color3.fromRGB(255, 190, 70)
local WHITE = Color3.new(1, 1, 1)
local CHANGED = Color3.fromRGB(255, 221, 51)
local TRACE_DOTS = 110

local rows: { Row } = {}
local panel: Frame
local tag: TextLabel
local stats: TextLabel
local output: TextBox
local flagButtons: { [string]: TextButton } = {}

local traceOn = true
local traceFolder: Folder
local dots: { Part } = {}
local dotIndex = 0
local dotAt = 0

-- the flight being measured
local measuring = false
local flightFrom = Vector3.zero
local flightAt = 0
local flightTop = 0
local flightSpeed = 0

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class :: any)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function text(props: { [string]: any }, parent: Instance, class: string?): any
	props.Font = FONT
	props.TextSize = props.TextSize or 13
	props.TextColor3 = props.TextColor3 or WHITE
	props.BorderSizePixel = 0
	return new(class or "TextLabel", props, parent)
end

-- a tool's part: a small corner and a thin black line round it
local function edge(object: GuiObject)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, object)
	local line = new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(8, 10, 14) }, object)
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local function valueOf(row: Row): number
	return (Config :: any)[row.Group][row.Key]
end

local function show(row: Row)
	local value = valueOf(row)
	row.Box.Text = string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
	row.Box.TextColor3 = if math.abs(value - row.Start) > 1e-6 then CHANGED else WHITE
end

local function apply(row: Row, value: number)
	value = math.floor(value * 1000 + 0.5) / 1000
	(Config :: any)[row.Group][row.Key] = value
	Config.refresh()
	Net.Sandbox:FireServer("Tune", row.Path, value)
	show(row)
end

local function changes(): string
	local lines = {}
	for _, row in rows do
		local value = valueOf(row)
		if math.abs(value - row.Start) > 1e-6 then
			table.insert(
				lines,
				string.format("Config.%s = %s -- was %s", row.Path, tostring(value), tostring(row.Start))
			)
		end
	end
	return if #lines > 0 then table.concat(lines, "\n") else "no numbers changed"
end

-- the switches: name -> read, write
local FLAGS: { { any } } = {
	{
		"Sandbox on",
		function()
			return workspace:GetAttribute("Sandbox") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "On", on)
		end,
	},
	{
		"No fail (a sunk jump leaves you floating)",
		function()
			return workspace:GetAttribute("SandboxNoFail") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "NoFail", on)
		end,
	},
	{
		"Endless air (off: Oxygen drains by land)",
		function()
			return workspace:GetAttribute("SandboxEndlessAir") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "EndlessAir", on)
		end,
	},
	{
		"Side view (V)",
		function()
			return State.SideCam
		end,
		function(on: boolean)
			State.SideCam = on
		end,
	},
	{
		"Arc trace",
		function()
			return traceOn
		end,
		function(on: boolean)
			traceOn = on
		end,
	},
	{
		"Pull you onto the locked fish by itself when the glide ends",
		function()
			return Config.Jump.AutoGrab >= 2
		end,
		function(on: boolean)
			Config.Jump.AutoGrab = if on then 2 else 0
		end,
	},
}

local function showFlags()
	for _, flag in FLAGS do
		local button = flagButtons[flag[1]]
		if button then
			local on = flag[2]()
			button.Text = (if on then "[x]  " else "[  ]  ") .. flag[1]
			button.TextColor3 = if on then WHITE else Color3.fromRGB(150, 165, 185)
		end
	end
	tag.Text = if workspace:GetAttribute("Sandbox") == true
		then "SANDBOX    N numbers    V side view    R back to the start"
		else "sandbox off    N to open its panel"
end

local function build()
	local gui = new("ScreenGui", {
		Name = "Sandbox",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, State.Player:WaitForChild("PlayerGui"))

	tag = text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(440, 22),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, gui)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, tag)
	edge(tag)
	stats = text({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.fromOffset(440, 40),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "jump to see its numbers here",
	}, gui)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, stats)
	edge(stats)

	panel = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 50),
		Size = UDim2.new(0, 320, 1, -110),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	-- a tool's look (UI.Kit): dark slate, squared paper, a thick black outline, an amber line under the title
	local slate = table.clone(Kit.Themes.Tool)
	slate.Fade = 0.04
	slate.Radius = 8
	Kit.dress(panel, slate)
	Kit.grid(panel, 24, 320, 1400)
	text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		TextSize = 15,
		TextColor3 = AMBER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "MOVEMENT SANDBOX",
	}, panel)
	new("Frame", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 2),
		BackgroundColor3 = AMBER,
		BorderSizePixel = 0,
	}, panel)

	local y = 36
	for _, flag in FLAGS do
		local button = text({
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 22),
			BackgroundColor3 = MID,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = flag[1],
			AutoButtonColor = true,
		}, panel, "TextButton")
		new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, button)
		edge(button)
		button.Activated:Connect(function()
			flag[3](not flag[2]())
			task.delay(0.15, showFlags) -- the server's switches come back as attributes
			showFlags()
		end)
		flagButtons[flag[1]] = button
		y += 24
	end

	local copy = text({
		Position = UDim2.fromOffset(10, y + 4),
		Size = UDim2.new(0.5, -14, 0, 24),
		BackgroundColor3 = Color3.fromRGB(60, 120, 90),
		Text = "Copy changes",
	}, panel, "TextButton")
	local reset = text({
		Position = UDim2.new(0.5, 4, 0, y + 4),
		Size = UDim2.new(0.5, -14, 0, 24),
		BackgroundColor3 = Color3.fromRGB(120, 70, 60),
		Text = "Numbers back to start",
	}, panel, "TextButton")
	y += 36
	edge(copy)
	edge(reset)

	output = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 120),
		BackgroundColor3 = Color3.fromRGB(8, 14, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextEditable = false,
		TextSize = 12,
		Text = "Copy changes lists the changed numbers here: click in, Ctrl+A, Ctrl+C, and paste them to Claude.",
	}, panel, "TextBox")
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, output)
	edge(output)

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 1, -y - 140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local order = 0
	local lastGroup = ""
	for _, tunable in TUNABLES do
		local group, key, step = tunable[1], tunable[2], tunable[3]
		local start = (Config :: any)[group][key]
		if type(start) == "number" then
			if group ~= lastGroup then
				lastGroup = group
				order += 1
				text({
					Size = UDim2.new(1, -8, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = AMBER,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = group,
					LayoutOrder = order,
				}, list)
			end
			order += 1
			local line =
				new("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, list)
			text({
				Size = UDim2.new(1, -132, 1, 0),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = if type(key) == "number" then "land " .. key else key,
			}, line)
			local minus = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -104, 0, 0),
				Size = UDim2.fromOffset(24, 22),
				BackgroundColor3 = MID,
				Text = "-",
			}, line, "TextButton")
			local box = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -28, 0, 0),
				Size = UDim2.fromOffset(72, 22),
				BackgroundColor3 = Color3.fromRGB(8, 14, 24),
				ClearTextOnFocus = false,
				Text = "",
			}, line, "TextBox")
			local plus = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(24, 22),
				BackgroundColor3 = MID,
				Text = "+",
			}, line, "TextButton")
			edge(minus)
			edge(box)
			edge(plus)
			local row: Row =
				{ Path = group .. "." .. key, Group = group, Key = key, Step = step, Start = start, Box = box }
			table.insert(rows, row)
			show(row)
			minus.Activated:Connect(function()
				apply(row, valueOf(row) - row.Step)
			end)
			plus.Activated:Connect(function()
				apply(row, valueOf(row) + row.Step)
			end)
			box.FocusLost:Connect(function()
				local typed = tonumber(box.Text)
				if typed then
					apply(row, typed)
				else
					show(row)
				end
			end)
		end
	end

	copy.Activated:Connect(function()
		local listed = changes()
		output.Text = listed
		print("[Sandbox] changed numbers:\n" .. listed)
	end)
	reset.Activated:Connect(function()
		for _, row in rows do
			if math.abs(valueOf(row) - row.Start) > 1e-6 then
				apply(row, row.Start)
			end
		end
	end)
	showFlags()
end

local function buildTrace()
	traceFolder = Instance.new("Folder")
	traceFolder.Name = "SandboxTrace"
	for _ = 1, TRACE_DOTS do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.7, 0.7, 0.7)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = WHITE
		dot.Transparency = 1
		dot.Parent = traceFolder
		table.insert(dots, dot)
	end
	traceFolder.Parent = workspace.CurrentCamera
end

local function step()
	local _, root = State.character()
	if not root then
		return
	end
	local jumping = State.Mode == "Jumping"
	if jumping and not measuring then
		-- a jump begins: its numbers and its trace start again
		measuring = true
		flightFrom = root.Position
		flightAt = os.clock()
		flightTop = 0
		flightSpeed = 0
		dotIndex = 0
		dotAt = 0
		for _, dot in dots do
			dot.Transparency = 1
		end
	end
	if jumping then
		flightTop = math.max(flightTop, root.Position.Y - flightFrom.Y)
		flightSpeed = State.Speed
		-- (live through the hop: the speed across the water and the hook's reach it gives right now)
		if State.Reach then
			stats.Text =
				string.format("in the air: %.0f studs a second   the hook reaches %.0f studs", State.Speed, State.Reach)
		end
		if traceOn and os.clock() - dotAt >= 0.04 and dotIndex < TRACE_DOTS then
			dotAt = os.clock()
			dotIndex += 1
			local dot = dots[dotIndex]
			dot.Position = root.Position
			dot.Transparency = 0.1
		end
	elseif measuring then
		measuring = false
		local along = (root.Position - flightFrom) * Vector3.new(1, 0, 1)
		stats.Text = string.format(
			"last jump: %s   %.2f s in the air   %.1f studs up   %.0f studs along   came down at %.0f studs a second",
			if State.Mode == "Riding" then "landed" else "sank",
			os.clock() - flightAt,
			flightTop,
			along.Magnitude,
			flightSpeed
		)
	end
end

function SandboxController.Start()
	if not RunService:IsStudio() then
		return
	end
	build()
	buildTrace()
	for _, attribute in { "Sandbox", "SandboxNoFail", "SandboxEndlessAir" } do
		workspace:GetAttributeChangedSignal(attribute):Connect(showFlags)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			panel.Visible = not panel.Visible
		elseif workspace:GetAttribute("Sandbox") ~= true then
			return
		elseif input.KeyCode == Enum.KeyCode.V then
			State.SideCam = not State.SideCam
			showFlags()
		elseif input.KeyCode == Enum.KeyCode.R then
			Net.Sandbox:FireServer("Reset")
		elseif input.KeyCode == Enum.KeyCode.F then
			-- onto the next fish of the try-out list: one of each passive archetype, a combo and a plain Common
			tryOut = tryOut % #TRY_OUT + 1
			local pick = TRY_OUT[tryOut]
			print(string.format("[Sandbox] riding %s%s", pick[1], if pick[2] ~= "" then " (" .. pick[2] .. ")" else ""))
			Net.Sandbox:FireServer("Ride", pick[1], pick[2])
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return SandboxController
