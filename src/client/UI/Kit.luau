--!strict
-- The HUD's kit: its colours, its letters and the few shapes every piece is made of. The look is pass 4 of
-- docs/design/ui.md (Hugo, 2026-11-12: bolder): every plate is a chunky rounded shape with a thick dark outline, a
-- light line inside it, a top-to-bottom gradient, a faint pattern over it and a shadow under it, in a theme that says
-- what the piece is for (Kit.Themes). Letters have a thick outline. It is Roblox's own UI plus two pictures that were
-- already uploaded for the map (Kit.Textures); nothing new is uploaded.
-- Rules for phones: nothing here is made per frame, text never changes size, a label's text is only set when it
-- changes, and only what Kit.pulse is given is tweened.

-- In this file, in order:
--   Colours, spacing and pictures: the HUD's colours, outline widths, corners and uploaded textures
--   Plate styles and the Oxygen box: what a plate style holds, and which glass box the Oxygen row wears
--   Ring looks: the options for the Oxygen and tame rings, and the one in use
--   Glass boxes and themes: the see-through box options, and one plate theme for each purpose
--   Lands and look switches: land colours, and which option each screen shows
--   Basic builders: new instances, lighter and darker colours, corners, outlines, gradients and letters
--   Rarity colours and styled words: rarity gradients, palettes and the fish tags' word style
--   Plates: dressing a frame as a plate or a glass box, and a plate with its shadow
--   Patterns and signs: stripes, grid paper, the warning pulse, and the bubble and coin signs
--   Rings: the sweeping arc, the emptying ring, the thin extra ring and seconds as text
--   Fail words: the slam band shown when a run fails
--   Numbers and touch: big numbers in short, and whether this is a phone

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

----------------------------------------------------------------------------------------------------------------------
-- Colours, spacing and pictures: the HUD's colours, outline widths, corners and uploaded textures

Kit.Font = Enum.Font.FredokaOne
Kit.Ink = Color3.fromRGB(16, 36, 63) -- every outline
Kit.Deep = Color3.fromRGB(10, 24, 44) -- every dark see-through fill: bars, slots, pills, the button, a ring's used part
Kit.Danger = Color3.fromRGB(214, 44, 56) -- a plate that warns: dark enough for white letters
Kit.Navy = Color3.fromRGB(24, 52, 92)
Kit.Aqua = Color3.fromRGB(51, 214, 240)
Kit.Sun = Color3.fromRGB(255, 210, 63)
Kit.Coral = Color3.fromRGB(255, 90, 95)
Kit.Good = Color3.fromRGB(141, 240, 106)
Kit.Pink = Color3.fromRGB(240, 96, 200)
Kit.White = Color3.new(1, 1, 1)
Kit.Edge = Color3.fromRGB(10, 12, 22) -- the dock's one outline: every window, card, button and hub plate

-- The outline's widths and the corners
Kit.Outline = { Hair = 1.2, Thin = 2, Bold = 3, Heavy = 4 }
Kit.Radius = { Tile = 5, Plate = 9, Round = 999 }

-- Pictures laid over a plate as its pattern, both uploaded before this pass: the map's stud tile
-- (art/map/textures.json, "tile2") and the picture the moving water drifts (tools/map/water_look.luau)
Kit.Textures = {
	Studs = "rbxassetid://124244361010023",
	Water = "rbxassetid://6126332496",
	-- the user's own O2 bubble (2026-11-17; art/ui/icons), and the green cash of the free icon pack the reference
	-- uses, which took the place of the user's own cash picture that day (art/ui/icons/CREDITS.md)
	Oxygen = "rbxassetid://133981557523389", -- the user's second O2 picture, in the pack's flat style
	Cash = "rbxassetid://119031387165673",
	-- from the free icon pack the reference uses (art/ui/icons/CREDITS.md): the Shop's basket, the Index's book
	Shop = "rbxassetid://139519009824812",
	Index = "rbxassetid://136062585112653",
	-- the raised square tile for a button's faint block pattern (art/ui/tiles/emboss_square.png, drawn by
	-- tools/ui/make_ui_tile.py), uploaded 2026-11-17 on the user's word
	Emboss = "rbxassetid://74391096180253",
}
-- The colour of money beside the cash: the reference's pale green
Kit.Cash = Color3.fromRGB(170, 255, 127)

----------------------------------------------------------------------------------------------------------------------
-- Plate styles and the Oxygen box: what a plate style holds, and which glass box the Oxygen row wears

export type Style = {
	Top: Color3, -- the fill, top to bottom
	Bottom: Color3,
	Edge: Color3?, -- the outline (the ink, if not given)
	Outline: number?, -- its width (3)
	Radius: number?, -- 999 and up: a circle or a pill
	Fade: number?, -- how see-through the fill is
	Texture: string?, -- a name in Kit.Textures
	TextureFade: number?,
	TextureSize: number?, -- one repeat of the picture, in the HUD's points
	Bevel: boolean?, -- the light line inside the outline (on, unless false)
	Shine: boolean?, -- a pale band over the upper half, as on glass
	Flat: boolean?, -- the plainer plate (Hugo, 2026-11-13): one colour, no light line, no shine, a hairline outline
	Box: boolean?, -- dressed as the chosen glass box, Kit.OxygenBox (0 there: as Flat)
	Drop: number?, -- how far under the plate its shadow sits (Kit.panel only; 0 for none)
}

-- The Oxygen row as a see-through box with highlights (Hugo, 2026-11-13: "a see through box with highlights, not a
-- custom rounded thing"): the options of docs/design/ui.md, "The Oxygen row as a glass box". Hugo's pick is this
-- one number: 0 is the flat plate before it (task u1), 1 to 5 the boxes in Kit.Boxes.
Kit.OxygenBox = 5

-- Hugo picked 5 (2026-11-14) and drew it grown into the screen's bottom left corner, with "a fade going from top to
-- bottom" on its fill (docs/design/ui.md, "The Oxygen box in the corner"). Which way the fade runs, one letter:
-- "A" strongest at the top, see-through at the screen's bottom edge; "B" the other way round; "" no fade.
Kit.OxygenBoxFade = "A"
-- how see-through the fill is at each end of the fade, on top of the box's own Fade (0 as the box is, 1 clear)
Kit.FadeEnds = { Strong = 0, Clear = 1 }

----------------------------------------------------------------------------------------------------------------------
-- Ring looks: the options for the Oxygen and tame rings, and the one in use

-- The Oxygen ring and the tame ring beside the rider (Hugo, 2026-11-18, task h1; docs/design/ui.md, "The Oxygen ring
-- in ticks, the red zone and the extra rings"):
-- Which look the two rings wear (Hugo, 2026-11-18, task b1: "give me more options for the bars, show me how they
-- progress, make it very slightly more detailed and make the border completely black"). 1 is the live look; 2 to 7
-- are the options on docs/attachments/oxygen-bar-options-1.png, one number to try each. Every look's border is
-- pure black and solid. Read when this module loads: a change shows after a restart of the playtest.
Kit.RingStyle = 1

export type RingStyle = {
	Name: string,
	Outline: number, -- the black line round the ring and its hole
	TrackFade: number, -- how see-through the used part is (0.5 until b1)
	Highlight: number?, -- a thin light line inside the outer edge, strongest at the top: how see-through there
	HoleShade: number?, -- a soft dark line on the band round the hole, strongest at the top: how see-through there
	Sheen: number?, -- the band's upper half paler, as on glass: how see-through at the top
	Rim: number?, -- a light line round the hole: how see-through
	TwoTone: number?, -- the inner half of the part left a lighter shade: how far toward white
	Segments: number?, -- black lines across the band, this many round the circle
	SegmentWidth: number?, -- whole points
	Shadow: number?, -- a dark copy of the band this far below it
	Lead: boolean?, -- a white line across the band at the end of the part left
	ExtraThick: number?, -- the thin rings past BarSize: their band (else RingLook's)
	ExtraGap: number?,
	ExtraEdge: number?, -- a black line round each thin ring's outside (0: none)
}

Kit.RingStyles = {
	-- the live look: h1's ring, its line black, the band one flat colour (Hugo, 2026-11-18: "remove highlights/shadows
	-- make it blank": b1's light line at the top and shade round the hole taken out); the extra ring a black hairline
	{ Name = "Clean (live)", Outline = 0.6, TrackFade = 0.5, ExtraEdge = 0.6 },
	-- a black line across the band every twelfth of the circle
	{
		Name = "Segmented",
		Outline = 0.8,
		TrackFade = 0.5,
		Highlight = 0.6,
		Segments = 12,
		SegmentWidth = 1, -- (whole points: a UI offset is a whole number, 0.8 drew nothing)
		ExtraEdge = 0.6,
	},
	-- a heavier black line, a solid dark used part, a brighter light line: a cartoon sticker
	{
		Name = "Bold cartoon",
		Outline = 1.8,
		TrackFade = 0.2,
		Highlight = 0.2,
		ExtraThick = 3,
		ExtraGap = 2,
		ExtraEdge = 1,
	},
	-- see-through used part, the upper half paler, a light line round the hole
	{ Name = "Glass", Outline = 0.8, TrackFade = 0.7, Sheen = 0.55, Rim = 0.45, ExtraEdge = 0.6 },
	-- the inner half of the band a lighter aqua
	{ Name = "Two-tone band", Outline = 0.8, TrackFade = 0.5, TwoTone = 0.45, HoleShade = 0.6, ExtraEdge = 0.6 },
	-- a dark shadow under the ring, as if it floated over the water
	{
		Name = "Drop shadow",
		Outline = 1.2,
		TrackFade = 0.35,
		Highlight = 0.45,
		Shadow = 2.5,
		ExtraEdge = 0.8,
	},
	-- a white line where the part left ends, so the edge that moves is easy to read
	{ Name = "Lit edge", Outline = 0.8, TrackFade = 0.5, Highlight = 0.55, Lead = true, ExtraEdge = 0.6 },
} :: { RingStyle }

-- The Oxygen ring and the tame ring beside the rider (Hugo, 2026-11-18, task h1; docs/design/ui.md, "The Oxygen ring
-- in ticks, the red zone and the extra rings"; the white piece and one extra ring since o2): the chosen look (Kit.RingStyle) over these
Kit.RingLook = {
	Outline = 0.6, -- the black line round both rings and their holes (Kit.Outline.Hair, 1.2, until 2026-11-18)
	Border = Color3.new(0, 0, 0), -- its colour: pure black, solid (Kit.Ink until b1)
	-- each Oxygen tick (Hugo, 2026-11-18, task o2): the bar ticks down and leaves the piece it lost WHITE; that piece
	-- breaks off (fades out) when the next tick starts, and the new piece is white in its place. The 2/3 break-off on
	-- a fish too strong (Config.Oxygen.BreakOff) is one such piece. (Until o2: red, held 0.1 s, faded at once.)
	Held = Color3.new(1, 1, 1), -- the piece just lost, until the next tick
	TickFade = 0.3, -- seconds a broken-off piece takes to fade out; at most TickFadeShare of the gap between ticks
	TickFadeShare = 0.8, -- (task s1: with more ticks the gap gets short; the fade shortens so one is gone before the next)
	TickWait = 3, -- seconds a white piece waits for a next tick that never comes (a stop, the end) before it breaks
	-- The white piece DRAWS BACK instead of fading (Hugo, 2026-11-18, task t1: "the white should not just fade out but
	-- be drawn back with damage taken"): a health bar's damage trail, the white's end running back along the ring to
	-- what is left. A tick during a draw-in takes the trail on from where it is (it never jumps). Big pieces (the 2/3
	-- break-off) take longer, up to TrailDrawMost. On the extra ring too. Captures docs/attachments/oxygen-trail-*.gif.
	--   0 the old fade (o2: white until the next tick, then it fades out)
	--   1 Straight: white until the next tick as o2, then the old piece draws straight (evenly) back to the new one
	--   2 Hold, then ease in: every tick's white piece holds TrailHold, then draws in, quick then slowing, to what is left
	--   3 Draw and melt: as 2, and the white goes see-through (to TrailMelt) as it draws in
	TickTrail = 2,
	TrailHold = 0.08, -- seconds the white piece holds before it draws in (2, 3)
	TrailDraw = 0.22, -- seconds one tick's piece takes to draw in; at most TrailShare of the gap between ticks
	TrailShare = 0.7,
	TrailDrawMost = 0.5, -- a bigger piece takes longer (as the square root of its size in ticks), up to this
	TrailMelt = 0.6, -- 3: how see-through the white is at the end of its draw-in
	-- (o2: the red zone's mark across the band is gone; the angry mode on the fish stays)
	-- past Config.Oxygen.BarSize of max Oxygen, ONE more ring all round the big one: the Oxygen above BarSize
	-- (Hugo, 2026-11-18, task o2: "only one extra bar that goes fully around"; until o2 a thin ring per BarSize)
	ExtraThick = 4, -- its band (the big ring's is 16)
	ExtraGap = 1.5, -- between it and the big ring
	Style = Kit.RingStyles[1],
}
do
	local style = Kit.RingStyles[Kit.RingStyle] or Kit.RingStyles[1]
	Kit.RingLook.Style = style
	Kit.RingLook.Outline = style.Outline
	Kit.RingLook.ExtraThick = style.ExtraThick or Kit.RingLook.ExtraThick
	Kit.RingLook.ExtraGap = style.ExtraGap or Kit.RingLook.ExtraGap
end

----------------------------------------------------------------------------------------------------------------------
-- Glass boxes and themes: the see-through box options, and one plate theme for each purpose

export type Box = {
	Name: string,
	Fade: number, -- how see-through the body is (0 solid, 1 clear)
	Radius: number, -- the corners: 0 square
	Edge: number, -- the thin dark outline's width; 0: none (the line stays, nearly clear, for the warning's beat)
	Tint: number?, -- smoked glass: how far the body's colour goes toward Kit.Deep
	TopLine: number?, -- a light line along the inside of the top edge: how see-through (nil for none)
	TopColour: Color3?, -- its colour (white)
	Rim: number?, -- a light line all round the inside: how see-through at the top (it fades toward the bottom)
	Sheen: number?, -- the upper half paler, as on glass: how see-through at its top
	Streak: number?, -- two slanted glints across the right part: how see-through
	Glint: boolean?, -- a bright top right corner, fading along the top and down the side
	Floor: number?, -- a dark line along the inside of the bottom edge: how see-through
	Pattern: boolean?, -- keep the water's picture on the body
	Corner: boolean?, -- grows into the screen's bottom left corner (StatRows), fading as Kit.OxygenBoxFade says; no
	-- floor line there (it would sit on the screen's edge)
}

Kit.Boxes = {
	{ Name = "Clear glass, a top line", Fade = 0.6, Radius = 0, Edge = 1.2, TopLine = 0.15, Floor = 0.7 },
	{ Name = "Frosted, a light rim", Fade = 0.35, Radius = 2, Edge = 1.2, Rim = 0.35, Pattern = true },
	{ Name = "Glass with a sheen", Fade = 0.5, Radius = 3, Edge = 1.2, TopLine = 0.4, Sheen = 0.55, Streak = 0.72 },
	{ Name = "No dark line, a light edge", Fade = 0.55, Radius = 2, Edge = 0, Rim = 0.1, TopLine = 0.05 },
	{
		Name = "Smoked glass, an aqua top",
		Fade = 0.3,
		Radius = 0,
		Edge = 1.2,
		Tint = 0.65,
		TopLine = 0.05,
		TopColour = Color3.fromRGB(51, 214, 240),
		Glint = true,
		Floor = 0.5,
		Corner = true,
	},
} :: { Box }

-- One theme a purpose: what a plate is for is read from its colour and its pattern before its words
Kit.Themes = {
	-- air: water-blue, bubbles
	Oxygen = {
		Top = Color3.fromRGB(72, 204, 255),
		Bottom = Color3.fromRGB(18, 96, 208),
		Texture = "Water",
		TextureFade = 0.72,
		TextureSize = 72,
		Flat = true,
		Box = true,
	},
	-- out of air, a miss: deep red going to black
	Danger = {
		Top = Color3.fromRGB(226, 52, 60),
		Bottom = Color3.fromRGB(70, 6, 28),
		Texture = "Water",
		TextureFade = 0.86,
		TextureSize = 72,
	},
	-- the press that is the game: yellow to orange (the stripes are Kit.stripes)
	Action = { Top = Color3.fromRGB(255, 226, 72), Bottom = Color3.fromRGB(255, 132, 24) },
	Grab = { Top = Color3.fromRGB(120, 240, 255), Bottom = Color3.fromRGB(20, 150, 226) },
	Off = { Top = Color3.fromRGB(128, 140, 160), Bottom = Color3.fromRGB(72, 82, 104) },
	-- money and a best: gold bricks
	Gold = {
		Top = Color3.fromRGB(255, 232, 110),
		Bottom = Color3.fromRGB(240, 150, 20),
		Texture = "Studs",
		TextureFade = 0.7,
		TextureSize = 28,
	},
	-- good news
	Good = {
		Top = Color3.fromRGB(96, 214, 96),
		Bottom = Color3.fromRGB(18, 110, 58),
		Texture = "Studs",
		TextureFade = 0.8,
		TextureSize = 28,
	},
	-- a plain dark plate: bricks
	Navy = {
		Top = Color3.fromRGB(38, 76, 130),
		Bottom = Color3.fromRGB(14, 32, 60),
		Texture = "Studs",
		TextureFade = 0.88,
		TextureSize = 28,
	},
	-- what holds a creature: an aquarium's glass
	Glass = {
		Top = Color3.fromRGB(170, 232, 255),
		Bottom = Color3.fromRGB(30, 110, 190),
		Fade = 0.45,
		Texture = "Water",
		TextureFade = 0.8,
		TextureSize = 64,
		Shine = true,
	},
	-- ours, not the player's: a tool's dark slate (the squares are Kit.grid)
	Tool = {
		Top = Color3.fromRGB(54, 62, 76),
		Bottom = Color3.fromRGB(26, 31, 41),
		Edge = Color3.fromRGB(8, 10, 14),
		Bevel = false,
	},
	-- a key of the keyboard
	Key = { Top = Color3.new(1, 1, 1), Bottom = Color3.fromRGB(206, 216, 232), Radius = 7 },
} :: { [string]: Style }

----------------------------------------------------------------------------------------------------------------------
-- Lands and look switches: land colours, and which option each screen shows

-- One colour a land, the map's own (tools/map/greybox.py, GROUND), and a short name for the strip's small tiles
Kit.Lands = {
	Color3.fromRGB(242, 214, 128),
	Color3.fromRGB(244, 148, 152),
	Color3.fromRGB(120, 172, 92),
	Color3.fromRGB(160, 148, 124),
	Color3.fromRGB(90, 124, 176),
	Color3.fromRGB(104, 96, 170),
	Color3.fromRGB(62, 66, 120),
	Color3.fromRGB(120, 72, 64),
	Color3.fromRGB(150, 150, 168),
	Color3.fromRGB(110, 44, 60),
}
Kit.LandShort = { "Shallows", "Reef", "Kelp", "Wrecks", "Blue", "Twilight", "Midnight", "Vents", "Bones", "Under" }

-- The land strip with a picture of each land (Hugo, 2026-11-17: "use first style, but remove the inner border, make the
-- numbers more stylised to each map part"; task l1, docs/design/ui.md "The land strip, style A"). 0 is today's strip
-- of coloured tiles; 1 the framed pictures, your avatar under them, the colour revealed as you go and the best line.
-- In Studio the workspace's "LandStripStyle" number overrides it. On (Boss, 2026-11-17, Hugo: "make sure map icons are
-- implemented"); the pictures are the generated set G4 since task l1 (docs/attachments/land-icons-gen-1.png; `atlas.py
-- --gen 4 --studio`).
Kit.LandStripStyle = 1
-- On style 1 every number and word is built as a rarity word (Kit.word) in its land's colour (task l1 replaced the
-- three number looks N1 to N3 of task l1's first round). The lands that glow in the map glow in their number too.
Kit.LandGlows = { [7] = true, [8] = true, [10] = true }
-- What colours the pictures in: "Dive" (how far this dive has got) or "Best" (the furthest ever, so the lands you have
-- reached stay in colour at a dive's start). Workspace "LandReveal". "Best" since task l1 (2026-11-18): a land's lock
-- breaks once, at your best, and the colour stays with it; the bar under the strip shows this dive.
Kit.LandReveal = "Best"
-- The pictures: one uploaded atlas, ten cells of LAND_CELL pixels across, colour on the top row and the grey locked
-- look under it (tools/ui/land_icons/atlas.py). Not uploaded yet: until it is, the tiles are plain land colour. In
-- Studio the workspace's "LandAtlas" string overrides it (rbxasset://textures/ridefish/land_atlas.png is a copy in
-- Studio's own content folder, for tests without an upload).
-- (uploaded 2026-11-22, the user: "Could we integrate that into the push too": the G4 set, art/ui/icons/roblox.json)
Kit.LandAtlas = "rbxassetid://124258870686064"
-- In Studio, while LandAtlas is empty, the strip reads the local copy so the pictures show without an upload.
Kit.LandAtlasStudio = "rbxasset://textures/ridefish/land_atlas_g4.png"
-- A land not reached (Hugo, 2026-11-18: "make sure its actually a screenshot even when locked, just unsaturated and
-- darker"; task s2): its own picture, desaturated and darkened in the game. The atlas carries a grey copy under each
-- colour picture; the colour one lies over it at Saturation (0 grey, 1 full colour) and both are multiplied by Tint
-- times Dark (1 as bright as the picture). Blur 0 sharp, 1 soft, 2 very soft: a pre-blurred copy in the atlas (a
-- Roblox ImageLabel cannot blur). Workspace "LandDark", "LandSaturation", "LandBlur" override them in Studio.
-- Sheet docs/attachments/land-strip-D-1.png.
Kit.LandLocked = { Dark = 0.62, Saturation = 0.3, Blur = 0, Tint = Color3.fromRGB(214, 224, 255) }
-- Hugo's picks from the mixes sheet (2026-11-18, task l1, docs/attachments/land-strip-mixes-1.png) are built in, not
-- switches: Mix 3's gold diamond on the line for your best, a thin bar like Mix 1's filled toward your best, your face
-- in a black ring over a flat black oval with the metres, one even border on every picture, locks that break once.
-- The metres' font (Hugo: "a cartoon font ... pick the best"; the sheet docs/attachments/land-strip-l1-fonts-1.png).
-- Workspace "LandMetresFont" (the font's name) overrides it in Studio.
Kit.LandMetresFont = Enum.Font.LuckiestGuy
-- The intro when you enter a land deeper than any yet this dive (not the one a dive starts in; going back up and down
-- again does not replay it). The first time ever in a land it also says NEW LAND and its lock breaks on the strip.
-- 0 off (the old land banner, Banners.land, plays instead); 1 Punch: the land's name big at the top centre, its number
-- over it, in its colour, about 1.5 s; 2 Banner: a chunky plate slides in from the left; 3 Fly: the strip's tile pops
-- and flies to the centre with the name under it; 4 Subtitle: one line "LAND 3 · KELP FOREST · 600 m" under the strip;
-- 5 Flash: the screen flashes the land's colour, the depth punches in. Workspace "LandIntroLook" overrides it in Studio.
-- Sheet docs/attachments/land-strip-l1-intro-1.png.
Kit.LandIntroLook = 1
-- On a phone (HUD scale 1 at 390 px high) the strip is drawn this much bigger, so its numbers and words read
-- (Nemu's review of task l1: at 1 they were a few pixels high)
Kit.LandPhoneScale = 1.25

-- The end of a dive and what came home (task s3; Hugo, 2026-11-18: "make sure it counts all the fish that were caught
-- in with a better animation, give me a couple options"): 0 Banners' own (the title, the tokens, the metres, as
-- before); in CatchShow, 1 Cards (each fish flips over in turn, the count ticks), 2 Stack (a list slides in at the
-- right, a badge counts), 3 Big number (one number rolls up, the fish burst out of it), 4 Toast (a compact pill under the
-- strip that fills). Sheet docs/attachments/catch-ui-options-1.png. In Studio the workspace's "CatchLook" overrides it.
-- Hugo picked 3 (task c1, 2026-11-19), built into the game with his changes: the catch screen (CatchShow, "3").
-- Hugo (task gd1, 2026-11-19): GREAT DIVE rebuilt on caught text 5's banner, the fish plopping in one by one and a
-- shiny number counting them: look 5 (DiveScreen), now the default.
Kit.CatchLook = 5
-- Its variant (DiveScreen): 1 Slam (the band slashes open, each fish slams down from the camera, the number shimmers
-- gold), 2 Drop (the band drops and bounces, the fish drop and bounce, the number in the rarity's colours), 3 Pop (the
-- band unrolls, the fish pop and overshoot, the number bursts on each count), 4 Stamp (the band and each fish stamp
-- down with dust, the number shimmers and bursts). Sheet docs/attachments/great-dive-options-1.png. In Studio the
-- workspace's "DiveLook" number overrides it. Hugo picked 2 (Drop, 2026-11-19: "the number changes colour with
-- rarity of fish, it looks the best").
Kit.DiveLook = 2

-- The words the moment a fish becomes yours (task t2; Hugo, 2026-11-19: "give me a selection for being caught ... make
-- it more stylised like the rest of the text UI, and it should feel better"): 0 Banners' own tilted "TAMED!" plate (as
-- before); in CaughtText, 1 Punch ("CAUGHT!" punches in at the top out of a closing ring), 2 Stamp (a rarity stamp
-- slams down with dust, the name unrolls on a ribbon), 3 Banner (the old plate at the left redone: whips in, the
-- portrait pops, the word drops on), 4 Burst (the portrait bursts out of a point with rays and confetti), 5 Slam (a
-- rarity band slashes across, the word slams onto it, the screen shakes). Sheet docs/attachments/caught-text-options-1.png
-- (GIFs caught-text-<n>.gif). Hugo picked 3 Banner (2026-11-19). In Studio the workspace's "CaughtLook" number
-- overrides it.
Kit.CaughtLook = 3

-- The tags over wild fish (Hugo, 2026-11-14: "attract the player more and feel less clumped"): the options of
-- docs/design/ui.md, "Fish tag options". 0 is the stacked tag (rarity, name, Needs); 1 to 6 the looks in Tags.Looks;
-- 7 Hugo's own three lines (2026-11-14: the rarity's word and the class icons, the name in white, "Required: n" and
-- the bubble; ui.md, "Every rarity's tag"), the game's tag. In Studio the workspace's "FishTags" number overrides it.
Kit.FishTags = 7

-- On the three-line tag (7), the fish's size chip and all its archetype icons sit on one row under the rarity's word
-- (Hugo, 2026-11-14: "put size and icons below rarity, make the sizes cooler too"; Handoff, task r4). Which
-- chip: 1 Glass (a dark pill edged and lettered in the size's colour; from Giant a gloss, from Huge a glow, Colossal
-- two gems), 2 Meter (a dark pill, white letters and five bars filled to the size), 3 Solid (a pill filled with the
-- size's colour, white letters, glossy; glow and gems at the top), 4 Sticker (live since 2026-11-17, Hugo's pick, S8 of
-- docs/attachments/fish-tags-size-text-options-1.png: no chip; the size as a small word built like the rarity word, in
-- its own colours cool to hot, tilted on the word's top-left corner, kept on far and crowded tags). In Studio the
-- workspace's "SizeChip" overrides it.
Kit.SizeChip = 4

-- The rarity's word on the three-line tag: which designed style each rarity takes (ui.md, "Rarity word options";
-- Hugo, 2026-11-14: "needs different font and they all need a look with highlights shading and gradients"). Empty:
-- r1's look (the tag's own font, its colour, glow from Rare). A rarity's number is its column on the options sheet,
-- e.g. { Common = 1, Legendary = 4 }; a rarity not named keeps r1's look. In Studio the workspace's "RarityWord"
-- string overrides it: "0" r1's look, "2" option 2 for every rarity, or codes "C1 U1 R2 E1 L4 M1 S3".
-- Live since 2026-11-14 (Hugo: "use the gotham black and make sure legendary + are animated and integrated"): style 5,
-- Gotham Black in the name's ink edge, every rarity; Legendary, Mythic and Secret each move in their own way.
Kit.RarityWords = {
	Common = 5,
	Uncommon = 5,
	Rare = 5,
	Epic = 5,
	Legendary = 5,
	Mythic = 5,
	Secret = 5,
} :: { [string]: number }

-- A fish you would hold this long reads green; shorter, yellow; under Short, red (the tuning chat's three steps)
Kit.HoldFine = 2
Kit.HoldShort = 0.5

----------------------------------------------------------------------------------------------------------------------
-- Basic builders: new instances, lighter and darker colours, corners, outlines, gradients and letters

function Kit.new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class :: any)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function Kit.lighter(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end

function Kit.darker(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end

-- Round corners; 999 and up makes a circle or a pill
function Kit.corner(parent: Instance, radius: number)
	Kit.new("UICorner", { CornerRadius = if radius >= 999 then UDim.new(0.5, 0) else UDim.new(0, radius) }, parent)
end

function Kit.stroke(parent: Instance, thickness: number, colour: Color3, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness,
		Color = colour,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- A top-to-bottom gradient of colour on a frame, or in a label's letters
function Kit.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, parent)
end

-- Letters with a thick dark outline (a little thicker on big letters). The size is fixed: text never scales to fit.
function Kit.text(props: { [string]: any }, parent: Instance, outline: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Kit.Font
	props.TextColor3 = props.TextColor3 or Kit.White
	props.TextSize = props.TextSize or 14
	props.Text = props.Text or ""
	local label: TextLabel = Kit.new("TextLabel", props, parent)
	Kit.stroke(label, outline or math.clamp(props.TextSize * 0.19, 1.6, 4), Kit.Ink)
	return label
end

----------------------------------------------------------------------------------------------------------------------
-- Rarity colours and styled words: rarity gradients, palettes and the fish tags' word style

local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 190)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 208, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 132, 16)),
})
local EMBER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 30, 120)),
})
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 120)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 90)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(250, 240, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 235, 150)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(110, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
})

-- A rarity's own colours, as a gradient and which way it runs (90: top to bottom). The lower rarities are their colour,
-- lighter at the top; a Legendary is gold, a Mythic an ember, and a Secret the rainbow, side to side
-- (docs/style/05-rarity-look.md: gold and the rainbow are the top of the ladder)
function Kit.tierFill(tier: string, colours: { [string]: any }): (ColorSequence, number)
	if tier == "Legendary" then
		return GOLD, 90
	elseif tier == "Mythic" then
		return EMBER, 90
	elseif tier == "Secret" then
		return RAINBOW, 0
	end
	local entry = colours[tier]
	local colour: Color3 = if entry then entry.Colour else Kit.White
	return ColorSequence.new(Kit.lighter(colour, 0.45), colour), 90
end

-- A rarity's word in those colours (the label's own colour must stay white for the gradient to show)
function Kit.tierColours(label: TextLabel, gradient: UIGradient, tier: string, colours: { [string]: any })
	label.TextColor3 = Kit.White
	gradient.Color, gradient.Rotation = Kit.tierFill(tier, colours)
end

-- Words built like the fish tags' rarity word (Tags.luau, family 5, the live Kit.RarityWords style): the same layers
-- of one word, back to front: a soft glow in its colour (where it fits), one darker copy a step down (its depth), the
-- word in a metal gradient split at the middle (lit top, its colour, a shade) with a thick ink edge, and a thin white
-- shine line across its top third. A palette is a rarity's four tones (Tags' PAL): the lit top, the colour, the shade,
-- the deepest. Used by the land strip (task l1, Hugo 2026-11-18: "every text and number on the strip ... built like the
-- fish tags' rarity words").
export type Pal = { Light: Color3, Mid: Color3, Dark: Color3, Deep: Color3 }
-- Tags' Legendary tones: your best is gold
Kit.GoldPal = {
	Light = Color3.fromRGB(255, 252, 200),
	Mid = Color3.fromRGB(255, 208, 48),
	Dark = Color3.fromRGB(238, 128, 16),
	Deep = Color3.fromRGB(122, 52, 6),
} :: Pal
-- Tags' Common tones, darker: a land not reached
Kit.LockedPal = {
	Light = Color3.fromRGB(214, 220, 230),
	Mid = Color3.fromRGB(150, 158, 174),
	Dark = Color3.fromRGB(98, 108, 128),
	Deep = Color3.fromRGB(40, 46, 62),
} :: Pal
Kit.WhitePal = {
	Light = Color3.new(1, 1, 1),
	Mid = Color3.fromRGB(236, 242, 250),
	Dark = Color3.fromRGB(178, 192, 214),
	Deep = Color3.fromRGB(58, 66, 84),
} :: Pal

-- A palette from one colour: the map's land colours are muted (Midnight is a dark navy), so the word's colour is that
-- hue made brighter and fuller, the way the rarities' are
function Kit.palOf(colour: Color3): Pal
	local h, s, v = colour:ToHSV()
	local full = Color3.fromHSV(h, math.min(1, s * 1.35 + 0.08), math.max(v, 0.9))
	-- a touch of white, so the deep blues and violets still read on the dark
	local mid = full:Lerp(Color3.new(1, 1, 1), 0.2)
	return {
		Light = full:Lerp(Color3.new(1, 1, 1), 0.66),
		Mid = mid,
		Dark = Color3.fromHSV(h, math.min(1, s * 1.35 + 0.15), math.max(v, 0.9) * 0.66),
		Deep = Color3.fromHSV(h, math.min(1, s * 1.2 + 0.2), 0.3),
	}
end

-- Tags' family-5 fill: hard metal shading split at the middle
function Kit.wordFill(p: Pal): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Kit.lighter(p.Light, 0.5)),
		ColorSequenceKeypoint.new(0.48, p.Light:Lerp(p.Mid, 0.35)),
		ColorSequenceKeypoint.new(0.52, p.Mid),
		ColorSequenceKeypoint.new(1, p.Mid:Lerp(p.Dark, 0.55)),
	})
end

export type Word = {
	root: Frame,
	main: TextLabel,
	wide: number,
	high: number,
	set: (text: string) -> (),
	paint: (p: Pal, glow: boolean?) -> (),
	setSize: (size: number) -> (),
}

local WordText = game:GetService("TextService")

-- One word in that style. props: TextSize, Text, Font (Gotham Black, as the tags), ZIndex (its back layer; it takes
-- four), AnchorPoint, Position, Name, Pal, Glow, Edge (the ink edge's share of the size, for big words: 0.17 and at
-- most 3.4 px if not given). Its root frame hugs the letters (edge and glow spill over), and is resized as the text
-- changes; `wide` and `high` are that size.
function Kit.word(parent: Instance, props: { [string]: any }): Word
	local font: Enum.Font = props.Font or Enum.Font.GothamBlack
	local size: number = props.TextSize or 12
	local edgeShare: number? = props.Edge
	local z: number = props.ZIndex or 1
	local root: Frame = Kit.new("Frame", {
		Name = props.Name or "Word",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local function layer(at: number): TextLabel
		return Kit.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = font,
			TextColor3 = Kit.White,
			Text = "",
			ZIndex = z + at,
		}, root)
	end
	local glow = layer(0)
	glow.TextTransparency = 0.4
	local glowEdge = Kit.stroke(glow, 4, Kit.White, 0.62)
	local drop = layer(1)
	local dropEdge = Kit.stroke(drop, 2, Kit.Ink)
	local main = layer(2)
	local mainFill = Kit.gradient(main, Kit.White, Kit.White)
	local mainEdge = Kit.stroke(main, 2, Kit.Ink)
	local shine = layer(3)
	Kit.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 1),
			NumberSequenceKeypoint.new(0.3, 0.15),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)
	local layers = { glow, drop, main, shine }
	local self: Word = {
		root = root,
		main = main,
		wide = 0,
		high = 0,
		set = nil :: any,
		paint = nil :: any,
		setSize = nil :: any,
	}
	local text = ""
	local function fit()
		local measured = WordText:GetTextSize(text, size, font, Vector2.new(2000, 200))
		self.wide = math.ceil(measured.X) + 2
		self.high = math.ceil(size) + 2
		root.Size = UDim2.fromOffset(self.wide, self.high)
	end
	function self.setSize(n: number)
		size = n
		local edge = if edgeShare then math.max(1.5, size * edgeShare) else math.clamp(size * 0.17, 1.5, 3.4)
		for _, label in layers do
			label.TextSize = size
		end
		mainEdge.Thickness = edge
		dropEdge.Thickness = edge
		-- Tags' glow is 3.5 to 6.5 px round a 15 to 19 px word; a small word gets a thin one, or it reads as a blot
		glowEdge.Thickness = edge + math.clamp(size * 0.14, 1, 4)
		drop.Position = UDim2.new(0.5, 0, 0.5, math.max(1, size * 0.1))
		fit()
	end
	function self.set(t: string)
		if t == text then
			return
		end
		text = t
		for _, label in layers do
			label.Text = t
		end
		fit()
	end
	function self.paint(p: Pal, withGlow: boolean?)
		mainFill.Color = Kit.wordFill(p)
		drop.TextColor3 = Kit.darker(p.Deep, 0.2)
		glow.Visible = withGlow == true
		glow.TextColor3 = p.Mid
		glowEdge.Color = p.Mid
	end
	self.setSize(size)
	self.set(props.Text or "")
	self.paint(props.Pal or Kit.WhitePal, props.Glow)
	return self
end

----------------------------------------------------------------------------------------------------------------------
-- Plates: dressing a frame as a plate or a glass box, and a plate with its shadow

export type Dressed = {
	Fill: UIGradient,
	Outline: UIStroke,
	Bevel: UIStroke?,
	Texture: ImageLabel?,
	paint: (top: Color3, bottom: Color3) -> (),
}

local BEVEL = NumberSequence.new(0.3, 0.88)
local SHINE = NumberSequence.new(0.66, 1)
local FLAT_MIX = 0.3 -- a flat plate's one colour: this far from its theme's top colour to its bottom one

local function outlineOf(style: Style): number
	return style.Outline or (if style.Flat then Kit.Outline.Hair else Kit.Outline.Bold)
end

local function fillOf(style: Style, top: Color3, bottom: Color3): ColorSequence
	return if style.Flat then ColorSequence.new(top:Lerp(bottom, FLAT_MIX)) else ColorSequence.new(top, bottom)
end

-- The glass box a style is dressed as, if any (read when it is dressed, so a test can switch Kit.OxygenBox live)
local function boxOf(style: Style): Box?
	if style.Box then
		return Kit.Boxes[Kit.OxygenBox]
	end
	return nil
end

-- The top-to-bottom fade of a corner box's fill (Kit.OxygenBoxFade), or nil for none
local function fadeOf(box: Box): NumberSequence?
	if not box.Corner then
		return nil
	end
	local strong, clear = Kit.FadeEnds.Strong, Kit.FadeEnds.Clear
	if Kit.OxygenBoxFade == "A" then
		return NumberSequence.new(strong, clear)
	elseif Kit.OxygenBoxFade == "B" then
		return NumberSequence.new(clear, strong)
	end
	return nil
end

-- A light (or dark) line of `thick` points along the inside of one edge of a face
local function edgeLine(face: Instance, name: string, bottom: boolean, thick: number, colour: Color3, fade: number)
	return Kit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0, if bottom then 1 else 0),
		Position = UDim2.fromScale(0, if bottom then 1 else 0),
		Size = UDim2.new(1, 0, 0, thick),
		BackgroundColor3 = colour,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, face)
end

-- A plate dressed as a see-through box (Kit.Boxes): one colour over the water, square or nearly square corners, the
-- thin dark outline (or none) and its highlights. Returns the same handles as a plate, so paint and the beat work.
local function dressBox(face: GuiObject, style: Style, box: Box): Dressed
	face.BackgroundColor3 = Kit.White
	face.BackgroundTransparency = box.Fade
	face.BorderSizePixel = 0
	if box.Radius > 0 then
		Kit.corner(face, box.Radius)
	end
	local tint = box.Tint or 0
	local function colours(top: Color3, bottom: Color3): ColorSequence
		return ColorSequence.new(top:Lerp(bottom, FLAT_MIX):Lerp(Kit.Deep, tint))
	end
	local fill = Kit.gradient(face, style.Top, style.Bottom)
	fill.Color = colours(style.Top, style.Bottom)
	-- the fade rides on the fill's own gradient (rotation 90: top to bottom), so painting it red keeps it
	local fade = fadeOf(box)
	if fade then
		fill.Transparency = fade
	end
	-- with no dark line the stroke is kept nearly clear: the row's warning still beats it (StatRows)
	local outline = Kit.stroke(face, if box.Edge > 0 then box.Edge else 1.2, Kit.Ink, if box.Edge > 0 then 0 else 0.85)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.LineJoinMode = if box.Radius > 0 then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter
	local texture: ImageLabel? = nil
	if box.Pattern and style.Texture then
		local size = style.TextureSize or 32
		texture = Kit.new("ImageLabel", {
			Name = "Pattern",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Kit.Textures[style.Texture],
			ImageTransparency = style.TextureFade or 0.8,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(size, size),
			ZIndex = 0,
		}, face)
		if box.Radius > 0 then
			Kit.corner(texture :: ImageLabel, box.Radius)
		end
	end
	if box.Sheen then
		local sheen = Kit.new("Frame", {
			Name = "Sheen",
			Size = UDim2.fromScale(1, 0.48),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, face)
		if box.Radius > 0 then
			Kit.corner(sheen, box.Radius)
		end
		Kit.new("UIGradient", { Transparency = NumberSequence.new(box.Sheen, 1), Rotation = 90 }, sheen)
	end
	if box.Streak then
		-- two slanted bands of light, a broad one and a thin one, over the right part of the box
		local s = box.Streak
		local band = Kit.new("Frame", {
			Name = "Streak",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, face)
		if box.Radius > 0 then
			Kit.corner(band, box.Radius)
		end
		Kit.new("UIGradient", {
			Rotation = -62,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(0.601, s),
				NumberSequenceKeypoint.new(0.68, s),
				NumberSequenceKeypoint.new(0.681, 1),
				NumberSequenceKeypoint.new(0.72, 1),
				NumberSequenceKeypoint.new(0.721, s),
				NumberSequenceKeypoint.new(0.745, s),
				NumberSequenceKeypoint.new(0.746, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, band)
	end
	local bevel: UIStroke? = nil
	if box.Rim then
		local inset = 1.5
		local line = Kit.new("Frame", {
			Name = "Rim",
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, face)
		if box.Radius > 0 then
			Kit.corner(line, math.max(box.Radius - 1, 1))
		end
		bevel = Kit.stroke(line, 1, Kit.White)
		local rim = bevel :: UIStroke
		rim.LineJoinMode = if box.Radius > 0 then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter
		Kit.new(
			"UIGradient",
			{ Transparency = NumberSequence.new(box.Rim, math.min(box.Rim + 0.45, 0.95)), Rotation = 90 },
			rim
		)
	end
	if box.TopLine then
		local top = edgeLine(face, "TopLine", false, 1.5, box.TopColour or Kit.White, 0)
		-- brightest at the left, fading toward the right corner
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, box.TopLine),
				NumberSequenceKeypoint.new(0.7, box.TopLine),
				NumberSequenceKeypoint.new(1, math.min(box.TopLine + 0.5, 0.95)),
			}),
		}, top)
	end
	if box.Floor and not box.Corner then
		edgeLine(face, "Floor", true, 1.5, Kit.Ink, box.Floor)
	end
	if box.Glint then
		-- a bright corner: a short line along the top and down the side, meeting in the top right corner
		for _, side in { { 14, 2, 0 }, { 2, 8, 0 } } do
			local piece = Kit.new("Frame", {
				Name = "Glint",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 2),
				Size = UDim2.fromOffset(side[1], side[2]),
				BackgroundColor3 = Kit.White,
				BackgroundTransparency = side[3],
				BorderSizePixel = 0,
				ZIndex = 0,
			}, face)
			Kit.new("UIGradient", {
				Rotation = if side[1] > side[2] then 180 else 90,
				Transparency = NumberSequence.new(0, 1),
			}, piece)
		end
	end
	local function paint(top: Color3, bottom: Color3)
		fill.Color = colours(top, bottom)
	end
	return { Fill = fill, Outline = outline, Bevel = bevel, Texture = texture, paint = paint }
end

-- Dresses a frame as a plate of the look: the gradient, the thick outline, the light line inside it, the pattern and
-- the shine. What it adds sits under the frame's own children (ZIndex 0). The frame's own colour becomes white: the
-- gradient carries the colour from then on (paint changes it). A Flat style is the plainer plate: one colour (still
-- carried by the gradient, so paint works the same), a hairline outline, and neither the light line nor the shine.
function Kit.dress(face: GuiObject, style: Style): Dressed
	local box = boxOf(style)
	if box then
		return dressBox(face, style, box)
	end
	local radius = style.Radius or Kit.Radius.Plate
	local round = radius >= 999
	face.BackgroundColor3 = Kit.White
	face.BackgroundTransparency = style.Fade or 0
	face.BorderSizePixel = 0
	Kit.corner(face, radius)
	local flat = style.Flat == true
	local fill = Kit.gradient(face, style.Top, style.Bottom)
	fill.Color = fillOf(style, style.Top, style.Bottom)
	local outline = Kit.stroke(face, outlineOf(style), style.Edge or Kit.Ink)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local texture: ImageLabel? = nil
	if style.Texture then
		local size = style.TextureSize or 32
		texture = Kit.new("ImageLabel", {
			Name = "Pattern",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Kit.Textures[style.Texture],
			ImageTransparency = style.TextureFade or 0.8,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(size, size),
			ZIndex = 0,
		}, face)
		Kit.corner(texture :: ImageLabel, radius)
	end
	if style.Shine and not flat then
		local shine = Kit.new("Frame", {
			Name = "Shine",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0.5, -2),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, face)
		Kit.corner(shine, if round then 999 else math.max(radius - 2, 0))
		Kit.new("UIGradient", { Transparency = SHINE, Rotation = 90 }, shine)
	end
	local bevel: UIStroke? = nil
	if style.Bevel ~= false and not flat then
		local line = Kit.new("Frame", {
			Name = "Bevel",
			Position = UDim2.fromOffset(2.5, 2.5),
			Size = UDim2.new(1, -5, 1, -5),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, face)
		Kit.corner(line, if round then 999 else math.max(radius - 2.5, 0))
		bevel = Kit.stroke(line, 1.5, Kit.White)
		Kit.new("UIGradient", { Transparency = BEVEL, Rotation = 90 }, bevel)
	end
	local function paint(top: Color3, bottom: Color3)
		fill.Color = fillOf(style, top, bottom)
	end
	return { Fill = fill, Outline = outline, Bevel = bevel, Texture = texture, paint = paint }
end

export type Panel = { Frame: Frame, Face: Frame, Shadow: Frame, Look: Dressed }

-- A plate with its shadow: a clear holder (it takes the props: where and how big), the shadow a little under it and
-- the dressed face over that. What the plate holds goes in Face.
function Kit.panel(parent: Instance, props: { [string]: any }, style: Style): Panel
	props.BackgroundTransparency = 1
	local holder: Frame = Kit.new("Frame", props, parent)
	-- a see-through box has no shadow: it would show through the glass
	local box = boxOf(style)
	local drop = if box then 0 else style.Drop or 3
	local shadow: Frame = Kit.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, drop),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 10, 22),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = drop > 0,
		ZIndex = 0,
	}, holder)
	Kit.corner(shadow, style.Radius or Kit.Radius.Plate)
	Kit.stroke(shadow, outlineOf(style), Color3.fromRGB(4, 10, 22), 0.45)
	local face: Frame = Kit.new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1) }, holder)
	return { Frame = holder, Face = face, Shadow = shadow, Look = Kit.dress(face, style) }
end

----------------------------------------------------------------------------------------------------------------------
-- Patterns and signs: stripes, grid paper, the warning pulse, and the bubble and coin signs

-- Motion stripes: slanted pale bands over a plate, as one gradient (no picture, and it keeps to the plate's corners)
function Kit.stripes(face: Instance, radius: number, fade: number?): Frame
	local clear = 1
	local pale = fade or 0.78
	local points = {}
	local bands = 4
	for i = 0, bands - 1 do
		local from = (i + 0.2) / bands
		local to = (i + 0.62) / bands
		table.insert(points, NumberSequenceKeypoint.new(if i == 0 then 0 else from - 0.001, clear))
		table.insert(points, NumberSequenceKeypoint.new(from, pale))
		table.insert(points, NumberSequenceKeypoint.new(to, pale))
		table.insert(points, NumberSequenceKeypoint.new(to + 0.001, clear))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, clear))
	local frame: Frame = Kit.new("Frame", {
		Name = "Stripes",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, face)
	Kit.corner(frame, radius)
	Kit.new("UIGradient", { Transparency = NumberSequence.new(points), Rotation = -58 }, frame)
	return frame
end

-- A tool's squared paper: thin pale lines every cell points, over a plate up to wide by high
function Kit.grid(face: Instance, cell: number, wide: number, high: number)
	local sheet = Kit.new("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 0,
	}, face)
	for x = cell, wide, cell do
		Kit.new("Frame", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, sheet)
	end
	for y = cell, high, cell do
		Kit.new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
		}, sheet)
	end
end

-- Something that beats while a warning is on (an outline going bright and back): one tween, played and cancelled, the
-- only thing in the HUD that is tweened all the time it shows. rest is what the target goes back to.
function Kit.pulse(
	target: Instance,
	rest: { [string]: any },
	peak: { [string]: any },
	period: number?
): (on: boolean) -> ()
	local info = TweenInfo.new(period or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(target, info, peak)
	local running = false
	return function(on: boolean)
		if on == running then
			return
		end
		running = on
		if on then
			tween:Play()
		else
			tween:Cancel()
			for key, value in rest do
				(target :: any)[key] = value
			end
		end
	end
end

-- The sign for Oxygen: a bubble (three circles)
function Kit.bubble(parent: Instance, size: number): Frame
	local bubble: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.White,
	}, parent)
	Kit.corner(bubble, 999)
	Kit.stroke(bubble, math.max(1.5, size * 0.11), Kit.Ink)
	-- lit from above: pale at the top, a deeper blue at the bottom
	Kit.gradient(bubble, Color3.fromRGB(176, 240, 255), Color3.fromRGB(72, 188, 250))
	local shine = Kit.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.16),
		Size = UDim2.fromScale(0.3, 0.22),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, bubble)
	Kit.corner(shine, 999)
	return bubble
end

-- The sign for money: a coin
function Kit.coin(parent: Instance, size: number): Frame
	local coin: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.White,
	}, parent)
	Kit.corner(coin, 999)
	Kit.stroke(coin, math.max(1.5, size * 0.11), Kit.Ink)
	-- lit from above: pale gold at the top, orange at the bottom, and a small shine as the bubble has
	Kit.gradient(coin, Color3.fromRGB(255, 232, 110), Color3.fromRGB(255, 172, 28))
	local shine = Kit.new("Frame", {
		Position = UDim2.fromScale(0.18, 0.12),
		Size = UDim2.fromScale(0.26, 0.16),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, coin)
	Kit.corner(shine, 999)
	local rim = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, coin)
	Kit.corner(rim, 999)
	Kit.stroke(rim, math.max(1, size * 0.09), Color3.fromRGB(240, 168, 24))
	return coin
end

----------------------------------------------------------------------------------------------------------------------
-- Rings: the sweeping arc, the emptying ring, the thin extra ring and seconds as text

export type Sweep = {
	Frame: Frame,
	set: (fraction: number) -> (),
	colour: (colour: Color3) -> (),
	fade: (transparency: number) -> (),
}

export type Ring = {
	Frame: Frame,
	Hole: Frame,
	set: (fraction: number) -> (),
	colour: (colour: Color3) -> (),
	Glow: UIStroke, -- a line round the whole ring, clear until a warning lights it (Kit.pulse)
	spent: (spent: boolean) -> (), -- the emptied part in red (an empty ring has no arc left to carry the colour)
	held: (fraction: number) -> (), -- a meter only: up to here, the piece just lost, white behind what is left
	broken: (fraction: number, transparency: number) -> (), -- up to here, the piece before it, fading out behind both
}

local TRACK = Kit.Deep
local HALF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
-- The left half laps over the right by this much. A ring more than half full had a thin dark line down from its hole
-- at 6 o'clock (seen on the tame ring, 2026-11-12, twice): the right half's own cut there is soft, a pixel of it half
-- see-through, and the left half stopped short of it. The left half now draws over that pixel in the same colour. The
-- right half does not lap the other way: that would start the arc a little before 12 o'clock.
local LAP = 2

-- A flat arc that runs clockwise from the top, as much of the circle as it is set to. It is two half rings, each an
-- outlined circle inside a frame that clips it to its half; the outline's gradient is see-through past its middle, and
-- turning that gradient sweeps the half open. Only the gradients' turn changes, in half-degree steps. A full circle is
-- one outline with no halves, so it has no seam.
function Kit.sweep(parent: Instance, diameter: number, thick: number, colour: Color3): Sweep
	local inner = diameter - thick * 2
	local half = diameter / 2
	local box: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	local function band(into: Instance, x: number): (UIStroke, Frame)
		local circle: Frame = Kit.new("Frame", {
			Position = UDim2.fromOffset(x, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
		}, into)
		Kit.corner(circle, 999)
		return Kit.stroke(circle, thick, colour), circle
	end
	local right: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(half, 0),
		Size = UDim2.fromOffset(half, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, box)
	local left: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(half + LAP, diameter),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, box)
	local rightStroke = band(right, thick - half)
	local leftStroke = band(left, thick)
	local wholeStroke, whole = band(box, thick)
	whole.Visible = false
	local rightTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 0 }, rightStroke)
	local leftTurn: UIGradient = Kit.new("UIGradient", { Transparency = HALF, Rotation = 180 }, leftStroke)

	local shown = -1
	local function set(fraction: number)
		local steps = math.floor(math.clamp(fraction, 0, 1) * 720 + 0.5)
		if steps == shown then
			return
		end
		shown = steps
		local degrees = steps / 2
		local full = steps >= 720
		whole.Visible = full
		right.Visible = degrees > 0 and not full
		left.Visible = degrees > 180 and not full
		if not full then
			rightTurn.Rotation = math.min(degrees, 180)
			leftTurn.Rotation = 180 + math.max(degrees - 180, 0)
		end
	end
	local function setColour(value: Color3)
		rightStroke.Color = value
		leftStroke.Color = value
		wholeStroke.Color = value
	end
	local function fade(transparency: number)
		rightStroke.Transparency = transparency
		leftStroke.Transparency = transparency
		wholeStroke.Transparency = transparency
	end
	set(1)
	return { Frame = box, set = set, colour = setColour, fade = fade }
end

-- A ring that empties, as the reference's: the part left runs clockwise from the top, and the used part is dark and
-- see-through. meter: the reference's meter beside the rider, which also has a thin dark edge, a clear hole, and the
-- part just lost in red behind what is left (lag). outline: the look's bold dark line round its outer edge and its
-- hole, with a pale line on the band (0 or nil for none; a meter then keeps its thin edge). plain: that dark line
-- without the pale one (Hugo, 2026-11-13: the rings beside the rider, with a hairline for the outline).
function Kit.ring(
	parent: Instance,
	diameter: number,
	thick: number,
	meter: boolean?,
	outline: number?,
	plain: boolean?
): Ring
	local inner = diameter - thick * 2
	local bold = outline or 0
	-- the rings beside the rider wear the chosen look (Kit.RingStyle); others (the aim) as before
	local style: RingStyle? = if plain then Kit.RingLook.Style else nil
	local border = if plain then Kit.RingLook.Border else Kit.Ink
	local trackFade = if style then style.TrackFade else 0.5
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	if style and style.Shadow and bold > 0 then
		-- a dark copy of the band and its line, a little below (behind everything)
		local shadow = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick, thick + style.Shadow),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, holder)
		Kit.corner(shadow, 999)
		Kit.stroke(shadow, thick + bold, Kit.RingLook.Border, 0.55)
	end
	-- the warning's glow, then the dark line round the outside (both drawn outward from the ring's own edge)
	local rim = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, holder)
	Kit.corner(rim, 999)
	local glow = Kit.stroke(rim, bold + 3, Kit.Coral, 1)
	if bold > 0 then
		local dark = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, holder)
		Kit.corner(dark, 999)
		Kit.stroke(dark, bold, border)
	end
	local trackCircle = Kit.new("Frame", {
		Position = UDim2.fromOffset(thick, thick),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundTransparency = 1,
	}, holder)
	Kit.corner(trackCircle, 999)
	local track = Kit.stroke(trackCircle, thick, TRACK, trackFade)
	-- a meter: the piece breaking off (fading), over it the piece just lost (white), both behind the part left
	local breaking: Sweep? = nil
	local holding: Sweep? = nil
	if meter then
		local made = Kit.sweep(holder, diameter, thick, Kit.RingLook.Held)
		made.set(0)
		breaking = made
		local white = Kit.sweep(holder, diameter, thick, Kit.RingLook.Held)
		white.set(0)
		holding = white
	end
	local front = Kit.sweep(holder, diameter, thick, Kit.Aqua)
	-- two-tone: the inner half of the part left a lighter shade, swept with it
	local lighterHalf: Sweep? = nil
	local twoTone = if style then style.TwoTone else nil
	if twoTone then
		local half = math.floor(thick / 2) -- (whole points: a UI offset is a whole number)
		local made = Kit.sweep(holder, diameter - half * 2, half, Kit.lighter(Kit.Aqua, twoTone))
		made.Frame.Position = UDim2.fromOffset(half, half)
		lighterHalf = made
	end
	-- a line from the band's outer edge to its inner, turned to `degrees` clockwise from the top
	local function across(degrees: number, width: number, colour: Color3, z: number): Frame
		local pivot: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(diameter, diameter),
			BackgroundTransparency = 1,
			Rotation = degrees,
			ZIndex = z,
		}, holder)
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(width, thick),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
		}, pivot)
		return pivot
	end
	if style and style.Segments and style.Segments > 1 then
		for i = 0, style.Segments - 1 do
			across(i * 360 / style.Segments, style.SegmentWidth or 1, border, 2)
		end
	end
	if style and style.Sheen then
		-- the upper half of the band paler, fading out toward the middle
		local sheenCircle = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(sheenCircle, 999)
		local sheen = Kit.stroke(sheenCircle, thick, Kit.White)
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, style.Sheen),
				NumberSequenceKeypoint.new(0.45, 0.92),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, sheen)
	end
	if style and style.Highlight then
		-- a thin light line just inside the outer edge, strongest at the top
		local inset = 1.6
		local light = Kit.new("Frame", {
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(light, 999)
		local line = Kit.stroke(light, 1, Kit.White)
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, style.Highlight),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, line)
	end
	local lead: Frame? = nil
	if style and style.Lead then
		lead = across(0, 1, Kit.White, 3)
	end
	local hole: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(thick, thick),
		Size = UDim2.fromOffset(inner, inner),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = if meter then 1 else 0.5,
	}, holder)
	Kit.corner(hole, 999)
	if bold > 0 then
		-- the dark line round the hole, drawn over the band's inner edge
		local lip = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick, thick),
			Size = UDim2.fromOffset(inner, inner),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(lip, 999)
		Kit.stroke(lip, bold, border)
	end
	if style and bold > 0 and (style.HoleShade or style.Rim) then
		-- round the hole, just outside its black line: a soft shade strongest at the top, or a light line
		local reach = bold + 0.5
		local around = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick - reach, thick - reach),
			Size = UDim2.fromOffset(inner + reach * 2, inner + reach * 2),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(around, 999)
		if style.HoleShade then
			local shade = Kit.stroke(around, 1.6, Kit.RingLook.Border)
			Kit.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, style.HoleShade),
					NumberSequenceKeypoint.new(0.6, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, shade)
		else
			Kit.stroke(around, 1, Kit.White, style.Rim)
		end
	end
	if lead then
		local line = lead:FindFirstChildOfClass("Frame")
		if line then
			Kit.stroke(line, 0.6, border)
		end
	end
	if bold > 0 and not plain then
		-- a pale line on the band's outside
		local pale = Kit.new("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, holder)
		Kit.corner(pale, 999)
		local paleLine = Kit.stroke(pale, 1.5, Kit.White)
		Kit.new("UIGradient", { Transparency = BEVEL, Rotation = 90 }, paleLine)
	elseif bold <= 0 and meter then
		-- the thin dark edge, outside and round the hole
		Kit.stroke(hole, 1.2, Kit.Ink, 0.45)
		local edge = Kit.new("Frame", {
			Size = UDim2.fromOffset(diameter, diameter),
			BackgroundTransparency = 1,
		}, holder)
		Kit.corner(edge, 999)
		Kit.stroke(edge, 1.2, Kit.Ink, 0.4)
	end

	local function spent(value: boolean)
		track.Color = if value then Kit.Coral else TRACK
		track.Transparency = if value then 0.15 else trackFade
	end
	local function set(fraction: number)
		front.set(fraction)
		if lighterHalf then
			lighterHalf.set(fraction)
		end
		if lead then
			local f = math.clamp(fraction, 0, 1)
			lead.Visible = f > 0.002 and f < 0.998
			lead.Rotation = f * 360
		end
	end
	local function setColour(value: Color3)
		front.colour(value)
		if lighterHalf and twoTone then
			lighterHalf.colour(Kit.lighter(value, twoTone))
		end
	end
	local function held(fraction: number)
		if holding then
			holding.set(fraction)
		end
	end
	local function broken(fraction: number, transparency: number)
		if breaking then
			breaking.set(fraction)
			breaking.fade(transparency)
		end
	end
	return {
		Frame = holder,
		Hole = hole,
		Glow = glow,
		set = set,
		colour = setColour,
		spent = spent,
		held = held,
		broken = broken,
	}
end

export type ThinRing = { Track: Sweep, Broken: Sweep, Held: Sweep, Front: Sweep }

-- The one ring round the big one past Config.Oxygen.BarSize (Rings), in the chosen look: its used part (all round),
-- the piece breaking off, the white piece just lost, the part left, and the look's black line outside and inside
function Kit.thinRing(parent: Instance, diameter: number, thick: number): ThinRing
	local style = Kit.RingLook.Style
	local track = Kit.sweep(parent, diameter, thick, Kit.Deep)
	track.fade(style.TrackFade)
	local broken = Kit.sweep(parent, diameter, thick, Kit.RingLook.Held)
	broken.set(0)
	local held = Kit.sweep(parent, diameter, thick, Kit.RingLook.Held)
	held.set(0)
	local front = Kit.sweep(parent, diameter, thick, Kit.Aqua)
	local edge = style.ExtraEdge or 0
	if edge > 0 then
		local outside = Kit.new("Frame", {
			Size = UDim2.fromOffset(diameter, diameter),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, parent)
		Kit.corner(outside, 999)
		Kit.stroke(outside, edge, Kit.RingLook.Border)
		-- and round its inner edge, drawn over the band (as the big ring's hole)
		local inside = Kit.new("Frame", {
			Position = UDim2.fromOffset(thick, thick),
			Size = UDim2.fromOffset(diameter - thick * 2, diameter - thick * 2),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, parent)
		Kit.corner(inside, 999)
		Kit.stroke(inside, edge, Kit.RingLook.Border)
	end
	return { Track = track, Broken = broken, Held = held, Front = front }
end

-- Seconds as the HUD writes them: two decimals under a second, one up to ten, whole seconds to a minute, then nothing
function Kit.seconds(value: number): string
	if value < 1 then
		return string.format("%.2f", math.max(value, 0))
	elseif value < 10 then
		return string.format("%.1f", value)
	elseif value < 60 then
		return string.format("%d", math.floor(value))
	end
	return ""
end

----------------------------------------------------------------------------------------------------------------------
-- Fail words: the slam band shown when a run fails

-- The words of a failed run (task b5; Hugo, 2026-11-22: "make text better and more stylised when failing a run. Out of
-- breath type text needs a rework"): look 1 of docs/attachments/fail-text-options-2026-11-22.png, the Slam band, the
-- family of GREAT DIVE and CAUGHT so a fail reads as the opposite of a win. Bangers in hard red metal on a tilted dark
-- streak with red edges, always red, a small second line under it. Its motion: the streak slashes open from a
-- hairline, the words slam on from the camera and ring (a squash, a white flash, a judder), the second line pops in;
-- it drops away as the black lifts. No pictures, nothing uploaded. Who shows it and what it says: FailController.
Kit.FailLook = {
	Font = Enum.Font.Bangers,
	Size = 76, -- the words, and the second line's
	Sub = 26,
	Tilt = -4, -- degrees
	Wide = 580, -- the streak: at least this wide, or the words and Pad
	Pad = 190,
	High = 92,
	Open = 0.16, -- seconds the streak takes to slash open
	SlamAt = 0.08, -- the words start in after this long,
	Slam = 0.2, -- take this long to land,
	From = 2.6, -- and come from this many times their size
	Ring = 0.1, -- the ring on landing: how far the words squash and bounce, of their size,
	RingRate = 5.5, -- how many times a second,
	RingFade = 9, -- and how fast it dies away
	Judder = 2.2, -- degrees the band judders on landing
	Flash = 0.2, -- seconds the white flash on the letters lasts
	SubAt = 0.5, -- the second line pops in after this long,
	SubPop = 0.22, -- over this long
	Drop = 90, -- on the way out it falls this far (of a 640-high screen) and turns this much more
	DropTurn = -5,
	FitWide = 0.94, -- never wider than this much of the screen,
	FitHigh = 640, -- full size on a screen this high,
	Most = 1.5, -- and never more than this many times it
}

export type FailWords = {
	Root: Frame,
	show: (text: string, sub: string) -> (), -- new words: the motion starts again from pose(0, 0)
	pose: (age: number, out: number) -> (), -- seconds since they came up; 0 to 1 of the way out
	hide: () -> (),
}

local FAIL_LINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0),
	NumberSequenceKeypoint.new(0.75, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local function outBack(u: number): number
	local c = 1.70158
	return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
end

function Kit.failWords(parent: Instance): FailWords
	local look = Kit.FailLook
	local dark = Color3.fromRGB(20, 2, 10)
	local root: Frame = Kit.new("Frame", {
		Name = "FailWords",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local tilt: Frame = Kit.new("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -8),
		Size = UDim2.fromOffset(look.Wide, 150),
		BackgroundTransparency = 1,
		Rotation = look.Tilt,
	}, root)
	local fit: UIScale = Kit.new("UIScale", {}, tilt)
	local streak: Frame = Kit.new("Frame", {
		Name = "Streak",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(look.Wide, look.High),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, tilt)
	local streakFill: UIGradient = Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(96, 8, 30), Color3.fromRGB(18, 4, 14)),
	}, streak)
	local edges: { Frame } = {}
	for _, y in { 0, 1 } do
		local edge: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Color3.fromRGB(255, 86, 86),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, streak)
		Kit.new("UIGradient", { Transparency = FAIL_LINE }, edge)
		table.insert(edges, edge)
	end
	-- the words: their shadow, the metal letters, and a white copy for the flash, slammed on as one
	local slam: Frame = Kit.new("Frame", {
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(look.Wide, 120),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, tilt)
	local slamScale: UIScale = Kit.new("UIScale", {}, slam)
	local function letters(props: { [string]: any }, into: Instance): TextLabel
		props.BackgroundTransparency = 1
		props.AnchorPoint = Vector2.new(0.5, 0.5)
		props.Size = UDim2.fromScale(1, 1)
		props.Font = look.Font
		props.Text = ""
		return Kit.new("TextLabel", props, into)
	end
	local shadow = letters({
		Position = UDim2.new(0.5, 0, 0.5, 7),
		TextSize = look.Size,
		TextColor3 = Color3.fromRGB(60, 4, 20),
		ZIndex = 3,
	}, slam)
	local shadowLine = Kit.stroke(shadow, 5, dark)
	local main = letters({
		Position = UDim2.fromScale(0.5, 0.5),
		TextSize = look.Size,
		TextColor3 = Kit.White,
		ZIndex = 4,
	}, slam)
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 120)),
			ColorSequenceKeypoint.new(0.54, Color3.fromRGB(250, 64, 70)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 14, 44)),
		}),
	}, main)
	local mainLine = Kit.stroke(main, 5, dark)
	local flash = letters({
		Position = UDim2.fromScale(0.5, 0.5),
		TextSize = look.Size,
		TextColor3 = Kit.White,
		TextTransparency = 1,
		ZIndex = 5,
	}, slam)
	local sub = letters({
		Position = UDim2.fromScale(0.5, 0.9),
		TextSize = look.Sub,
		TextColor3 = Color3.fromRGB(255, 226, 150),
		ZIndex = 6,
	}, tilt)
	sub.Size = UDim2.fromOffset(look.Wide, 40)
	local subLine = Kit.stroke(sub, 3, dark)
	local subScale: UIScale = Kit.new("UIScale", {}, sub)

	local wide = look.Wide
	local settled = false
	local lastOut = -1
	local function refit()
		local screen = root.AbsoluteSize
		if screen.X > 0 and screen.Y > 0 then
			fit.Scale = math.min(screen.X * look.FitWide / wide, screen.Y / look.FitHigh, look.Most)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	local function fade(out: number)
		if out == lastOut then
			return
		end
		lastOut = out
		local faint = 0.12 + 0.88 * out
		streakFill.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.22, faint),
			NumberSequenceKeypoint.new(0.78, faint),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, edge in edges do
			edge.BackgroundTransparency = out
		end
		shadow.TextTransparency = out
		shadowLine.Transparency = out
		mainLine.Transparency = out
		sub.TextTransparency = out
		subLine.Transparency = out
	end

	local function pose(age: number, out: number)
		out = math.clamp(out, 0, 1)
		local landed = age - look.SlamAt - look.Slam -- seconds since the words landed
		if settled and out == lastOut then
			return
		end
		-- the streak slashes open from a hairline
		local open = math.clamp(age / look.Open, 0, 1)
		streak.Size = UDim2.fromOffset(
			wide * (0.25 + 0.75 * (1 - (1 - open) ^ 3)),
			math.max(2, look.High * (0.03 + 0.97 * outBack(open)))
		)
		-- the words come from the camera, faster and faster, and land
		local u = math.clamp((age - look.SlamAt) / look.Slam, 0, 1)
		local ring, judder, bright = 0, 0, 1
		if landed > 0 then
			local dying = math.exp(-landed * look.RingFade)
			ring = -look.Ring * dying * math.sin(landed * math.pi * 2 * look.RingRate)
			judder = dying * math.sin(landed * 70) * look.Judder
			bright = 0.1 + 0.9 * math.clamp(landed / look.Flash, 0, 1)
		end
		slamScale.Scale = look.From + (1 - look.From) * u ^ 3 + ring
		slam.Visible = u > 0
		main.TextTransparency = math.max(1 - math.clamp(u / 0.35, 0, 1), out)
		flash.TextTransparency = math.max(bright, out)
		-- the second line pops in
		local v = math.clamp((age - look.SubAt) / look.SubPop, 0, 1)
		sub.Visible = v > 0 and sub.Text ~= ""
		subScale.Scale = math.max(0.01, outBack(v))
		-- and on the way out the whole band drops away, turning
		local eased = out * out
		tilt.Position = UDim2.new(0.5, 0, 0.5, -8 + look.Drop * fit.Scale * eased)
		tilt.Rotation = look.Tilt + judder + look.DropTurn * eased
		fade(out)
		settled = out == 0 and v >= 1 and landed > 6 / look.RingFade
	end

	local function show(text: string, subText: string)
		shadow.Text, main.Text, flash.Text = text, text, text
		sub.Text = subText
		-- (measured, not read off the label: its TextBounds are in the band's own scale)
		local bounds = TextService:GetTextSize(text, look.Size, look.Font, Vector2.new(4000, 400))
		wide = math.max(look.Wide, bounds.X + look.Pad)
		tilt.Size = UDim2.fromOffset(wide, 150)
		slam.Size = UDim2.fromOffset(wide, 120)
		refit()
		settled = false
		lastOut = -1
		root.Visible = true
		pose(0, 0)
	end

	return {
		Root = root,
		show = show,
		pose = pose,
		hide = function()
			root.Visible = false
		end,
	}
end

-- Who shows the words of a failed run (FailController sets it; Banners.miss hands them over when it is set)
Kit.FailShow = nil :: ((text: string, fade: number) -> ())?

----------------------------------------------------------------------------------------------------------------------
-- Numbers and touch: big numbers in short, and whether this is a phone

local UNITS = { "K", "M", "B", "T" }

-- A big number in short: 950, 1.9K, 12.5K, 2.3M
function Kit.short(value: number): string
	if value < 1000 then
		return tostring(math.floor(value + 0.5))
	end
	local unit = 0
	while value >= 1000 and unit < #UNITS do
		value /= 1000
		unit += 1
	end
	local text = if value >= 100 then string.format("%d", math.floor(value)) else string.format("%.1f", value)
	text = (string.gsub(text, "%.0$", ""))
	return text .. UNITS[unit]
end

-- Whether the player is on a touch screen with no keyboard: the phone layout
-- In Studio the workspace's "HudTouch" (true or false) forces the answer, to see the phone layout without a phone.
function Kit.touch(): boolean
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("HudTouch")
		if type(forced) == "boolean" then
			return forced
		end
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return true
	elseif
		last == Enum.UserInputType.Keyboard
		or string.match(last.Name, "^Mouse")
		or string.match(last.Name, "^Gamepad")
	then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Kit
