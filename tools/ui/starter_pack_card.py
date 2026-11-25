"""Draws the mock-up of the Great White pack's card in the Shop's own look (docs/design/starter-packs.md), by code: a page
through headless Chrome with Roblox's built-in font, the Shop's own colours, studs and icons, and the model's own render
(`python tools/art/voxel_preview.py GreatWhite`, which writes work/voxel/hand/GreatWhite/hero.png). Nothing here is game
code, nothing is uploaded or generated.

    python tools/ui/starter_pack_card.py [look] [--try]      look: Gold (default), Sky, Berry, Sea, Grape
"""
import glob
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "attachments" / "starter-pack-greatwhite.png"
WORK = Path(tempfile.gettempdir()) / "rideafish_starter_pack"
CHROME = [p for p in (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                      r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") if os.path.exists(p)][0]
FONT = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf")),
              key=os.path.getmtime)[-1]
CONTENT = Path(FONT).parents[1]
ROBUX = sorted(CONTENT.glob("textures/ui/common/robux*.png"))
LOOKS = {"Gold": ("rgb(255,214,72)", "rgb(255,132,24)"), "Sky": ("rgb(96,214,255)", "rgb(36,116,236)"),
         "Berry": ("rgb(255,108,176)", "rgb(196,40,120)"), "Grape": ("rgb(190,120,255)", "rgb(110,54,220)"),
         "Sea": ("rgb(70,236,214)", "rgb(16,150,170)")}
W, H = 1200, 610

# the numbers: what docs/design/starter-packs.md says
PRICE = "149"
ODDS = [("Plain", "93.83", "87.67", "#fff"), ("Silver", "5.00", "10.00", "#dfe6f2"), ("Gold", "1.00", "2.00", "#ffd648"),
        ("Rainbow", "0.17", "0.33", "#ff8ad8")]


def u(p):
    return Path(p).as_uri()


def build(look):
    top, foot = LOOKS[look]
    WORK.mkdir(parents=True, exist_ok=True)
    hero = Image.open(ROOT / "work" / "voxel" / "hand" / "GreatWhite" / "hero.png").convert("RGBA")
    hero.crop(hero.getbbox()).save(WORK / "hero.png")
    body = ROOT / "art" / "ui" / "shop" / "shop_body.png"
    head = ROOT / "art" / "ui" / "shop" / "shop_head.png"
    icons = ROOT / "art" / "ui" / "icons"
    robux = f'<img class=rb src="{u(ROBUX[-1])}">' if ROBUX else "<b class=rb>R$</b>"
    rows = "".join(f'<tr><td style="color:{c}">{n}</td><td>{a}%</td><td class=now>{b}%</td></tr>' for n, a, b, c in ODDS)
    rays = "".join(f'<i style="transform:translate(-50%,-50%) rotate({i * 20}deg)"></i>' for i in range(9))
    css = """
*{box-sizing:border-box;margin:0;padding:0}
body{width:%(W)dpx;height:%(H)dpx;background:#0b6f9c;font-family:F;color:#fff;overflow:hidden;position:relative}
.t{paint-order:stroke;-webkit-text-stroke:5px #17233f}
.win{position:absolute;background:#0a0c14;border:3px solid #10131f;border-radius:6px;box-shadow:0 5px 0 rgba(0,0,0,.35)}
.win .in{position:absolute;inset:6px;background:#05060b url("%(body)s");background-size:24px;border-radius:5px}
.head{position:absolute;left:6px;right:6px;top:6px;height:64px;background:linear-gradient(#5fd9f4,#2fb9de);border:3px solid #10131f;border-radius:4px;overflow:hidden}
.head:before{content:"";position:absolute;inset:0;background:url("%(head)s");background-size:24px;opacity:.25}
.head b{position:absolute;inset:0;text-align:center;line-height:58px;font-size:38px;font-weight:400}
.x{position:absolute;right:6px;top:4px;width:50px;height:48px;background:linear-gradient(#ff5c6e 50%%,#d62240 50%%);border:3px solid #10131f;border-radius:5px;text-align:center;font-size:30px;line-height:42px}
.card{position:absolute;left:118px;top:124px;width:728px;height:424px;border:3px solid #10131f;border-radius:6px;background:linear-gradient(%(top)s,%(foot)s);overflow:hidden}
.studs{position:absolute;inset:0;background:url("%(head)s");background-size:24px;opacity:.16}
.rays{position:absolute;left:30%%;top:44%%;width:1px;height:1px}
.rays i{position:absolute;left:0;top:0;width:1500px;height:34px;background:#fff;opacity:.15}
.glow{position:absolute;left:30%%;top:44%%;width:460px;height:340px;transform:translate(-50%%,-50%%);border-radius:50%%;background:radial-gradient(closest-side,rgba(255,255,255,.9),rgba(255,255,255,.4) 55%%,transparent)}
.hero{position:absolute;left:24px;top:46px;width:382px;filter:drop-shadow(0 0 1.2px #10131f) drop-shadow(0 0 1px #10131f) drop-shadow(0 6px 6px rgba(0,20,60,.4))}
.name{position:absolute;left:18px;top:10px;font-size:42px}
.items{position:absolute;left:448px;top:18px;width:262px}
.it{height:72px;margin-bottom:9px;background:rgba(16,28,66,.82);border:2.5px solid #10131f;border-radius:5px;display:flex;align-items:center;padding:0 12px;gap:12px}
.it img{width:48px;height:48px;object-fit:contain}
.it b{font-size:26px;font-weight:400;line-height:30px;display:block;white-space:nowrap}
.it s{text-decoration:none;font-size:17px;display:block;line-height:22px;color:#eaf6ff;white-space:nowrap}
.it.big{height:122px} .it.big b{font-size:29px;line-height:32px}
.it.big b i{font-style:normal;color:#ffe27a}
.band{position:absolute;left:0;right:0;bottom:0;height:96px;background:rgba(14,22,54,.88);border-top:3px solid #10131f}
.band .l{position:absolute;left:18px;top:9px;font-size:20px;color:#ffe27a}
.chips{position:absolute;left:16px;top:41px;display:flex;gap:8px}
.chip{height:42px;padding:0 13px;border:2.5px solid #10131f;border-radius:5px;font-size:23px;line-height:37px;white-space:nowrap}
.btn{position:absolute;border:3px solid #10131f;border-radius:5px;text-align:center;box-shadow:inset 0 2px 0 rgba(255,255,255,.5)}
.buy{right:16px;top:12px;width:176px;height:54px;background:linear-gradient(#ffde3c 50%%,#ff961c 50%%);font-size:33px;line-height:48px}
.rb{height:30px;vertical-align:-4px;margin-right:6px;filter:drop-shadow(0 0 2px #17233f) drop-shadow(0 0 1px #17233f)}
.odds{left:420px;top:41px;width:80px;height:42px;background:linear-gradient(#ced2e0 50%%,#9aa0b6 50%%);font-size:21px;line-height:36px}
.once{position:absolute;right:16px;width:176px;top:71px;text-align:center;font-size:16px}
.rail{position:absolute;left:12px;top:84px;width:92px}
.rail div{height:76px;margin-bottom:8px;border:3px solid #10131f;border-radius:5px;background:#404658;text-align:center;font-size:18px;line-height:70px}
.rail div.on{background:linear-gradient(#ffd648,#ff8418)}
.sec{position:absolute;left:120px;top:82px;font-size:30px}
.pop .in2{position:absolute;left:16px;right:16px;top:84px;bottom:16px;background:#22283a;border:3px solid #10131f;border-radius:6px;padding:12px 14px}
.pop p{font-size:16px;line-height:20px;color:#dfe8ff}
.pop table{width:100%%;border-collapse:collapse;font-size:19px;margin:8px 0}
.pop td,.pop th{text-align:right;padding:5px 2px;font-weight:400} .pop td:first-child,.pop th:first-child{text-align:left}
.pop th{font-size:15px;color:#9fb2d8} .pop tr+tr td{border-top:2px solid #333b52} .now{color:#6dee4c}
.cap{position:absolute;font-size:15px;line-height:19px;color:#d8f3ff;font-family:Arial}
""" % dict(W=W, H=H, body=u(body), head=u(head), top=top, foot=foot)
    font = '@font-face{font-family:F;src:url("%s")}' % u(FONT)
    html = f"""<meta charset=utf-8><style>{font}{css}</style>
<div class=win style="left:16px;top:14px;width:862px;height:564px"><div class=in></div>
 <div class=head><b class=t>Shop</b><div class="x t">X</div></div>
 <div class=rail><div class=t>★</div><div class="on t">Packs</div><div class=t>x2</div><div class=t>Oxygen</div><div class=t>Cash</div></div>
 <div class="sec t">Packs</div>
 <div class=card><div class=rays>{rays}</div><div class=studs></div><div class=glow></div>
  <img class=hero src="{u(WORK / 'hero.png')}">
  <div class="name t">Great White Pack</div>
  <div class=items>
   <div class="it big"><div><b class=t><i>Colossal</i></b><b class=t>Great White</b><s class=t>Earns $742/s in your tank</s></div></div>
   <div class=it><img src="{u(icons / 'oxygen.png')}"><b class=t>+100K Oxygen</b></div>
   <div class=it><img src="{u(icons / 'cash.png')}"><b class=t>+$5M</b></div>
  </div>
  <div class=band><div class="l t">Everyone in the server, 1 hour:</div>
   <div class=chips><div class="chip t" style="background:linear-gradient(#64d8ff 50%,#1c96ec 50%)">x2 Oxygen</div>
   <div class="chip t" style="background:linear-gradient(#96fa46 50%,#46ce20 50%)">x2 Cash</div>
   <div class="chip t" style="background:linear-gradient(#c482ff 50%,#8e46e6 50%)">x2 Luck</div></div>
   <div class="btn odds t">Odds</div>
   <div class="btn buy t">{robux}{PRICE}</div><div class="once t">One per player</div></div>
 </div></div>
<div class="win pop" style="left:898px;top:124px;width:286px;height:366px"><div class=in></div>
 <div class=head><b class=t style="font-size:29px">x2 Luck odds</b></div>
 <div class=in2><p>The colour of each new wild fish. The same for every fish in every land.</p>
 <table><tr><th>Colour</th><th>Normal</th><th>x2 Luck</th></tr>{rows}</table></div></div>
<div class=cap style="left:898px;top:504px;width:284px">What the Odds button opens: Roblox wants the odds shown before the
purchase. Players whose region blocks paid random items get a pack without luck.</div>
<div class=cap style="left:20px;top:586px">Mock-up, drawn by code. The price and the amounts are proposals.</div>"""
    page = WORK / "card.html"
    page.write_text(html, encoding="utf-8")
    shot = WORK / f"card_{look}.png"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--user-data-dir={WORK / 'profile'}", f"--window-size={W},{H}", "--force-device-scale-factor=1.5",
                    f"--screenshot={shot}", u(page)], check=True, capture_output=True, timeout=120)
    return shot


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("-")]
    made = build(names[0] if names else "Gold")
    if "--try" in sys.argv:
        print(made)
    else:
        Image.open(made).convert("RGB").save(OUT)
        print(OUT)
