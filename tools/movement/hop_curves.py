"""The hop's curves, three versions, drawn from the game's own formulas (no Studio needed).

Speed across the water, height and the hook's reach over the hop's time, off a slow, a normal and a fast fish:
  first:  JumpController's speedAt and heightAt at commits 52d62fa and 484d9e3 (the boost gone in 0.75 s, a slow sink);
  three:  the three-part air of 0ca31d4 (fast for the whole glide, the speed lost in 0.35 s, then a fall);
  one:    the one curve (Config.hopFrom, hopKept, hopSpeed, hopSink, reachOf as they are now).
The numbers below are Config.Jump's (ONE) and the two older sets; change ONE here to try a shape.

    python tools/movement/hop_curves.py [out.png] [--measured runs.json]
        (needs rsvg-convert; the SVG it is made from goes to /tmp. runs.json: what the Studio driver's `air` command
        logged, as {"<speed>": [[t, speed, height], ...]}: drawn as dots over the one curve)
"""
import json
import math
import subprocess
import sys
from pathlib import Path

J = dict(
    Window=3.2, LaunchTime=0.4, FloatTime=1.5, FloatRise=1, Apex=20,
    AirSlowSpeed=20, AirFastSpeed=130, AirSlow=-0.5, AirFast=0.5, AirLeast=0.6,
    # first and three: how the hop left
    OldLaunch=1.6, OldHopBoost=18, OldBoostFloor=10, OldAirShare=0.85,
    # first
    BoostHold=0.12, BoostTime=0.75, Drop=12, DropCurve=2, DropSpeed=42, AirSpeed=54, OldRange=180,
    # three
    FastKeep=0.55, FastCurve=1.5, StallTime=0.35, StallShare=0.25, FallGravity=130, OldFallSpeed=90,
    OldGrabFullSpeed=180,
)
# the one curve: Config.Jump as it is now
ONE = dict(
    Launch=0.85, HopBoost=15, AirShare=0.6, BoostFloor=8, SpeedHalf=1.5, SpeedTail=2.5, StopTime=3.2, StopShare=0,
    FallSpeed=80, SinkCurve=3, GrabRange=150, GrabNear=60, GrabFullSpeed=120,
)
FISH = [("slow fish, 40 studs a second", 40), ("normal fish, 74", 74), ("fast fish, 138", 138)]


def smoothstep(a, b, x):
    if b <= a:
        return 1.0 if x >= b else 0.0
    u = min(max((x - a) / (b - a), 0), 1)
    return u * u * (3 - 2 * u)


def out_quad(u):
    u = min(max(u, 0), 1)
    return 1 - (1 - u) ** 2


def air_of(speed):
    u = min(max((speed - J["AirSlowSpeed"]) / (J["AirFastSpeed"] - J["AirSlowSpeed"]), 0), 1)
    return max(J["AirSlow"] + (J["AirFast"] - J["AirSlow"]) * u, J["AirLeast"] - J["FloatTime"])


def old_from(had):
    air = J["OldAirShare"] * had
    launch = max(had * J["OldLaunch"] + J["OldHopBoost"], air + J["OldBoostFloor"])
    return launch, air, air_of(had)


def rise(t, extra):
    """The pop and the glide's last rise: the same in all three."""
    apex, whole = J["Apex"], J["Apex"] + J["FloatRise"]
    if t < J["LaunchTime"]:
        return apex * out_quad(t / J["LaunchTime"])
    return apex + (whole - apex) * out_quad((t - J["LaunchTime"]) / (J["FloatTime"] + extra))


# ---- first ----
def first_speed(t, had):
    launch, air, extra = old_from(had)
    drop_at = J["LaunchTime"] + J["FloatTime"] + extra
    drop_time = J["Window"] - J["LaunchTime"] - J["FloatTime"]
    cruise = launch + (air - launch) * smoothstep(J["BoostHold"], J["BoostTime"], t)
    slow = cruise * min(1, J["DropSpeed"] / J["AirSpeed"])
    return cruise + (slow - cruise) * smoothstep(drop_at, drop_at + drop_time, t)


def first_height(t, had):
    extra = air_of(had)
    drop_at = J["LaunchTime"] + J["FloatTime"] + extra
    drop_time = J["Window"] - J["LaunchTime"] - J["FloatTime"]
    if t < drop_at:
        return rise(t, extra)
    u = min(max((t - drop_at) / drop_time, 0), 1)
    whole = J["Apex"] + J["FloatRise"]
    return whole - (whole + J["Drop"]) * u ** J["DropCurve"]


# ---- three ----
def three_speed(t, had):
    launch, air, extra = old_from(had)
    fast_end = J["LaunchTime"] + J["FloatTime"] + extra
    stall = air * J["StallShare"]
    fast = launch - (launch - air) * (1 - J["FastKeep"]) * (max(t, 0) / fast_end) ** J["FastCurve"]
    fast = max(fast, stall)
    return fast + (stall - fast) * smoothstep(fast_end, fast_end + J["StallTime"], t)


def three_sink(t):
    if t <= 0:
        return 0
    time, most = J["StallTime"], J["OldFallSpeed"]
    pull = min(J["FallGravity"], 2 * most / time)
    x = min(t / time, 1)
    depth = pull * time * time * (x ** 4 / 4 - x ** 5 / 10)
    if t <= time:
        return depth
    speed, rest = pull * time / 2, t - time
    to_most = (most - speed) / pull
    if rest <= to_most:
        return depth + speed * rest + pull * rest * rest / 2
    return depth + speed * to_most + pull * to_most ** 2 / 2 + most * (rest - to_most)


def three_height(t, had):
    extra = air_of(had)
    fast_end = J["LaunchTime"] + J["FloatTime"] + extra
    if t < fast_end:
        return rise(t, extra)
    return J["Apex"] + J["FloatRise"] - three_sink(t - fast_end)


# ---- one ----
def one_from(had, ridden=None):
    launch = had * ONE["Launch"] + ONE["HopBoost"]
    launch = max(launch, ONE["AirShare"] * (ridden if ridden is not None else had) + ONE["BoostFloor"])
    return launch, air_of(had)


def one_kept(t, extra):
    stop = max(ONE["StopTime"] + extra, 0.2)
    rest = ONE["StopShare"]
    u = max(t, 0) / stop
    if u >= 1:
        return rest
    tail = max(ONE["SpeedTail"], 1)
    half = min(max(ONE["SpeedHalf"] / max(ONE["StopTime"], 0.2), 0.05), 0.95)
    a = max(1, math.log(1 - 0.5 ** (1 / tail)) / math.log(half))
    return rest + (1 - rest) * (1 - u ** a) ** tail


def one_speed(t, had):
    launch, extra = one_from(had)
    return launch * one_kept(t, extra)


def one_sink(t, extra):
    if t <= 0:
        return 0
    rest = ONE["StopShare"]
    rate = lambda at: min(max((1 - one_kept(at, extra)) / (1 - rest) if rest < 1 else 1, 0), 1) ** ONE["SinkCurve"]
    stop = max(ONE["StopTime"] + extra, 0.2)
    to = min(t, stop)
    n = 24
    h = to / n
    total = rate(0) + rate(to) + sum(rate(i * h) * (4 if i % 2 else 2) for i in range(1, n))
    return ONE["FallSpeed"] * (total * h / 3 + (t - to))


def one_height(t, had):
    extra = air_of(had)
    return rise(min(t, J["LaunchTime"] + J["FloatTime"] + extra), extra) - one_sink(t, extra)


def reach(speed, full):
    return ONE["GrabNear"] + (ONE["GrabRange"] - ONE["GrabNear"]) * min(max(speed / full, 0), 1)


def along(f, had, window):
    return sum(f(i / 1000, had) for i in range(int(window * 1000))) / 1000


def table():
    """The numbers the note quotes."""
    for name, had in FISH + [("slowest hop: a 40 fish, angry (29)", 29), ("a 40 fish standing still", 0)]:
        ridden = 40 if had in (29, 0) else had
        extra = air_of(had)
        window = J["Window"] + extra
        glide_end = J["LaunchTime"] + J["FloatTime"] + extra
        launch = one_from(had, ridden)[0]
        sp = lambda t: launch * one_kept(t, extra)
        dist = sum(sp(i / 1000) for i in range(int(window * 1000))) / 1000
        worst = max((sp(i / 100) - sp(i / 100 + 0.1)) / 0.1 for i in range(int(window * 100)))
        fall = max((one_sink(i / 100 + 0.01, extra) - one_sink(i / 100, extra)) / 0.01 for i in range(int(window * 100)))
        print(
            f"{name}: leaves at first {old_from(had)[0]:.0f}, one {launch:.0f} | glide ends {glide_end:.2f} s, window {window:.2f} s | "
            f"one curve at 0.5 s {sp(0.5):.0f}, 1 s {sp(1):.0f}, glide's end {sp(glide_end):.0f}, 0.5 s later {sp(glide_end + 0.5):.0f}, window's end {sp(window):.0f} | "
            f"most speed lost in a second: {worst:.0f} | "
            f"studs along: first {along(first_speed, had, window):.0f}, three {along(three_speed, had, window):.0f}, one {dist:.0f} | "
            f"height at the glide's end {one_height(glide_end, had):.0f}, at the window's end {one_height(window, had):.0f}, fastest fall {fall:.0f} | "
            f"reach: {reach(launch, ONE['GrabFullSpeed']):.0f} leaving, {reach(sp(glide_end), ONE['GrabFullSpeed']):.0f} at the glide's end, {reach(sp(window), ONE['GrabFullSpeed']):.0f} at the end"
        )


# ---- drawing (an SVG by hand: matplotlib isn't on this PC) ----
INK, INK2, GRID, SURFACE = "#1f1f1d", "#5d5c56", "#e4e2da", "#ffffff"
C_ONE, C_THREE, C_FIRST = "#2a78d6", "#eb6834", "#8a8880"
PW, PH, GAP_X, GAP_Y, LEFT, TOP = 330, 200, 64, 74, 70, 150
ROWS = [
    ("Speed across the water, studs a second", first_speed, three_speed, one_speed),
    ("Height above where you left, studs (open water: the sea floor stops the fall sooner)", first_height, three_height, one_height),
    ("The hook's reach, studs", lambda t, h: J["OldRange"], lambda t, h: reach(three_speed(t, h), J["OldGrabFullSpeed"]), lambda t, h: reach(one_speed(t, h), ONE["GrabFullSpeed"])),
]
YRANGE = [(0, 240, 60), (-90, 30, 30), (0, 200, 50)]
TMAX = 4.0


def draw(out: Path, measured: dict):
    width = LEFT + 3 * PW + 2 * GAP_X + 40
    height = TOP + 3 * PH + 2 * GAP_Y + 60
    lx = LEFT - 44
    s = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="DejaVu Sans, Arial, sans-serif">',
        f'<rect width="{width}" height="{height}" fill="{SURFACE}"/>',
        f'<text x="{lx}" y="34" font-size="20" font-weight="bold" fill="{INK}">The hop, three versions: the one curve (2026-11-13) against the two before it</text>',
        f'<line x1="{lx}" y1="60" x2="{lx + 28}" y2="60" stroke="{C_ONE}" stroke-width="3.2"/><text x="{lx + 34}" y="65" font-size="14" fill="{INK}">now: one curve, easing to a stop (Config.hopSpeed, hopSink)</text>',
        f'<line x1="{lx + 470}" y1="60" x2="{lx + 498}" y2="60" stroke="{C_THREE}" stroke-width="2.4" stroke-dasharray="7 4"/><text x="{lx + 504}" y="65" font-size="14" fill="{INK}">three parts: fast, stall, fall (0ca31d4)</text>',
        f'<line x1="{lx + 800}" y1="60" x2="{lx + 828}" y2="60" stroke="{C_FIRST}" stroke-width="2.4" stroke-dasharray="2 4"/><text x="{lx + 834}" y="65" font-size="14" fill="{INK}">first: boost, then the glide (52d62fa)</text>',
        f'<text x="{lx}" y="88" font-size="13" fill="{INK2}">Lines: the game\'s formulas. '
        + ("Dots: the one curve as flown in Studio (one hop each, every 0.1 s). " if measured else "")
        + "The thin upright line: the glide's end, where the pull-in begins by itself. Curves end where the window does.</text>",
    ]
    for row, (title, f_first, f_three, f_one) in enumerate(ROWS):
        y0 = TOP + row * (PH + GAP_Y)
        lo, hi, step = YRANGE[row]
        s.append(f'<text x="{lx}" y="{y0 - 12}" font-size="14" font-weight="bold" fill="{INK}">{title}</text>')
        for col, (name, had) in enumerate(FISH):
            x0 = LEFT + col * (PW + GAP_X)
            extra = air_of(had)
            window = J["Window"] + extra
            glide_end = J["LaunchTime"] + J["FloatTime"] + extra
            px = lambda t: x0 + t / TMAX * PW
            py = lambda v: y0 + PH - (min(max(v, lo), hi) - lo) / (hi - lo) * PH
            v = lo
            while v <= hi + 1e-6:
                s.append(f'<line x1="{x0}" y1="{py(v):.1f}" x2="{x0 + PW}" y2="{py(v):.1f}" stroke="{GRID}" stroke-width="1"/>')
                s.append(f'<text x="{x0 - 8}" y="{py(v) + 4:.1f}" font-size="11" text-anchor="end" fill="{INK2}">{v:g}</text>')
                v += step
            if lo < 0:
                s.append(f'<line x1="{x0}" y1="{py(0):.1f}" x2="{x0 + PW}" y2="{py(0):.1f}" stroke="{INK2}" stroke-width="1"/>')
            s.append(f'<line x1="{px(glide_end):.1f}" y1="{y0}" x2="{px(glide_end):.1f}" y2="{y0 + PH}" stroke="{INK2}" stroke-width="1" stroke-dasharray="2 3"/>')
            for tick in range(0, int(TMAX) + 1):
                s.append(f'<text x="{px(tick):.1f}" y="{y0 + PH + 16}" font-size="11" text-anchor="middle" fill="{INK2}">{tick} s</text>')
            if row == 0:
                s.append(f'<text x="{x0}" y="{y0 - 34}" font-size="13" font-weight="bold" fill="{INK2}">{name}</text>')
            ends = []
            for colour, f, dash, wide in ((C_FIRST, f_first, ' stroke-dasharray="2 4"', 2.2), (C_THREE, f_three, ' stroke-dasharray="7 4"', 2.2), (C_ONE, f_one, "", 3)):
                pts = []
                n = int(window * 100)
                for i in range(n + 1):
                    t = i / 100
                    pts.append(f"{px(t):.1f},{py(f(t, had)):.1f}")
                s.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{colour}" stroke-width="{wide}" stroke-linejoin="round"{dash}/>')
                ends.append((py(f(window, had)), f(window, had), colour))
            # the end values, kept from sitting on each other
            ends.sort()
            last = -99
            for y, value, colour in ends:
                s.append(f'<circle cx="{px(window):.1f}" cy="{y:.1f}" r="4" fill="{colour}" stroke="{SURFACE}" stroke-width="2"/>')
                ty = max(y + 4, last + 13)
                last = ty
                s.append(f'<text x="{px(window) + 8:.1f}" y="{ty:.1f}" font-size="11" fill="{INK}">{value:.0f}</text>')
            if row < 2:
                for t, speed, high in measured.get(str(had), []):
                    value = speed if row == 0 else high
                    if t <= TMAX and lo <= value <= hi:
                        s.append(f'<circle cx="{px(t):.1f}" cy="{py(value):.1f}" r="2.6" fill="{SURFACE}" stroke="{C_ONE}" stroke-width="1.4"/>')
    s.append("</svg>")
    svg = Path("/tmp") / (out.stem + ".svg")
    svg.write_text("\n".join(s))
    subprocess.run(["rsvg-convert", "-o", str(out), str(svg)], check=True)
    print(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    measured = {}
    if "--measured" in args:
        i = args.index("--measured")
        measured = json.loads(Path(args[i + 1]).read_text())
        del args[i : i + 2]
    table()
    draw(Path(args[0]) if args else Path(__file__).resolve().parents[2] / "docs/attachments/hop-one-curve.png", measured)
