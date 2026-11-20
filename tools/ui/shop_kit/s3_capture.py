"""Task s3's captures: the tank's popup, prompt and confirm in the shop kit's look, in a Studio playtest.
    python tools/ui/shop_kit/s3_capture.py install | remove
    python tools/ui/shop_kit/s3_capture.py setup              # in a playtest: the player before their tank
    python tools/ui/shop_kit/s3_capture.py shot <state> <name> [phone WxH]
        states: list rarity full empty prompt deposit (tank_client.luau)
    python tools/ui/shop_kit/s3_capture.py sheet              # docs/attachments/tank-*.jpg
Needs Studio with the studio-runner plugin and Rojo serving this repo; `install` before `play`, `remove` after `stop`.
Raw shots go to work/shop_kit/.
"""
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import s1_capture as S1  # noqa: E402
from s1_capture import C, OUT, ATT, REFS, view_of, font, LISTEN  # noqa: E402


def install(remove=False):
    src = (HERE / "tank_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZTankS3")
if old then old:Destroy() end
workspace:SetAttribute("TankShot", nil)
workspace:SetAttribute("PanelPhone", nil)
if {C.lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZTankS3"
s.Source = {C.lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return C.run([f.name])


SETUP = LISTEN + """local p = game:GetService('Players'):GetPlayers()[1]
if not p then return 'no player' end
local plot = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(p:GetAttribute('Plot') or '')
local water = plot and plot:FindFirstChild('TankWater')
local pad = plot and plot:FindFirstChild('Pad')
local root = p.Character and p.Character:FindFirstChild('HumanoidRootPart')
if not (water and root) then return 'no tank ' .. tostring(p:GetAttribute('Plot')) end
local way = pad and (pad.Position - water.Position) * Vector3.new(1, 0, 1) or water.CFrame.LookVector
way = way.Unit
local half = water.Size / 2
local reach = math.abs(water.CFrame:VectorToObjectSpace(way).X) > 0.7 and half.X or half.Z
local at = Vector3.new(water.Position.X, water.Position.Y - half.Y + 4, water.Position.Z) + way * (reach + 7)
root.CFrame = CFrame.lookAt(at, at - way)
return 'ok ' .. plot.Name"""


def shot(state, name, phone=None):
    code = (f"workspace:SetAttribute('PanelPhone', Vector2.new({phone[0]}, {phone[1]})) " if phone
            else "workspace:SetAttribute('PanelPhone', nil) ")
    code += "workspace:SetAttribute('TankShot', '') "
    print(C.server(code + "return 'ok'"))
    time.sleep(0.6)
    print(C.server(f"workspace:SetAttribute('TankShot', {C.lua(state)}) return 'ok'"))
    time.sleep(2.2)
    raw = OUT / "raw.png"
    if raw.exists():
        raw.unlink()
    C.run(["shot", str(raw)])
    last = -1
    for _ in range(30):
        time.sleep(0.4)
        if raw.exists() and raw.stat().st_size > 0 and raw.stat().st_size == last:
            break
        last = raw.stat().st_size if raw.exists() else -1
    im = view_of(Image.open(raw).convert("RGB"))
    im.save(OUT / f"tank-{name}.png")
    print("saved", OUT / f"tank-{name}.png", im.size)


def box(im, phone=False):
    """Our window in a shot (the game view): wider than s1's crop; the phone box's window sits low in the view."""
    w, h = im.size
    if phone:
        return im.crop((w // 2 - 430, 330, w // 2 + 430, min(h, 745)))
    return im.crop((w // 2 - 640, 140, w // 2 + 640, h))


def labelled(im, title, h):
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
    out = Image.new("RGB", (im.width, h + 44), (24, 26, 32))
    out.paste(im, (0, 44))
    ImageDraw.Draw(out).text((10, 10), title, fill=(255, 230, 120), font=font(22))
    return out


def row(images, out):
    w = sum(i.width for i in images) + 10 * (len(images) + 1)
    h = max(i.height for i in images) + 20
    sheet = Image.new("RGB", (w, h), (24, 26, 32))
    x = 10
    for i in images:
        sheet.paste(i, (x, 10))
        x += i.width + 10
    sheet.save(out, quality=90)
    print("wrote", out)


def sheet():
    def get(n):
        p = OUT / f"tank-{n}.png"
        return Image.open(p).convert("RGB") if p.exists() else None

    # the popup beside the reference's sell list (style only)
    if get("list"):
        ref = Image.open(REFS["Kit"]).convert("RGB")
        row([labelled(ref, "Reference (style only)", 560),
             labelled(box(get("list")), "Ours: your tank (in the game)", 560)], ATT / "tank-vs-ref.jpg")
    pairs = [("rarity", "Sorted by rarity"), ("full", "Tank full: FULL buttons, the refusal"), ("empty", "No fish yet")]
    ims = [labelled(box(get(n)), t, 420) for n, t in pairs if get(n)]
    if ims:
        row(ims, ATT / "tank-states.jpg")
    w = []
    for n, t in (("prompt", "The tank's prompt (E; TAP on a phone)"), ("deposit", "A fish goes in")):
        im = get(n)
        if im:
            W, H = im.size
            w.append(labelled(im.crop((W // 2 - 620, 60, W // 2 + 620, 640)), t, 420))
    if w:
        row(w, ATT / "tank-prompt.jpg")
    if get("phone"):
        row([labelled(box(get("phone"), True), "Your tank on a phone (844x390)", 500)], ATT / "tank-phone.jpg")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "install":
        print(install())
    elif cmd == "remove":
        print(install(True))
    elif cmd == "setup":
        print(C.server(SETUP))
    elif cmd == "shot":
        args = sys.argv[2:]
        phone = None
        if "phone" in args[2:]:
            phone = tuple(int(v) for v in args[args.index("phone", 2) + 1].split("x"))
        shot(args[0], args[1], phone)
    elif cmd == "log":
        print(C.server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZShopLog') return v and v.Value or 'none'"))
    elif cmd == "sheet":
        sheet()
