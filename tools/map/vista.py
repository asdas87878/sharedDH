"""The later lands as a far view from the hub, second draft (2026-11-18). The user, on the first draft
(tools/map/landmarks.py): it "almost stops, doesnt connote distance and looks more like a factory than an enticing
layer of mystical lands"; study Steal an Egg's distance view instead (its start looks down a long straight run where
each land reads as a band, and a small, glowing, mystical cluster sits at the vanishing point).

So here: every land along one sight line from the spawn through the gate, each a band of a few shapes in its own
colours, smaller and paler the further it is, and at the far end a small mystical hero: two dark spires leaning out in
a V round a glowing rift, a ring of floating rubble over it, a shaft of light. No smoke, no chimneys.

usage: python tools/map/vista.py [valley|frames|halo]   writes art/map/landmark_drafts/vista/<variant>/ (parts.json, path.json)
       GREYBOX_OUT=<abs path>/art/map/landmark_drafts/vista blender --background --python tools/blender/map_greybox_view.py -- vista,vista_back"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import landmarks as lm  # noqa: E402
import props  # noqa: E402

OUT = os.path.join(lm.OUT, "vista")
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "valley"
TIGHT = 0.22  # how far a land's pieces spread round its middle (1: as built)
SKY = os.environ.get("SKY") == "1"  # for tools/art/sky_vista.py: the far view alone, to paint into the sky
PLATEAU = 300  # the crown stands this high on its stepped plateau, clear of everything in front of it


def stack(k, x, z, w, h, tones, r, lean=0.0, yaw=0.0):
    """a sea stack of three or four blocks, each smaller and turned, the top in the light tone"""
    y, n = -10.0, 4
    for i in range(n):
        hh = h / n * r.uniform(0.85, 1.15)
        k.piece((x + r.uniform(-0.06, 0.06) * w, y + hh / 2, z), (w * (1 - 0.16 * i), hh, w * (1 - 0.16 * i) * 0.9), tones[min(i, len(tones) - 1)],
                lm.prism_axes(r.uniform(-20, 20) + yaw, lean * 0.3, lean, 0))
        y += hh


def reef_band(k, z, r):
    """land 2: warm coral stacks either side of the line, the nearest band"""
    for x, w, h in ((-300, 46, 110), (-240, 30, 70), (-380, 26, 60), (280, 50, 120), (350, 30, 80), (220, 22, 50)):
        stack(k, x, z + r.uniform(-60, 60), w, h, [(214, 104, 92), (240, 130, 120), (252, 176, 150), (255, 214, 170)], r, lean=r.uniform(-6, 6))


def kelp_band(k, z, r):
    """land 3: tall thin green spires, swaying apart"""
    for x, h, lean in ((-470, 230, -9), (-410, 170, -4), (-520, 150, -12), (430, 240, 8), (500, 180, 12), (380, 140, 4), (-150, 120, -5)):
        foot = (x, -10, z + r.uniform(-80, 80))
        for i in range(5):
            c = ((60, 140, 96), (76, 160, 104), (96, 182, 116), (126, 204, 132), (170, 230, 160))[i]
            foot = k.beam(foot, 26 - 3 * i, h / 5, c, spin=r.uniform(0, 30), roll=lean + i * lean * 0.25)


def wreck_band(k, z, r):
    """land 4: a great broken mast and a bow rising out of the water, far off to one side"""
    t = k.beam((330, -10, z), 22, 300, (120, 104, 92), spin=0, roll=-14)
    k.beam((t[0] - 60, t[1] - 90, t[2]), 12, 150, (140, 122, 106), spin=0, roll=76)
    k.beam((240, -10, z + 60), 60, 120, (106, 92, 84), spin=10, roll=24, pitch=-10)


def ice_band(k, z, r):
    """land 6 or 7: slanted crystals in two clusters leaning outward, a V with the line between"""
    tones = [(110, 104, 190), (150, 150, 226), (200, 212, 250), (236, 248, 255)]
    for side in (-1, 1):
        for dx, w, h, dl in ((0, 64, 520, 0), (-90, 44, 360, -5), (80, 40, 300, 6), (-160, 28, 200, 9), (150, 26, 180, -7)):
            lm.crystal(k, (side * (300 + dx), -20, z + r.uniform(-90, 90)), w, h, 0, 0, tones)
            # lean outward: rebuild the last four pieces leaned (crystal() takes lean as pitch; here a roll is wanted)
            del k.b[-4:]
            t = k.beam((side * (300 + dx), -20, z), w, h * 0.45, tones[0], roll=side * (10 + dl * 0.5))
            t = k.beam(t, w * 0.92, h * 0.35, tones[1], roll=side * (10 + dl * 0.5))
            t = k.beam(t, w * 0.7, h * 0.14, tones[2], roll=side * (10 + dl * 0.5))
            k.beam(t, w * 0.38, h * 0.08, (190, 240, 255), roll=side * (10 + dl * 0.5), kind="vglow")


def vents_band(k, z, r):
    """land 8: warm rust rock stacks with glowing orange crowns, the last warm colour before the cosmic end"""
    for x, w, h in ((-300, 60, 260), (-380, 40, 170), (-230, 34, 130), (310, 64, 280), (390, 40, 180), (240, 30, 120)):
        stack(k, x, z + r.uniform(-60, 60), w, h, [(122, 52, 44), (160, 72, 52), (200, 98, 60), (236, 130, 70)], r, lean=r.uniform(-5, 5))
        k.piece((x, h - 2, z), (w * 0.5, 14, w * 0.5), (255, 150, 70), lm.prism_axes(45, 0, 0, 0), "vglow")


def bones_band(k, z, r):
    """land 9: pale ribs arching out of the sea either side"""
    for side in (-1, 1):
        lm.rib_arch(k, side * 330, z, 0.55, r)


def hero(k, z, r):
    """the end, as a crown on the vanishing point: a symmetric gate on the axis with a glowing rift in it, ranks of
    dark spires either side stepping down outward and leaning in, gate after gate in front (shrinking repeats read as
    distance), a ring of floating rubble over it and one thin beam you can see from the start; behind it the land's
    own sky, a dark starfield that starts at its border"""
    dark, rim, glow = (34, 22, 72), (70, 50, 130), (255, 130, 240)
    for side in (-1, 1):  # the gate's pillars and the ranks of spires
        k.piece((side * 120, 330, z), (70, 700, 70), dark, lm.prism_axes(45, 0, 0, 0), "vglow")
        k.piece((side * 120, 700, z), (40, 60, 40), glow, lm.prism_axes(45, 0, 0, 0), "vglow")
        for j, (dx, h) in enumerate(((230, 620), (330, 500), (420, 400), (500, 300))):
            t = k.beam((side * dx, -20, z + 40 * j), 60 - 8 * j, h, dark if j % 2 == 0 else rim, spin=45, roll=side * (6 + 4 * j), kind="vglow")
            k.beam(t, 22 - 3 * j, 50, glow, spin=45, roll=side * (6 + 4 * j), kind="vglow")
    k.piece((0, 700, z), (300, 50, 60), rim, lm.prism_axes(0, 0, 0, 0), "vglow")  # the lintel
    k.piece((0, 330, z), (120, 640, 20), glow, lm.prism_axes(0, 0, 0, 0), "vglow")  # the rift
    k.piece((0, 330, z + 1), (50, 580, 24), (190, 250, 255), lm.prism_axes(0, 0, 0, 0), "vglow")
    for j in range(4):  # gates in front of it, shrinking toward it
        zz, f = z - 300 - 260 * j, 0.55 - 0.08 * j
        for side in (-1, 1):
            k.piece((side * 135, 280 * f, zz), (34, 560 * f, 34), rim, lm.prism_axes(45, 0, 0, 0), "vglow")
        k.piece((0, 560 * f, zz), (300, 26, 30), glow if j % 2 == 0 else rim, lm.prism_axes(0, 0, 0, 0), "vglow")
    if VARIANT != "blackhole":  # (there the hole's own jet is the beam)
        k.piece((0, 2400, z), (18, 3400, 18), (190, 230, 255), lm.prism_axes(0, 0, 0, 0), "vglow")  # the beam
    # (its own sky, the starfield, is a separate step: the user, 2026-11-18, 'get rid of the darkening sky for now')


def spike(k, foot, w, h, lean, tones, r):
    """a tall spiky peak: five tapering segments, leaning in toward the sight line, lighter toward the tip"""
    t = foot
    for i, (f, wf) in enumerate(((0.32, 1.0), (0.25, 0.72), (0.19, 0.5), (0.14, 0.32), (0.1, 0.16))):  # tapering to a point
        t = k.beam(t, w * wf, h * f, tones[min(i, len(tones) - 1)], spin=45 + r.uniform(-8, 8), roll=lean * (1 + 0.15 * i), kind="vglow")


def mountain(k, x, z, w, h, tones, r):
    """a stepped mountain: four or five blocks turned to show an edge, each narrower, the top one lighter"""
    y, n = -20.0, 5
    for i in range(n):
        hh = h / n * r.uniform(0.9, 1.1)
        ww = w * (1 - 0.18 * i)
        k.piece((x + r.uniform(-0.04, 0.04) * w, y + hh / 2, z), (ww, hh, ww * 0.8), tones[min(i, len(tones) - 1)], lm.prism_axes(45 + r.uniform(-10, 10), 0, 0, 0), "vglow")
        y += hh


def peak(k, x, z, h, tones, r, wide=1.0, flat=0.5):
    """a mountain as peaks, not steps: a block turned 45 degrees in the view's plane so it points up, sunk so its
    peak stands h over the sea, with a lower shoulder either side and a lighter cap on the main peak"""
    def diamond(cx, top, size, c):
        # a square turned 45 degrees, then squashed in height: the sides slope at about atan(flat), not 45 degrees
        d = size / math.sqrt(2)
        for i in range(1):
            k.piece((cx, top - d * flat, z + r.uniform(-30, 30)), (size, size, 40), c, tuple(tuple(v * (flat if n == 1 else 1) for n, v in enumerate(a)) for a in lm.prism_axes(0, 0, 45, 0)), "vglow")
    size = h / flat * math.sqrt(2) * 0.9 * wide
    diamond(x, h, size, tones[0])
    for sx in (-1, 1):
        diamond(x + sx * size * r.uniform(0.38, 0.5), h * r.uniform(0.55, 0.72), size * r.uniform(0.55, 0.7), tones[1])
    diamond(x, h, size * 0.3, tones[-1])


def mesa(k, x, z, w, h, face, cap, r, side, steps=3, shard=None):
    """a far mountain built like our walls: square blocks stepping up away from the sight line, each with a lighter cap,
    and a slanted shard leaning on its inner edge (the user: "more like the walls, squarer in shape maybe framed with
    some slanted shapes")"""
    y = -20.0
    for i in range(steps):
        ww, hh = w * (1 - 0.26 * i), h / steps * r.uniform(0.92, 1.08)
        cx = x + side * w * 0.13 * i  # each step sits further out, so the outline climbs away from the middle
        k.piece((cx, y + hh / 2, z), (ww, hh, ww * 0.6), face, lm.prism_axes(0, 0, 0, 0), "vglow")
        k.piece((cx, y + hh + 5, z - 2), (ww + 10, 12, ww * 0.6 + 6), cap, lm.prism_axes(0, 0, 0, 0), "vglow")
        y += hh
    if shard:
        k.beam((x - side * w * 0.48, -20, z - 40), w * 0.14, h * 0.95, shard, spin=45, roll=side * 13, kind="vglow")


def backdrop(k, r):
    """the far ground either side of the crown: square stepped mesas like our walls, lower near the middle and taller
    further out, so the outline climbs from the crown out to the walls in steps and funnels the eye back; slanted
    shards and spikes lean in to frame it. Mirrored side to side with a little jitter, in cool flat colours, paler the
    further off."""
    near = ((86, 116, 164), (128, 166, 202))
    far = ((112, 140, 186), (150, 182, 214))
    shard = (76, 84, 156)
    peaks = [(48, 40, 104), (58, 50, 120), (70, 62, 138), (86, 80, 160), (120, 116, 200)]
    for side in (-1, 1):
        j = lambda v, f=0.06: v * r.uniform(1 - f, 1 + f)  # noqa: E731
        for x, z, w, h in ((760, 7700, 380, 460), (1120, 8000, 480, 640), (1560, 7900, 560, 840), (2100, 8300, 660, 1060)):
            mesa(k, side * j(x), j(z, 0.02), j(w), j(h), *near, r, side, shard=shard)
        for x, z, w, h in ((1500, 9700, 760, 640), (2500, 9900, 900, 900)):
            mesa(k, side * j(x), j(z, 0.02), j(w), j(h), *far, r, side, steps=2)
        for x, z, w, h, lean in ((620, 6900, 210, 1350, 5), (880, 7300, 190, 980, 7), (1180, 7000, 150, 680, 9)):  # spikes, leaning in
            spike(k, (side * j(x), -20, j(z, 0.03)), j(w), j(h), side * lean, peaks, r)


def _smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _ramp(x):
    """the game's colour ramp for the hole (src/client/Lib/BlackHole.luau, ramp): ember, orange, yellow, white, then
    blue-white when shifted toward the viewer; x from 0 to about 1.6"""
    a = _smooth(0, 0.36, x)
    rr, g, b = 0.30 + 0.70 * a, 0.015 + 0.245 * a, 0.02 * a
    a = _smooth(0.30, 0.62, x)
    rr, g, b = rr + (1.0 - rr) * a, g + (0.68 - g) * a, b + (0.22 - b) * a
    a = _smooth(0.56, 0.92, x)
    rr, g, b = rr + (1.0 - rr) * a, g + (0.94 - g) * a, b + (0.84 - b) * a
    a = _smooth(0.98, 1.55, x)
    return rr + (0.70 - rr) * a, g + (0.83 - g) * a, b + (1.0 - b) * a


def _ramp_cosmic(x):
    """the same ramp moved to cosmic colours for the far view (the user, 2026-11-18: "more cosmic purple like stuff
    instead of the orange red"): near-black violet, purple, magenta, pink-white, and cyan-white on the side turning
    toward the viewer"""
    stops = ((0.0, (0.08, 0.02, 0.16)), (0.3, (0.36, 0.08, 0.58)), (0.62, (0.78, 0.24, 0.88)), (0.95, (1.0, 0.70, 0.98)), (1.5, (0.72, 0.96, 1.0)))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if x <= b:
            t = _smooth(a, b, x)
            return tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3))
    return stops[-1][1]


def black_hole(k, centre, rs, r, jet_up=40.0, jet_down=9.0, cosmic=True):
    """a still frame of the game's voxel black hole (Lib/BlackHole), scaled up: one horizon radius = rs studs, cubes
    0.236 of that (the game's Voxel / Scale), the ball 2.6 across its radius, the disc from 3 to 9.4 in the hole's
    level plane, brighter and whiter on the side turning toward the viewer, the far side's light bent up over the
    ball into an arc and a faint one under it, a thin bright photon ring, and the jets up and down as dotted
    white-blue cubes (the beam). Roblox can't bend light: the game moves the cubes to where bent light shows them,
    by where the camera is; this mock does the same once, for the view from the spawn."""
    cx, cy, cz = centre
    vox = 0.236 * rs

    ramp = _ramp_cosmic if cosmic else _ramp
    # dark lanes and clumps in the disc (the user: "it lacks its variety of colour and darker spots in the ring"):
    # a few clouds of cooler, darker gas lying across it, which also break its outline from far off
    clumps = [(r.uniform(0, math.tau), r.uniform(3.5, 9.0), r.uniform(0.25, 0.55), r.uniform(0.6, 1.4)) for _ in range(14)]

    def colour(heat, bright):
        c = ramp(heat)
        f = min(1.0, 0.38 + bright * 1.6)  # most of it bright; the dark clumps below give the dark spots
        q = lambda v: int(round(v * f * 255 / 12)) * 12  # noqa: E731 (a few steps, so few materials)
        return (min(255, q(c[0])), min(255, q(c[1])), min(255, q(c[2])))

    def cube(x, y, z, c, size=1.0):
        k.piece((cx + x * rs, cy + y * rs, cz + z * rs), (vox * size,) * 3, c, lm.prism_axes(0, 0, 0, 0), "vglow")

    for i in range(2400):  # the disc and its bent images
        rad = 3 + (9.4 - 3) * r.random() ** 1.6
        ph = r.uniform(0, math.tau)
        x, z = rad * math.cos(ph), rad * math.sin(ph)
        y = r.uniform(-1, 1) * (0.05 + 0.03 * rad)
        beta = 0.42 * math.sqrt(3 / rad)
        doppler = math.sqrt(1 - beta * beta) / (1 - beta * -math.sin(ph))  # the side moving toward the camera (-z) is brighter
        temp = (3 / rad) ** 0.75
        streak = 0.6 + 0.3 * math.sin(2 * ph + 4.5 * math.log(rad)) + 0.3 * (r.random() - 0.5)
        heat = 0.9 * temp * doppler * math.sqrt(1 - 1 / rad) / 0.8165
        bright = temp ** 1.5 * doppler ** 3 * max(streak, 0.07) * (1 - 0.7 * _smooth(7.5, 9.4, rad))
        for cph, crad, cw, cr in clumps:
            dph = (ph - cph + math.pi) % math.tau - math.pi
            if (dph / cw) ** 2 + ((rad - crad) / cr) ** 2 < 1:
                bright *= 0.05
                heat *= 0.3
        heat = heat + 0.12 + r.uniform(-0.2, 0.2)  # hotter overall in the cosmic ramp, and a little grain cube to cube
        if bright < 0.006:
            continue
        c = colour(heat, bright)
        if z < 0:  # the near half: seen as it is
            cube(x, y, z, c)
        else:  # the far half: its light bent up over the ball (first image) and a faint flipped one under it
            rho = math.hypot(x, y) or 0.01
            e = 2.8 * math.sqrt(min(1.0, z / 9.4))
            for sign, fade in ((1, 1.0), (-1, 0.45)):
                rr = (rho + sign * math.sqrt(rho * rho + 4 * e * e)) / 2
                if sign < 0 and i % 3:
                    continue
                ux, uy = x / rho, (y + (0.6 if sign > 0 else -0.6) * e) / rho
                n = math.hypot(ux, uy)
                px, py = ux / n * abs(rr), uy / n * abs(rr) * (1 if sign > 0 else -1)
                if math.hypot(px, py) > 2.75:
                    cube(px if sign > 0 else -px * 0.9, abs(py) * (1 if sign > 0 else -1), -3.2, colour(heat, bright * fade))
    rows = int(2 * 2.6 / 0.236)
    for j in range(rows):  # the ball: black strips facing the camera
        yy = -2.6 + (j + 0.5) * 0.236
        half = math.sqrt(max(0.0, 2.6 * 2.6 - yy * yy))
        k.piece((cx, cy + yy * rs, cz - 3.0 * rs), (2 * half * rs, vox, vox), (0, 0, 0), lm.prism_axes(0, 0, 0, 0), "vglow")
    for j in range(140):  # the photon ring, face on
        a = j / 140 * math.tau
        cube(2.66 * math.cos(a), 2.66 * math.sin(a), -3.1, colour(1.05 * (1 + 0.4 * math.cos(a)) + r.uniform(-0.15, 0.15), 0.8 * r.uniform(0.4, 1.0)))
    for length, sign in ((jet_up, 1), (jet_down, -1)):  # the jets
        for j in range(int(length * 9)):
            h = r.uniform(0, length)
            out = (0.14 + 0.04 * min(h, 13)) * math.sqrt(r.random())
            a = r.uniform(0, math.tau)
            c = (236, 226, 255) if r.random() < 0.6 else ((190, 150, 255) if r.random() < 0.6 else (150, 220, 255))  # white, lavender, cyan
            cube(out * math.cos(a), sign * (2.75 + h), out * math.sin(a) - 3.0, c, 0.8)


def focus(k, z, variant, r):
    """three ways to make the far middle read as designed (the user: "make the focus of it ... look more intentionally
    designed like it follows the countor better and visually digests infomration better for the eyes"):
      valley   a stepped dais under the gate, a clean ring in place of the scattered rubble, nothing in front of it
      frames   valley + two pairs of big slanted slabs nested round the gate, leaning out at the spires' angles, so
               the outline closes round the gate like brackets, dark to light outward
      halo     valley + one big clean ring of blocks standing behind the gate, a pale glow, centred on the beam"""
    stone, top = (64, 70, 124), (110, 120, 180)
    for i, (w, h) in enumerate(((1200, 100), (920, 100), (660, 100))):  # the plateau the crown stands on, in steps like our walls
        y = -20 + i * h
        k.piece((0, y + h / 2, z - 220 + i * 60), (w, h, 300), stone, lm.prism_axes(0, 0, 0, 0), "vglow")
        k.piece((0, y + h + 5, z - 220 + i * 60), (w + 10, 10, 306), top, lm.prism_axes(0, 0, 0, 0), "vglow")
    lift = PLATEAU
    if variant == "blackhole":  # A valley, with the game's black hole in place of the ring and its jets as the beam
        black_hole(k, (0, lift + 1150, z), 72, r, jet_up=26, jet_down=(1150 - 700) / 72 - 2.75)
    if variant in ("valley", "frames"):
        for j in range(20):  # the ring over the gate, even and level: one clean shape, not a scatter
            a = j / 20 * math.tau
            k.piece((math.cos(a) * 260, 980 + lift + math.sin(a) * 70, z + math.sin(a) * 60), (46, 30, 40), (70, 50, 130) if j % 2 else (255, 140, 240), lm.prism_axes(0, 0, 0, 0), "vglow")
    if variant == "frames":
        for side in (-1, 1):
            for dx, h, lean, c in ((290, 900, 18, (96, 126, 186)), (450, 720, 28, (126, 156, 206))):  # lighter than the spires, darker than the sky
                k.beam((side * dx, lift - 20, z + 80), 90, h, c, spin=0, roll=-side * lean, kind="vglow")
    if variant == "halo":
        for j in range(32):
            a = j / 32 * math.tau
            k.piece((math.cos(a) * 560, 560 + lift + math.sin(a) * 560, z + 260), (90, 90, 30), (150, 210, 255) if j % 4 else (255, 160, 240), lm.prism_axes(0, 0, math.degrees(a), 0), "vglow")


ISLAND = {"reef_band": ((214, 120, 108), (240, 170, 150)), "kelp_band": ((80, 128, 88), (130, 180, 120)),
          "wreck_band": ((120, 104, 90), (170, 150, 126)), "ice_band": ((100, 96, 180), (170, 170, 230)),
          "vents_band": ((140, 62, 52), (230, 130, 80)), "bones_band": ((186, 178, 156), (232, 226, 206))}  # (face, cap)

HAZE_C = (176, 198, 214)  # what a far muted colour leans to: the far sky's
NEAR_C = (84, 102, 128)  # and a near one: a calm mid-dark blue, so the near lands sit back in value
MUTE = [0.5, 0.6, 0.7, 0.8, 0.88, 0.95]
WALL_H, WALL_LINE = 70.0, (230.0, 175.0)  # the far walls' height and where they stand across, near and far  # how much of each land's own colour shows, nearest first

BANDS = [(reef_band, 1250, 0.15, 0.075), (kelp_band, 2000, 0.135, 0.085), (wreck_band, 2800, 0.12, 0.095), (ice_band, 4300, 0.105, 0.105),
         (vents_band, 5300, 0.09, 0.115), (bones_band, 6200, 0.075, 0.125), (hero, 7300, None, None)]
# (builder, z, where its middle stands across the view, how high its top stands; both as a share of its distance from
# the spawn): each land a step further in and a step higher than the one before, both sides, so the lands stack as a
# stepped V into the crown and the colour builds land by land
# the lands in order, each in its own colours, so the colour builds from warm coral to cosmic violet (the user, 2026-11-18:
# 'what happened to the layering of like orange and different coloured stuff which built throughout the lands')
# (builder, z, squeeze toward the line, base, scale): rising out of the sea beyond our own walls (the user, 2026-11-18:
# keep our walls, don't copy their style); only what stands over the walls reads far; glow kept for the far lands;
# the near bands kept out to the sides so nothing stands in front of the crown


def main():
    parts = json.load(open(os.path.join(lm.SRC, "parts.json")))["parts"]
    path = json.load(open(os.path.join(lm.SRC, "path.json")))
    keep = [p for p in parts if -500 < p["p"][2] < 9000 and abs(p["p"][0]) < 3000 and p["k"] != "prop"]  # our own walls, as built
    if SKY:  # for the sky picture (2026-11-19): only the far view's own pieces, nothing of the map
        keep = []
    k = lm.K()
    backdrop(k, random.Random(123))
    focus(k, 7300, VARIANT, random.Random(5))
    for i, (fn, z, across, high) in enumerate(BANDS):
        band = lm.K()
        fn(band, z, random.Random(30 + i))
        if across is None:  # the crown: as built, on its plateau
            for c, sz, col, ax, kind in band.b:
                k.piece((c[0], c[1] + PLATEAU, c[2]), sz, col, ax, kind)
            continue
        top = max(c[1] + max(sz) / 2 for c, sz, col, ax, kind in band.b) + 10
        # the land as a wall run like ours (the user, 2026-11-18: the blocks "dont follow the curvy wall taper"): short
        # pieces along a curve that sways in and out and tapers in toward the end, carrying on from the land before;
        # its top steps up and down in whole steps; a neck (a gap) before the next land
        z1 = BANDS[i + 1][1] - 70
        nxt = BANDS[i + 1]
        a1, h1 = (nxt[2], nxt[3]) if nxt[2] is not None else (across * 0.8, high * 1.08)
        mute = MUTE[i]  # the near lands calm, the colour building further out (the user: the near one "too bright and vibrant too quickly")
        # muted toward a calm mid-dark blue near and toward the pale sky far, so the light values sit at the back (the
        # user, 2026-11-18: the bright land "so far forward is too overpowering ... that should be further back")
        toward = tuple(int(NEAR_C[j] + (HAZE_C[j] - NEAR_C[j]) * i / (len(MUTE) - 1)) for j in range(3))
        face, cap = (tuple(int(toward[j] + (c[j] - toward[j]) * mute) for j in range(3)) for c in ISLAND[fn.__name__])
        zz = z
        while zz < z1:  # our walls' build: one height (so the tops carry on our walls' taper to the vanishing point),
            # a gentle sway, whole steps up and down, and a taller tier set back behind
            seg = min(90.0, z1 - zz)
            zm = zz + seg / 2
            line = WALL_LINE[0] + (WALL_LINE[1] - WALL_LINE[0]) * (zm - 1250) / 6000
            steps = round(2 * math.sin(zm / 230 + 1.7 * i) + math.sin(zm / 97))
            hh = WALL_H + 16 * steps
            for side in (-1, 1):
                x = side * (line + 26 * math.sin(zm / 610 + i))
                xn = side * (line + 26 * math.sin((zm + seg) / 610 + i))
                yaw = math.degrees(math.atan2(xn - x, seg))
                for tier, (dx, hk, fc) in enumerate(((0, 1.0, 1.0), (54, 1.7, 0.86))):
                    tf = tuple(int(v * fc) for v in face)
                    k.piece((x + side * dx, -10 + hh * hk / 2, zm), (40, hh * hk, seg + 2), tf, lm.prism_axes(yaw, 0, 0, 0), "vglow")
                    k.piece((x + side * (dx - 3), -10 + hh * hk + 5, zm), (50, 10, seg + 4), cap, lm.prism_axes(yaw, 0, 0, 0), "vglow")
            zz += seg
        mean = sum(abs(c[0]) for c, sz, col, ax, kind in band.b) / len(band.b)
        zmid = z + 0.45 * (z1 - z)
        line = WALL_LINE[0] + (WALL_LINE[1] - WALL_LINE[0]) * (zmid - 1250) / 6000 + 54
        base = WALL_H * 1.7
        sc = 0.9 * WALL_H / top * (1 + 0.25 * i)  # a few of its shapes on its top tier, small, a little bigger further on
        for c, sz, col, ax, kind in band.b:
            side = 1 if c[0] >= 0 else -1
            col = tuple(int(toward[j] + (col[j] - toward[j]) * mute) for j in range(3))
            x = side * line + (c[0] - side * mean) * sc * TIGHT
            k.piece((x, (c[1] + 10) * sc - 10 + base, zmid + (c[2] - z) * sc * TIGHT), tuple(v * sc for v in sz), col, ax, kind)
    add = [{"n": "Vista", "k": kind, "p": [round(v, 2) for v in c], "x": list(ax[0]), "y": list(ax[1]), "z": list(ax[2]), "s": [round(v, 2) for v in sz],
            "c": list(col), "solid": False} for c, sz, col, ax, kind in k.b]
    if not SKY:
        add.append({"n": "FarSea", "k": "water", "p": [0, -1, 9000], "x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1], "s": [40000, 2, 20000], "c": [64, 190, 210], "solid": False})
    out = os.path.join(OUT, VARIANT + ("_sky" if SKY else ""))
    os.makedirs(out, exist_ok=True)
    json.dump({"parts": keep + add}, open(os.path.join(out, "parts.json"), "w"))
    json.dump(path, open(os.path.join(out, "path.json"), "w"))
    print(len(add), "vista pieces")


if __name__ == "__main__":
    main()
