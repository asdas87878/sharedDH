"""Colour blocking tried on the four trial sharks (docs/style/08-colour-treatments.md, second round). The user found the
first round too dark: these give parts of the body ANOTHER COLOUR to mark tops, edges, fins and features. Nothing here
darkens. Each is a list of the kit's PAINT rules laid over the built model, so no model file is touched.
usage: python tools/art/voxel_colour_blocks.py [render] [sheets]     (no word: both)"""
import os
import sys
from concurrent.futures import ThreadPoolExecutor

from voxel_colour_trials import OUT, render, sheet

# each shark: its top colours and belly; a LIGHT version of its top colour; a PARTNER (a neighbouring hue of about the
# same strength, for whole parts); a POP (a far hue, for thin things); and which way its hue turns as it climbs
SHARKS = {
    "TrialReefShark": {"top": ["gold"], "belly": "cream", "light": "#F6DC8A", "partner": "#E8744F", "pop": "#19B5A5", "climb": 18},
    "TrialGreatWhite": {"top": ["blue"], "belly": "white", "light": "#8FC3EE", "partner": "#2FB3A6", "pop": "#FFD45A", "climb": -30},
    "TrialHammerhead": {"top": ["back", "band"], "belly": "belly", "light": "#EDB877", "partner": "#C9506A", "pop": "#2FB3A6", "climb": 16},
    "TrialMegalodon": {"top": ["moss", "fin"], "fin": ["fin"], "belly": "bone", "light": "#8DB354", "partner": "#2E8C86", "pop": "#E8B93A", "climb": 26},
}


def light_tops(k):
    """every face that looks up takes the light colour: the tops of the plates read as lit"""
    return [{"on": {"colours": k["top"], "depth": [0, 0.9]}, "to": {"mix": [k["light"], 0.75]}}]


def light_edges(k):
    """only the rim of each plate takes the light colour: every step is drawn as a line"""
    return [{"on": {"colours": k["top"], "edge": "top"}, "to": {"mix": [k["light"], 0.9]}}]


def inlaid_tops(k):
    """the middle of each plate takes the partner colour and its rim stays the body's: tops set in like inlay"""
    return [{"on": {"colours": k["top"], "edge": "inner", "depth": [0, 0.9]}, "to": {"hex": k["partner"]}}]


def colour_tops(k):
    """the tops along the middle of the back take the partner colour, at the body's own strength"""
    return [{"on": {"colours": k["top"], "depth": [0, 0.9], "width": [0, 0.7]}, "to": {"hex": k["partner"]}}]


def fins(k, colour="partner"):
    """the fins take another colour. A model that names its fins' colour (the Megalodon's "fin") is simply recoloured;
    in the others a fin is found as a free piece behind the head, which is right for these four and not a rule to trust"""
    if "fin" in k:
        return [{"on": {"colours": k["fin"]}, "to": {"hex": k[colour]}}]
    return [{"on": {"colours": k["top"], "pieces": True, "along": [0.24, 1.0]}, "to": {"hex": k[colour]}}]


def mask(k):
    """the head and the end of the tail take the partner colour"""
    return [{"on": {"colours": k["top"], "along": [0, 0.22]}, "to": {"hex": k["partner"]}},
            {"on": {"colours": k["top"], "along": [0.9, 1.0]}, "to": {"hex": k["partner"]}}]


def saddles(k):
    """three bands across the back in the partner colour"""
    return [{"on": {"colours": k["top"], "along": [a, b], "depth": [0, 2.9], "height": [0.45, 1.0], "pieces": False}, "to": {"hex": k["partner"]}}
            for a, b in ((0.3, 0.36), (0.48, 0.54), (0.66, 0.71))]


def terraces(k):
    """the hue turns step by step as the body climbs, and gets lighter, never darker"""
    return [{"on": {"colours": k["top"], "height": [0.3, 1.0]},
             "to": {"hue": [0, k["climb"]], "val": [1.0, 1.14], "sat": [1.0, 0.9], "steps": 4, "over": "height"}}]


def band(k, rows=(0, 1)):
    """a band of the pop colour between the top and the belly, straight along the flank"""
    return [{"on": {"colours": k["top"] + [k["belly"]], "exposed": "side", "along": [0.15, 0.95],
                    "waterline": {"top": k["top"], "belly": [k["belly"]], "rows": list(rows)}}, "to": {"hex": k["pop"]}}]


def lips(k):
    """the rim of the mouth in the pop colour"""
    return [{"on": {"colours": k["top"] + [k["belly"]], "touching": {"colours": ["mouth", "gum"], "where": "any"}}, "to": {"hex": k["pop"]}}]


TOPS = [
    ("base", "As built", "top colour, belly, one mark", lambda k: []),
    ("b_lighttops", "Light tops", "every face that looks up is lighter", light_tops),
    ("b_edges", "Light edges", "only the rim of each plate is lighter", light_edges),
    ("b_inlay", "Inlaid tops", "plate middles in a partner colour, rims left", inlaid_tops),
    ("b_tops", "Colour tops", "the back's tops in a partner colour", colour_tops),
]
PARTS = [
    ("b_fins", "Fins", "the fins in a partner colour", fins),
    ("b_mask", "Head and tail", "the head and tail end in a partner colour", mask),
    ("b_saddles", "Saddles", "three bands across the back", saddles),
    ("b_terraces", "Hue terraces", "the hue turns and lightens as it climbs", terraces),
    ("b_band", "Band and lips", "a pop-colour band on the flank and round the mouth", lambda k: band(k) + lips(k)),
]
MIXES = [
    ("m_a", "Mix A", "light edges, fins in the partner, a thin pop line", lambda k: light_edges(k) + fins(k) + band(k, (0, 0))),
    ("m_b", "Mix B", "inlaid tops, head and tail, pop lips", lambda k: inlaid_tops(k) + mask(k) + lips(k)),
    ("m_c", "Mix C", "hue terraces, light edges, fins in the pop", lambda k: terraces(k) + light_edges(k) + fins(k, "pop")),
    ("m_d", "Mix D", "light tops, saddles, a pop band", lambda k: light_tops(k) + saddles(k) + band(k)),
]

if __name__ == "__main__":
    words = sys.argv[1:] or ["render", "sheets"]
    os.makedirs(OUT, exist_ok=True)
    if "render" in words:
        jobs = [(creature, key, rules(k)) for creature, k in SHARKS.items() for key, _, _, rules in TOPS[1:] + PARTS + MIXES]
        with ThreadPoolExecutor(4) as pool:
            for tag, result in pool.map(render, jobs):
                if result != "ok":
                    print(tag, result, flush=True)
        print(len(jobs), "looks rendered")
    if "sheets" in words:
        rows = list(SHARKS)
        sheet("voxel-colour-blocks-tops.jpg", "Colour blocking 1: tops and edges (nothing is darkened)", TOPS, rows, 520, 360)
        sheet("voxel-colour-blocks-parts.jpg", "Colour blocking 2: parts of the body in another colour", PARTS, rows, 520, 360)
        sheet("voxel-colour-blocks-mixes.jpg", "Colour blocking 3: mixes", MIXES, rows, 560, 390)
