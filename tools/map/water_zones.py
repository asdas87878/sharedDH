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
ZONES = [
    {"name": "Shallows", "water": (72, 224, 232), "see": 1800, "thick": 0.45, "tint": (226, 255, 250), "vivid": 0.10, "shafts": 1.0,
     "specks": (255, 255, 255), "ceiling": (170, 240, 255), "glow": None, "light": "full daylight; shafts of light"},
    {"name": "Coral Reef", "water": (40, 186, 250), "see": 1800, "thick": 0.5, "tint": (222, 244, 255), "vivid": 0.18, "shafts": 0.9,
     "specks": (255, 240, 250), "ceiling": (150, 226, 255), "glow": None, "light": "bright sky blue; the corals are the colour"},
    {"name": "Kelp Forest", "water": (40, 206, 128), "see": 1800, "thick": 0.55, "tint": (220, 255, 226), "vivid": 0.20, "shafts": 0.85,
     "specks": (230, 255, 170), "ceiling": (160, 246, 190), "glow": None, "light": "emerald, with green shafts"},
    {"name": "Shipwrecks", "water": (24, 160, 176), "see": 1800, "thick": 0.6, "tint": (214, 246, 244), "vivid": 0.16, "shafts": 0.7,
     "specks": (255, 226, 170), "ceiling": (140, 228, 228), "glow": None, "light": "deep teal; warm lanterns on the wrecks"},
    {"name": "Open Blue", "water": (36, 104, 244), "see": 1800, "thick": 0.55, "tint": (214, 228, 255), "vivid": 0.22, "shafts": 0.65,
     "specks": (200, 230, 255), "ceiling": (130, 176, 255), "glow": None, "light": "one royal blue all round; you see far"},
    {"name": "Twilight", "water": (104, 72, 232), "see": 1800, "thick": 0.65, "tint": (228, 216, 255), "vivid": 0.26, "shafts": 0.55,
     "specks": (150, 255, 240), "ceiling": (184, 156, 255), "glow": (100, 250, 230), "light": "violet; violet shafts; the ledges begin to glow"},
    {"name": "Midnight", "water": (44, 50, 176), "see": 1300, "thick": 1.0, "tint": (206, 210, 255), "vivid": 0.30, "shafts": 0.4,
     "specks": (120, 240, 255), "ceiling": (112, 124, 244), "glow": (90, 230, 255), "light": "indigo, and the view closes far off; glowing ledges"},
    {"name": "Vents", "water": (196, 72, 60), "see": 1800, "thick": 0.7, "tint": (255, 222, 206), "vivid": 0.30, "shafts": 0.5,
     "specks": (255, 190, 90), "ceiling": (255, 156, 112), "glow": (255, 170, 70), "light": "ember red; orange shafts and ledges"},
    {"name": "Bone Graveyard", "water": (60, 176, 150), "see": 1800, "thick": 0.7, "tint": (214, 255, 238), "vivid": 0.20, "shafts": 0.5,
     "specks": (190, 255, 210), "ceiling": (164, 242, 212), "glow": (190, 255, 200), "light": "ghost jade; pale green ledges"},
    {"name": "The Underworld", "water": (176, 30, 78), "see": 1200, "thick": 1.0, "tint": (255, 210, 222), "vivid": 0.34, "shafts": 0.45,
     "specks": (255, 110, 90), "ceiling": (255, 112, 144), "glow": (255, 90, 70), "light": "crimson, and the view closes far off; red ledges"},
]
# the lands' floors (and wall tops): the deep ones are kept light enough to read (2026-11-13: the dark ones were first
# guesses, and with dark water over them the deep lands lost their shape)
GROUND = [(242, 214, 128), (244, 148, 152), (120, 172, 92), (160, 148, 124), (110, 150, 220),
          (150, 130, 230), (104, 112, 214), (214, 120, 92), (196, 212, 204), (206, 84, 112)]
