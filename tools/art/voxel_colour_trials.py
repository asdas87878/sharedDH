"""Colour treatments tried on the four trial sharks (docs/style/08-colour-treatments.md). Each treatment is a list of the
kit's PAINT rules, laid over the built model with --look, so no model file is touched. Renders go to
work/voxel/paint/<Creature>_<treatment>/; two sheets go to docs/attachments.
usage: python tools/art/voxel_colour_trials.py [render] [sheets]     (no word: both)"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageDraw

from voxel_paths import BLENDER as B, ROOT as R, WORK as S, font

OUT = S + "paint/"
BG = (254, 248, 241)

# each shark: its top colours, its belly colour, an accent that stands against the top, a second colour for a split body,
# how far the hue turns from nose to tail (degrees), and a tint for the belly
SHARKS = {
    "TrialReefShark": {"label": "Reef Shark", "top": ["gold"], "belly": "cream", "accent": "#19B5A5", "second": "#E8663C", "turn": -16, "flush": "#FFD9A0"},
    "TrialGreatWhite": {"label": "Great White", "top": ["blue"], "belly": "white", "accent": "#FF6B4A", "second": "#1FA6A0", "turn": -26, "flush": "#CFE8FF"},
    "TrialHammerhead": {"label": "Hammerhead", "top": ["back", "band"], "belly": "belly", "accent": "#FFD45A", "second": "#A8323A", "turn": -14, "flush": "#FFE2B8"},
    "TrialMegalodon": {"label": "Megalodon", "top": ["moss", "fin"], "belly": "bone", "accent": "#C8E84A", "second": "#1E6E78", "turn": 42, "flush": "#F2D9A8"},
}


# ---- the building blocks: each gives PAINT rules
def cap(k):
    """the strip on top: two stepped layers along the spine, each darker than the last (as Ride a Dino's dinos have)"""
    return [{"on": {"colours": k["top"], "depth": [0, 1.9], "width": [0, 0.8], "along": [0.1, 0.84]}, "to": {"val": 0.8}},
            {"on": {"colours": k["top"], "depth": [0, 0.9], "width": [0, 0.45], "along": [0.14, 0.78]}, "to": {"val": 0.78, "sat": 1.08}}]


def low_band(k):
    """a paler line where the top colour meets the belly: a third tone between the two"""
    return [{"on": {"colours": k["top"], "exposed": "side", "touching": {"colours": [k["belly"]], "where": "below"}}, "to": {"val": 1.2, "sat": 0.75}}]


def fade(k):
    """the colour turns and deepens in flat steps from the nose to the tail"""
    return [{"on": {"colours": k["top"]}, "to": {"hue": [0, k["turn"]], "val": [1.04, 0.84], "steps": 5, "over": "along"}}]


def layers(k):
    """the top colour in flat bands by height: darkest on the back, lightest low on the flank"""
    return [{"on": {"colours": k["top"], "height": [0.25, 1.0]}, "to": {"val": [1.14, 0.72], "sat": [0.82, 1.1], "steps": 4, "over": "height"}}]


def tips(k, glow=None):
    """the ends of the fins and the tail in the accent"""
    to = {"hex": k["accent"]}
    if glow:
        to["glow"] = glow
    # only the thin ends: the top of what stands on the centre line (a back fin, the tail's upper lobe) and the very end
    # of the tail. Not the side fins: by position alone their ends can't be told from the widest part of the body, and
    # the rule painted the Megalodon's shoulder and the Reef Shark's flank. A side fin's tip is set by hand in the model
    return [{"on": {"colours": k["top"], "height": [0.84, 1.0], "span": [0, 0.2], "size": [0, 6]}, "to": to},
            {"on": {"colours": k["top"], "along": [0.94, 1.0]}, "to": to}]


def stripe(k, glow=None):
    """one thin straight line of the accent along the flank, at the row where top meets belly (the user: thin continuous
    stripes along the whole animal are welcome). Straight, so it doesn't trace every tooth of a ragged meeting line"""
    to = {"hex": k["accent"]}
    if glow:
        to["glow"] = glow
    return [{"on": {"colours": k["top"] + [k["belly"]], "exposed": "side", "along": [0.2, 0.93],
                    "waterline": {"top": k["top"], "belly": [k["belly"]], "rows": [0, 0]}}, "to": to}]


def flush(k):
    """the belly takes a tint instead of plain cream or white"""
    return [{"on": {"colours": [k["belly"]]}, "to": {"mix": [k["flush"], 0.5]}}]


def split(k):
    """two colours to one body: the back half runs into a second colour"""
    return [{"on": {"colours": k["top"], "along": [0.45, 1.0]}, "to": {"mix": [k["second"], [0.15, 0.9]], "steps": 4, "over": "along"}}]


TREATMENTS = [  # (key, title, what it is, the rules)
    ("base", "As built", "top colour, belly, one mark", lambda k: []),
    ("cap", "Top strip", "two darker steps along the spine", cap),
    ("three", "Three tones", "top strip and a pale line above the belly", lambda k: cap(k) + low_band(k)),
    ("layers", "Layered", "flat bands by height, dark back to light flank", layers),
    ("fade", "Nose to tail", "the hue turns and deepens in steps", lambda k: fade(k) + cap(k)),
    ("trim", "Accent trim", "fin ends and a thin line in an accent", lambda k: cap(k) + tips(k) + stripe(k)),
    ("flush", "Tinted belly", "top strip, and the belly takes a tint", lambda k: cap(k) + flush(k)),
    ("split", "Two colours", "the back half runs into a second colour", lambda k: split(k) + cap(k)),
]
LADDER = [  # colour added rung by rung with rarity
    ("r1", "Common", "two colours", lambda k: []),
    ("r2", "Uncommon", "+ the top strip", cap),
    ("r3", "Rare", "+ a pale line above the belly", lambda k: cap(k) + low_band(k)),
    ("r4", "Epic", "+ fin ends in an accent", lambda k: cap(k) + low_band(k) + tips(k)),
    ("r5", "Legendary", "+ a nose-to-tail turn, a glowing accent line", lambda k: fade(k) + cap(k) + tips(k) + stripe(k, glow=0.6)),
    ("r6", "Mythic", "+ a second body colour, layered, a tinted belly, glow", lambda k: layers(k) + split(k) + cap(k) + tips(k, glow=0.8) + stripe(k, glow=1.0) + flush(k)),
]


def render(job):
    creature, key, rules = job
    tag = f"{creature}_{key}"
    path = f"{OUT}{tag}.json"
    json.dump({"PAINT": rules}, open(path, "w"))
    r = subprocess.run([B, "--background", "--python", R + "tools/blender/voxel_kit.py", "--", R + f"art/creatures/{creature}/voxel.py",
                        OUT + tag, "--look", path, "--hero"], capture_output=True, text=True)
    bad = [ln for ln in (r.stdout + r.stderr).splitlines() if "Error" in ln or "Traceback" in ln or ln.startswith("  !")]
    return tag, ("ok" if os.path.exists(OUT + tag + "/hero.png") and not bad else "FAILED " + "; ".join(bad[-2:]))


def sheet(name, title, columns, rows, width=430, height=300):
    pad, top, head = 12, 64, 54
    out = Image.new("RGB", (pad + (width + pad) * len(columns), top + head + (height + pad) * len(rows)), (255, 255, 255))
    d = ImageDraw.Draw(out)
    d.text((pad, 14), title, fill=(20, 20, 20), font=font("arialbd.ttf", 30))
    for c, (key, label, what, _) in enumerate(columns):
        x = pad + c * (width + pad)
        d.text((x + 4, top), label, fill=(20, 20, 20), font=font("arialbd.ttf", 21))
        d.text((x + 4, top + 27), what, fill=(90, 90, 90), font=font("arial.ttf", 15))
    for r, creature in enumerate(rows):
        for c, (key, _, _, _) in enumerate(columns):
            cell = Image.new("RGB", (width, height), BG)
            path = f"{OUT}{creature}_{key}/hero.png"
            if os.path.exists(path):
                im = Image.open(path).convert("RGBA")
                box = im.getbbox()
                if box:
                    im = im.crop(box)
                im.thumbnail((width - 24, height - 24), Image.LANCZOS)
                cell.paste(im, ((width - im.width) // 2, (height - im.height) // 2), im)
            out.paste(cell, (pad + c * (width + pad), top + head + r * (height + pad)))
    out.save(R + "docs/attachments/" + name, quality=88)
    print(name, out.size)


if __name__ == "__main__":
    words = sys.argv[1:] or ["render", "sheets"]
    os.makedirs(OUT, exist_ok=True)
    if "render" in words:
        jobs = [(creature, key, rules(k)) for creature, k in SHARKS.items() for key, _, _, rules in TREATMENTS + LADDER]
        with ThreadPoolExecutor(4) as pool:
            for tag, result in pool.map(render, jobs):
                if result != "ok":
                    print(tag, result, flush=True)
        print(len(jobs), "looks rendered")
    if "sheets" in words:
        sheet("voxel-colour-treatments.jpg", "Colour treatments on the four trial sharks", TREATMENTS, list(SHARKS))
        sheet("voxel-colour-rarity-ladder.jpg", "Colour added rung by rung with rarity (the same four models)", LADDER, list(SHARKS))
