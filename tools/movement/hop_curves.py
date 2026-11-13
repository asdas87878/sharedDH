"""The hop's curves before and after 2026-11-13, drawn from the game's own formulas (no Studio needed).

Speed across the water, height and the hook's reach over the hop's time, for a slow, a normal and a fast fish.
"Before" is JumpController's speedAt and heightAt as they were in commit 484d9e3; "after" is Config.hopSpeed,
Config.hopSink and Config.reachOf. The numbers below are Config.Jump's; change them here to try a shape.

    python tools/movement/hop_curves.py [out.png]      (needs rsvg-convert; the SVG it is made from goes to /tmp)
"""
import subprocess
import sys
from pathlib import Path

J = dict(
    Window=3.2, LaunchTime=0.4, FloatTime=1.5, FloatRise=1, Apex=20, Launch=1.6, HopBoost=18, BoostFloor=10,
    AirShare=0.85, AirSlowSpeed=20, AirFastSpeed=130, AirSlow=-0.5, AirFast=0.5, AirLeast=0.6,
    # before
    BoostHold=0.12, BoostTime=0.75, Drop=12, DropCurve=2, DropSpeed=42, AirSpeed=54, OldRange=180,
    # after
    FastKeep=0.55, FastCurve=1.5, StallTime=0.35, StallShare=0.25, FallGravity=130, FallSpeed=90,
    GrabRange=150, GrabNear=60, GrabFullSpeed=180,
)
FISH = [("slow fish, 40 studs a second", 40), ("normal fish, 75", 75), ("fast fish, 128", 128)]


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


def hop_from(had):
    air = J["AirShare"] * had
    launch = max(had * J["Launch"] + J["HopBoost"], air + J["BoostFloor"])
    return launch, air, air_of(had)


def rise(t, extra):
    """The pop and the glide: the same before and after."""
    apex, whole = J["Apex"], J["Apex"] + J["FloatRise"]
    if t < J["LaunchTime"]:
        return apex * out_quad(t / J["LaunchTime"])
    return apex + (whole - apex) * out_quad((t - J["LaunchTime"]) / (J["FloatTime"] + extra))


def old_speed(t, launch, air, extra):
    drop_at = J["LaunchTime"] + J["FloatTime"] + extra
    drop_time = J["Window"] - J["LaunchTime"] - J["FloatTime"]
    cruise = launch + (air - launch) * smoothstep(J["BoostHold"], J["BoostTime"], t)
    slow = cruise * min(1, J["DropSpeed"] / J["AirSpeed"])
    return cruise + (slow - cruise) * smoothstep(drop_at, drop_at + drop_time, t)


def old_height(t, extra):
    drop_at = J["LaunchTime"] + J["FloatTime"] + extra
    drop_time = J["Window"] - J["LaunchTime"] - J["FloatTime"]
    if t < drop_at:
        return rise(t, extra)
    u = min(max((t - drop_at) / drop_time, 0), 1)
    whole = J["Apex"] + J["FloatRise"]
    return whole - (whole + J["Drop"]) * u ** J["DropCurve"]


def new_speed(t, launch, air, extra):
    fast_end = J["LaunchTime"] + J["FloatTime"] + extra
    stall = air * J["StallShare"]
    fast = launch - (launch - air) * (1 - J["FastKeep"]) * (max(t, 0) / fast_end) ** J["FastCurve"]
    fast = max(fast, stall)
    return fast + (stall - fast) * smoothstep(fast_end, fast_end + J["StallTime"], t)


def hop_sink(t):
    if t <= 0:
        return 0
    time, most = J["StallTime"], J["FallSpeed"]
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


def new_height(t, extra):
    fast_end = J["LaunchTime"] + J["FloatTime"] + extra
    if t < fast_end:
        return rise(t, extra)
    return J["Apex"] + J["FloatRise"] - hop_sink(t - fast_end)


def reach_of(speed):
    return J["GrabNear"] + (J["GrabRange"] - J["GrabNear"]) * min(max(speed / J["GrabFullSpeed"], 0), 1)


def table():
    """The numbers the note quotes."""
    for name, had in FISH:
        launch, air, extra = hop_from(had)
        window = J["Window"] + extra
        fast_end = J["LaunchTime"] + J["FloatTime"] + extra
        dist_old = sum(old_speed(i / 1000, launch, air, extra) for i in range(int(window * 1000))) / 1000
        dist_new = sum(new_speed(i / 1000, launch, air, extra) for i in range(int(window * 1000))) / 1000
        print(
            f"{name}: launch {launch:.0f}, glide pace {air:.0f}, fast part ends {fast_end:.2f} s, window {window:.2f} s | "
            f"speed at the fast part's end: before {old_speed(fast_end, launch, air, extra):.0f}, after {new_speed(fast_end, launch, air, extra):.0f} | "
            f"0.35 s later: before {old_speed(fast_end + 0.35, launch, air, extra):.0f}, after {new_speed(fast_end + 0.35, launch, air, extra):.0f} | "
            f"studs along in the whole window: before {dist_old:.0f}, after {dist_new:.0f} | "
            f"height 0.8 s after the fast part: before {old_height(fast_end + 0.8, extra):.0f}, after {new_height(fast_end + 0.8, extra):.0f} | "
            f"reach after: {reach_of(launch):.0f} at the pop, {reach_of(new_speed(fast_end, launch, air, extra)):.0f} at the fast part's end, "
            f"{reach_of(air * J['StallShare']):.0f} stalled (before: {J['OldRange']} throughout)"
        )


# ---- drawing (an SVG by hand: matplotlib isn't on this PC) ----
INK, INK2, GRID, SURFACE = "#1f1f1d", "#5d5c56", "#e4e2da", "#ffffff"
NEW, OLD = "#2a78d6", "#eb6834"
PW, PH, GAP_X, GAP_Y, LEFT, TOP = 330, 190, 64, 74, 70, 140
ROWS = [
    ("Speed across the water, studs a second", lambda t, l, a, e: old_speed(t, l, a, e), lambda t, l, a, e: new_speed(t, l, a, e)),
    ("Height above where you left, studs (open water: the sea floor stops the fall sooner)", lambda t, l, a, e: old_height(t, e), lambda t, l, a, e: new_height(t, e)),
    ("The hook's reach, studs", lambda t, l, a, e: J["OldRange"], lambda t, l, a, e: reach_of(new_speed(t, l, a, e))),
]
YRANGE = [(0, 240, 60), (-60, 30, 30), (0, 200, 50)]
TMAX = 4.0


def draw(out: Path):
    width = LEFT + 3 * PW + 2 * GAP_X + 30
    height = TOP + 3 * PH + 2 * GAP_Y + 60
    s = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="DejaVu Sans, Arial, sans-serif">',
        f'<rect width="{width}" height="{height}" fill="{SURFACE}"/>',
        f'<text x="{LEFT - 44}" y="34" font-size="20" font-weight="bold" fill="{INK}">The hop, before and after 2026-11-13: fast, then a stall, then a fall</text>',
        f'<line x1="{LEFT - 44}" y1="60" x2="{LEFT - 16}" y2="60" stroke="{NEW}" stroke-width="3"/><text x="{LEFT - 10}" y="65" font-size="14" fill="{INK}">after (Config.hopSpeed, hopSink, reachOf)</text>',
        f'<line x1="{LEFT + 300}" y1="60" x2="{LEFT + 328}" y2="60" stroke="{OLD}" stroke-width="3" stroke-dasharray="7 4"/><text x="{LEFT + 334}" y="65" font-size="14" fill="{INK}">before (commit 484d9e3)</text>',
        f'<text x="{LEFT - 44}" y="86" font-size="13" fill="{INK2}">shaded: the stall (Jump.StallTime). Curves end where the window does.</text>',
    ]
    for row, (title, old_f, new_f) in enumerate(ROWS):
        y0 = TOP + row * (PH + GAP_Y)
        lo, hi, step = YRANGE[row]
        s.append(f'<text x="{LEFT - 44}" y="{y0 - 12}" font-size="14" font-weight="bold" fill="{INK}">{title}</text>')
        for col, (name, had) in enumerate(FISH):
            x0 = LEFT + col * (PW + GAP_X)
            launch, air, extra = hop_from(had)
            window = J["Window"] + extra
            fast_end = J["LaunchTime"] + J["FloatTime"] + extra
            px = lambda t: x0 + t / TMAX * PW
            py = lambda v: y0 + PH - (min(max(v, lo), hi) - lo) / (hi - lo) * PH
            s.append(f'<rect x="{px(fast_end):.1f}" y="{y0}" width="{px(fast_end + J["StallTime"]) - px(fast_end):.1f}" height="{PH}" fill="#f1efe8"/>')
            v = lo
            while v <= hi + 1e-6:
                s.append(f'<line x1="{x0}" y1="{py(v):.1f}" x2="{x0 + PW}" y2="{py(v):.1f}" stroke="{GRID}" stroke-width="1"/>')
                s.append(f'<text x="{x0 - 8}" y="{py(v) + 4:.1f}" font-size="11" text-anchor="end" fill="{INK2}">{v:g}</text>')
                v += step
            if lo < 0:
                s.append(f'<line x1="{x0}" y1="{py(0):.1f}" x2="{x0 + PW}" y2="{py(0):.1f}" stroke="{INK2}" stroke-width="1"/>')
            for tick in range(0, int(TMAX) + 1):
                s.append(f'<text x="{px(tick):.1f}" y="{y0 + PH + 16}" font-size="11" text-anchor="middle" fill="{INK2}">{tick} s</text>')
            if row == 0:
                s.append(f'<text x="{x0}" y="{y0 - 34}" font-size="13" font-weight="bold" fill="{INK2}">{name}</text>')
            for colour, f, dash in ((OLD, old_f, ' stroke-dasharray="7 4"'), (NEW, new_f, "")):
                pts = []
                n = int(window * 100)
                for i in range(n + 1):
                    t = i / 100
                    pts.append(f"{px(t):.1f},{py(f(t, launch, air, extra)):.1f}")
                s.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{colour}" stroke-width="2.2" stroke-linejoin="round"{dash}/>')
                end = f(window, launch, air, extra)
                s.append(f'<circle cx="{px(window):.1f}" cy="{py(end):.1f}" r="4" fill="{colour}" stroke="{SURFACE}" stroke-width="2"/>')
                dy = -8 if (colour == OLD) == (old_f(window, launch, air, extra) >= new_f(window, launch, air, extra)) else 16
                s.append(f'<text x="{px(window) + 7:.1f}" y="{py(end) + dy:.1f}" font-size="11" fill="{INK}">{end:.0f}</text>')
    s.append("</svg>")
    svg = Path("/tmp") / (out.stem + ".svg")
    svg.write_text("\n".join(s))
    subprocess.run(["rsvg-convert", "-o", str(out), str(svg)], check=True)
    print(out)


if __name__ == "__main__":
    table()
    draw(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "docs/attachments/hop-air-curves.png")
