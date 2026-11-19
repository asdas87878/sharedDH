"""Task s1's captures: each shop screen in a Studio playtest, beside Hugo's reference shots.
    python tools/ui/shop_kit/s1_capture.py install | remove
    python tools/ui/shop_kit/s1_capture.py setup            # in a playtest: coins, a sub tier, the player at the stand
    python tools/ui/shop_kit/s1_capture.py shot <Sub|Aura|Kit> <name> [free 0|1] [phone WxH]
    python tools/ui/shop_kit/s1_capture.py sheet             # docs/attachments/shop-*.png, side by side
Needs Studio with the studio-runner plugin and Rojo serving this repo; `install` before `play`, `remove` after `stop`.
Raw shots go to work/shop_kit/.
"""
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/ui/catch_show"))
import capture as C  # noqa: E402
from c1_capture import view_of  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = ROOT / "work/shop_kit"
OUT.mkdir(parents=True, exist_ok=True)
ATT = ROOT / "docs/attachments"
REF = Path("/home/hugo/Projects/nullroom/data/uploads/2026-11-19")
REFS = {
    "Kit": REF / "235222-pasted-235222.png",
    "Aura": REF / "235238-pasted-235238.png",
    "Sub": REF / "235250-pasted-235250.png",
}


def install(remove=False):
    src = (HERE / "shop_client.luau").read_text()
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZShopS1")
if old then old:Destroy() end
workspace:SetAttribute("ShopShot", nil)
workspace:SetAttribute("ShopFree", nil)
workspace:SetAttribute("PanelPhone", nil)
if {C.lua(remove)} then return "removed" end
local s = Instance.new("LocalScript")
s.Name = "ZZShopS1"
s.Source = {C.lua(src)}
s.Parent = sps
return "installed " .. #s.Source
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return C.run([f.name])


LISTEN = """local RS = game:GetService('ReplicatedStorage')
local SS = game:GetService('ServerStorage')
local log = SS:FindFirstChild('ZZShopLog') or Instance.new('StringValue')
log.Name = 'ZZShopLog' log.Parent = SS
if not RS:FindFirstChild('ZZShopReport') then
	local r = Instance.new('RemoteEvent') r.Name = 'ZZShopReport' r.Parent = RS
	r.OnServerEvent:Connect(function(_, text) log.Value = string.sub(log.Value .. '\\n' .. tostring(text), -3000) end)
end
"""

SETUP = LISTEN + """local p = game:GetService('Players'):GetPlayers()[1]
if not p then return 'no player' end
p:SetAttribute('Coins', 31400)
p:SetAttribute('SubTier', 2)
p:SetAttribute('SubEquip', 2)
p:SetAttribute('SubDest', 3)
p:SetAttribute('Aura', 3)
local st = workspace.ClaudeBlockout.Dock.Stations:FindFirstChild('Sub')
local ring = st and (st:FindFirstChild('Ring') or st.PrimaryPart)
local root = p.Character and p.Character:FindFirstChild('HumanoidRootPart')
if ring and root then root.CFrame = ring.CFrame + Vector3.new(6, 4, 0) end
return 'ok ' .. tostring(ring ~= nil)"""


def shot(which, name, free=None, phone=None):
    code = f"workspace:SetAttribute('ShopShot', {C.lua(which)}) "
    if free is not None:
        code += f"workspace:SetAttribute('ShopFree', {free}) "
    code += (f"workspace:SetAttribute('PanelPhone', Vector2.new({phone[0]}, {phone[1]})) " if phone
             else "workspace:SetAttribute('PanelPhone', nil) ")
    print(C.server(code + "return 'ok'"))
    time.sleep(2.0)
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
    im.save(OUT / f"{name}.png")
    print("saved", OUT / f"{name}.png", im.size)


def font(size):
    for f in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def pair(ref, ours, out, title):
    h = 560
    a = Image.open(ref).convert("RGB")
    b = Image.open(ours).convert("RGB")
    a = a.resize((round(a.width * h / a.height), h), Image.LANCZOS)
    b = b.resize((round(b.width * h / b.height), h), Image.LANCZOS)
    sheet = Image.new("RGB", (a.width + b.width + 30, h + 60), (24, 26, 32))
    sheet.paste(a, (10, 50))
    sheet.paste(b, (a.width + 20, 50))
    d = ImageDraw.Draw(sheet)
    d.text((14, 12), "Reference (style only)", fill=(220, 220, 220), font=font(22))
    d.text((a.width + 24, 12), title, fill=(255, 230, 120), font=font(22))
    sheet.save(out, quality=90)
    print("wrote", out)


def sheet():
    for which, ours, out, title in (
        ("Sub", "sub", "shop-sub-vs-ref.jpg", "Ours: the sub stand (in the game)"),
        ("Aura", "aura", "shop-aura-vs-ref.jpg", "Ours: the aura shop (ready, not wired)"),
        ("Kit", "kit", "shop-kit-vs-ref.jpg", "Ours: the kit's list pieces (a sample)"),
    ):
        if (OUT / f"{ours}.png").exists():
            pair(REFS[which], OUT / f"{ours}.png", ATT / out, title)


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
        free = phone = None
        if "free" in args:
            free = int(args[args.index("free") + 1])
        if "phone" in args:
            phone = tuple(int(v) for v in args[args.index("phone") + 1].split("x"))
        shot(args[0], args[1], free, phone)
    elif cmd == "log":
        print(C.server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZShopLog') return v and v.Value or 'none'"))
    elif cmd == "sheet":
        sheet()
