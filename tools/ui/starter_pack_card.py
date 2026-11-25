"""Draws the mock-up of the Great White pack's card in the Shop's own look (docs/design/starter-packs.md), by code: a page
through headless Chrome with Roblox's built-in font, the Shop's own colours and icons, square studs drawn after the Shop's, and the model's own render
(`python tools/art/voxel_preview.py GreatWhite`, which writes work/voxel/hand/GreatWhite/hero.png). Nothing here is game
code, nothing is uploaded or generated.

    python tools/ui/starter_pack_card.py [look] [--luck] [--try]      look: Gold (default), Sky, Berry, Sea, Grape
    --luck: the later version with x2 luck and its Odds window (the user, 2026-11-25: luck is added after launch)
"""
import glob
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

from PIL import Image, ImageFilter

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


# Square studs as the Shop's: a raised square, lit along its top and left, dark along its foot and right
STUD = "data:image/svg+xml," + quote(
    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect x="4.5" y="4.5" width="11" height="11" rx="2" '
    'fill="#fff" fill-opacity=".34"/><path d="M4.5 15.5V4.5H15.5" fill="none" stroke="#fff" stroke-opacity=".8" '
    'stroke-width="1.8"/><path d="M15.5 4.5V15.5H4.5" fill="none" stroke="#000" stroke-opacity=".5" stroke-width="1.8"/></svg>')


def outlined(src, out):
    """The model's render, cropped to it, with a slight dark outline round its shape"""
    im = Image.open(src).convert("RGBA")
    im = im.crop(im.getbbox())
    pad = 10
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad))
    big.paste(im, (pad, pad))
    edge = big.getchannel("A").filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(0.8))
    line = Image.new("RGBA", big.size, (23, 35, 63, 255))
    line.putalpha(edge)
    Image.alpha_composite(line, big).save(out)


def u(p):
    return Path(p).as_uri()


def build(look, luck):
    wide = W if luck else 894
    top, foot = LOOKS[look]
    WORK.mkdir(parents=True, exist_ok=True)
    outlined(ROOT / "work" / "voxel" / "hand" / "GreatWhite" / "hero.png", WORK / "hero.png")
    icons = ROOT / "art" / "ui" / "icons"
    robux = f'<img class=rb src="{u(ROBUX[-1])}">' if ROBUX else "<b class=rb>R$</b>"
    rows = "".join(f'<tr><td style="color:{c}">{n}</td><td>{a}%</td><td class=now>{b}%</td></tr>' for n, a, b, c in ODDS)
    rays = "".join(f'<i style="transform:translate(-50%,-50%) rotate({i * 20}deg)"></i>' for i in range(9))
    css = """
*{box-sizing:border-box;margin:0;padding:0}
body{width:%(W)dpx;height:%(H)dpx;background:#0b6f9c;font-family:F;color:#fff;overflow:hidden;position:relative}
.t{paint-order:stroke;-webkit-text-stroke:5px #17233f}
.win{position:absolute;background:#0a0c14;border:3px solid #10131f;border-radius:6px;box-shadow:0 5px 0 rgba(0,0,0,.35)}
.win .in{position:absolute;inset:6px;background:#10131f;border-radius:5px}
.win .in:after{content:"";position:absolute;inset:0;background:url("%(stud)s");background-size:16px;opacity:.16}
.head{position:absolute;left:6px;right:6px;top:6px;height:64px;background:linear-gradient(#5fd9f4,#2fb9de);border:3px solid #10131f;border-radius:4px;overflow:hidden}
.head:before{content:"";position:absolute;inset:0;background:url("%(stud)s");background-size:18px;opacity:.28}
.head b{position:absolute;inset:0;text-align:center;line-height:58px;font-size:38px;font-weight:400}
.x{position:absolute;right:6px;top:4px;width:50px;height:48px;background:linear-gradient(#ff5c6e 50%%,#d62240 50%%);border:3px solid #10131f;border-radius:5px;text-align:center;font-size:30px;line-height:42px}
.card{position:absolute;left:118px;top:124px;width:728px;height:424px;border:3px solid #10131f;border-radius:6px;background:linear-gradient(%(top)s,%(foot)s);overflow:hidden}
.studs{position:absolute;inset:0;background:url("%(stud)s");background-size:18px;opacity:.2}
.rays{position:absolute;left:30%%;top:45%%;width:1px;height:1px}
.rays i{position:absolute;left:0;top:0;width:1500px;height:38px;background:linear-gradient(90deg,transparent 10%%,rgba(255,255,255,.62) 42%%,rgba(255,255,255,.62) 58%%,transparent 90%%)}
.glow{position:absolute;left:30%%;top:45%%;width:540px;height:400px;transform:translate(-50%%,-50%%);border-radius:50%%;background:radial-gradient(closest-side,#fff,rgba(255,255,255,.88) 38%%,rgba(255,246,190,.5) 68%%,transparent)}
.hero{position:absolute;left:40px;top:58px;width:334px;filter:drop-shadow(0 6px 5px rgba(90,30,0,.45))}
.g{position:relative;display:inline-block;color:transparent;white-space:nowrap;font-weight:400}
.g:before{content:attr(data-t);position:absolute;left:0;top:0;color:#17233f;-webkit-text-stroke:var(--w,7px) #17233f;text-shadow:0 3px 0 #17233f}
.g:after{content:attr(data-t);position:absolute;left:0;top:0;background:linear-gradient(#fffbe0 22%%,#ffe04a 52%%,#ffa81c 86%%);-webkit-background-clip:text;background-clip:text;color:transparent}
.g.name:after{background:linear-gradient(#fff 38%%,#fff3a0 60%%,#ffd23a 88%%);-webkit-background-clip:text;background-clip:text}
.g.green:after{background:linear-gradient(#f4ffd8 22%%,#a8ff4a 55%%,#3fe02a 88%%);-webkit-background-clip:text;background-clip:text}
.name{position:absolute;left:16px;top:3px;font-size:43px;--w:8px}
.star{position:absolute;color:#fff;font-size:26px;line-height:1;filter:drop-shadow(0 0 1.5px #17233f) drop-shadow(0 0 3px #fff)}
.items{position:absolute;left:446px;top:9px;width:264px}
.it{position:relative;height:81px;margin-bottom:8px;border:3px solid #10131f;border-radius:6px;box-shadow:inset 0 2px 0 rgba(255,255,255,.55),inset 0 -5px 0 rgba(0,0,0,.18)}
.it:before{content:"";position:absolute;inset:0;background:url("%(stud)s");background-size:22px;opacity:.36;border-radius:4px;-webkit-mask-image:linear-gradient(#000 30%%,rgba(0,0,0,.35));mask-image:linear-gradient(#000 30%%,rgba(0,0,0,.35))}
.it.o2{background:linear-gradient(#5cd8ff,#1470ea)} .it.cash{background:linear-gradient(#8df050,#189b34)}
.it.big{height:128px;background:linear-gradient(#cd84ff,#6c28dc)}
.it .pic{position:absolute;left:4px;top:50%%;width:74px;height:74px;transform:translateY(-50%%) rotate(-8deg);object-fit:contain;filter:drop-shadow(0 4px 0 rgba(10,16,40,.55))}
.it .num{position:absolute;left:88px;top:1px;font-size:49px;line-height:54px}
.it .word{position:absolute;left:90px;top:50px;font-size:20px;line-height:24px;letter-spacing:1px}
.big .col{position:absolute;left:12px;top:2px;font-size:43px;line-height:50px;--w:8px}
.big .gw{position:absolute;left:13px;top:49px;font-size:28px;line-height:32px}
.big .earn{position:absolute;left:12px;top:85px;font-size:30px;line-height:34px;--w:6px}
.big .size{position:absolute;right:8px;top:86px;background:linear-gradient(#ff5c6e,#d62240);border:2.5px solid #10131f;border-radius:5px;font-size:17px;line-height:26px;padding:0 8px;transform:rotate(-3deg)}
.band{position:absolute;left:0;right:0;bottom:0;height:92px;background:linear-gradient(#27376e,#141d42);border-top:3px solid #10131f}
.band:before{content:"";position:absolute;inset:0;background:url("%(stud)s");background-size:18px;opacity:.13}
.band .l{position:absolute;left:16px;top:5px;font-size:23px;line-height:30px;--w:6px}
.chips{position:absolute;left:14px;top:40px;display:flex;gap:8px}
.chip{position:relative;height:42px;padding:0 12px 0 8px;border-radius:6px;display:flex;align-items:center;gap:7px;font-size:23px;line-height:42px;white-space:nowrap}
.chip .g{font-size:32px;line-height:40px;--w:6px}
.chip.oc{background:rgba(48,160,255,.6)} .chip.cc{background:rgba(70,200,50,.6)} .chip.lc{background:rgba(170,90,255,.65)}
.btn{position:absolute;border:3px solid #10131f;border-radius:6px;text-align:center;box-shadow:inset 0 2px 0 rgba(255,255,255,.6)}
.buy{right:14px;top:8px;width:200px;height:58px;background:linear-gradient(100deg,transparent 12%%,rgba(255,255,255,.55) 12%% 22%%,transparent 22%% 26%%,rgba(255,255,255,.35) 26%% 30%%,transparent 30%%),linear-gradient(#ffe548 50%%,#ff9a1c 50%%);font-size:41px;line-height:52px;box-shadow:inset 0 2px 0 rgba(255,255,255,.7),0 0 12px 2px rgba(255,220,80,.75)}
.buy.t{-webkit-text-stroke:7px #17233f}
.rb{height:38px;vertical-align:-6px;margin-right:7px;filter:drop-shadow(0 0 2px #17233f) drop-shadow(0 0 1px #17233f)}
.odds{left:428px;top:40px;width:68px;height:42px;background:linear-gradient(#64d8ff 50%%,#1c96ec 50%%);font-size:20px;line-height:36px}
.once{position:absolute;right:14px;width:200px;top:68px;text-align:center;font-size:17px}
.rail{position:absolute;left:12px;top:84px;width:92px}
.rail div{height:76px;margin-bottom:8px;border:3px solid #10131f;border-radius:5px;background:#404658;text-align:center;font-size:28px;line-height:70px}
.rail img{height:52px;margin-top:9px}
.rail div.on{background:linear-gradient(#ffd648,#ff8418)}
.sec{position:absolute;left:120px;top:82px;font-size:30px}
.pop .in2{position:absolute;left:16px;right:16px;top:84px;bottom:16px;background:#22283a;border:3px solid #10131f;border-radius:6px;padding:12px 14px}
.pop p{font-size:16px;line-height:20px;color:#dfe8ff}
.pop table{width:100%%;border-collapse:collapse;font-size:19px;margin:8px 0}
.pop td,.pop th{text-align:right;padding:5px 2px;font-weight:400} .pop td:first-child,.pop th:first-child{text-align:left}
.pop th{font-size:15px;color:#9fb2d8} .pop tr+tr td{border-top:2px solid #333b52} .now{color:#6dee4c}
.cap{position:absolute;font-size:15px;line-height:19px;color:#d8f3ff;font-family:Arial}
""" % dict(W=wide, H=H, stud=STUD, top=top, foot=foot)
    font = '@font-face{font-family:F;src:url("%s")}' % u(FONT)

    def gold(text, kind=""):
        return f'<b class="g {kind}" data-t="{text}">{text}</b>'

    def chip(kind, word):
        return f'<div class="chip {kind}">{gold("x2")}<span class=t>{word}</span></div>'

    chips = chip("oc", "Oxygen") + chip("cc", "Cash") + (chip("lc", "Luck") if luck else "")
    odds = '<div class="btn odds t">Odds</div>' if luck else ""
    pop = f"""<div class="win pop" style="left:898px;top:124px;width:286px;height:366px"><div class=in></div>
 <div class=head><b class=t style="font-size:29px">x2 Luck odds</b></div>
 <div class=in2><p>The colour of each new wild fish. The same for every fish in every land.</p>
 <table><tr><th>Colour</th><th>Normal</th><th>x2 Luck</th></tr>{rows}</table></div></div>
<div class=cap style="left:898px;top:504px;width:284px">What the Odds button opens: Roblox wants the odds shown before the
purchase. Players whose region blocks paid random items get a pack without luck.</div>""" if luck else ""
    html = f"""<meta charset=utf-8><style>{font}{css}</style>
<div class=win style="left:16px;top:14px;width:862px;height:564px"><div class=in></div>
 <div class=head><b class=t>Shop</b><div class="x t">X</div></div>
 <div class=rail><div class=t>★</div><div class="on"><img src="{u(icons / 'shop.png')}"></div><div class=t>x2</div><div><img src="{u(icons / 'oxygen.png')}"></div><div><img src="{u(icons / 'cash.png')}"></div></div>
 <div class="sec t">Packs</div>
 <div class=card><div class=rays>{rays}</div><div class=studs></div><div class=glow></div>
  <img class=hero src="{u(WORK / 'hero.png')}">
  <div class=star style="left:22px;top:96px">✦</div><div class=star style="left:404px;top:150px;font-size:34px">✦</div>
  <div class=star style="left:338px;top:292px;font-size:22px">✦</div><div class=star style="left:132px;top:92px;font-size:18px">✦</div>
  {gold("Great White Pack", "name")}
  <div class=items>
   <div class="it big">{gold("COLOSSAL", "col")}<span class="t gw">Great White</span>{gold("+$742/s", "earn green")}
    <span class="t size">Biggest size!</span></div>
   <div class="it o2"><img class=pic src="{u(icons / 'oxygen.png')}">{gold("+50K", "num")}<span class="t word">OXYGEN</span></div>
   <div class="it cash"><img class=pic src="{u(icons / 'cash.png')}">{gold("+$1M", "num")}<span class="t word">CASH</span></div>
  </div>
  <div class=band>{gold("WHOLE SERVER: x2 for 1 hour!", "l")}
   <div class=chips>{chips}</div>{odds}
   <div class="btn buy t">{robux}{PRICE}</div><div class="once t">One per player</div></div>
 </div></div>
{pop}
<div class=cap style="left:20px;top:586px">Mock-up, drawn by code. The price is a proposal.</div>"""
    page = WORK / "card.html"
    page.write_text(html, encoding="utf-8")
    shot = WORK / f"card_{look}{'_luck' if luck else ''}.png"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--user-data-dir={WORK / 'profile'}", f"--window-size={wide},{H}", "--force-device-scale-factor=1.5",
                    f"--screenshot={shot}", u(page)], check=True, capture_output=True, timeout=120)
    return shot


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("-")]
    luck = "--luck" in sys.argv
    made = build(names[0] if names else "Gold", luck)
    if "--try" in sys.argv:
        print(made)
    else:
        out = OUT.with_name("starter-pack-greatwhite-luck.png") if luck else OUT
        Image.open(made).convert("RGB").save(out)
        print(out)
