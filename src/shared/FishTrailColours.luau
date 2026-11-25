--!strict
-- Each creature's own trail colours, from its palette. Written by tools/trails/fish_colours.py: don't edit by hand.
-- Main: the colour its haze leans to; Glow: what glows on it, or its strongest accent.
-- stylua: ignore
return {
	AbyssalWatcher = { Main = Color3.fromRGB(116, 73, 153), Glow = Color3.fromRGB(209, 242, 76) }, -- hide, glow (glows)
	Angelfish = { Main = Color3.fromRGB(242, 182, 50), Glow = Color3.fromRGB(242, 182, 50) }, -- gold, gold
	Anglerfish = { Main = Color3.fromRGB(138, 107, 153), Glow = Color3.fromRGB(166, 245, 58) }, -- skin, lure (glows)
	Anomalocaris = { Main = Color3.fromRGB(138, 142, 224), Glow = Color3.fromRGB(103, 242, 216) }, -- fin, soft (glows)
	Archelon = { Main = Color3.fromRGB(33, 153, 134), Glow = Color3.fromRGB(248, 207, 110) }, -- shell, soft (glows)
	AuroraJelly = { Main = Color3.fromRGB(109, 95, 203), Glow = Color3.fromRGB(58, 242, 235) }, -- frill, teal (glows)
	Barracuda = { Main = Color3.fromRGB(98, 126, 153), Glow = Color3.fromRGB(109, 179, 242) }, -- back, back
	Basilosaurus = { Main = Color3.fromRGB(107, 125, 153), Glow = Color3.fromRGB(242, 196, 106) }, -- hide, soft (glows)
	BlueWhale = { Main = Color3.fromRGB(69, 118, 153), Glow = Color3.fromRGB(109, 242, 214) }, -- body, lume (glows)
	BobbitWorm = { Main = Color3.fromRGB(227, 186, 159), Glow = Color3.fromRGB(110, 245, 176) }, -- belly, lume (glows)
	BoneLeviathan = { Main = Color3.fromRGB(228, 209, 160), Glow = Color3.fromRGB(99, 242, 218) }, -- bone, glow (glows)
	BrimstoneEel = { Main = Color3.fromRGB(255, 138, 30), Glow = Color3.fromRGB(255, 138, 30) }, -- lava, lava (glows)
	CinderRay = { Main = Color3.fromRGB(150, 107, 153), Glow = Color3.fromRGB(255, 124, 22) }, -- back, ember (glows)
	Clownfish = { Main = Color3.fromRGB(255, 171, 115), Glow = Color3.fromRGB(255, 171, 115) }, -- orange, orange
	CoralDragon = { Main = Color3.fromRGB(0, 153, 137), Glow = Color3.fromRGB(255, 115, 143) }, -- cream, polyp (glows)
	Cuttlefish = { Main = Color3.fromRGB(193, 137, 104), Glow = Color3.fromRGB(242, 158, 109) }, -- brown, brown
	Dakosaurus = { Main = Color3.fromRGB(0, 153, 91), Glow = Color3.fromRGB(246, 207, 111) }, -- hide, soft (glows)
	Dolphin = { Main = Color3.fromRGB(128, 155, 183), Glow = Color3.fromRGB(109, 174, 242) }, -- grey, grey
	Dunkleosteus = { Main = Color3.fromRGB(69, 102, 153), Glow = Color3.fromRGB(255, 178, 62) }, -- bone, amber (glows)
	Elasmosaurus = { Main = Color3.fromRGB(0, 153, 134), Glow = Color3.fromRGB(246, 203, 111) }, -- sea, soft (glows)
	ElectricRay = { Main = Color3.fromRGB(87, 118, 153), Glow = Color3.fromRGB(255, 232, 56) }, -- back, spark (glows)
	EmberSerpent = { Main = Color3.fromRGB(139, 140, 153), Glow = Color3.fromRGB(255, 138, 30) }, -- plate, orange (glows)
	FrilledShark = { Main = Color3.fromRGB(182, 141, 127), Glow = Color3.fromRGB(242, 99, 93) }, -- hide, frill
	GalleonWhale = { Main = Color3.fromRGB(92, 153, 122), Glow = Color3.fromRGB(255, 196, 90) }, -- hide, lamp (glows)
	Garibaldi = { Main = Color3.fromRGB(255, 122, 28), Glow = Color3.fromRGB(255, 122, 28) }, -- orange, orange
	GiantIsopod = { Main = Color3.fromRGB(161, 142, 203), Glow = Color3.fromRGB(233, 246, 241) }, -- shell, shine (glows)
	GiantSeaBass = { Main = Color3.fromRGB(153, 130, 107), Glow = Color3.fromRGB(242, 195, 109) }, -- body, lip
	GiantSquid = { Main = Color3.fromRGB(196, 60, 46), Glow = Color3.fromRGB(242, 74, 57) }, -- red, red
	GinsuShark = { Main = Color3.fromRGB(153, 149, 89), Glow = Color3.fromRGB(242, 235, 109) }, -- olive, olive
	GoblinShark = { Main = Color3.fromRGB(233, 163, 170), Glow = Color3.fromRGB(242, 109, 122) }, -- pink, pink
	GoliathGrouper = { Main = Color3.fromRGB(56, 57, 153), Glow = Color3.fromRGB(88, 90, 242) }, -- olive, olive
	GraveRay = { Main = Color3.fromRGB(163, 165, 159), Glow = Color3.fromRGB(66, 242, 218) }, -- hide, teal (glows)
	GraveTurtle = { Main = Color3.fromRGB(255, 249, 231), Glow = Color3.fromRGB(93, 242, 221) }, -- bone, teal (glows)
	GreatWhite = { Main = Color3.fromRGB(63, 116, 173), Glow = Color3.fromRGB(88, 162, 242) }, -- blue, blue
	HalfboneMegalodon = { Main = Color3.fromRGB(103, 125, 153), Glow = Color3.fromRGB(66, 242, 221) }, -- back, teal (glows)
	HammerheadShark = { Main = Color3.fromRGB(178, 194, 136), Glow = Color3.fromRGB(207, 242, 109) }, -- back, back
	Helicoprion = { Main = Color3.fromRGB(34, 142, 153), Glow = Color3.fromRGB(255, 208, 115) }, -- teal, soft (glows)
	HellfinShark = { Main = Color3.fromRGB(125, 107, 153), Glow = Color3.fromRGB(255, 122, 30) }, -- char, ember (glows)
	Hellmaw = { Main = Color3.fromRGB(255, 123, 28), Glow = Color3.fromRGB(255, 123, 28) }, -- lava, lava (glows)
	HumpheadWrasse = { Main = Color3.fromRGB(47, 159, 166), Glow = Color3.fromRGB(69, 232, 242) }, -- body, body
	InfernalAngler = { Main = Color3.fromRGB(255, 106, 28), Glow = Color3.fromRGB(255, 106, 28) }, -- lava, lava (glows)
	KelpWyrm = { Main = Color3.fromRGB(131, 153, 0), Glow = Color3.fromRGB(255, 177, 59) }, -- olive, amber (glows)
	Kraken = { Main = Color3.fromRGB(153, 54, 90), Glow = Color3.fromRGB(180, 242, 90) }, -- wine, lume (glows)
	Kronosaurus = { Main = Color3.fromRGB(140, 153, 107), Glow = Color3.fromRGB(255, 211, 107) }, -- hide, halo (glows)
	LanternLeviathan = { Main = Color3.fromRGB(132, 96, 153), Glow = Color3.fromRGB(255, 194, 71) }, -- plum, gold (glows)
	LeopardShark = { Main = Color3.fromRGB(209, 204, 188), Glow = Color3.fromRGB(242, 236, 218) }, -- sand, sand
	Lionfish = { Main = Color3.fromRGB(199, 101, 76), Glow = Color3.fromRGB(242, 123, 93) }, -- rust, rust
	Liopleurodon = { Main = Color3.fromRGB(81, 105, 153), Glow = Color3.fromRGB(255, 179, 107) }, -- hide, halo (glows)
	Livyatan = { Main = Color3.fromRGB(107, 122, 153), Glow = Color3.fromRGB(242, 196, 106) }, -- hide, soft (glows)
	MantaRay = { Main = Color3.fromRGB(107, 125, 153), Glow = Color3.fromRGB(109, 183, 242) }, -- back, pale
	Megalodon = { Main = Color3.fromRGB(103, 125, 153), Glow = Color3.fromRGB(255, 176, 112) }, -- back, soft (glows)
	MoltenMegalodon = { Main = Color3.fromRGB(142, 138, 153), Glow = Color3.fromRGB(255, 154, 34) }, -- back, lava (glows)
	MorayEel = { Main = Color3.fromRGB(106, 154, 62), Glow = Color3.fromRGB(202, 242, 109) }, -- green, spot
	Mosasaurus = { Main = Color3.fromRGB(84, 133, 153), Glow = Color3.fromRGB(104, 242, 219) }, -- hide, lume (glows)
	Octopus = { Main = Color3.fromRGB(194, 58, 20), Glow = Color3.fromRGB(242, 72, 25) }, -- orange, orange
	Orca = { Main = Color3.fromRGB(81, 102, 153), Glow = Color3.fromRGB(109, 155, 242) }, -- back, saddle
	Otodus = { Main = Color3.fromRGB(107, 153, 70), Glow = Color3.fromRGB(255, 196, 92) }, -- moss, soft (glows)
	Parrotfish = { Main = Color3.fromRGB(31, 184, 172), Glow = Color3.fromRGB(247, 152, 58) }, -- teal, orange
	PearlSerpent = { Main = Color3.fromRGB(111, 108, 217), Glow = Color3.fromRGB(255, 230, 240) }, -- pearl, moon (glows)
	PhantomWhale = { Main = Color3.fromRGB(178, 229, 255), Glow = Color3.fromRGB(83, 242, 219) }, -- ice, teal (glows)
	Pufferfish = { Main = Color3.fromRGB(232, 182, 58), Glow = Color3.fromRGB(242, 190, 61) }, -- back, back
	ReefShark = { Main = Color3.fromRGB(140, 151, 158), Glow = Color3.fromRGB(215, 232, 242) }, -- grey, grey
	Ringbearer = { Main = Color3.fromRGB(200, 141, 76), Glow = Color3.fromRGB(110, 208, 244) }, -- ochre, ice2 (glows)
	Sawfish = { Main = Color3.fromRGB(218, 185, 137), Glow = Color3.fromRGB(242, 188, 109) }, -- sand, sand
	SeaLion = { Main = Color3.fromRGB(153, 103, 66), Glow = Color3.fromRGB(242, 180, 109) }, -- fur, chest
	SeaScorpion = { Main = Color3.fromRGB(198, 100, 46), Glow = Color3.fromRGB(242, 122, 56) }, -- rust, rust
	SeaTurtle = { Main = Color3.fromRGB(123, 153, 67), Glow = Color3.fromRGB(195, 242, 105) }, -- shell, shell
	Seahorse = { Main = Color3.fromRGB(240, 122, 62), Glow = Color3.fromRGB(242, 123, 63) }, -- coral, coral
	SergeantMajor = { Main = Color3.fromRGB(251, 236, 127), Glow = Color3.fromRGB(251, 234, 113) }, -- yellow, yellow
	Shonisaurus = { Main = Color3.fromRGB(85, 115, 153), Glow = Color3.fromRGB(109, 236, 242) }, -- hide, soft (glows)
	SkullAngler = { Main = Color3.fromRGB(107, 153, 129), Glow = Color3.fromRGB(92, 242, 218) }, -- flesh, lure (glows)
	StellersSeaCow = { Main = Color3.fromRGB(153, 131, 107), Glow = Color3.fromRGB(242, 195, 109) }, -- hide, belly
	Stingray = { Main = Color3.fromRGB(180, 142, 94), Glow = Color3.fromRGB(242, 183, 109) }, -- sand, sand
	StormSerpent = { Main = Color3.fromRGB(92, 112, 153), Glow = Color3.fromRGB(255, 234, 115) }, -- slate, bolt (glows)
	Swordfish = { Main = Color3.fromRGB(51, 84, 153), Glow = Color3.fromRGB(109, 165, 242) }, -- blue, line
	TheDevourer = { Main = Color3.fromRGB(139, 99, 153), Glow = Color3.fromRGB(255, 122, 26) }, -- char, lava (glows)
	Totality = { Main = Color3.fromRGB(65, 79, 153), Glow = Color3.fromRGB(242, 123, 52) }, -- back, haze (glows)
	Viperfish = { Main = Color3.fromRGB(76, 95, 153), Glow = Color3.fromRGB(110, 244, 220) }, -- ink, light (glows)
	VoidWhale = { Main = Color3.fromRGB(41, 59, 153), Glow = Color3.fromRGB(115, 186, 255) }, -- void, ice (glows)
	WhaleShark = { Main = Color3.fromRGB(23, 165, 126), Glow = Color3.fromRGB(34, 242, 185) }, -- green, green
	WraithEel = { Main = Color3.fromRGB(233, 228, 210), Glow = Color3.fromRGB(109, 243, 226) }, -- bone, glow (glows)
	Xiphactinus = { Main = Color3.fromRGB(45, 103, 153), Glow = Color3.fromRGB(246, 203, 110) }, -- steel, soft (glows)
	YellowTang = { Main = Color3.fromRGB(247, 212, 23), Glow = Color3.fromRGB(247, 212, 23) }, -- yellow, yellow
} :: { [string]: { Main: Color3, Glow: Color3 } }
