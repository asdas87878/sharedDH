--!strict
-- The twelve auras (Hugo, 2026-11-19: "add cool auras that you can buy at the aura stand ... 1.5 2 2.5 3 3.5 4 5 6 7
-- 8 10 12x ... animated and colored, getting cooler with each tier") and the spawn-in effect ("when you spawn in you
-- play a cool little animation around the player"). The look is the 3D one round the body (Hugo, 2026-11-25: "actually
-- surrounding the player"; docs/design/auras.md; its numbers: Shared/AuraVolume), the names and colours draft 3's; the
-- looks before it are kept behind Config.Aura.Look (1 draft 4's flame, Shared/AuraFlame; 0 draft 2's particles).
--
-- The switch: a player's "Aura" attribute (a tier number, 1 to 12; 0 or missing is none), set by AuraService when an
-- aura is bought (prices: Config.Aura.Prices); every machine draws every player's aura (Controllers/AuraController).
-- In Studio, `Test` puts a tier on your own player without the server, and a Model tagged "AuraRig" with its own "Aura"
-- attribute shows one too (for captures: tools/studio/aura_capture.py).
-- This table is only what a tier is and its colours, so a shop, a sign or a panel can read them too.

export type Tier = {
	Id: number,
	Name: string,
	Mult: number, -- multiplies the Oxygen the seahorse gives (replaces the one before)
	Main: Color3, -- the aura's own colour (a shop's swatch)
	Second: Color3, -- 40% toward white (the inner flame's)
	Blurb: string, -- what it does on screen, in a few words
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Auras = {}

Auras.Tiers = {
	{
		Id = 1,
		Name = "Bubble",
		Mult = 1.5,
		Main = rgb(255, 255, 255),
		Second = rgb(255, 255, 255),
		Blurb = "faint wisps at your feet",
	},
	{
		Id = 2,
		Name = "Shell",
		Mult = 2,
		Main = rgb(255, 163, 153),
		Second = rgb(255, 200, 194),
		Blurb = "strokes whip over the ground",
	},
	{
		Id = 3,
		Name = "Tide",
		Mult = 2.5,
		Main = rgb(0, 214, 230),
		Second = rgb(102, 230, 240),
		Blurb = "a ring of light turns round you",
	},
	{
		Id = 4,
		Name = "Current",
		Mult = 3,
		Main = rgb(0, 119, 255),
		Second = rgb(102, 173, 255),
		Blurb = "a ribbon winds up round you",
	},
	{
		Id = 5,
		Name = "Reef",
		Mult = 3.5,
		Main = rgb(255, 77, 166),
		Second = rgb(255, 148, 202),
		Blurb = "an inner glow that breathes",
	},
	{
		Id = 6,
		Name = "Storm",
		Mult = 4,
		Main = rgb(247, 255, 0),
		Second = rgb(250, 255, 102),
		Blurb = "a ring of flames, a second ribbon",
	},
	{
		Id = 7,
		Name = "Moon",
		Mult = 5,
		Main = rgb(201, 153, 255),
		Second = rgb(223, 194, 255),
		Blurb = "tall shafts of light",
	},
	{
		Id = 8,
		Name = "Lantern",
		Mult = 6,
		Main = rgb(255, 110, 0),
		Second = rgb(255, 168, 102),
		Blurb = "embers spiral up round you",
	},
	{
		Id = 9,
		Name = "Ember",
		Mult = 7,
		Main = rgb(230, 23, 23),
		Second = rgb(240, 116, 116),
		Blurb = "spray bursts at its foot",
	},
	{
		Id = 10,
		Name = "Urchin",
		Mult = 8,
		Main = rgb(191, 0, 134),
		Second = rgb(217, 102, 182),
		Blurb = "arcs and shock rings",
	},
	{
		Id = 11,
		Name = "Abyss",
		Mult = 10,
		Main = rgb(34, 0, 255),
		Second = rgb(122, 102, 255),
		Blurb = "a towering pillar of light",
	},
	{
		Id = 12,
		Name = "Leviathan",
		Mult = 12,
		Main = rgb(224, 25, 255),
		Second = rgb(236, 117, 255),
		Blurb = "two great serpents and a crown",
	},
} :: { Tier }

-- Which spawn-in plays when a character appears (on every machine, for every player): 1 Splash, 2 Whirlpool,
-- 3 Drop. 0 turns it off. A draft: Hugo picks one.
Auras.SpawnStyle = 2
Auras.SpawnNames = { "Splash", "Whirlpool", "Drop" }

-- Studio only: a tier shown on your own player without the server (0 = off)
Auras.Test = 0

-- The 3D look's pictures, uploaded: each empty until the user says yes to the upload (art/ui/aura_volume; twelve, the same
-- name in small letters). Where one is empty a live game draws an engine picture in its place, or leaves that layer out
-- (Lib/AuraAround.Standin); Studio reads the local copies (python tools/auras/volume_sheets.py --local). A picture that
-- changes needs a new SheetSet: Studio keeps the old one under its name.
Auras.Sheets = {
	Wisp = "", -- 8x8
	Flame = "", -- 8x8
	Ring = "", -- 4x4, as those under it
	Sweep = "",
	Shock = "",
	Jet = "",
	Haze = "",
	Shaft = "",
	Mote = "",
	Arc = "",
	Ribbon = "", -- the Beams'
	Glow = "", -- a still
} :: { [string]: string }
Auras.SheetSet = "v1"

-- Look 1 uses the six uploaded flame pictures from art/ui/aura_flame/upload.
Auras.Pictures = {
	Flame = "rbxassetid://124821179310672",
	Tip = "rbxassetid://80539956547919",
	Streaks = "rbxassetid://106939583053473",
	Lick = "rbxassetid://86325853542441",
	Bubble = "rbxassetid://123139847562727",
	Arc = "rbxassetid://113590203083136",
} :: { [string]: string }
Auras.PictureSet = "f1"

-- Auras further than this from the camera are not animated (their parts are hidden)
Auras.DrawRange = 220

return Auras
