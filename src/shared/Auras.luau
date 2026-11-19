--!strict
-- The twelve auras (Hugo, 2026-11-19: "add cool auras that you can buy at the aura stand ... 1.5 2 2.5 3 3.5 4 5 6 7
-- 8 10 12x ... animated and colored, getting cooler with each tier") and the spawn-in effect ("when you spawn in you
-- play a cool little animation around the player"). DRAFT 2 (task a1): the looks only, particles round the body only (Hugo: nothing on the ground). Not bought yet: buying waits
-- for the economy's prices (docs/design/progression.md, "The economy, draft 1"); names are that draft's stand-ins.
--
-- The switch: a player's "Aura" attribute (a tier number, 1 to 12; 0 or missing is none). The server will set it when
-- an aura is bought; every machine draws every player's aura (Controllers/AuraController). In Studio, `Test` puts a
-- tier on your own player without the server, and a Model tagged "AuraRig" with its own "Aura" attribute shows one too
-- (for captures: tools/studio/aura_capture.py).
-- The look is drawn by AuraController; this table is only what a tier is and its colours, so a shop, a sign or a
-- panel can read them too.

export type Tier = {
	Id: number,
	Name: string,
	Mult: number, -- multiplies all Oxygen gained (replaces the one before)
	Main: Color3, -- the aura's own colour (a shop's swatch)
	Second: Color3, -- its accent
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
		Main = rgb(190, 235, 255),
		Second = rgb(255, 255, 255),
		Blurb = "a few soft bubbles rise off you",
	},
	{
		Id = 2,
		Name = "Foam",
		Mult = 2,
		Main = rgb(235, 250, 255),
		Second = rgb(120, 210, 255),
		Blurb = "bubbles and a white foam haze hug you",
	},
	{
		Id = 3,
		Name = "Tide",
		Mult = 2.5,
		Main = rgb(40, 210, 200),
		Second = rgb(200, 255, 245),
		Blurb = "a wave of teal light runs round you",
	},
	{
		Id = 4,
		Name = "Current",
		Mult = 3,
		Main = rgb(40, 170, 255),
		Second = rgb(170, 240, 255),
		Blurb = "three streaks spiral up, lines shoot up you",
	},
	{
		Id = 5,
		Name = "Reef",
		Mult = 3.5,
		Main = rgb(255, 110, 150),
		Second = rgb(255, 200, 80),
		Blurb = "coral sparkles twinkle all over you",
	},
	{
		Id = 6,
		Name = "Storm",
		Mult = 4,
		Main = rgb(255, 235, 80),
		Second = rgb(70, 90, 170),
		Blurb = "a dark cloud, bright crackles, sparks",
	},
	{
		Id = 7,
		Name = "Moon",
		Mult = 5,
		Main = rgb(215, 220, 255),
		Second = rgb(160, 130, 255),
		Blurb = "two silver rings of light, a small moon",
	},
	{
		Id = 8,
		Name = "Lantern",
		Mult = 6,
		Main = rgb(255, 200, 70),
		Second = rgb(255, 120, 40),
		Blurb = "four warm lanterns of light circle you",
	},
	{
		Id = 9,
		Name = "Ember",
		Mult = 7,
		Main = rgb(255, 110, 30),
		Second = rgb(255, 230, 120),
		Blurb = "a flame wraps you, embers fly up",
	},
	{
		Id = 10,
		Name = "Phantom",
		Mult = 8,
		Main = rgb(110, 255, 190),
		Second = rgb(170, 110, 255),
		Blurb = "a ghostly mist, four wisps swirl",
	},
	{
		Id = 11,
		Name = "Abyss",
		Mult = 10,
		Main = rgb(150, 60, 255),
		Second = rgb(20, 0, 40),
		Blurb = "void smoke, light pulled in, a halo",
	},
	{
		Id = 12,
		Name = "Leviathan",
		Mult = 12,
		Main = rgb(255, 255, 255),
		Second = rgb(255, 80, 200),
		Blurb = "a rainbow flame, two rainbow serpents",
	},
} :: { Tier }

-- Which spawn-in plays when a character appears (on every machine, for every player): 1 Splash, 2 Whirlpool,
-- 3 Drop. 0 turns it off. A draft: Hugo picks one.
Auras.SpawnStyle = 2
Auras.SpawnNames = { "Splash", "Whirlpool", "Drop" }

-- Studio only: a tier shown on your own player without the server (0 = off)
Auras.Test = 0

-- Auras further than this from the camera are not animated (their parts are hidden)
Auras.DrawRange = 220

function Auras.get(id: number): Tier?
	return Auras.Tiers[id]
end

return Auras
