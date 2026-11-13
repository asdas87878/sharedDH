"""The water's look in each land (docs/design/water.md, "Under the water"): one list, read by the sheet
(tools/map/zone_looks.py) and baked into the game's water script (tools/map/water_luau.py).

The rule (the user, 2026-11-12): vibrant and bright, never murky; and the player must feel the change from land to land.
So a land is told apart by its HUE, not by how dark it is. Each water colour is full and clean. The lands step down in
brightness only gently until the Twilight, and even the last ones are a deep colour, never black or grey.

water: the colour the distance fades into. see: how far you see before it (studs). tint: what it washes the near view
with (kept light, so things stay their own colour). vivid: extra colour strength (0 to 0.4). shafts: light shafts from the
surface, 0 to 1. specks: the colour of the things drifting in the water. light: what lights it, in words (for later).
glow: the colour of that land's own lamps, when they are built."""
ZONES = [
    {"name": "Shallows", "water": (72, 224, 232), "see": 900, "tint": (226, 255, 250), "vivid": 0.10, "shafts": 1.0, "specks": (255, 255, 255),
     "light": "full daylight; shafts of light; light rippling on the floor", "glow": None},
    {"name": "Coral Reef", "water": (40, 186, 250), "see": 820, "tint": (222, 244, 255), "vivid": 0.18, "shafts": 0.9, "specks": (255, 240, 250),
     "light": "bright sky blue; the corals are the colour", "glow": (255, 120, 170)},
    {"name": "Kelp Forest", "water": (40, 206, 128), "see": 620, "tint": (220, 255, 226), "vivid": 0.20, "shafts": 0.8, "specks": (230, 255, 170),
     "light": "emerald, with green shafts between the kelp", "glow": (255, 236, 110)},
    {"name": "Shipwrecks", "water": (24, 160, 176), "see": 560, "tint": (214, 246, 244), "vivid": 0.16, "shafts": 0.5, "specks": (255, 226, 170),
     "light": "deep teal; warm lanterns on the wrecks", "glow": (255, 190, 100)},
    {"name": "Open Blue", "water": (36, 104, 244), "see": 760, "tint": (214, 228, 255), "vivid": 0.22, "shafts": 0.3, "specks": (200, 230, 255),
     "light": "one royal blue all round; you see far", "glow": None},
    {"name": "Twilight", "water": (104, 72, 232), "see": 480, "tint": (228, 216, 255), "vivid": 0.26, "shafts": 0.0, "specks": (150, 255, 240),
     "light": "violet; the first glowing things", "glow": (100, 250, 230)},
    {"name": "Midnight", "water": (44, 50, 176), "see": 400, "tint": (206, 210, 255), "vivid": 0.30, "shafts": 0.0, "specks": (120, 240, 255),
     "light": "indigo; lit ledges, lures, the herd's own glow", "glow": (90, 230, 255)},
    {"name": "Vents", "water": (196, 72, 60), "see": 380, "tint": (255, 222, 206), "vivid": 0.30, "shafts": 0.0, "specks": (255, 190, 90),
     "light": "ember red; the vents throw orange up the walls", "glow": (255, 150, 60)},
    {"name": "Bone Graveyard", "water": (60, 176, 150), "see": 400, "tint": (214, 255, 238), "vivid": 0.20, "shafts": 0.0, "specks": (190, 255, 210),
     "light": "ghost jade; the bones glow pale green", "glow": (170, 255, 190)},
    {"name": "The Underworld", "water": (176, 30, 78), "see": 340, "tint": (255, 210, 222), "vivid": 0.34, "shafts": 0.0, "specks": (255, 110, 90),
     "light": "crimson; red cracks in the floor and the walls", "glow": (255, 70, 50)},
]
