"""The water's look in each land (docs/design/water.md, "Under the water"): one list, read by the sheet
(tools/map/zone_looks.py), by the map (tools/map/greybox.py: what the cliffs fade into, the glowing ledges) and baked
into the game's water script (tools/map/water_luau.py).

The rules (the user, 2026-11-12 and 13):
- Vibrant and bright, never murky; the player must feel the change from land to land. So a land is told apart by its
  HUE, not by how dark it is.
- You must see far enough ahead to steer, in every land. So the water is a veil, not a wall: in most lands it never
  hides anything wholly. Only the darkest lands (Midnight, the Underworld) close the view, and far off.
- The deep lands must feel as much a place as the first ones: so they keep a lit ceiling of water overhead, shafts of
  light in their own colour, and ledges that glow.

water: the colour the distance fades toward. see: a distance (studs), and thick: how much of the view the water has
taken by that distance (1 = wholly hidden there; 0.5 = things there are half water colour, and still seen beyond).
tint: what it washes the near view with. vivid: extra colour strength. shafts: light shafts, 0 to 1. specks: the colour
of the things drifting in the water. ceiling: the lit water overhead, seen from below. glow: that land's own light, on
its ledges. light: what lights it, in words."""
# Seen in play, 2026-11-13: with the first numbers Midnight was one electric blue and the Vents a blinding pure red. The
# extra colour strength ("vivid") stacks on the game's own, so the deep lands take very little of it, and the hot lands'
# water is a warm colour, never pure red. A deep ceiling is a middle tone, so the white lines of its picture show on it.
ZONES = [
    {"name": "Shallows", "water": (151, 227, 231), "see": 1800, "thick": 0.45, "tint": (226, 255, 250), "vivid": 0.10, "shafts": 1.0,
     "specks": (255, 255, 255), "ceiling": (187, 236, 239), "glow": None, "light": "full daylight; shafts of light"},
    {"name": "Coral Reef", "water": (138, 207, 237), "see": 1800, "thick": 0.5, "tint": (222, 244, 255), "vivid": 0.18, "shafts": 0.9,
     "specks": (255, 240, 250), "ceiling": (178, 223, 243), "glow": None, "light": "bright sky blue; the corals are the colour"},
    {"name": "Kelp Forest", "water": (128, 214, 174), "see": 1800, "thick": 0.55, "tint": (220, 255, 226), "vivid": 0.20, "shafts": 0.85,
     "specks": (230, 255, 170), "ceiling": (172, 228, 202), "glow": None, "light": "emerald, with green shafts"},
    {"name": "Shipwrecks", "water": (109, 184, 193), "see": 1800, "thick": 0.6, "tint": (214, 246, 244), "vivid": 0.16, "shafts": 0.7,
     "specks": (255, 226, 170), "ceiling": (160, 208, 214), "glow": None, "light": "deep teal; warm lanterns on the wrecks"},
    {"name": "Open Blue", "water": (128, 161, 227), "see": 1800, "thick": 0.55, "tint": (214, 228, 255), "vivid": 0.14, "shafts": 0.65,
     "specks": (200, 230, 255), "ceiling": (172, 193, 236), "glow": None, "light": "one royal blue all round; you see far"},
    {"name": "Twilight", "water": (179, 171, 215), "see": 1800, "thick": 0.65, "tint": (228, 216, 255), "vivid": 0.12, "shafts": 0.55,
     "specks": (150, 255, 240), "ceiling": (205, 200, 229), "glow": (100, 250, 230), "light": "violet; violet shafts; the ledges begin to glow"},
    {"name": "Midnight", "water": (115, 120, 174), "see": 1300, "thick": 1.0, "tint": (226, 228, 255), "vivid": 0.06, "shafts": 0.4,
     "specks": (120, 240, 255), "ceiling": (164, 167, 202), "glow": (90, 230, 255), "light": "indigo, and the view closes far off; glowing ledges"},
    {"name": "Vents", "water": (156, 94, 78), "see": 1800, "thick": 0.55, "tint": (255, 236, 226), "vivid": -0.12, "shafts": 0.5,
     "specks": (255, 190, 90), "ceiling": (190, 150, 139), "glow": (255, 170, 70), "light": "ember red; orange shafts and ledges"},
    {"name": "Bone Graveyard", "water": (128, 191, 177), "see": 1800, "thick": 0.7, "tint": (214, 255, 238), "vivid": 0.1, "shafts": 0.5,
     "specks": (190, 255, 210), "ceiling": (172, 213, 204), "glow": (190, 255, 200), "light": "ghost jade; pale green ledges"},
    {"name": "The Underworld", "water": (112, 93, 195), "see": 1200, "thick": 1.0, "tint": (255, 228, 236), "vivid": -0.1, "shafts": 0.45,
     "specks": (150, 240, 255), "ceiling": (162, 149, 216), "glow": (100, 255, 253), "light": "cosmic indigo, the view closes far off; cyan ledges (2026-11-19)"},
]
# 2026-11-19: the water is the halfway fog and the floors the colour proposal's (docs/design/colour.md: each land copies its
# nearest Ride a Dino land's values; the user chose "Halfway" for the fog and cosmic indigo for the Underworld); the
# lit ceiling is the water a third of the way to white. Before that:
# the lands' floors (and wall tops): the deep ones are kept light enough to read (2026-11-13: the dark ones were first
# guesses, and with dark water over them the deep lands lost their shape)
# Midnight's floor is a light grey-blue, not the water's own blue (2026-11-13): floor, walls and water were one blue,
# and the land had no shape
GROUND = [(222, 213, 169), (239, 138, 154), (53, 157, 85), (136, 128, 92), (143, 191, 224), (203, 200, 232), (174, 184, 226), (42, 33, 40), (138, 138, 102), (154, 154, 230)]
# each land's wall faces (2026-11-19, the colour proposal: far from the floor in lightness, as the reference's are)
FACES = [(184, 145, 104), (166, 90, 108), (178, 203, 184), (171, 187, 148), (43, 127, 194), (85, 83, 143), (37, 48, 110), (149, 49, 34), (180, 194, 156), (34, 9, 121)]
