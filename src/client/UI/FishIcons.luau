--!strict
-- The fish icons the user had drawn from our own renders (ChatGPT, 2026-11-25; art/ui/fish_icons/upload/fish_icons_c1..3).
-- Where each fish sits in the icon pages: Page, and X, Y, W, H in that page's pixels. Each has its dark outline drawn in
-- (Outlined: UI.Portrait puts none round it). Fish not here keep the live model picture (UI.Portrait): GreatWhite
-- (remodelled since its icon was drawn), WhaleShark, GinsuShark, Otodus, Ringbearer, Totality.
-- The pages before these (the plain renders, tools/ui/fish_icons/cut.py, which must not overwrite this file):
-- 93792111820130, 120444178713345, 82464769530334.
local FishIcons = {}

-- The uploaded pages. While one is "" the game uses the live model picture
FishIcons.Pages = {
	"rbxassetid://138492185931923",
	"rbxassetid://100228983942661",
	"rbxassetid://125595167321974",
}
FishIcons.Studio = FishIcons.Pages -- (no local copies: they are uploaded)
FishIcons.Outlined = true

export type Icon = { Page: number, X: number, Y: number, W: number, H: number, Bust: boolean }
FishIcons.Icons = {
	AbyssalWatcher = { Page = 1, X = 4, Y = 30, W = 162, H = 109, Bust = false },
	Angelfish = { Page = 1, X = 174, Y = 16, W = 162, H = 137, Bust = false },
	Anglerfish = { Page = 1, X = 348, Y = 4, W = 154, H = 162, Bust = false },
	Anomalocaris = { Page = 1, X = 514, Y = 43, W = 162, H = 84, Bust = false },
	Archelon = { Page = 1, X = 684, Y = 30, W = 162, H = 109, Bust = false },
	AuroraJelly = { Page = 1, X = 877, Y = 4, W = 116, H = 162, Bust = false },
	Barracuda = { Page = 1, X = 4, Y = 204, W = 162, H = 101, Bust = false },
	Basilosaurus = { Page = 1, X = 174, Y = 207, W = 162, H = 96, Bust = false },
	BlueWhale = { Page = 1, X = 344, Y = 187, W = 162, H = 136, Bust = false },
	BobbitWorm = { Page = 1, X = 514, Y = 206, W = 162, H = 97, Bust = false },
	BoneLeviathan = { Page = 1, X = 684, Y = 193, W = 162, H = 123, Bust = false },
	BrimstoneEel = { Page = 1, X = 854, Y = 199, W = 162, H = 111, Bust = false },
	CinderRay = { Page = 1, X = 4, Y = 375, W = 162, H = 99, Bust = false },
	Clownfish = { Page = 1, X = 174, Y = 346, W = 162, H = 158, Bust = false },
	CoralDragon = { Page = 1, X = 344, Y = 351, W = 162, H = 147, Bust = false },
	CosmicHollow = { Page = 1, X = 514, Y = 353, W = 162, H = 144, Bust = false },
	Cuttlefish = { Page = 1, X = 684, Y = 394, W = 162, H = 62, Bust = false },
	Dakosaurus = { Page = 1, X = 854, Y = 366, W = 162, H = 117, Bust = false },
	Dolphin = { Page = 1, X = 4, Y = 541, W = 162, H = 108, Bust = false },
	Dunkleosteus = { Page = 1, X = 174, Y = 534, W = 162, H = 122, Bust = false },
	Elasmosaurus = { Page = 1, X = 344, Y = 546, W = 162, H = 97, Bust = false },
	ElectricRay = { Page = 1, X = 514, Y = 552, W = 162, H = 86, Bust = false },
	EmberSerpent = { Page = 1, X = 684, Y = 530, W = 162, H = 130, Bust = false },
	FrilledShark = { Page = 1, X = 854, Y = 540, W = 162, H = 109, Bust = false },
	GalleonWhale = { Page = 1, X = 4, Y = 700, W = 162, H = 130, Bust = false },
	Garibaldi = { Page = 1, X = 174, Y = 716, W = 162, H = 98, Bust = false },
	GiantIsopod = { Page = 1, X = 344, Y = 708, W = 162, H = 113, Bust = false },
	GiantSeaBass = { Page = 1, X = 514, Y = 705, W = 162, H = 120, Bust = false },
	GiantSquid = { Page = 1, X = 684, Y = 685, W = 162, H = 160, Bust = false },
	GoblinShark = { Page = 1, X = 854, Y = 710, W = 162, H = 109, Bust = false },
	GoliathGrouper = { Page = 1, X = 4, Y = 872, W = 162, H = 126, Bust = false },
	GraveRay = { Page = 1, X = 174, Y = 885, W = 162, H = 99, Bust = false },
	GraveTurtle = { Page = 1, X = 344, Y = 881, W = 162, H = 108, Bust = false },
	HalfboneMegalodon = { Page = 1, X = 514, Y = 882, W = 162, H = 106, Bust = false },
	HammerheadShark = { Page = 1, X = 684, Y = 892, W = 162, H = 86, Bust = false },
	Helicoprion = { Page = 1, X = 854, Y = 874, W = 162, H = 121, Bust = false },
	HellfinShark = { Page = 2, X = 4, Y = 29, W = 162, H = 111, Bust = false },
	Hellmaw = { Page = 2, X = 174, Y = 7, W = 162, H = 155, Bust = false },
	HumpheadWrasse = { Page = 2, X = 344, Y = 7, W = 162, H = 156, Bust = false },
	InfernalAngler = { Page = 2, X = 516, Y = 4, W = 158, H = 162, Bust = false },
	KelpWyrm = { Page = 2, X = 684, Y = 35, W = 162, H = 99, Bust = false },
	Kraken = { Page = 2, X = 871, Y = 4, W = 127, H = 162, Bust = false },
	Kronosaurus = { Page = 2, X = 4, Y = 209, W = 162, H = 92, Bust = false },
	LanternLeviathan = { Page = 2, X = 174, Y = 197, W = 162, H = 115, Bust = false },
	LeopardShark = { Page = 2, X = 344, Y = 201, W = 162, H = 107, Bust = false },
	Lionfish = { Page = 2, X = 514, Y = 183, W = 162, H = 143, Bust = false },
	Liopleurodon = { Page = 2, X = 684, Y = 208, W = 162, H = 94, Bust = false },
	Livyatan = { Page = 2, X = 854, Y = 194, W = 162, H = 121, Bust = false },
	MantaRay = { Page = 2, X = 4, Y = 375, W = 162, H = 99, Bust = false },
	Megalodon = { Page = 2, X = 174, Y = 369, W = 162, H = 111, Bust = false },
	MoltenMegalodon = { Page = 2, X = 344, Y = 372, W = 162, H = 106, Bust = false },
	MorayEel = { Page = 2, X = 514, Y = 372, W = 162, H = 106, Bust = false },
	Mosasaurus = { Page = 2, X = 684, Y = 376, W = 162, H = 97, Bust = false },
	Octopus = { Page = 2, X = 859, Y = 344, W = 152, H = 162, Bust = false },
	Orca = { Page = 2, X = 4, Y = 533, W = 162, H = 124, Bust = false },
	Parrotfish = { Page = 2, X = 174, Y = 541, W = 162, H = 107, Bust = false },
	PearlSerpent = { Page = 2, X = 344, Y = 525, W = 162, H = 140, Bust = false },
	PhantomWhale = { Page = 2, X = 514, Y = 538, W = 162, H = 114, Bust = false },
	Pufferfish = { Page = 2, X = 684, Y = 531, W = 162, H = 127, Bust = false },
	ReefShark = { Page = 2, X = 854, Y = 542, W = 162, H = 105, Bust = false },
	Sawfish = { Page = 2, X = 4, Y = 718, W = 162, H = 93, Bust = false },
	SeaLion = { Page = 2, X = 174, Y = 715, W = 162, H = 100, Bust = false },
	SeaScorpion = { Page = 2, X = 344, Y = 721, W = 162, H = 88, Bust = false },
	SeaTurtle = { Page = 2, X = 514, Y = 716, W = 162, H = 97, Bust = false },
	Seahorse = { Page = 2, X = 706, Y = 684, W = 118, H = 162, Bust = false },
	SergeantMajor = { Page = 2, X = 854, Y = 695, W = 162, H = 140, Bust = false },
	Shonisaurus = { Page = 2, X = 4, Y = 877, W = 162, H = 115, Bust = false },
	SkullAngler = { Page = 2, X = 174, Y = 860, W = 162, H = 149, Bust = false },
	StellersSeaCow = { Page = 2, X = 344, Y = 872, W = 162, H = 126, Bust = false },
	Stingray = { Page = 2, X = 514, Y = 887, W = 162, H = 95, Bust = false },
	StormSerpent = { Page = 2, X = 684, Y = 862, W = 162, H = 145, Bust = false },
	Swordfish = { Page = 2, X = 854, Y = 883, W = 162, H = 104, Bust = false },
	TheDevourer = { Page = 3, X = 4, Y = 15, W = 162, H = 140, Bust = false },
	Viperfish = { Page = 3, X = 181, Y = 4, W = 147, H = 162, Bust = false },
	VoidWhale = { Page = 3, X = 344, Y = 19, W = 162, H = 132, Bust = false },
	WraithEel = { Page = 3, X = 514, Y = 31, W = 162, H = 107, Bust = false },
	Xiphactinus = { Page = 3, X = 684, Y = 25, W = 162, H = 120, Bust = false },
	YellowTang = { Page = 3, X = 854, Y = 13, W = 162, H = 144, Bust = false },
} :: { [string]: Icon }

return FishIcons
