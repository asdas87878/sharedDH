"""Captures for task r1 (the partner's renders as the fish icons): the real end of a dive and the inventory slots in a
Studio playtest, each set twice: the old pictures (the models, workspace FishIcons = "Model") and the new (the renders).
Uses the x3 driver (tools/ui/catch_show/x3_client.luau).
    python tools/ui/fish_icons/r1_capture.py install | remove      # the x3 driver, in Edit
    python tools/ui/fish_icons/r1_capture.py shots                  # in a playtest: work/catch_show/r1_*.png
    python tools/ui/fish_icons/r1_capture.py sheet                  # docs/attachments/fish-icons-old-new.png + the still
"""
import shutil
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "catch_show"))
import capture as C  # noqa: E402
import x3_capture as X  # noqa: E402

OUT, ATT = C.OUT, C.ATT
TILES, SLOTS = (550, 597, 1430, 720), (620, 945, 1365, 1047)
SETS = dict(X.SETS)
SETS["C"] = [("Stingray", "Common"), ("Octopus", "Uncommon"), ("Sawfish", "Rare"), ("Orca", "Epic"),
             ("AuroraJelly", "Legendary"), ("Anglerfish", "Mythic"), ("TheDevourer", "Secret")]
X.SETS = SETS


def mode(model):
    C.server(f"workspace:SetAttribute('FishIcons', {'\"Model\"' if model else 'nil'}) return 'ok'")


def shots():
    for s in SETS:
        for tag, model in (("old", True), ("new", False)):
            mode(model)
            X.start(s, slots=False)  # (empties the slots, so they show again in the new mode)
            time.sleep(0.5)
            X.start(s, slots=True)
            X.still(s)
            shutil.copy(OUT / f"x3_{s}.png", OUT / f"r1_{tag}_{s}.png")
            print(tag, s)
    mode(False)


def sheet():
    blocks = []
    for s in SETS:
        names = ", ".join(i for i, _ in SETS[s])
        for tag, title in (("old", "before: the model drawn live"), ("new", "now: the partner's render")):
            im = Image.open(OUT / f"r1_{tag}_{s}.png").convert("RGB")
            tiles, slots = im.crop(TILES), im.crop(SLOTS)
            big = tiles.resize((tiles.width * 2, tiles.height * 2), Image.LANCZOS)
            row = Image.new("RGB", (big.width + 24 + slots.width, max(big.height, slots.height)), (22, 26, 36))
            row.paste(big, (0, 0))
            row.paste(slots, (big.width + 24, (row.height - slots.height) // 2))
            blocks.append((f"Set {s}, {title}  ({names}; Common to Secret)", row))
    pad = 24
    width = max(b.width for _, b in blocks) + 2 * pad
    out = Image.new("RGB", (width, 120 + sum(b.height + 54 for _, b in blocks)), (22, 26, 36))
    d = ImageDraw.Draw(out)
    d.text((pad, 20), "Fish icons (task r1): the partner's renders in place of the live model pictures",
           font=C.font(34), fill="white")
    d.text((pad, 66), "Left: the catch screen's tiles at 2x. Right: the inventory slots, real size. Studio playtest, "
           "the live end screen.", font=C.font(18), fill=(190, 200, 220))
    y = 110
    for title, b in blocks:
        d.text((pad, y), title, font=C.font(20), fill=(255, 210, 63) if "now" in title else (170, 180, 200))
        y += 30
        out.paste(b, (pad, y))
        y += b.height + 24
    out.save(ATT / "fish-icons-old-new.png")
    Image.open(OUT / "r1_new_A.png").convert("RGB").save(ATT / "fish-icons-catch-still.png")
    print("sheet", out.size)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(X.install())
    elif what == "remove":
        print(X.install(remove=True))
    elif what == "shots":
        shots()
    elif what == "sheet":
        sheet()
