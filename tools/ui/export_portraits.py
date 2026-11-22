"""Saves every fish's picture, as the game draws it (src/client/UI/Portrait.luau), as its own square PNG on white: the
starting point for drawn icons (the user, 2026-11-19: "we could use the icons to chatgpt generate the icons from those").
Pages of plain pictures go on screen in Studio (Edit) through tools/ui/portrait_sheet.py, each page is captured and cut
up, and the sheet is taken away after each capture. Only the chat that has Studio runs it; Studio must be on screen
(a minimised Studio draws nothing).
usage: python tools/ui/export_portraits.py <studio_id> [out folder] [--tile N] [--only Name,Name]
  out folder: art/ui/fish_icons/renders by default; one <Id>.png each, and contact.jpg, all of them on one sheet
"""
import json
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLIENT = "C:/Users/blast/RpgGame/tools/studio/studio_mcp.py"
GAP = 10


def call(tool, args, timeout=120, image=None):
    env = dict(os.environ)
    if image:
        env["MCP_IMG"] = image
    fd, path = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(args, f)
    try:
        out = subprocess.run(["python", CLIENT, "call", tool, "@" + path, str(timeout)], capture_output=True, text=True,
                             encoding="utf-8", errors="replace", env=env).stdout
    finally:
        os.remove(path)
    line = next((l for l in out.splitlines() if l.startswith('{"content"')), None)
    return json.loads(line) if line else None


def luau(studio, code):
    result = call("execute_luau", {"studio_id": studio, "datamodel_type": "Edit", "code": code})
    if not result or result.get("isError"):
        return None
    return result["content"][0]["text"]


def sheet(studio, *args):
    """Runs tools/ui/portrait_sheet.py, a few times if Studio's link drops a call; True when it drew."""
    for _ in range(4):
        run = subprocess.run(["python", os.path.join(ROOT, "tools", "ui", "portrait_sheet.py"), studio, *args],
                             cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        text = run.stdout + run.stderr
        if "pictures drawn" in text or "sheet taken away" in text:
            return True
    return False


def main():
    args = sys.argv[1:]
    studio = args[0]
    out = os.path.join(ROOT, "art", "ui", "fish_icons", "renders")
    tile, only = 240, None
    i = 1
    while i < len(args):
        if args[i] == "--tile":
            tile = int(args[i + 1])
            i += 1
        elif args[i] == "--only":
            only = args[i + 1].split(",")
            i += 1
        else:
            out = args[i]
        i += 1
    os.makedirs(out, exist_ok=True)
    listing = luau(studio, """
local names = {}
for _, m in game:GetService("ReplicatedStorage").FishModels:GetChildren() do table.insert(names, m.Name) end
table.sort(names)
local size = workspace.CurrentCamera.ViewportSize
return string.format("%d,%d;", size.X, size.Y) .. table.concat(names, ",")""")
    if not listing:
        sys.exit("Studio did not answer (is it open, in Edit, with this id?)")
    size, names = listing.split(";")
    width, height = [int(v) for v in size.split(",")]
    names = names.split(",")
    if only:
        names = [n for n in names if n in only]
    cols = (width - 20) // (tile + GAP)
    rows = (height - 20) // (tile + GAP)
    page = cols * rows
    shot = os.path.join(tempfile.gettempdir(), "portrait_page.png")
    saved = []
    for first in range(0, len(names), page):
        chunk = names[first:first + page]
        if not sheet(studio, ",".join(chunk), "--plain", "--tile", str(tile)):
            sys.exit("the sheet would not draw (page from %s)" % chunk[0])
        result = call("screen_capture", {"studio_id": studio, "capture_id": "Portraits_%d" % first}, image=shot)
        sheet(studio, "off")
        jpeg = shot.replace(".png", ".jpeg")
        if not result or not os.path.exists(jpeg):
            sys.exit("no capture (page from %s)" % chunk[0])
        im = Image.open(jpeg).convert("RGB")
        if im.size != (width, height):
            im = im.resize((width, height), Image.LANCZOS)
        for k, name in enumerate(chunk):
            x, y = 10 + (k % cols) * (tile + GAP), 10 + (k // cols) * (tile + GAP)
            cell = im.crop((x, y, x + tile, y + tile))
            cell.save(os.path.join(out, name + ".png"))
            saved.append(name)
        os.remove(jpeg)
        print("page from %s: %d saved" % (chunk[0], len(chunk)))
    # every render in the folder on one contact sheet, named (not only this run's, when --only made a few)
    saved = sorted(n[:-4] for n in os.listdir(out) if n.endswith(".png"))
    per = 10
    small = 160
    contact = Image.new("RGB", (per * small, math.ceil(len(saved) / per) * (small + 18)), (255, 255, 255))
    draw = ImageDraw.Draw(contact)
    font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 12)
    for k, name in enumerate(saved):
        cell = Image.open(os.path.join(out, name + ".png")).resize((small, small), Image.LANCZOS)
        x, y = (k % per) * small, (k // per) * (small + 18)
        contact.paste(cell, (x, y))
        draw.text((x + 4, y + small + 2), name, font=font, fill=(30, 30, 30))
    contact.save(os.path.join(out, "contact.jpg"), quality=88)
    print("%d pictures in %s" % (len(saved), out))


if __name__ == "__main__":
    main()
