"""Captures for task x3: the catch screen's fish tiles (the inventory's pictures, behind the border) in the real game:
the real end of a dive (Banners.greatDive, the live look) in a Studio playtest on a stopped clock, with the inventory
slots filled with the same fish below it.
    python tools/ui/catch_show/x3_capture.py install | remove | listen | log
    python tools/ui/catch_show/x3_capture.py still <A|B> [t]   # work/catch_show/x3_<set>.png
    python tools/ui/catch_show/x3_capture.py phone <A|B>       # the live screen in a phone-sized frame
    python tools/ui/catch_show/x3_capture.py gif               # docs/attachments/catch-ui-final-2.gif (set A)
    python tools/ui/catch_show/x3_capture.py sheet             # docs/attachments/catch-ui-icons-2.png
Needs Studio with the studio-runner plugin, the repo's code in the place, and a playtest running (after `install`).
"""
import json
import shutil
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import capture as C  # noqa: E402
import c1_capture as K  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT, ATT, PICS = C.OUT, C.ATT, C.PICS
FPS = 12
T0 = 1000.0
LENGTH = 4.4
END = 4.6
# every rarity, and every kind of picture: round, tall, a long eel, flat, a serpent, tentacles, invented
SETS = {
    "A": [("Pufferfish", "Common"), ("Angelfish", "Uncommon"), ("MorayEel", "Rare"), ("MantaRay", "Epic"),
          ("Basilosaurus", "Legendary"), ("Kraken", "Mythic"), ("Hellmaw", "Secret")],
    "B": [("Clownfish", "Common"), ("Lionfish", "Uncommon"), ("Seahorse", "Rare"), ("ReefShark", "Epic"),
          ("Megalodon", "Legendary"), ("BrimstoneEel", "Mythic"), ("BlueWhale", "Secret")],
}
PHONE = (667, 375)  # an iPhone 8 held sideways, in points


def listing(name):
    return json.dumps([{"Id": i, "Tier": t} for i, t in SETS[name]])


def install(remove=False):
    src = (HERE / "x3_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZCatchX3")
if old then old:Destroy() end
if {C.lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZCatchX3"
s.Source = {C.lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return C.run([f.name])


def set_attrs(**kw):
    code = "local RS = game:GetService('ReplicatedStorage') "
    for k, v in kw.items():
        code += f"RS:SetAttribute('{k}', {'nil' if v is None else C.lua(v)}) "
    return C.server(code + "return 'ok'")


def start(name, slots=False):
    set_attrs(X3Phone=None, X3Clock=T0)
    set_attrs(X3Show=f"{'S' if slots else ''}{int(time.time() * 1000)}|{listing(name)}")
    time.sleep(2.0)  # (the fish pictures load)


def at(t, name, cropped=True):
    set_attrs(X3Clock=T0 + t)
    im = K.vshot(name)
    return K.crop(im) if cropped else im


def still(name, t=END):
    start(name)
    # (stepped there: a jump straight to the end can leave the screen's canvas undrawn in Studio)
    for k in (1.0, 2.5):
        at(k, f"x3_{name}_step")
    im = at(t, f"x3_{name}", cropped=False)
    print("still", name, im.size)
    return im


def phone(name):
    set_attrs(X3Clock=T0)
    set_attrs(X3Phone=f"{int(time.time() * 1000)}|{PHONE[0]}:{PHONE[1]}|{listing(name)}")
    time.sleep(2.5)
    for k in (1.0, 2.5, END):  # (it starts at the clock's time when played; stepped, as in still)
        set_attrs(X3Clock=T0 + k)
        time.sleep(1.2)
    im = K.vshot(f"x3_phone_{name}")
    set_attrs(X3Phone=None)
    return im


def gif():
    start("A")
    pics = [at(i / FPS, f"x3_gif_{i:03d}") for i in range(int(LENGTH * FPS) + 1)]
    K.save_gif(pics, ATT / "catch-ui-final-2.gif", fps=FPS, hold_last=12)
    print("gif", len(pics))


def sheet():
    """docs/attachments/catch-ui-icons-2.png from the shots: each set's tiles real size and at 3x, the inventory's
    slots with the same fish, and the phone's tiles real size and at 3x."""
    def cut(name, box):
        return Image.open(OUT / name).convert("RGB").crop(box)
    tiles, slots, phone_tiles = (550, 597, 1430, 720), (620, 945, 1365, 1047), (860, 552, 1125, 592)
    blocks = []
    for s in "AB":
        names = ", ".join(i for i, _ in SETS[s])
        im = cut(f"x3_{s}.png", tiles)
        blocks.append((f"Set {s} ({names}), Common to Secret: the catch screen, real size", im))
        blocks.append((f"Set {s}: at 3x (the fish under the border: the outline, the light rim and the dark lip)",
                       im.resize((im.width * 3, im.height * 3), Image.NEAREST)))
        blocks.append((f"Set {s}: the inventory slots with the same fish: the same pictures", cut(f"x3_slots_{s}.png", slots)))
        ph = cut(f"x3_phone_{s}.png", phone_tiles)
        big = ph.resize((ph.width * 3, ph.height * 3), Image.NEAREST)
        both = Image.new("RGB", (ph.width + 20 + big.width, big.height), (22, 26, 36))
        both.paste(ph, (0, 0))
        both.paste(big, (ph.width + 20, 0))
        blocks.append((f"Set {s}: on a phone ({PHONE[0]} x {PHONE[1]}), real size and 3x", both))
    pad = 24
    width = max(b.width for _, b in blocks) + 2 * pad
    out = Image.new("RGB", (width, 130 + sum(b.height + 54 for _, b in blocks)), (22, 26, 36))
    d = ImageDraw.Draw(out)
    d.text((pad, 20), "Catch screen fish icons (task x3): the inventory's own pictures, under the border",
           font=C.font(34), fill="white")
    d.text((pad, 66), "Each tile, bottom to top: the rarity's colours, the fish (framed exactly as in its inventory slot, "
           "cut off at the tile's inside), then the border.", font=C.font(18), fill=(190, 200, 220))
    d.text((pad, 92), "Real game, Studio playtest, the live end screen (DiveScreen).", font=C.font(18),
           fill=(190, 200, 220))
    y = 130
    for title, b in blocks:
        d.text((pad, y), title, font=C.font(20), fill=(255, 210, 63))
        y += 30
        out.paste(b, (pad, y))
        y += b.height + 24
    out.save(ATT / "catch-ui-icons-2.png")
    print("sheet", out.size)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "listen":
        print(C.server(C.LISTEN))
    elif what == "log":
        print(C.log())
    elif what == "still":
        still(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else END)
    elif what == "phone":
        phone(sys.argv[2])
    elif what == "gif":
        gif()
    elif what == "sheet":
        sheet()
