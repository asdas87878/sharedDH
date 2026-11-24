--!strict
-- The shopkeepers behind the hub's stands, and the few props round each (Hugo, 2026-11-23: "Add specialised
-- characters behind every stand ... a looping idle animation where they stand while bobbing up and down a little
-- smoothly then doing something for a second, they should also follow the player when the player gets close ... add
-- small same styled fitting props around the stands"). The tables, and under them the sums that pose a keeper from
-- them: Controllers/KeeperController builds the keepers from plain Parts on each player's own machine, so nothing is
-- uploaded and nothing is added to the place.
--
-- EVERYTHING BETWEEN THE TWO MARKS IS PLAIN TABLES OF NUMBERS AND WORDS, nothing worked out: tools/keepers/keepers.py
-- reads the same text to draw the design sheet (docs/attachments/hub-keepers-1.png) and to check that nothing stands
-- inside a stall (tools/keepers/check.py). Keep it that way. The sums under the marks are written a second time in
-- keepers.py, and tools/keepers/sums_check.py holds the two against each other: change both together.
--
-- A stand's own space: the floor under the middle of its counter (a stall: its CounterTop) or of its glowing core
-- (the Fuse machine), z towards its floor ring, x to the right as seen from the ring, y up. Studs.
-- A keeper's own space: its feet, the same axes. It is drawn in its "bind" pose (arms straight out in front), and each
-- joint's rest turn then poses it.
--   Joint  { name, parent, x, y, z, rx, ry, rz }     where it turns (keeper space, bind pose), its rest turn (degrees)
--     a parent comes before its children; "Root" is the keeper's own space and never moves; the look turns "Body"
--     (the waist) and "Head"
--   Part   { joint, shape, sx, sy, sz, x, y, z, rx, ry, rz, colour, options }     (keeper space, bind pose)
--   Prop   { shape, sx, sy, sz, x, y, z, rx, ry, rz, colour, options }            (stand space)
--     shape: "Block", "Ball" (give it three equal sizes) or "Cylinder" (its length is its x, as Roblox's)
--     turns are CFrame.Angles(rx, ry, rz), in degrees
--     options (may be left out): Mat = "Neon", See = 0 to 1 (see-through), Stud = true (the map's stud picture on
--     its top), Light = { range, brightness } (a small light of its own colour)
--   Sway   { joint, seconds, phase, rx, ry, rz, dx, dy, dz }   the idle's small swing: a sine of that many seconds,
--     its phase in turns (0 to 1), the most it turns (degrees) and moves (studs)
--   Track  { joint, { t, rx, ry, rz, dx, dy, dz }, ... }       the one-second action: keys at t (0 to 1 of the
--     action's Time), eased between; every track starts and ends at rest
export type Row = { any }
export type Action = { Time: number, Every: { number }, Tracks: { Row } }
export type Keeper = {
	Id: string, -- the model's name
	Station: string, -- its stand: the Model's name under Dock.Stations
	Stand: string, -- the part of the station its stand space is read from: "CounterTop" or "Core"
	At: { number }, -- where its feet are, x and z in stand space
	Joints: { Row },
	Parts: { Row },
	Bob: { number }, -- the idle: studs up and down, seconds for one
	Sway: { Row },
	Action: Action,
	Props: { Row },
}
export type Look = {
	Near: number,
	Far: number,
	Switch: number,
	RearIn: number,
	RearOut: number,
	Body: number,
	BodyShare: number,
	Head: number,
	Up: number,
	Down: number,
	Time: number,
	Animate: number,
	Hide: number,
	Every: number,
	CounterTall: number,
	CoreAhead: number,
	Least: number,
	Most: number,
	Reach: number,
	Stud: string,
}
export type Anim = { [string]: { number } } -- a joint's six numbers: its turn (rx, ry, rz, degrees), its move (studs)
type Module = {
	Look: Look,
	Colours: { [string]: { number } },
	List: { Keeper },
	ease: (k: number) -> number,
	trackAt: (track: Row, t: number) -> (number, number, number, number, number, number),
	anim: (keeper: Keeper, idle: number?, action: number?, into: Anim?) -> Anim,
	lookSplit: (yaw: number, pitch: number) -> (number, number, number),
	aim: (at: Vector3) -> (number, number),
	pivots: (keeper: Keeper) -> { [string]: Vector3 },
	joints: (
		keeper: Keeper,
		scale: number,
		anim: Anim?,
		body: number,
		head: number,
		tip: number,
		into: { [string]: CFrame }?
	) -> { [string]: CFrame },
	offset: (keeper: Keeper, part: Row, scale: number) -> CFrame,
	propAt: (prop: Row, scale: number) -> CFrame,
	standSpace: (anchor: Vector3, ring: Vector3, floor: number) -> CFrame?,
}
local Keepers = ({} :: any) :: Module

--<<DATA
-- The engine's numbers, the same for every keeper
Keepers.Look = {
	Near = 22, -- a player this near (studs, from the keeper's head) is looked at: every edge of a stand's ring
	Far = 27, -- and is let go of past this
	Switch = 3, -- another player has to be this much nearer than the one looked at to be looked at instead
	RearIn = 105, -- degrees off straight ahead: a player further round than this, behind the keeper, is not picked up
	RearOut = 125, -- and one being looked at is let go of past this (the stalls have no back wall)
	Body = 14, -- the most the upper body turns at the waist, degrees
	BodyShare = 0.25, -- the share of the turn the body takes; the head takes the rest
	Head = 56, -- the most the head turns on the body
	Up = 6, -- the most the head tips up: little, as a hat that tips back goes up behind the awning's lip for a player
	-- at the counter (tools/keepers/check.py), and the camera looks down on the keeper anyway
	Down = 16, -- and down
	Time = 0.32, -- seconds the turn takes to catch up (eased in and out)
	Animate = 150, -- studs from the camera within which a keeper moves
	Hide = 420, -- past this it is taken out of the world
	Every = 1, -- seconds between looks at the stations (a stand may stream in late)
	CounterTall = 2.94, -- the counter the keepers are drawn for, studs over the floor: a taller one makes them bigger
	CoreAhead = 11.55, -- the Fuse machine as drawn: its ring's middle this far in front of its core
	Least = 0.7, -- a keeper and its props are never made smaller than this share of their drawn size
	Most = 1.5, -- or bigger than this
	Reach = 4.5, -- a keeper stands on the highest solid piece of its station under its feet, up to this high
	Stud = "rbxassetid://80588427262742", -- the map's stud picture (art/map/textures.json, tile3), 16 studs a tile
}

Keepers.Colours = {
	-- shared
	Eye = { 36, 40, 58 },
	White = { 248, 246, 238 },
	Wood = { 172, 124, 70 },
	WoodDark = { 124, 82, 46 },
	Iron = { 84, 90, 108 },
	IronLight = { 138, 146, 164 },
	Brass = { 232, 180, 66 },
	BrassDark = { 190, 136, 44 },
	Ice = { 214, 238, 250 },
	Water = { 86, 190, 232 },
	Rope = { 222, 196, 138 },
	-- the fishmonger (SELL, red)
	Oilskin = { 252, 204, 44 },
	OilskinDark = { 226, 160, 28 },
	Skin = { 250, 200, 158 },
	Nose = { 238, 142, 124 },
	Kerchief = { 232, 58, 58 },
	KerchiefDark = { 190, 40, 46 },
	Welly = { 44, 92, 84 },
	FishOrange = { 255, 142, 52 },
	FishFin = { 232, 88, 40 },
	FishBlue = { 70, 150, 240 },
	FishBlueFin = { 44, 104, 200 },
	Cooler = { 240, 244, 248 },
	Bucket = { 110, 150, 190 },
	-- the sea mystic (AURAS, purple): no purple on her, so she stands out of her stall
	Robe = { 26, 128, 150 },
	RobeDark = { 18, 92, 118 },
	RobeLight = { 60, 176, 186 },
	Shell = { 252, 240, 222 },
	ShellPink = { 255, 190, 200 },
	AquaSkin = { 156, 228, 222 },
	Jelly = { 255, 138, 182 },
	JellyLight = { 255, 198, 220 },
	Pearl = { 250, 250, 255 },
	PearlGlow = { 190, 255, 248 },
	AuraPurple = { 160, 70, 255 },
	AuraPink = { 255, 110, 200 },
	AuraCyan = { 90, 230, 255 },
	Starfish = { 255, 150, 96 },
	Glass = { 190, 235, 250 },
	-- the diver (SUBMARINE, teal)
	Canvas = { 238, 224, 190 },
	CanvasDark = { 204, 184, 142 },
	SubTeal = { 24, 176, 152 },
	Porthole = { 30, 62, 84 },
	-- the tinkerer (FUSE, yellow and blue)
	FuseBlue = { 58, 112, 224 },
	Trouser = { 50, 64, 112 },
	Apron = { 216, 170, 104 },
	SkinTan = { 222, 164, 118 },
	Octo = { 255, 122, 98 },
	OctoDark = { 218, 82, 72 },
	OctoLight = { 255, 196, 172 },
	Lens = { 120, 235, 255 },
	FuseGlow = { 255, 226, 110 },
	CoralPink = { 255, 128, 150 },
	CoralOrange = { 255, 160, 80 },
	CoralTeal = { 60, 200, 190 },
}

Keepers.List = {
	{
		Id = "Fishmonger",
		Station = "Sell",
		Stand = "CounterTop",
		At = { 0, -2 },
		Joints = {
			{ "Body", "Root", 0, 1.2, 0, 0, 0, 0 },
			{ "Head", "Body", 0, 3.15, 0.25, 0, 0, 0 },
			{ "ArmL", "Body", 1.26, 3.2, 0, -9, -14, 0 },
			{ "ArmR", "Body", -1.26, 3.2, 0, -9, -8, 0 },
			{ "Item", "ArmR", -1.26, 3.2, 1.42, 9, 8, 0 },
			{ "Tail", "Item", -2.28, 3.55, 1.6, 0, 0, 0 },
		},
		Parts = {
			-- wellies
			{ "Root", "Block", 0.85, 1.25, 0.86, 0.47, 0.625, 0, 0, 0, 0, "Welly" },
			{ "Root", "Block", 0.85, 1.25, 0.86, -0.47, 0.625, 0, 0, 0, 0, "Welly" },
			{ "Root", "Block", 0.85, 0.42, 0.5, 0.47, 0.21, 0.6, 0, 0, 0, "Welly" },
			{ "Root", "Block", 0.85, 0.42, 0.5, -0.47, 0.21, 0.6, 0, 0, 0, "Welly" },
			-- the oilskin coat
			{ "Body", "Block", 1.9, 2.1, 1, 0, 2.25, 0, 0, 0, 0, "Oilskin" },
			{ "Body", "Block", 2.04, 0.44, 1.12, 0, 1.44, 0, 0, 0, 0, "OilskinDark" },
			{ "Body", "Block", 0.3, 1.5, 0.08, 0, 2.3, 0.52, 0, 0, 0, "OilskinDark" },
			{ "Body", "Block", 0.2, 0.2, 0.1, 0, 2.7, 0.56, 0, 0, 0, "Eye" },
			{ "Body", "Block", 0.2, 0.2, 0.1, 0, 2.1, 0.56, 0, 0, 0, "Eye" },
			-- the neckerchief, over the shoulders
			{ "Body", "Block", 2, 0.3, 1.08, 0, 3.24, 0, 0, 0, 0, "Kerchief" },
			{ "Body", "Block", 0.4, 0.36, 0.16, 0.56, 3.2, 0.56, 0, 0, 18, "KerchiefDark" },
			-- the head, sunk in the collar: a full white beard, a moustache, a red nose, bushy brows
			{ "Head", "Block", 1.44, 1, 1.3, 0, 3.62, 0.3, 0, 0, 0, "Skin" },
			{ "Head", "Block", 1.52, 0.5, 0.56, 0, 3.36, 0.72, 0, 0, 0, "White" },
			{ "Head", "Block", 0.92, 0.18, 0.16, 0, 3.64, 1, 0, 0, 0, "White" },
			{ "Head", "Block", 0.3, 0.26, 0.26, 0, 3.76, 1.04, 0, 0, 0, "Nose" },
			{ "Head", "Block", 0.18, 0.2, 0.08, 0.34, 3.87, 0.96, 0, 0, 0, "Eye" },
			{ "Head", "Block", 0.18, 0.2, 0.08, -0.34, 3.87, 0.96, 0, 0, 0, "Eye" },
			{ "Head", "Block", 0.44, 0.12, 0.12, 0.34, 4.02, 0.98, 0, 0, -9, "White" },
			{ "Head", "Block", 0.44, 0.12, 0.12, -0.34, 4.02, 0.98, 0, 0, 9, "White" },
			-- the sou'wester, pulled down to the brows: a wide brim, a low crown
			{ "Head", "Block", 2.04, 0.12, 1.8, 0, 4.07, 0.26, 0, 0, 0, "OilskinDark" },
			{ "Head", "Block", 1.5, 0.12, 1.1, 0, 4.15, 0.45, 0, 0, 0, "Oilskin" },
			-- the arms: a sleeve and a hand each
			{ "ArmL", "Block", 0.5, 0.5, 1.3, 1.26, 3.2, 0.55, 0, 0, 0, "Oilskin" },
			{ "ArmL", "Block", 0.5, 0.5, 0.45, 1.26, 3.2, 1.42, 0, 0, 0, "Skin" },
			{ "ArmR", "Block", 0.5, 0.5, 1.3, -1.26, 3.2, 0.55, 0, 0, 0, "Oilskin" },
			{ "ArmR", "Block", 0.5, 0.5, 0.45, -1.26, 3.2, 1.42, 0, 0, 0, "Skin" },
			-- the catch, held up on his palm with its side to the customer: a snout, a body with a white band, an
			-- eye, a back fin, and a forked tail that still flaps
			{ "Item", "Block", 1.24, 0.6, 0.34, -1.66, 3.55, 1.6, 0, 0, 0, "FishOrange" },
			{ "Item", "Block", 0.3, 0.42, 0.3, -0.92, 3.53, 1.6, 0, 0, 0, "FishOrange" },
			{ "Item", "Block", 0.2, 0.62, 0.36, -1.46, 3.55, 1.6, 0, 0, 0, "White" },
			{ "Item", "Block", 0.12, 0.12, 0.38, -1.14, 3.65, 1.6, 0, 0, 0, "Eye" },
			{ "Item", "Block", 0.6, 0.2, 0.1, -1.72, 3.93, 1.6, 0, 0, 0, "FishFin" },
			{ "Tail", "Block", 0.3, 0.3, 0.24, -2.38, 3.55, 1.6, 0, 0, 0, "FishOrange" },
			{ "Tail", "Block", 0.56, 0.22, 0.12, -2.68, 3.73, 1.6, 0, 0, -40, "FishFin" },
			{ "Tail", "Block", 0.56, 0.22, 0.12, -2.68, 3.37, 1.6, 0, 0, 40, "FishFin" },
		},
		Bob = { 0.11, 2.4 },
		Sway = {
			{ "Head", 4.8, 0, 0, 0, 2, 0, 0, 0 },
			{ "ArmR", 2.4, 0.3, 1.5, 0, 0, 0, 0, 0 },
			{ "Tail", 1.1, 0, 0, 0, 9, 0, 0, 0 },
		},
		-- holds the catch out over the counter to the customer, where it thrashes in his hand; he looks at it
		Action = {
			Time = 1.4,
			Every = { 4.5, 8 },
			Tracks = {
				{ "ArmR", { 0.22, -1, 24, 0, 0, 0, 0.25 }, { 0.72, -1, 24, 0, 0, 0, 0.25 } },
				{
					"Item",
					{ 0.22, 0, 0, 0, 0, 0, 0 },
					{ 0.32, 0, 0, 14, 0, 0, 0 },
					{ 0.42, 0, 0, -3, 0, 0, 0 },
					{ 0.52, 0, 0, 14, 0, 0, 0 },
					{ 0.62, 0, 0, -3, 0, 0, 0 },
					{ 0.72, 0, 0, 8, 0, 0, 0 },
					{ 0.86, 0, 0, 0, 0, 0, 0 },
				},
				{
					"Tail",
					{ 0.22, 0, 0, 0, 0, 0, 0 },
					{ 0.32, 0, 0, 16, 0, 0, 0 },
					{ 0.42, 0, 0, -12, 0, 0, 0 },
					{ 0.52, 0, 0, 16, 0, 0, 0 },
					{ 0.62, 0, 0, -12, 0, 0, 0 },
					{ 0.72, 0, 0, 12, 0, 0, 0 },
					{ 0.86, 0, 0, 0, 0, 0, 0 },
				},
				{ "Head", { 0.22, 0, -12, 3, 0, 0, 0 }, { 0.72, 0, -12, 3, 0, 0, 0 } },
			},
		},
		Props = {
			-- two fish crates, the top one open on ice
			{ "Block", 1.9, 0.9, 1.4, -5.95, 0.45, -0.75, 0, 0, 0, "Wood" },
			{ "Block", 1.96, 0.2, 1.46, -5.95, 0.24, -0.75, 0, 0, 0, "WoodDark" },
			{ "Block", 1.96, 0.2, 1.46, -5.95, 0.7, -0.75, 0, 0, 0, "WoodDark" },
			{ "Block", 1.7, 0.8, 1.3, -6, 1.3, -0.8, 0, 14, 0, "Wood" },
			{ "Block", 1.76, 0.2, 1.36, -6, 1.5, -0.8, 0, 14, 0, "WoodDark" },
			{ "Block", 1.5, 0.2, 1.1, -6, 1.74, -0.8, 0, 14, 0, "Ice", { Stud = true } },
			{ "Block", 0.95, 0.3, 0.4, -6.2, 1.96, -0.62, 0, 32, 0, "FishOrange" },
			{ "Block", 0.1, 0.34, 0.5, -6.68, 1.98, -0.32, 0, 32, 0, "FishFin" },
			{ "Block", 0.95, 0.3, 0.4, -5.72, 1.96, -1.02, 0, -12, 0, "FishBlue" },
			{ "Block", 0.1, 0.34, 0.5, -5.2, 1.98, -1.13, 0, -12, 0, "FishBlueFin" },
			-- an ice box
			{ "Block", 1.6, 1, 1.2, -5.85, 0.5, -2.75, 0, -6, 0, "Cooler" },
			{ "Block", 1.7, 0.28, 1.3, -5.85, 1.14, -2.75, 0, -6, 0, "Kerchief", { Stud = true } },
			{ "Block", 0.8, 0.12, 0.14, -5.85, 1.36, -2.75, 0, -6, 0, "Eye" },
			-- a bucket of water with a tail sticking out
			{ "Cylinder", 1, 1.15, 1.15, 5.75, 0.5, -0.5, 0, 0, 90, "Bucket" },
			{ "Cylinder", 0.14, 1.28, 1.28, 5.75, 1, -0.5, 0, 0, 90, "IronLight" },
			{ "Cylinder", 0.06, 1.02, 1.02, 5.75, 1.06, -0.5, 0, 0, 90, "Water" },
			{ "Block", 0.12, 0.5, 0.56, 5.8, 1.3, -0.5, 20, 40, 0, "FishFin" },
			-- the scale, hung from the post
			{ "Block", 1.24, 0.22, 0.22, 5.12, 5.1, 0, 0, 0, 0, "WoodDark" },
			{ "Block", 0.08, 0.5, 0.08, 5.5, 4.75, 0, 0, 0, 0, "Iron" },
			{ "Cylinder", 0.22, 0.86, 0.86, 5.5, 4.1, 0, 0, 90, 0, "Brass" },
			{ "Cylinder", 0.24, 0.62, 0.62, 5.5, 4.1, 0.02, 0, 90, 0, "White" },
			{ "Block", 0.07, 0.26, 0.05, 5.55, 4.16, 0.14, 0, 0, -30, "Kerchief" },
			{ "Block", 0.06, 0.46, 0.06, 5.5, 3.46, 0, 0, 0, 0, "Iron" },
			{ "Cylinder", 0.12, 1.05, 1.05, 5.5, 3.2, 0, 0, 0, 90, "Brass" },
		},
	},
	{
		Id = "Mystic",
		Station = "Auras",
		Stand = "CounterTop",
		At = { 0, -2 },
		Joints = {
			{ "Body", "Root", 0, 1.2, 0, 0, 0, 0 },
			{ "Head", "Body", 0, 3.15, 0.25, 0, 0, 0 },
			{ "TentL", "Head", 0.86, 4, 0.3, 0, 0, 0 },
			{ "TentR", "Head", -0.86, 4, 0.3, 0, 0, 0 },
			{ "ArmL", "Body", 1.26, 3.2, 0, -8, -6, 0 },
			{ "ArmR", "Body", -1.26, 3.2, 0, -8, 8, 0 },
			{ "Pearl", "ArmL", 1.3, 3.74, 1.5, 8, 6, 0 },
		},
		Parts = {
			-- the robe to the floor, a shell hem
			{ "Root", "Block", 1.84, 1.3, 1, 0, 0.65, 0, 0, 0, 0, "RobeDark" },
			{ "Root", "Block", 2, 0.28, 1.16, 0, 0.14, 0, 0, 0, 0, "Shell" },
			{ "Body", "Block", 1.9, 2.1, 1, 0, 2.25, 0, 0, 0, 0, "Robe" },
			{ "Body", "Block", 1.98, 0.3, 1.08, 0, 1.42, 0, 0, 0, 0, "Jelly" },
			{ "Body", "Block", 0.52, 1.3, 0.08, 0, 2.3, 0.52, 0, 0, 0, "RobeLight" },
			-- a scallop collar over the shoulders, a pearl at the throat
			{ "Body", "Block", 2.3, 0.24, 1.36, 0, 3.24, 0.04, 0, 0, 0, "Shell" },
			{ "Body", "Block", 0.5, 0.2, 0.3, 0.92, 3.4, 0.5, 0, 0, 0, "ShellPink" },
			{ "Body", "Block", 0.5, 0.2, 0.3, -0.92, 3.4, 0.5, 0, 0, 0, "ShellPink" },
			-- the face: eyes shut, a small smile
			{ "Head", "Block", 1.44, 1, 1.3, 0, 3.62, 0.3, 0, 0, 0, "AquaSkin" },
			{ "Head", "Block", 0.34, 0.08, 0.08, 0.34, 3.72, 0.96, 0, 0, -8, "Eye" },
			{ "Head", "Block", 0.34, 0.08, 0.08, -0.34, 3.72, 0.96, 0, 0, 8, "Eye" },
			{ "Head", "Block", 0.34, 0.08, 0.08, 0, 3.4, 0.96, 0, 0, 0, "Eye" },
			{ "Head", "Block", 0.24, 0.12, 0.06, 0.52, 3.54, 0.96, 0, 0, 0, "Jelly" },
			{ "Head", "Block", 0.24, 0.12, 0.06, -0.52, 3.54, 0.96, 0, 0, 0, "Jelly" },
			-- the jellyfish bell, worn low like a hood: a wide rim, a dome, pale spots, a frill over the brow
			{ "Head", "Block", 1.96, 0.24, 1.7, 0, 4, 0.38, 0, 0, 0, "Jelly" },
			{ "Head", "Block", 1.56, 0.1, 1.2, 0, 4.17, 0.46, 0, 0, 0, "Jelly" },
			{ "Head", "Block", 0.34, 0.03, 0.26, 0.3, 4.225, 0.8, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.03, 0.26, -0.3, 4.225, 0.8, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.03, 0.26, 0.3, 4.225, 0.46, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.03, 0.26, -0.3, 4.225, 0.46, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.4, 0.14, 0.08, 0.42, 4.06, 1.24, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.4, 0.14, 0.08, -0.42, 4.06, 1.24, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.14, 0.14, 0, 3.88, 1.2, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.14, 0.14, 0.62, 3.88, 1.2, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.14, 0.14, -0.62, 3.88, 1.2, 0, 0, 0, "JellyLight" },
			-- its tentacles, down each side of the face and the back
			{ "TentL", "Block", 0.26, 0.7, 0.26, 0.88, 3.56, 0.72, 0, 0, 0, "Jelly" },
			{ "TentL", "Block", 0.22, 0.26, 0.22, 0.94, 3.2, 0.72, 0, 0, 14, "JellyLight" },
			{ "TentL", "Block", 0.24, 0.84, 0.24, 0.84, 3.54, -0.2, 0, 0, 0, "JellyLight" },
			{ "TentR", "Block", 0.26, 0.7, 0.26, -0.88, 3.56, 0.72, 0, 0, 0, "Jelly" },
			{ "TentR", "Block", 0.22, 0.26, 0.22, -0.94, 3.2, 0.72, 0, 0, -14, "JellyLight" },
			{ "TentR", "Block", 0.24, 0.84, 0.24, -0.84, 3.54, -0.2, 0, 0, 0, "JellyLight" },
			{ "Head", "Block", 0.34, 0.6, 0.22, 0, 3.7, -0.46, 0, 0, 0, "Jelly" },
			-- the arms: a sleeve, a wide shell cuff, a hand
			{ "ArmL", "Block", 0.5, 0.5, 1.3, 1.26, 3.2, 0.55, 0, 0, 0, "Robe" },
			{ "ArmL", "Block", 0.64, 0.64, 0.26, 1.26, 3.2, 1.12, 0, 0, 0, "ShellPink" },
			{ "ArmL", "Block", 0.46, 0.46, 0.4, 1.26, 3.2, 1.42, 0, 0, 0, "AquaSkin" },
			{ "ArmR", "Block", 0.5, 0.5, 1.3, -1.26, 3.2, 0.55, 0, 0, 0, "Robe" },
			{ "ArmR", "Block", 0.64, 0.64, 0.26, -1.26, 3.2, 1.12, 0, 0, 0, "ShellPink" },
			{ "ArmR", "Block", 0.46, 0.46, 0.4, -1.26, 3.2, 1.42, 0, 0, 0, "AquaSkin" },
			-- the pearl, afloat over her open hand, two sparks going round it
			{
				"Pearl",
				"Ball",
				0.56,
				0.56,
				0.56,
				1.3,
				3.74,
				1.5,
				0,
				0,
				0,
				"PearlGlow",
				{ Mat = "Neon", Light = { 9, 1.1 } },
			},
			{ "Pearl", "Block", 0.13, 0.13, 0.13, 1.72, 3.62, 1.5, 0, 0, 0, "AuraCyan", { Mat = "Neon" } },
			{ "Pearl", "Block", 0.13, 0.13, 0.13, 0.88, 3.66, 1.5, 0, 0, 0, "AuraPink", { Mat = "Neon" } },
		},
		Bob = { 0.1, 2.8 },
		Sway = {
			{ "Head", 5.6, 0.2, 0, 0, 2, 0, 0, 0 },
			{ "TentL", 2.8, 0.1, 5, 0, 5, 0, 0, 0 },
			{ "TentR", 2.8, 0.4, 5, 0, -5, 0, 0, 0 },
			{ "ArmR", 3.4, 0, 0, 5, 0, 0, 0, 0 },
			{ "Pearl", 2.1, 0.25, 0, 0, 0, 0, 0.05, 0 },
			{ "Pearl", 7, 0, 0, 180, 0, 0, 0, 0 },
		},
		-- the pearl floats out over the counter and across from her one hand to the other, turning, hangs there and
		-- floats back; her head follows it. On the way it dips to her chin, so it covers little of her face
		Action = {
			Time = 1.5,
			Every = { 5, 9 },
			Tracks = {
				{ "ArmR", { 0.3, -4, -6, 0, 0, 0, 0 }, { 0.75, -4, -6, 0, 0, 0, 0 } },
				{
					"Pearl",
					{ 0.1, 0, 40, 0, 0, 0.1, 0.2 },
					{ 0.32, 0, 180, 0, -1.2, -0.45, 0.5 },
					{ 0.5, 0, 320, 0, -2.4, 0.08, 0.1 },
					{ 0.64, 0, 420, 0, -2.4, 0.08, 0.1 },
					{ 0.84, 0, 600, 0, -1.2, -0.45, 0.5 },
					{ 1, 0, 720, 0, 0, 0, 0 },
				},
				{
					"Head",
					{ 0.32, 0, -8, 0, 0, 0, 0 },
					{ 0.5, 0, -16, 0, 0, 0, 0 },
					{ 0.64, 0, -16, 0, 0, 0, 0 },
					{ 0.84, 0, -6, 0, 0, 0, 0 },
				},
			},
		},
		Props = {
			-- a great scallop shell stood on its hinge
			{ "Block", 1.5, 0.3, 0.7, -5.9, 0.15, -1.2, 0, 0, 0, "ShellPink" },
			{ "Block", 0.52, 1.7, 0.3, -5.9, 1.05, -1.25, 0, 0, 0, "Shell" },
			{ "Block", 0.52, 1.5, 0.3, -5.42, 0.98, -1.25, 0, 0, -16, "ShellPink" },
			{ "Block", 0.52, 1.5, 0.3, -6.38, 0.98, -1.25, 0, 0, 16, "ShellPink" },
			{ "Block", 0.52, 1.1, 0.3, -4.98, 0.78, -1.25, 0, 0, -34, "Shell" },
			{ "Block", 0.52, 1.1, 0.3, -6.82, 0.78, -1.25, 0, 0, 34, "Shell" },
			-- a pearl on a cushion before it
			{ "Block", 1, 0.3, 0.9, -5.9, 0.15, -0.3, 0, 0, 0, "AuraPurple", { Stud = true } },
			{ "Ball", 0.62, 0.62, 0.62, -5.9, 0.6, -0.3, 0, 0, 0, "Pearl" },
			-- a starfish
			{ "Block", 1.1, 0.14, 0.34, -6.3, 0.07, -2.9, 0, 0, 0, "Starfish" },
			{ "Block", 1.1, 0.15, 0.34, -6.3, 0.07, -2.9, 0, 60, 0, "Starfish" },
			{ "Block", 1.1, 0.16, 0.34, -6.3, 0.07, -2.9, 0, 120, 0, "Starfish" },
			-- two jars of auras: a glowing orb or three in each
			{ "Cylinder", 1.5, 1.2, 1.2, 5.8, 0.75, -0.6, 0, 0, 90, "Glass", { See = 0.55 } },
			{ "Cylinder", 0.26, 0.86, 0.86, 5.8, 1.62, -0.6, 0, 0, 90, "Wood" },
			{ "Ball", 0.44, 0.44, 0.44, 5.68, 0.42, -0.56, 0, 0, 0, "AuraPurple", { Mat = "Neon" } },
			{ "Ball", 0.34, 0.34, 0.34, 5.98, 0.86, -0.62, 0, 0, 0, "AuraPink", { Mat = "Neon" } },
			{ "Ball", 0.26, 0.26, 0.26, 5.7, 1.2, -0.7, 0, 0, 0, "AuraCyan", { Mat = "Neon" } },
			{ "Cylinder", 1, 0.9, 0.9, 6.25, 0.5, -1.9, 0, 0, 90, "Glass", { See = 0.55 } },
			{ "Cylinder", 0.22, 0.64, 0.64, 6.25, 1.1, -1.9, 0, 0, 90, "Wood" },
			{ "Ball", 0.4, 0.4, 0.4, 6.25, 0.48, -1.9, 0, 0, 0, "AuraCyan", { Mat = "Neon" } },
			-- an open clam with its pearl
			{ "Block", 1.2, 0.3, 1, 5.6, 0.15, -3.1, 0, 0, 0, "ShellPink" },
			{ "Block", 1.2, 0.3, 1, 5.6, 0.72, -3.42, -52, 0, 0, "Shell" },
			{ "Ball", 0.42, 0.42, 0.42, 5.6, 0.5, -3.05, 0, 0, 0, "Pearl" },
		},
	},
	{
		Id = "Diver",
		Station = "Sub",
		Stand = "CounterTop",
		At = { 0, -2 },
		Joints = {
			{ "Body", "Root", 0, 1.2, 0, 0, 0, 0 },
			{ "Head", "Body", 0, 3.1, 0.25, 0, 0, 0 },
			{ "Needle", "Body", 0.72, 3.28, 0.84, 0, 0, 0 },
			{ "ArmL", "Body", 1.26, 3.2, 0, -6, -10, 0 },
			{ "ArmR", "Body", -1.26, 3.2, 0, -8, 0, 0 },
			{ "Item", "ArmR", -1.26, 3.2, 1.42, 8, 0, 0 },
		},
		Parts = {
			-- weighted boots, canvas legs
			{ "Root", "Block", 0.95, 0.5, 1.15, 0.5, 0.25, 0.1, 0, 0, 0, "Iron" },
			{ "Root", "Block", 0.95, 0.5, 1.15, -0.5, 0.25, 0.1, 0, 0, 0, "Iron" },
			{ "Root", "Block", 0.82, 0.8, 0.86, 0.47, 0.85, 0, 0, 0, 0, "CanvasDark" },
			{ "Root", "Block", 0.82, 0.8, 0.86, -0.47, 0.85, 0, 0, 0, 0, "CanvasDark" },
			-- the suit, a belt, the brass corselet over the shoulders with its bolts and its gauge
			{ "Body", "Block", 1.9, 2.1, 1, 0, 2.25, 0, 0, 0, 0, "Canvas" },
			{ "Body", "Block", 1.98, 0.3, 1.08, 0, 1.42, 0, 0, 0, 0, "SubTeal" },
			{ "Body", "Block", 0.4, 0.38, 0.1, 0, 1.42, 0.56, 0, 0, 0, "Brass" },
			{ "Body", "Block", 2.3, 0.42, 1.36, 0, 3.2, 0.02, 0, 0, 0, "Brass" },
			{ "Body", "Block", 1.3, 0.4, 0.12, 0, 2.8, 0.54, 0, 0, 0, "BrassDark" },
			{ "Body", "Block", 0.2, 0.1, 0.2, 0.94, 3.45, 0.42, 0, 0, 0, "BrassDark" },
			{ "Body", "Block", 0.2, 0.1, 0.2, -0.94, 3.45, 0.42, 0, 0, 0, "BrassDark" },
			{ "Body", "Cylinder", 0.12, 0.52, 0.52, 0.72, 3.28, 0.74, 0, 90, 0, "BrassDark" },
			{ "Body", "Cylinder", 0.14, 0.4, 0.4, 0.72, 3.28, 0.76, 0, 90, 0, "White" },
			{ "Needle", "Block", 0.06, 0.18, 0.04, 0.72, 3.35, 0.85, 0, 0, 0, "Kerchief" },
			-- an air tank on the back
			{ "Body", "Cylinder", 1.5, 0.76, 0.76, 0, 2.3, -0.88, 0, 0, 90, "Oilskin" },
			{ "Body", "Cylinder", 0.2, 0.4, 0.4, 0, 3.15, -0.88, 0, 0, 90, "Iron" },
			-- the helmet, sat in the corselet: a brass ball, a face window with two eyes in it, a window each
			-- side, a crest over the top
			{ "Head", "Ball", 1.28, 1.28, 1.28, 0, 3.62, 0.25, 0, 0, 0, "Brass" },
			{ "Head", "Cylinder", 0.26, 0.94, 0.94, 0, 3.64, 0.81, 0, 90, 0, "BrassDark" },
			{ "Head", "Cylinder", 0.28, 0.7, 0.7, 0, 3.64, 0.83, 0, 90, 0, "Porthole" },
			{ "Head", "Block", 0.16, 0.2, 0.06, 0.16, 3.67, 0.98, 0, 0, 0, "White" },
			{ "Head", "Block", 0.16, 0.2, 0.06, -0.16, 3.67, 0.98, 0, 0, 0, "White" },
			{ "Head", "Cylinder", 1.38, 0.5, 0.5, 0, 3.66, 0.25, 0, 0, 0, "BrassDark" },
			{ "Head", "Cylinder", 1.42, 0.3, 0.3, 0, 3.66, 0.25, 0, 0, 0, "Porthole" },
			{ "Head", "Block", 0.3, 0.08, 0.5, 0, 4.22, 0.45, 0, 0, 0, "BrassDark" },
			-- the arms: a sleeve, a brass cuff, a glove
			{ "ArmL", "Block", 0.5, 0.5, 1.2, 1.26, 3.2, 0.5, 0, 0, 0, "Canvas" },
			{ "ArmL", "Block", 0.64, 0.64, 0.18, 1.26, 3.2, 1.14, 0, 0, 0, "Brass" },
			{ "ArmL", "Block", 0.54, 0.54, 0.45, 1.26, 3.2, 1.42, 0, 0, 0, "SubTeal" },
			{ "ArmR", "Block", 0.5, 0.5, 1.2, -1.26, 3.2, 0.5, 0, 0, 0, "Canvas" },
			{ "ArmR", "Block", 0.64, 0.64, 0.18, -1.26, 3.2, 1.14, 0, 0, 0, "Brass" },
			{ "ArmR", "Block", 0.54, 0.54, 0.45, -1.26, 3.2, 1.42, 0, 0, 0, "SubTeal" },
			-- a stubby wrench, held upright in the fist
			{ "Item", "Block", 0.22, 0.56, 0.16, -1.26, 3.58, 1.42, 0, 0, 0, "IronLight" },
			{ "Item", "Block", 0.28, 0.3, 0.22, -1.26, 2.98, 1.42, 0, 0, 0, "Kerchief" },
			{ "Item", "Block", 0.66, 0.28, 0.18, -1.26, 3.94, 1.42, 0, 0, 0, "IronLight" },
			{ "Item", "Block", 0.2, 0.22, 0.18, -1.03, 4.14, 1.42, 0, 0, 0, "IronLight" },
			{ "Item", "Block", 0.2, 0.22, 0.18, -1.49, 4.14, 1.42, 0, 0, 0, "IronLight" },
		},
		Bob = { 0.1, 3 },
		Sway = {
			{ "Head", 6, 0.1, 0, 0, 1.5, 0, 0, 0 },
			{ "Needle", 1.7, 0, 0, 0, 38, 0, 0, 0 },
			{ "ArmR", 3, 0.3, 1.5, 0, 0, 0, 0, 0 },
		},
		-- raps the wrench twice on the counter in front of him, looking down at it: low and forward, so no hand or
		-- wrench comes near the helmet or its window whichever way the head is turned
		Action = {
			Time = 1.2,
			Every = { 5, 8.5 },
			Tracks = {
				{
					"Item",
					{ 0.3, 106, 0, 0, 0, 0, 0 },
					{ 0.44, 64, 0, 0, 0, 0, 0 },
					{ 0.58, 106, 0, 0, 0, 0, 0 },
					{ 0.78, 24, 0, 0, 0, 0, 0 },
				},
				{ "Head", { 0.3, 10, -10, 0, 0, 0, 0 }, { 0.7, 10, -10, 0, 0, 0, 0 } },
			},
		},
		Props = {
			-- two air tanks
			{ "Cylinder", 2, 0.9, 0.9, -5.6, 1, -0.6, 0, 0, 90, "Oilskin" },
			{ "Cylinder", 0.3, 0.5, 0.5, -5.6, 2.15, -0.6, 0, 0, 90, "Iron" },
			{ "Block", 0.56, 0.12, 0.12, -5.6, 2.36, -0.6, 0, 30, 0, "Kerchief" },
			{ "Cylinder", 1.7, 0.8, 0.8, -6.45, 0.85, -1.3, 0, 0, 90, "SubTeal" },
			{ "Cylinder", 0.28, 0.46, 0.46, -6.45, 1.84, -1.3, 0, 0, 90, "Iron" },
			-- a coil of rope
			{ "Cylinder", 0.3, 1.6, 1.6, -5.9, 0.15, -2.9, 0, 0, 90, "Rope" },
			{ "Cylinder", 0.3, 1.36, 1.36, -5.9, 0.45, -2.9, 0, 0, 90, "Rope" },
			{ "Cylinder", 0.32, 0.6, 0.6, -5.9, 0.46, -2.9, 0, 0, 90, "WoodDark" },
			-- a toolbox
			{ "Block", 1.6, 0.8, 0.9, 5.8, 0.4, -0.5, 0, -10, 0, "Kerchief" },
			{ "Block", 1.66, 0.2, 0.96, 5.8, 0.9, -0.5, 0, -10, 0, "KerchiefDark", { Stud = true } },
			{ "Block", 0.7, 0.14, 0.14, 5.8, 1.07, -0.5, 0, -10, 0, "Iron" },
			-- a periscope
			{ "Cylinder", 0.25, 0.9, 0.9, 6.2, 0.125, -2.3, 0, 0, 90, "Iron" },
			{ "Cylinder", 3.4, 0.5, 0.5, 6.2, 1.7, -2.3, 0, 0, 90, "IronLight" },
			{ "Cylinder", 0.2, 0.62, 0.62, 6.2, 2.5, -2.3, 0, 0, 90, "Brass" },
			{ "Block", 0.62, 0.62, 1.05, 6.2, 3.62, -2.06, 0, 0, 0, "SubTeal" },
			{ "Cylinder", 0.1, 0.44, 0.44, 6.2, 3.62, -1.5, 0, 90, 0, "Water" },
		},
	},
	{
		Id = "Tinkerer",
		Station = "Fuse",
		Stand = "Core",
		At = { 6.5, -0.75 },
		Joints = {
			{ "Body", "Root", 0, 1.5, 0, 0, 0, 0 },
			{ "Head", "Body", 0, 3.6, 0, 0, 0, 0 },
			{ "Goggles", "Head", 0, 4.42, 0.7, 0, 0, 0 },
			{ "Octo", "Head", 0, 4.88, 0, 0, 0, 0 },
			{ "TentL", "Octo", 0.86, 4.9, 0, 0, 0, 0 },
			{ "TentR", "Octo", -0.86, 4.9, 0, 0, 0, 0 },
			{ "ArmL", "Body", 1.3, 3.36, 0, -12, -12, 0 },
			{ "ArmR", "Body", -1.3, 3.36, 0, -35, 0, 0 },
			{ "Item", "ArmR", -1.3, 3.36, 1.5, 35, 0, 0 },
		},
		Parts = {
			{ "Root", "Block", 0.85, 1.6, 0.9, 0.47, 0.8, 0, 0, 0, 0, "Trouser" },
			{ "Root", "Block", 0.85, 1.6, 0.9, -0.47, 0.8, 0, 0, 0, 0, "Trouser" },
			{ "Root", "Block", 0.87, 0.45, 0.52, 0.47, 0.225, 0.6, 0, 0, 0, "WoodDark" },
			{ "Root", "Block", 0.87, 0.45, 0.52, -0.47, 0.225, 0.6, 0, 0, 0, "WoodDark" },
			-- a blue shirt under a leather apron, a pocket with a tool in it
			{ "Body", "Block", 2, 2.25, 1.1, 0, 2.475, 0, 0, 0, 0, "FuseBlue" },
			{ "Body", "Block", 2.08, 0.3, 1.18, 0, 1.72, 0, 0, 0, 0, "WoodDark" },
			{ "Body", "Block", 1.5, 2, 0.1, 0, 2.4, 0.58, 0, 0, 0, "Apron" },
			{ "Body", "Block", 0.62, 0.42, 0.08, 0.36, 3, 0.66, 0, 0, 0, "WoodDark" },
			{ "Body", "Block", 0.12, 0.4, 0.08, 0.46, 3.26, 0.67, 0, 0, 0, "Kerchief" },
			-- a pack of coral tubes on the back
			{ "Body", "Block", 1.4, 1.5, 0.55, 0, 2.7, -0.82, 0, 0, 0, "WoodDark" },
			{ "Body", "Cylinder", 1.7, 0.36, 0.36, -0.44, 3.9, -0.88, 0, 0, 90, "CoralPink" },
			{ "Body", "Cylinder", 2.2, 0.36, 0.36, 0, 4.15, -0.92, 0, 0, 90, "CoralOrange" },
			{ "Body", "Cylinder", 1.4, 0.36, 0.36, 0.44, 3.75, -0.88, 0, 0, 90, "CoralTeal" },
			-- the head: a grin, goggles with glowing lenses
			{ "Head", "Block", 1.4, 1.3, 1.35, 0, 4.25, 0, 0, 0, 0, "SkinTan" },
			{ "Head", "Block", 0.52, 0.1, 0.08, 0, 3.96, 0.69, 0, 0, 0, "Eye" },
			{ "Head", "Block", 0.26, 0.22, 0.2, 0, 4.14, 0.74, 0, 0, 0, "Nose" },
			{ "Head", "Block", 1.46, 0.26, 1.4, 0, 4.42, 0, 0, 0, 0, "Eye" },
			{ "Goggles", "Cylinder", 0.26, 0.68, 0.68, 0.36, 4.42, 0.7, 0, 90, 0, "Brass" },
			{ "Goggles", "Cylinder", 0.28, 0.46, 0.46, 0.36, 4.42, 0.71, 0, 90, 0, "Lens", { Mat = "Neon" } },
			{ "Goggles", "Cylinder", 0.26, 0.68, 0.68, -0.36, 4.42, 0.7, 0, 90, 0, "Brass" },
			{ "Goggles", "Cylinder", 0.28, 0.46, 0.46, -0.36, 4.42, 0.71, 0, 90, 0, "Lens", { Mat = "Neon" } },
			-- a small octopus sat on the head for a hat, its arms hanging down each side
			{ "Octo", "Block", 1.56, 0.4, 1.5, 0, 5.06, 0, 0, 0, 0, "OctoDark" },
			{ "Octo", "Ball", 1.7, 1.7, 1.7, 0, 5.72, -0.12, 0, 0, 0, "Octo" },
			{ "Octo", "Block", 0.34, 0.34, 0.1, 0.36, 5.62, 0.66, 0, 0, 0, "White" },
			{ "Octo", "Block", 0.34, 0.34, 0.1, -0.36, 5.62, 0.66, 0, 0, 0, "White" },
			{ "Octo", "Block", 0.16, 0.2, 0.06, 0.36, 5.6, 0.72, 0, 0, 0, "Eye" },
			{ "Octo", "Block", 0.16, 0.2, 0.06, -0.36, 5.6, 0.72, 0, 0, 0, "Eye" },
			{ "Octo", "Block", 0.3, 0.14, 0.06, 0.62, 6.1, 0.42, 0, 0, 0, "OctoLight" },
			{ "Octo", "Block", 0.22, 0.14, 0.06, -0.5, 6.22, 0.36, 0, 0, 0, "OctoLight" },
			{ "TentL", "Block", 0.32, 0.9, 0.32, 0.88, 4.5, 0.3, 0, 0, 0, "Octo" },
			{ "TentL", "Block", 0.62, 0.3, 0.32, 1.06, 3.98, 0.3, 0, 0, 0, "Octo" },
			{ "TentL", "Block", 0.3, 0.34, 0.32, 1.26, 4.24, 0.3, 0, 0, 0, "OctoLight" },
			{ "TentL", "Block", 0.3, 1.1, 0.3, 0.88, 4.4, -0.38, 0, 0, 0, "OctoDark" },
			{ "TentR", "Block", 0.32, 0.9, 0.32, -0.88, 4.5, 0.3, 0, 0, 0, "Octo" },
			{ "TentR", "Block", 0.62, 0.3, 0.32, -1.06, 3.98, 0.3, 0, 0, 0, "Octo" },
			{ "TentR", "Block", 0.3, 0.34, 0.32, -1.26, 4.24, 0.3, 0, 0, 0, "OctoLight" },
			{ "TentR", "Block", 0.3, 1.1, 0.3, -0.88, 4.4, -0.38, 0, 0, 0, "OctoDark" },
			-- the arms: a sleeve and a work glove each
			{ "ArmL", "Block", 0.62, 0.62, 1.45, 1.3, 3.36, 0.6, 0, 0, 0, "FuseBlue" },
			{ "ArmL", "Block", 0.64, 0.64, 0.5, 1.3, 3.36, 1.5, 0, 0, 0, "Apron" },
			{ "ArmR", "Block", 0.62, 0.62, 1.45, -1.3, 3.36, 0.6, 0, 0, 0, "FuseBlue" },
			{ "ArmR", "Block", 0.64, 0.64, 0.5, -1.3, 3.36, 1.5, 0, 0, 0, "Apron" },
			-- a flask of the machine's glow
			{ "Item", "Cylinder", 0.6, 0.56, 0.56, -1.3, 3.84, 1.5, 0, 0, 90, "FuseGlow", { Mat = "Neon" } },
			{ "Item", "Cylinder", 0.34, 0.26, 0.26, -1.3, 4.3, 1.5, 0, 0, 90, "Glass" },
			{ "Item", "Cylinder", 0.16, 0.3, 0.3, -1.3, 4.52, 1.5, 0, 0, 90, "Wood" },
		},
		Bob = { 0.1, 2.2 },
		Sway = {
			{ "Head", 4.4, 0.3, 0, 0, 2, 0, 0, 0 },
			{ "Octo", 3.3, 0, 0, 0, 3, 0, 0, 0 },
			{ "TentL", 2.2, 0.2, 0, 0, 6, 0, 0, 0 },
			{ "TentR", 2.2, 0.6, 0, 0, -6, 0, 0, 0 },
			{ "Item", 2.2, 0.5, 0, 0, 6, 0, 0, 0 },
		},
		-- tosses the flask straight up, where it tips a little, and catches it; he and the octopus on his head watch
		-- it go. It does not turn over: the Item joint turns about the hand, so a full turn would swing it through the glove.
		-- Nothing in it reaches for the head: the head turns up to 70 degrees to the ring and an arm cannot follow it
		Action = {
			Time = 1.2,
			Every = { 4.5, 8 },
			Tracks = {
				{
					"ArmR",
					{ 0.15, 6, 0, 0, 0, 0, 0 },
					{ 0.3, -8, 0, 0, 0, 0, 0 },
					{ 0.6, 0, 0, 0, 0, 0, 0 },
					{ 0.86, 5, 0, 0, 0, 0, 0 },
				},
				{
					"Item",
					{ 0.15, 0, 0, 0, 0, -0.08, 0 },
					{ 0.5, 0, 0, 16, 0.2, 1.35, 0 },
					{ 0.86, 0, 0, 0, 0, -0.06, 0 },
				},
				{ "Head", { 0.3, -6, -8, 0, 0, 0, 0 }, { 0.7, -6, -8, 0, 0, 0, 0 } },
				{ "Octo", { 0.5, 0, -14, 0, 0, 0.1, 0 } },
				{ "TentL", { 0.5, 0, 0, -22, 0, 0, 0 } },
				{ "TentR", { 0.5, 0, 0, 22, 0, 0, 0 } },
			},
		},
		Props = {
			-- on the machine's base, left of the great pod: two jars of coral
			{ "Cylinder", 1.6, 1.3, 1.3, -5.2, 2.12, -1.6, 0, 0, 90, "Glass", { See = 0.55 } },
			{ "Cylinder", 0.2, 1.4, 1.4, -5.2, 3.02, -1.6, 0, 0, 90, "Iron" },
			{ "Block", 0.3, 1.1, 0.3, -5.2, 1.95, -1.6, 0, 0, 0, "CoralPink" },
			{ "Block", 0.24, 0.6, 0.24, -4.92, 2.3, -1.6, 0, 0, -32, "CoralPink" },
			{ "Block", 0.24, 0.5, 0.24, -5.46, 2.16, -1.6, 0, 0, 32, "CoralPink" },
			{ "Cylinder", 1.1, 1, 1, -6.9, 1.87, -2.7, 0, 0, 90, "Glass", { See = 0.55 } },
			{ "Cylinder", 0.2, 1.1, 1.1, -6.9, 2.52, -2.7, 0, 0, 90, "Iron" },
			{ "Block", 0.28, 0.8, 0.28, -6.9, 1.8, -2.7, 0, 0, 0, "CoralOrange" },
			{ "Block", 0.22, 0.42, 0.22, -6.7, 2.02, -2.7, 0, 0, -32, "CoralOrange" },
			-- a stack of pipes
			{ "Cylinder", 2.4, 0.6, 0.6, -5, 1.62, 1, 0, 14, 0, "IronLight" },
			{ "Cylinder", 2.2, 0.6, 0.6, -5.1, 1.62, 0.3, 0, 14, 0, "FuseBlue" },
			{ "Cylinder", 2.2, 0.6, 0.6, -5.05, 2.14, 0.65, 0, 14, 0, "Oilskin" },
			-- behind the tinkerer: a crate of parts, a cog on it
			{ "Block", 1.4, 0.9, 1.1, 7.6, 1.77, -3.3, 0, 0, 0, "Wood", { Stud = true } },
			{ "Block", 0.72, 0.2, 0.72, 7.6, 2.32, -3.3, 0, 0, 0, "IronLight" },
			{ "Block", 0.72, 0.21, 0.72, 7.6, 2.32, -3.3, 0, 45, 0, "IronLight" },
		},
	},
}
-->>DATA

-- THE SUMS (the same ones as tools/keepers/keepers.py: pose, track_at, look_split, aim, stand_space)
local RAD = math.pi / 180

function Keepers.ease(k: number): number
	return k * k * (3 - 2 * k)
end

-- A track's six numbers at t (0 to 1 through the action): rest at both ends, eased between its keys
function Keepers.trackAt(track: Row, t: number): (number, number, number, number, number, number)
	local at, a1, a2, a3, a4, a5, a6 = 0, 0, 0, 0, 0, 0, 0
	for i = 2, #track + 1 do
		local key: Row? = track[i] -- past the last key: back at rest at 1
		local bt: number = if key then key[1] else 1
		local b1: number, b2: number, b3: number = 0, 0, 0
		local b4: number, b5: number, b6: number = 0, 0, 0
		if key then
			b1, b2, b3 = key[2] or 0, key[3] or 0, key[4] or 0
			b4, b5, b6 = key[5] or 0, key[6] or 0, key[7] or 0
		end
		if t <= bt then
			local k = if bt > at then Keepers.ease((t - at) / (bt - at)) else 1
			return a1 + (b1 - a1) * k,
				a2 + (b2 - a2) * k,
				a3 + (b3 - a3) * k,
				a4 + (b4 - a4) * k,
				a5 + (b5 - a5) * k,
				a6 + (b6 - a6) * k
		end
		at, a1, a2, a3, a4, a5, a6 = bt, b1, b2, b3, b4, b5, b6
	end
	return 0, 0, 0, 0, 0, 0
end

-- What the idle and the action add to each joint. idle: seconds into the idle (nil: none of it); action: 0 to 1
-- through the action (nil: not in it). `into` is used again when given (one table a keeper, not one a frame)
function Keepers.anim(keeper: Keeper, idle: number?, action: number?, into: Anim?): Anim
	local anim: Anim = into or {}
	for _, six in anim do
		six[1], six[2], six[3], six[4], six[5], six[6] = 0, 0, 0, 0, 0, 0
	end
	local function add(joint: string, rx: number, ry: number, rz: number, dx: number, dy: number, dz: number)
		local six = anim[joint]
		if not six then
			six = { 0, 0, 0, 0, 0, 0 }
			anim[joint] = six
		end
		six[1] += rx
		six[2] += ry
		six[3] += rz
		six[4] += dx
		six[5] += dy
		six[6] += dz
	end
	if idle then
		add("Body", 0, 0, 0, 0, keeper.Bob[1] * math.sin(2 * math.pi * idle / keeper.Bob[2]), 0)
		for _, row in keeper.Sway do
			local k = math.sin(2 * math.pi * (idle / row[2] + row[3]))
			add(row[1], row[4] * k, row[5] * k, row[6] * k, row[7] * k, row[8] * k, row[9] * k)
		end
	end
	if action then
		for _, track in keeper.Action.Tracks do
			add(track[1], Keepers.trackAt(track, action))
		end
	end
	return anim
end

-- The whole turn towards a player (degrees) -> the body's turn, the head's turn on the body, the head's tip, each
-- held to its most
function Keepers.lookSplit(yaw: number, pitch: number): (number, number, number)
	local look = Keepers.Look
	yaw = math.clamp(yaw, -(look.Body + look.Head), look.Body + look.Head)
	local body = math.clamp(yaw * look.BodyShare, -look.Body, look.Body)
	local head = math.clamp(yaw - body, -look.Head, look.Head)
	return body, head, math.clamp(pitch, -look.Up, look.Down)
end

-- The turn that points a head at `at` (a point in the keeper's space, measured from the head's joint): yaw and pitch
-- in degrees. Looking up is a NEGATIVE pitch (a turn about x takes z towards -y)
function Keepers.aim(at: Vector3): (number, number)
	return math.atan2(at.X, at.Z) / RAD, -math.atan2(at.Y, math.sqrt(at.X * at.X + at.Z * at.Z)) / RAD
end

-- Where each joint turns, keeper space, bind pose
local pivotsOf: { [Keeper]: { [string]: Vector3 } } = {}
function Keepers.pivots(keeper: Keeper): { [string]: Vector3 }
	local known = pivotsOf[keeper]
	if known then
		return known
	end
	local pivots: { [string]: Vector3 } = { Root = Vector3.zero }
	for _, joint in keeper.Joints do
		pivots[joint[1]] = Vector3.new(joint[3], joint[4], joint[5])
	end
	pivotsOf[keeper] = pivots
	return pivots
end

-- Every joint in the keeper's space, posed: its rest turn, the look (body, head, tip: degrees, from lookSplit) and
-- what `anim` adds. `into` is used again when given
function Keepers.joints(
	keeper: Keeper,
	scale: number,
	anim: Anim?,
	body: number,
	head: number,
	tip: number,
	into: { [string]: CFrame }?
): { [string]: CFrame }
	local pivots = Keepers.pivots(keeper)
	local world: { [string]: CFrame } = into or {}
	world.Root = CFrame.identity
	for _, joint in keeper.Joints do
		local name: string, parent: string = joint[1], joint[2]
		local m = world[parent]
			* CFrame.new((pivots[name] - pivots[parent]) * scale)
			* CFrame.Angles(joint[6] * RAD, joint[7] * RAD, joint[8] * RAD)
		if name == "Body" then
			m *= CFrame.Angles(0, body * RAD, 0)
		elseif name == "Head" then
			m *= CFrame.Angles(0, head * RAD, 0) * CFrame.Angles(tip * RAD, 0, 0)
		end
		local six = anim and anim[name]
		if six then
			m = m
				* CFrame.new(six[4] * scale, six[5] * scale, six[6] * scale)
				* CFrame.Angles(six[1] * RAD, six[2] * RAD, six[3] * RAD)
		end
		world[name] = m
	end
	return world
end

-- A part against its joint: the joint's CFrame times this is the part's, in the keeper's space
function Keepers.offset(keeper: Keeper, part: Row, scale: number): CFrame
	local pivot = Keepers.pivots(keeper)[part[1]]
	return CFrame.new((Vector3.new(part[6], part[7], part[8]) - pivot) * scale)
		* CFrame.Angles(part[9] * RAD, part[10] * RAD, part[11] * RAD)
end

-- A prop in its stand's space
function Keepers.propAt(prop: Row, scale: number): CFrame
	return CFrame.new(prop[5] * scale, prop[6] * scale, prop[7] * scale)
		* CFrame.Angles(prop[8] * RAD, prop[9] * RAD, prop[10] * RAD)
end

-- A stand's space in the world, from the middle of its anchor (its CounterTop or its Core), the middle of its floor
-- ring and the floor's height. Nil when the ring is right under the anchor (no way to face)
function Keepers.standSpace(anchor: Vector3, ring: Vector3, floor: number): CFrame?
	local ahead = Vector3.new(ring.X - anchor.X, 0, ring.Z - anchor.Z)
	if ahead.Magnitude < 0.5 then
		return nil
	end
	ahead = ahead.Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(Vector3.new(anchor.X, floor, anchor.Z), up:Cross(ahead), up, ahead)
end

return Keepers
