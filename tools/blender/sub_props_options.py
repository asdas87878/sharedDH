"""Propeller options for the toy submarines: four better versions beside today's, as big stills and a spinning clip.

Options only: nothing here is in the game. The picked one goes into tools/blender/sub_stages.py's tail() later.

    python tools/blender/sub_props_options.py all [work folder]        everything below, in order (12 to 14 minutes)
    python tools/blender/sub_props_options.py clip [work folder]       the clip and its check alone (about 10 minutes)
    blender --background --python tools/blender/sub_props_options.py -- gate <tier> <out folder>     no pictures
    blender --background --python tools/blender/sub_props_options.py -- stills <tier> <out folder> [--only 0,2]
    blender --background --python tools/blender/sub_props_options.py -- frames <tier> <out folder> [--range 0,360] [--blur 0.2]
    blender --background --python tools/blender/sub_props_options.py -- encode <frames folder> <out.mp4>
    blender --background --python tools/blender/sub_props_options.py -- decode <clip.mp4> <out folder> [--check angles.json]
    python tools/blender/sub_props_options.py sheet <stills folder> <out.png>
    python tools/blender/sub_props_options.py overlay <frames folder> <out folder>
    python tools/blender/sub_props_options.py strips <decoded folder> <out.png>

How it reaches the subs: sub_stages.py builds and renders as it is read, so this runs its source up to where the build
starts (its builders, colours and gate, unchanged) and swaps the propeller's pieces in tail(). sub_stages.py is not
edited. Axes as there: X runs nose (-X) to tail, Z is up, 1 unit = 1 stud; the game gets (y, z, x).

What a propeller must keep (docs/design/sub-models.md): the parts are named Prop and Prop_Glow (tiers 6 to 9: the
glowing hub); each part's box is centred on the hub's line, because the game turns a part about its box's middle
(tools/subs/install.py puts each mesh's box middle at the part's place), so a wheel of three or five blades, whose box
is not centred by itself, carries a thin dark backing plate with corners on the four axes; the blades stay inside the
red guard ring; no flat face lies closer than a tenth of a stud to the ring's dark disc (the gate does not compare the
propeller with the hull).

The turn (SubController.place): the part turns about its own +Z, the sub's tail end, by a growing angle, which seen from
behind is anticlockwise. TURN is that; the blades' pitch follows it, so the leading edge is the forward one.

The turn rule drawn in the clip is the proposal of docs/design/sub-props.md (RULE below), beside today's."""
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
NAMES = ["NOW", "FAT PADDLES", "SCIMITARS", "TOY FAN", "SCREW"]
ABOUT = ["three flat bars: six arms, no twist", "three fat twisted paddles", "four swept, curved blades",
         "five rounded petals", "two fat flights round a nose cone"]
BLADES = [6, 3, 4, 5, 2]  # how many times the wheel looks the same in one turn
TURN = 1  # +1: anticlockwise seen from behind, as the game turns it
FPS = 60

# ---- the proposed turn rule (docs/design/sub-props.md), and today's
RULE = {
    "Idle": 4.0,  # radians a second with the sub standing: 0.64 turns a second (today's own number)
    "PerSpeed": 0.04,  # and this much more for every stud a second (today: 0.12)
    "StepShare": 0.25,  # the most it turns in one frame, as a share of the gap between two blades
    "StepMost": 30.0,  # and never more than this, degrees
    "BlurFrom": 150.0,  # the blur disc starts to show at this speed, studs a second
    "BlurFull": 450.0,  # and is fullest from this speed
    "BlurMost": 0.2,  # how solid it gets (Transparency 1 - this)
}
TOP = 4315.0  # the fastest trip's top speed (to land 10), studs a second
LOW_TOP = 464.0  # the top speed of the trip to land 2 (docs/design/sub-models.md): the only trip tier 1's sub makes


def step_most(blades):
    return min(RULE["StepShare"] * 360.0 / blades, RULE["StepMost"])


def turn_new(speed, dt, blades):
    """degrees turned this frame by the proposed rule, and how solid the blur disc is"""
    rate = RULE["Idle"] + RULE["PerSpeed"] * speed
    u = min(max((speed - RULE["BlurFrom"]) / (RULE["BlurFull"] - RULE["BlurFrom"]), 0.0), 1.0)
    return min(math.degrees(rate * dt), step_most(blades)), RULE["BlurMost"] * u * u * (3 - 2 * u)


def turn_now(speed, dt):
    return math.degrees((4 + 0.12 * speed) * dt)


def speed_at(t):
    """the clip's speed: a second at the dock, four seconds rising (each second about 4.6 times faster, so the slow
    end is not over in a blink), a second at the top"""
    if t < 1.0:
        return 0.0
    return min(TOP, 10.0 * (TOP / 10.0) ** ((t - 1.0) / 4.0))


def blender_part():
    import bmesh
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Matrix, Vector

    argv = sys.argv[sys.argv.index("--") + 1:]
    mode = argv[0]

    def flag(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default

    # ------------------------------------------------------------------------------------------ video in and out
    def video_scene(w, h):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = w, h, 100
        scene.render.fps, scene.render.fps_base = FPS, 1.0
        scene.view_settings.view_transform = "Standard"
        scene.sequence_editor_create()
        return scene, scene.sequence_editor

    if mode == "encode":
        src, out = argv[1], argv[2]
        names = sorted(n for n in os.listdir(src) if n.endswith(".png"))
        first = bpy.data.images.load(os.path.join(src, names[0]))
        scene, se = video_scene(*first.size)
        strips = se.strips if hasattr(se, "strips") else se.sequences
        strip = strips.new_image("frames", os.path.join(src, names[0]), 1, 1)
        for n in names[1:]:
            strip.elements.append(n)
        scene.frame_start, scene.frame_end = 1, len(names)
        im = scene.render.image_settings
        if hasattr(im, "media_type"):
            im.media_type = "VIDEO"
        im.file_format = "FFMPEG"
        ff = scene.render.ffmpeg
        ff.format, ff.codec = "MPEG4", "H264"
        ff.constant_rate_factor = flag("--crf", "HIGH")
        ff.ffmpeg_preset = "GOOD"
        ff.gopsize = 30
        ff.audio_codec = "NONE"
        scene.render.filepath = out
        scene.render.use_file_extension = False
        bpy.ops.render.render(animation=True)
        print("props: wrote %s, %d frames at %d a second, %.2f MB" % (out, len(names), FPS, os.path.getsize(out) / 1e6))
        return

    if mode == "decode":
        import numpy as np

        clip, out = argv[1], argv[2]
        os.makedirs(out, exist_ok=True)
        scene, se = video_scene(1920, 1080)
        strips = se.strips if hasattr(se, "strips") else se.sequences
        strip = strips.new_movie("clip", clip, 1, 1)
        el = strip.elements[0]
        scene.render.resolution_x, scene.render.resolution_y = el.orig_width, el.orig_height
        n = strip.frame_final_duration
        fps = el.orig_fps if hasattr(el, "orig_fps") else None
        scene.frame_start, scene.frame_end = 1, n
        im = scene.render.image_settings
        if hasattr(im, "media_type"):
            im.media_type = "IMAGE"
        im.file_format, im.color_mode, im.compression = "PNG", "RGB", 15
        scene.render.filepath = os.path.join(out, "f")
        bpy.ops.render.render(animation=True)
        print("props: %s: %d frames, %s a second, %d x %d, %.1f s, %.2f MB" % (
            clip, n, fps, el.orig_width, el.orig_height, n / (fps or FPS), os.path.getsize(clip) / 1e6))
        log = flag("--check")
        if not log:
            return
        # ---- frame by frame, from the clip itself: where each wheel's blades are, against where they were turned to
        truth = json.load(open(log))
        tiles = truth["tiles"]
        seen = {t["key"]: [] for t in tiles}
        for f in range(n):
            img = bpy.data.images.load(os.path.join(out, "f%04d.png" % (f + 1)))
            w, h = img.size
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            bpy.data.images.remove(img)
            px = px.reshape(h, w, 4)[::-1]  # the top row first
            for t in tiles:
                cx, cy = t["hub"]
                half = int(t["reach_px"] * 1.25)
                crop = px[cy - half:cy + half, cx - half:cx + half, :3]
                ys, xs = np.mgrid[-half:half, -half:half]
                # a pixel back to the propeller's plane (the camera's right and up, as the frames step drew it)
                (a, b), (c, d) = t["plane"]
                det = a * d - b * c
                y = (d * xs - b * (-ys)) / det
                z = (-c * xs + a * (-ys)) / det
                r = np.hypot(y, z)
                th = np.arctan2(z, y)
                red, green, blue = crop[..., 0], crop[..., 1], crop[..., 2]
                mark = (red > 0.55) & (green < 0.72 * red) & (blue < 0.72 * red)
                # the blades' own white only: the blur disc hazes the dark disc up to 0.81, a lit blade is over 0.94
                bright = (red > 0.88) & (green > 0.86) & (blue > 0.78)
                ring = (r > t["lo"]) & (r < t["hi"])
                if t["marked"]:
                    m = mark & ring
                    k = 1
                else:
                    m = (bright | mark) & ring
                    k = t["blades"]
                if m.sum() < 30:
                    seen[t["key"]].append(None)
                    continue
                seen[t["key"]].append(math.degrees(math.atan2(np.sin(k * th[m]).sum(), np.cos(k * th[m]).sum())) / k)
        report = {"frames": n, "fps": fps, "tiles": {}}
        ok = True
        for t in tiles:
            got, want = seen[t["key"]], truth["angles"][t["key"]]
            gap = 360.0 / (1 if t["marked"] else t["blades"])
            steps, drawn, lost = [], [], 0
            for f in range(1, n):
                if got[f] is None or got[f - 1] is None:
                    lost += 1
                    continue
                steps.append(((got[f] - got[f - 1] + gap / 2) % gap) - gap / 2)  # the turn as the eye takes it
                drawn.append(want[f] - want[f - 1])
            off = max(abs(s - d) for s, d in zip(steps, drawn)) if steps else None
            # how far the blade seen ever is from where it was turned to, the steps added up: a frame that aliased
            # would leave it a whole gap out for good. A step alone can be out with nothing wrong (the screw's
            # coloured flight is a spiral on a cone seen from one side, so its middle doesn't travel evenly).
            drift, run = 0.0, 0.0
            for a, b in zip(steps, drawn):
                run += a - b
                drift = max(drift, abs(run))
            back = sum(1 for s in steps if s < -0.5)
            still = sum(1 for s in steps if abs(s) < 0.5)
            row = {"lost": lost, "backwards": back, "still": still, "seen_least": min(steps), "seen_most": max(steps),
                   "drawn_least": min(drawn), "drawn_most": max(drawn), "furthest_from_drawn": off, "drift": drift, "judged": t["judged"]}
            report["tiles"][t["key"]] = row
            row["steps_seen"] = [round(v, 1) for v in steps]
            row["steps_drawn"] = [round(v, 1) for v in drawn]
            bad = t["judged"] and (back or still or lost > n // 20 or off is None or drift > min(30.0, gap / 4))
            ok = ok and not bad
            print("props: %-14s seen %6.1f to %6.1f deg a frame (drawn %6.1f to %6.1f); backwards on %3d frames, still on "
                  "%3d, unread %3d; one step furthest from drawn %.1f, the blade never more than %.1f from its place%s" % (
                      t["key"], row["seen_least"], row["seen_most"], row["drawn_least"], row["drawn_most"], back, still,
                      lost, off or -1, drift, "" if t["judged"] else "   (today's rule: shown as proof, not judged)"))
            if bad:
                print("  ! %s does not read as one steady turn" % t["key"])
        report["ok"] = ok
        json.dump(report, open(os.path.join(out, "check.json"), "w"), indent=1)
        print("props: the clip's check %s" % ("passes" if ok else "FAILS"))
        sys.exit(0 if ok else 1)

    # ------------------------------------------------------------------------------------------ the sub's builders
    tier, out = int(argv[1]), argv[2]
    os.makedirs(out, exist_ok=True)
    path = os.path.join(HERE, "sub_stages.py")
    src = open(path, encoding="utf-8").read()
    marker = '\ndropped = 0\nif STYLE == "voxel":'
    assert marker in src, "sub_stages.py no longer has the line the build starts at"
    kept, sys.argv = sys.argv, ["blender", "--", str(tier), out, "--style", "toy"]
    S = {"__file__": path, "__name__": "sub_stages"}
    exec(compile(src[:src.index(marker)], path, "exec"), S)
    sys.argv = kept
    scene, PIECES, PALETTE, rgba = S["scene"], S["PIECES"], S["PALETTE"], S["rgba"]
    TAIL = {}
    real_tail = S["tail"]

    def tail(tx=16.6, az=0.7, ring=4.3, cross=(11.5, 12.5), blades="white", hub="trim+", glow=False, tips=None):
        TAIL.update(tx=tx, az=az, ring=ring, k=ring / 4.3, blades=blades, hub=hub, glow=glow, cross=cross)
        real_tail(tx=tx, az=az, ring=ring, cross=cross, blades=blades, hub=hub, glow=glow, tips=tips)

    S["tail"] = tail
    S["toy%d" % tier]()
    BODY_PIECES = [p for p in PIECES if not p["part"].startswith("Prop")]
    NOW_PIECES = [p for p in PIECES if p["part"].startswith("Prop")]
    tx, az, k = TAIL["tx"], TAIL["az"], TAIL["k"]
    HUB = Vector((tx, 0.0, az))
    DISC = tx + 0.95  # the dark disc's face
    FACE = DISC + 0.1  # nothing flat closer than this

    def dist(a, b):
        """how far apart two colours are, a difference in brightness counting most (that is what reads when small)"""
        light = [0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2] for c in (PALETTE[a], PALETTE[b])]
        return math.sqrt(sum((p - q) ** 2 for p, q in zip(PALETTE[a], PALETTE[b]))) + 2 * abs(light[0] - light[1])

    # one blade in the colour furthest from both the blades and the dark disc behind them
    MARK = max((c for c in ("ring", "white", "hull", "accent") if PALETTE[c] != PALETTE[TAIL["blades"]]),
               key=lambda c: min(dist(c, TAIL["blades"]), dist(c, "trim")))
    print("props: tier %d %s: blades %s %s, hub %s%s, one blade %s %s" % (
        tier, S["NAME"], TAIL["blades"], PALETTE[TAIL["blades"]], TAIL["hub"], " and a glowing ball" if TAIL["glow"] else "",
        MARK, PALETTE[MARK]))

    # ------------------------------------------------------------------------------------------ the pieces
    def frame(deg):
        a = math.radians(deg)
        return Vector((0, math.cos(a), math.sin(a))), Vector((0, -math.sin(a), math.cos(a))) * TURN

    EX = Vector((1, 0, 0))

    def blade(at, stations, colour, smooth=True):
        """a twisted blade at `at` degrees round the hub: at each station (how far out, chord, thickness, pitch in
        degrees from the wheel's plane, sweep in degrees against the turn, how far behind FACE its middle is) a
        four-cornered section. The leading edge is the forward one."""
        bm = S["piece"]("Prop", colour, smooth)
        rings = []
        for r, chord, thick, pitch, sweep, back in stations:
            er, et = frame(at - TURN * sweep)
            b = math.radians(pitch)
            along = et * math.cos(b) - EX * math.sin(b)
            across = et * math.sin(b) + EX * math.cos(b)
            c = HUB + EX * (FACE - tx + back * k) + er * (r * k)
            rings.append([bm.verts.new(c + along * (sa * chord * k / 2) + across * (sc * thick * k / 2))
                          for sa, sc in ((1, 1), (1, -1), (-1, -1), (-1, 1))])
        for a, z in zip(rings, rings[1:]):
            for i in range(4):
                bm.faces.new((a[i], z[i], z[(i + 1) % 4], a[(i + 1) % 4]))
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
        S["shut"](bm)

    def petal(at, outline, thick, pitch, back, colour):
        """a flat rounded blade tipped by `pitch`: outline as (how far out, how far to the leading side)"""
        bm = S["piece"]("Prop", colour, False)
        er, et = frame(at)
        b = math.radians(pitch)
        along = et * math.cos(b) - EX * math.sin(b)
        across = et * math.sin(b) + EX * math.cos(b)
        c = HUB + EX * (FACE - tx + back * k)
        lo = [bm.verts.new(c + er * (r * k) + along * (s * k) - across * (thick * k / 2)) for r, s in outline]
        hi = [bm.verts.new(c + er * (r * k) + along * (s * k) + across * (thick * k / 2)) for r, s in outline]
        bm.faces.new(lo)
        bm.faces.new(list(reversed(hi)))
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bm.faces.new((lo[i], hi[i], hi[j], lo[j]))
        S["shut"](bm)

    def flight(at, sweep, x0, x1, inner, outer0, outer1, thick, colour, n=7):
        """a screw's flight: a fat ribbon wound `sweep` degrees round the cone, from x0 (leading, forward) to x1"""
        bm = S["piece"]("Prop", colour, True)
        rings = []
        for i in range(n):
            u = i / (n - 1)
            er, _ = frame(at - TURN * sweep * u)
            x = x0 + (x1 - x0) * u
            r_out = outer0 + (outer1 - outer0) * u ** 1.4
            if i in (0, n - 1):
                r_out = inner + (r_out - inner) * 0.55  # blunt ends
            c = HUB + EX * (FACE - tx + x * k)
            rings.append([bm.verts.new(c + er * (r * k) + EX * (s * thick * k / 2))
                          for r, s in ((inner * (1 - 0.5 * u), -1), (r_out, -1), (r_out, 1), (inner * (1 - 0.5 * u), 1))])
        for a, z in zip(rings, rings[1:]):
            for i in range(4):
                bm.faces.new((a[i], z[i], z[(i + 1) % 4], a[(i + 1) % 4]))
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
        S["shut"](bm)

    def hub(length, r0, r1, n=8):
        """the hub: a blunt cone from inside the disc to `length` behind FACE; and the glowing ball on tiers 6 to 9"""
        x0, x1 = tx + 0.1, FACE + length * k
        S["cyl"]("Prop", ((x0 + x1) / 2, 0, az), r0 * k, x1 - x0, TAIL["hub"], axis="x", n=n, r2=r1 * k, smooth=False)
        if TAIL["glow"]:
            S["ball"]("Prop", (x1 + 0.15 * k, 0, az), 0.8 * k, "glow", u=8, v=4)

    def plate(reach):
        """the backing plate of a wheel with an odd count: thin, the disc's own dark colour, corners on the four axes
        at the blades' reach, so the part's box is centred on the hub whatever way the blades point"""
        S["cyl"]("Prop", (FACE + 0.06, 0, az), reach, 0.12, "trim", axis="x", n=8, smooth=False)

    def reach_of(pieces):
        return max(math.hypot(v.co.y, v.co.z - az) for p in pieces if p["part"] == "Prop" for v in p["bm"].verts)

    def colours(n):
        return [MARK] + [TAIL["blades"]] * (n - 1)

    def option(i):
        """the propeller's pieces for option i (0: today's), as the list of pieces"""
        if i == 0:
            return NOW_PIECES
        start = len(PIECES)
        if i == 1:  # fat paddles: narrow at the root, wide and round at the tip, twisted
            hub(2.0, 1.3, 0.85)
            st = [(0.5, 1.0, 0.85, 38, 0, 0.95), (1.6, 1.9, 0.8, 31, 0, 0.95), (2.8, 2.8, 0.7, 23, 0, 0.95),
                  (3.38, 1.5, 0.6, 20, 0, 0.95)]
            for j, c in enumerate(colours(3)):
                blade(90 + 120 * j, st, c)
        elif i == 2:  # scimitars: swept back against the turn, to a blunt point
            hub(1.9, 1.2, 0.7)
            st = [(0.5, 1.2, 0.75, 36, 0, 0.85), (1.6, 1.85, 0.7, 30, 12, 0.85), (2.7, 1.55, 0.6, 24, 35, 0.85),
                  (3.4, 0.5, 0.5, 20, 58, 0.85)]
            for j, c in enumerate(colours(4)):
                blade(100 + 90 * j, st, c)
        elif i == 3:  # the toy fan: five flat rounded petals, each tipped, on a fat hub
            hub(1.75, 1.55, 1.15)
            outline = [(0.7, -0.4), (2.3, -1.15), (3.25, -0.7), (3.38, 0.4), (2.5, 1.25), (0.7, 0.4)]
            for j, c in enumerate(colours(5)):
                petal(90 + 72 * j, outline, 0.6, 24, 0.8, c)
        elif i == 4:  # the screw: a long nose cone and two fat flights winding back along it
            x0, x1 = tx + 0.1, FACE + 3.3 * k
            S["cyl"]("Prop", ((x0 + x1) / 2, 0, az), 1.75 * k, x1 - x0, TAIL["hub"], axis="x", n=8, r2=0.5 * k, smooth=False)
            if TAIL["glow"]:
                S["ball"]("Prop", (x1 + 0.1 * k, 0, az), 0.8 * k, "glow", u=8, v=4)
            for j, c in enumerate(colours(2)):
                flight(90 + 180 * j, 205, 0.4, 2.7, 1.1, 3.4, 1.5, 0.75, c)
        made = PIECES[start:]
        del PIECES[start:]
        if BLADES[i] % 2:
            start = len(PIECES)
            plate(reach_of(made) + 0.04)
            made += PIECES[start:]
            del PIECES[start:]
        return made

    def gate(i, pieces):
        """the builder's own gate on the sub with this propeller, and what the gate does not look at"""
        PIECES[:] = BODY_PIECES + pieces
        faults = S["toy_check"]()
        tris, boxes = {}, {}
        for part in sorted({p["part"] for p in pieces}):
            vs = [v.co for p in pieces if p["part"] == part for v in p["bm"].verts]
            tris[part] = sum(len(f.verts) - 2 for p in pieces if p["part"] == part for f in p["bm"].faces)
            mid = [(min(v[a] for v in vs) + max(v[a] for v in vs)) / 2 for a in range(3)]
            boxes[part] = (mid[1], mid[2] - az)
            if math.hypot(*boxes[part]) > 0.005:
                faults.append("  ! option %d: %s's box is %.3f off the hub" % (i, part, math.hypot(*boxes[part])))
        reach = reach_of(pieces)
        if reach > TAIL["ring"] - 0.6:
            faults.append("  ! option %d: the blades reach %.2f, past the ring's inside (%.2f)" % (i, reach, TAIL["ring"] - 0.6))
        low = min(v.co.x for p in pieces if p["part"] == "Prop" and p["colour"] != TAIL["hub"] for v in p["bm"].verts)
        if i and low < FACE - 1e-4:
            faults.append("  ! option %d: a blade comes within %.2f of the dark disc" % (i, low - DISC))
        far = max(v.co.x for p in pieces for v in p["bm"].verts)
        for line in faults:
            print(line)
        print("props: tier %d option %d %s: %s triangles (%s), reach %.2f of the ring's %.2f, %.2f behind the disc, box off "
              "the hub by %s, %d faults" % (tier, i, NAMES[i], sum(tris.values()),
                                           ", ".join("%s %d" % kv for kv in tris.items()), reach, TAIL["ring"] - 0.6,
                                           far - DISC, ", ".join("%.3f" % math.hypot(*b) for b in boxes.values()), len(faults)))
        return {"option": i, "name": NAMES[i], "triangles": tris, "reach": round(reach, 2), "behind": round(far - DISC, 2),
                "faults": faults, "mark": MARK}

    def meshes(pieces, origin=Vector((0, 0, 0)), cut=None):
        """the pieces of each part into one mesh object (as sub_stages does), about `origin`; cut: only what lies
        behind that x (the clip's tail ends)"""
        parts = {}
        for pc in pieces:
            bm_src = pc["bm"]
            if cut is not None:
                xs = [v.co.x for v in bm_src.verts]
                if max(xs) < cut or (min(xs) < cut and pc is not BODY_PIECES[0]):
                    continue
                if min(xs) < cut:
                    bm_src = bm_src.copy()
                    bmesh.ops.bisect_plane(bm_src, geom=bm_src.verts[:] + bm_src.edges[:] + bm_src.faces[:],
                                           plane_co=(cut, 0, 0), plane_no=(-1, 0, 0), clear_outer=True)
            bm = parts.setdefault(pc["part"], bmesh.new())
            index = S["mat"](pc["colour"])
            twin = {v: bm.verts.new(v.co - origin) for v in bm_src.verts}
            for f in bm_src.faces:
                g = bm.faces.new([twin[v] for v in f.verts])
                g.material_index, g.smooth = index, pc["smooth"]
        made = []
        for name, bm in parts.items():
            bm.normal_update()
            for e in bm.edges:
                e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(0.0) < math.radians(50)
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            bm.free()
            used = sorted({poly.material_index for poly in me.polygons})
            for j in used:
                me.materials.append(S["MATS"][S["ORDER"][j]])
            for poly in me.polygons:
                poly.material_index = used.index(poly.material_index)
            ob = bpy.data.objects.new(name, me)
            ob.location = origin
            scene.collection.objects.link(ob)
            made.append(ob)
        return made

    def look_from(ob, source, target):
        ob.location = source
        ob.rotation_euler = (Vector(target) - Vector(source)).to_track_quat("-Z", "Y").to_euler()

    def camera(name, ortho=None, lens=50):
        cam = bpy.data.cameras.new(name)
        if ortho:
            cam.type, cam.ortho_scale = "ORTHO", ortho
        else:
            cam.lens = lens
        cam.clip_start, cam.clip_end = 0.5, 2000
        ob = bpy.data.objects.new(name, cam)
        scene.collection.objects.link(ob)
        return ob

    def render(cam, name, w, h):
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = w, h, 100
        scene.render.filepath = os.path.join(out, name)
        bpy.ops.render.render(write_still=True)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = rgba((254, 248, 241))
    bg.inputs["Strength"].default_value = 0.6
    scene.world = world
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy, sun_data.angle = 2.3, math.radians(14)
    sun = bpy.data.objects.new("Key", sun_data)
    scene.collection.objects.link(sun)
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"

    if mode == "gate":
        # no pictures: every option through the gate on this tier, the colour its one blade gets, and whatever of the
        # sub stands in the space the options turn in (behind the dark disc, inside the ring; boxes compared, so a
        # near miss is named too)
        inside = TAIL["ring"] - 0.6
        deep = 0.0
        for i in range(5):
            row = gate(i, option(i))
            deep = max(deep, row["behind"])
        near = []
        for pc in BODY_PIECES:
            vs = [v.co for v in pc["bm"].verts]
            lo = [min(v[a] for v in vs) for a in range(3)]
            hi = [max(v[a] for v in vs) for a in range(3)]
            if hi[0] > FACE and lo[0] < DISC + deep and lo[1] < inside and hi[1] > -inside and lo[2] < az + inside and hi[2] > az - inside:
                reach = min(math.hypot(v.y, v.z - az) for v in vs if v.x > FACE) if any(v.x > FACE for v in vs) else -1
                near.append("%s %s (x %.2f to %.2f, nearest corner %.2f from the hub's line)" % (pc["part"], pc["colour"], lo[0], hi[0], reach))
        print("props: tier %d: the coloured blade is %s (blades %s, glow %s); ring's inside %.2f; the deepest option ends %.2f "
              "behind the disc; of the sub in that space: %s" % (tier, MARK, TAIL["blades"], TAIL["glow"], inside, deep,
                                                                 "; ".join(near) or "nothing"))
        return
    if mode == "stills":
        only = [int(v) for v in flag("--only", "0,1,2,3,4").split(",")]
        # a blocky rider on the seat, as sub_stages draws one (root 1.7 over the seat's top)
        rider = []
        for key, c in (("skin", (242, 201, 76)), ("shirt", (45, 127, 211)), ("legs", (92, 168, 74))):
            m = bpy.data.materials.new("Rider_" + key)
            m.use_nodes = True
            m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = rgba(c)
            rider.append(m)

        def rbox(c, size, mat, r=(0, 0, 0)):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(c) @ S["rot"](r) @ Matrix.Diagonal((*size, 1.0)))
            me = bpy.data.meshes.new("Rider")
            bm.to_mesh(me)
            bm.free()
            me.materials.append(rider[mat])
            scene.collection.objects.link(bpy.data.objects.new("Rider", me))

        SX, SZ = 5.0, 5.7
        rbox((SX, 0, SZ + 1.7), (1.0, 2.0, 2.0), 1, r=(0, -8, 0))
        rbox((SX - 0.3, 0, SZ + 3.4), (1.25, 1.25, 1.25), 0)
        for s in (-1, 1):
            rbox((SX - 1.0, s * 0.55, SZ + 0.5), (2.0, 0.95, 0.95), 2)
            rbox((SX - 2.0, s * 0.55, SZ - 0.1), (0.95, 0.95, 1.6), 2, r=(0, 20, 0))
            rbox((SX - 1.2, s * 1.5, SZ + 1.75), (2.3, 0.9, 0.9), 0, r=(0, 22, 0))
        meshes(BODY_PIECES)
        ring = TAIL["ring"]
        behind = camera("Behind", ortho=2.75 * ring)
        look_from(behind, (tx + 80, 0, az), (tx, 0, az))
        rear = camera("Rear", ortho=2.7 * ring)
        look_from(rear, (tx + 66, -50, az + 30), (tx + 0.4, -0.5, az - 0.2))
        # the riding camera on the run at Sub.Speed, 620 studs a second (SubController.cameraFor, Config.Sub): Distance 30 + 8 behind the
        # sub's middle, 10 - 3 over it, looking 25 + 20 ahead of it, 70 + Fov 18 degrees high
        ride = camera("Ride")
        ride.data.sensor_fit = "VERTICAL"
        ride.data.angle = math.radians(88)
        look_from(ride, (38, 0, 7), (-45, 0, 0))
        stats = []
        for i in only:
            pieces = option(i)
            stats.append(gate(i, pieces))
            made = meshes(pieces)
            look_from(sun, (tx + 9, -11, 11), (tx, 0, az))
            render(behind, "o%d_behind.png" % i, 1200, 1200)
            render(rear, "o%d_rear.png" % i, 1200, 1200)
            look_from(sun, (4, -5, 12), (0, 0, 0))
            render(ride, "o%d_ride.png" % i, 3840, 2160)
            bpy.context.view_layer.update()
            spots = [world_to_camera_view(scene, ride, HUB + Vector((1.0, dy, dz))) for dy, dz in
                     ((0, TAIL["ring"] - 0.6), (0, -(TAIL["ring"] - 0.6)))]
            stats[-1]["ride_share"] = round(abs(spots[0].y - spots[1].y), 3)
            for ob in made:
                bpy.data.objects.remove(ob)
        json.dump({"tier": tier, "name": S["NAME"], "glow": TAIL["glow"], "cross": bool(TAIL["cross"]), "options": stats},
                  open(os.path.join(out, "stats.json"), "w"), indent=1)
        if any(s["faults"] for s in stats):
            sys.exit(1)
        return

    # ------------------------------------------------------------------------------------------ the clip's frames
    # six tail ends in one picture, three across: today's wheel by today's rule (the proof), then today's wheel and
    # the four options by the proposed rule. One frame of the clip is one frame of the game at 60 a second; nothing
    # is smeared, as nothing is in the game.
    TILES = [("now_today", 0, False), ("now", 0, True), ("o1", 1, True), ("o2", 2, True), ("o3", 3, True), ("o4", 4, True)]
    PXS, TW, TH, HEAD = 48, 640, 480, 120
    DY, DZ, YAW, PITCH = 16.0, 13.0, math.radians(24), math.radians(13)
    total = FPS * 6
    lo, hi = (int(v) for v in flag("--range", "0,%d" % total).split(","))
    RULE["BlurMost"] = float(flag("--blur", RULE["BlurMost"]))  # to try another strength of the blur disc
    cut = tx - 6.5
    body = meshes(BODY_PIECES, cut=cut)
    for ob in body:
        scene.collection.objects.unlink(ob)
    W, H = 2 * int(DY * math.cos(YAW) * PXS) + TW + 40, int(DZ * math.cos(PITCH) * PXS) + TH + 40
    cam = camera("Clip", ortho=W / PXS)
    away = Vector((math.cos(PITCH) * math.cos(YAW), -math.cos(PITCH) * math.sin(YAW), math.sin(PITCH)))
    look_from(cam, HUB + away * 200, HUB)
    look_from(sun, (tx + 14, -9, 13), (tx, 0, az))
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = W, H, 100
    scene.render.image_settings.compression = 15
    try:
        scene.eevee.taa_render_samples = 24
    except AttributeError:
        pass
    blur = bpy.data.materials.new("Blur")
    blur.use_nodes = True
    shader = blur.node_tree.nodes.get("Principled BSDF")
    # unlit, so that its share of the picture is exactly the number in RULE (a lit white disc came out far more solid)
    shader.inputs["Base Color"].default_value = (0, 0, 0, 1)
    shader.inputs["Emission Color"].default_value = rgba(PALETTE[TAIL["blades"]])
    shader.inputs["Emission Strength"].default_value = 1.0
    shader.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in shader.inputs:
        shader.inputs["Specular IOR Level"].default_value = 0.0
    if hasattr(blur, "surface_render_method"):
        blur.surface_render_method = "BLENDED"
    else:
        blur.blend_method = "BLEND"
    bpy.context.view_layer.update()
    right = cam.matrix_world.to_3x3() @ Vector((1, 0, 0))
    up = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
    wheels, truth = [], {"fps": FPS, "frames": total, "tier": tier, "tiles": [], "angles": {}, "speed": [], "blur": [],
                         "raw": [W, H], "tile": [TW, TH], "head": HEAD}
    for n, (key, i, new_rule) in enumerate(TILES):
        col, row = n % 3, n // 3
        off = Vector((0, (col - 1) * DY, (0.5 - row) * DZ))
        for ob in body:
            twin = ob.copy()
            twin.location = off
            scene.collection.objects.link(twin)
        pieces = option(i)
        stats = gate(i, pieces)
        made = meshes(pieces, origin=HUB)
        for ob in made:
            ob.location = HUB + off
        disc = None
        if new_rule:
            # the blur disc: thin, the blades' colour, low in the blades (just behind the backing plate), so the
            # blades and the one coloured blade stay sharp in front of it and the dark disc behind them hazes over
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=stats["reach"] + 0.05, radius2=stats["reach"] + 0.05,
                                  depth=0.04, matrix=Matrix.Translation((FACE + 0.16 - tx, 0, 0)) @ S["rot"]((0, 90, 0)))
            me = bpy.data.meshes.new("Blur")
            bm.to_mesh(me)
            bm.free()
            me.materials.append(blur)
            disc = bpy.data.objects.new("Blur", me)
            disc.location = HUB + off
            scene.collection.objects.link(disc)
        bpy.context.view_layer.update()
        spot = world_to_camera_view(scene, cam, HUB + off)
        sx, sy = spot.x * W, (1 - spot.y) * H
        mid = world_to_camera_view(scene, cam, HUB + off + EX * (FACE - tx + 0.9 * k))  # the hub at the blades' middle
        mx, my = mid.x * W, (1 - mid.y) * H
        box = [int(round(sx - TW / 2)), int(round(sy - TH / 2 - 8))]
        wheels.append((key, i, new_rule, made, disc))
        truth["tiles"].append({
            "key": key, "option": i, "name": NAMES[i], "about": ABOUT[i], "new_rule": new_rule, "blades": BLADES[i],
            "triangles": sum(stats["triangles"].values()), "crop": box, "at": [col * TW, HEAD + row * TH],
            "hub": [int(round(col * TW + mx - box[0])), int(round(HEAD + row * TH + my - box[1]))],
            "plane": [[right.y * PXS, right.z * PXS], [up.y * PXS, up.z * PXS]], "reach_px": stats["reach"] * PXS,
            "lo": 1.5 * k, "hi": 2.6 * k, "marked": i > 0, "judged": new_rule, "step_most": step_most(BLADES[i])})
        truth["angles"][key] = []
    angle = {key: 0.0 for key, *_ in TILES}
    alphas = []
    for f in range(total):
        v = speed_at(f / FPS)
        truth["speed"].append(v)
        for key, i, new_rule, made, disc in wheels:
            truth["angles"][key].append(angle[key])
        alphas.append(turn_new(v, 1 / FPS, 3)[1])
        if lo <= f < hi:
            shader.inputs["Alpha"].default_value = alphas[-1]
            for key, i, new_rule, made, disc in wheels:
                for ob in made:
                    ob.rotation_euler = (TURN * math.radians(angle[key]), 0, 0)
                if disc:
                    disc.hide_render = alphas[-1] < 0.004
            scene.render.filepath = os.path.join(out, "raw%04d.png" % (f + 1))
            bpy.ops.render.render(write_still=True)
        for key, i, new_rule, made, disc in wheels:
            angle[key] += turn_new(v, 1 / FPS, BLADES[i])[0] if new_rule else turn_now(v, 1 / FPS)
    truth["blur"] = alphas
    if lo == 0:
        json.dump(truth, open(os.path.join(out, "truth.json"), "w"))
    print("props: frames %d to %d of %d, %d x %d" % (lo + 1, hi, total, W, H))


# ------------------------------------------------------------------------------------------------ the pictures (Pillow)
def pillow():
    from PIL import Image, ImageDraw, ImageFont

    bold = next((p for p in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                             "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf") if os.path.exists(p)), None)

    def font(size):
        try:
            return ImageFont.truetype(bold, size)
        except (OSError, TypeError, AttributeError):
            return ImageFont.load_default(size)

    return Image, ImageDraw, font


def overlay(src, out):
    """the clip's pictures: each raw frame's six tail ends cut out and laid three across, named, under a speed bar"""
    Image, ImageDraw, font = pillow()
    truth = json.load(open(os.path.join(src, "truth.json")))
    os.makedirs(out, exist_ok=True)
    TW, TH = truth["tile"]
    HEAD = truth["head"]
    W, H = 3 * TW, HEAD + 2 * TH
    back = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(back)
    for y in range(H):
        u = y / H
        d.line((0, y, W, y), fill=(int(22 - 8 * u), int(74 - 26 * u), int(124 - 36 * u)))
    d.rectangle((0, 0, W, HEAD), fill=(12, 30, 54))
    for t in truth["tiles"]:
        x, y = t["at"]
        d.rectangle((x, y, x + TW - 1, y + TH - 1), outline=(12, 30, 54), width=3)
    WHITE, SOFT, WARN, GOOD = (255, 255, 255), (176, 204, 232), (255, 196, 70), (140, 232, 150)
    f_name, f_small, f_title, f_num = font(30), font(21), font(34), font(44)
    static = back.copy()
    d = ImageDraw.Draw(static)
    d.text((24, 12), "PROPELLER OPTIONS, TIER %d" % truth["tier"], font=f_title, fill=WHITE)
    d.text((24, 56), "one frame here is one frame of the game at %d a second; nothing is smeared" % truth["fps"], font=f_small, fill=SOFT)
    d.text((24, 84), "tier %d's own trip tops out at %d studs a second: see the mark" % (truth["tier"], LOW_TOP),
           font=f_small, fill=WARN)
    mark = next((i for i, v in enumerate(truth["speed"]) if v >= LOW_TOP), None)
    longest = d.textlength("88.8 turns a second, 498\u00b0 a frame", font=f_small)  # the widest caption a tile gets
    plaque = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plaque)
    for t in truth["tiles"]:
        x, y = t["at"]
        badge = "NOW" if t["option"] == 0 else str(t["option"])
        bw = 26 + int(pd.textlength(badge, font=f_name))
        name = t["name"] if t["option"] else "today's propeller"
        rule = "the turn rule proposed" if t["new_rule"] else "TODAY'S TURN RULE"
        wide = 36 + bw + int(max(pd.textlength(name, font=f_name), pd.textlength(rule, font=f_small)))
        pd.rounded_rectangle((x + 8, y + 8, x + 8 + wide, y + 92), 12, fill=(12, 30, 54, 215))
        pd.rounded_rectangle((x + 16, y + 16, x + 16 + bw, y + 58), 10, fill=WHITE)
        pd.text((x + 16 + bw // 2, y + 37), badge, font=f_name, fill=(12, 30, 54), anchor="mm")
        pd.text((x + 28 + bw, y + 16), name, font=f_name, fill=WHITE)
        pd.text((x + 28 + bw, y + 58), rule, font=f_small, fill=GOOD if t["new_rule"] else WARN)
        pd.rounded_rectangle((x + 8, y + TH - 44, x + 30 + int(longest), y + TH - 8), 10, fill=(12, 30, 54, 215))
    names = sorted(n for n in os.listdir(src) if n.startswith("raw") and n.endswith(".png"))
    for name in names:
        f = int(name[3:7]) - 1
        raw = Image.open(os.path.join(src, name)).convert("RGBA")
        frame = static.copy()
        d = ImageDraw.Draw(frame)
        v = truth["speed"][f]
        phase = ("AT THE DOCK" if v <= 0 else "TOP SPEED OF THE LAND 10 TRIP" if v >= TOP - 1 else
                 "PICKING UP SPEED" if v < LOW_TOP else "FASTER THAN TIER %d EVER GOES" % truth["tier"])
        bx0, bx1, by = 960, W - 330, 34
        d.rounded_rectangle((bx0, by, bx1, by + 22), 11, fill=(40, 70, 104))
        u = f / (truth["frames"] - 1)
        d.rounded_rectangle((bx0, by, bx0 + max(22, int((bx1 - bx0) * u)), by + 22), 11, fill=WHITE)
        d.text((bx0, by + 32), phase, font=f_small, fill=SOFT if v < LOW_TOP else WARN)
        if mark is not None:
            mx = bx0 + int((bx1 - bx0) * mark / (truth["frames"] - 1))
            d.rectangle((mx - 2, by - 8, mx + 2, by + 30), fill=WARN)
            d.text((mx + 10, by - 30), "%d: tier %d's top" % (LOW_TOP, truth["tier"]), font=f_small, fill=WARN)
        d.text((W - 24, 8), "%d" % round(v), font=f_num, fill=WHITE, anchor="ra")
        d.text((W - 24, 62), "studs a second", font=f_small, fill=SOFT, anchor="ra")
        lines = []
        for t in truth["tiles"]:
            x, y = t["at"]
            cx, cy = t["crop"]
            cell = raw.crop((cx, cy, cx + TW, cy + TH))
            frame.paste(cell, (x, y), cell)
            a = truth["angles"][t["key"]]
            step = (a[f + 1] - a[f]) if f + 1 < len(a) else (a[f] - a[f - 1])
            line = "%.1f turns a second, %d\u00b0 a frame" % (step * truth["fps"] / 360, round(step))
            lines.append(((x + 18, y + TH - 38), line, WHITE if t["new_rule"] else WARN))
        frame.paste(plaque, (0, 0), plaque)
        for at, line, fill in lines:
            d.text(at, line, font=f_small, fill=fill)
        d.rectangle((0, HEAD, W - 1, H - 1), outline=(12, 30, 54), width=3)
        for c in (1, 2):
            d.line((c * TW, HEAD, c * TW, H), fill=(12, 30, 54), width=3)
        d.line((0, HEAD + TH, W, HEAD + TH), fill=(12, 30, 54), width=3)
        frame.save(os.path.join(out, "c%04d.png" % (f + 1)), compress_level=1)
    print("props: %d clip pictures in %s" % (len(names), out))


def sheet(src, out):
    """the preview sheet: a block for today's propeller and for each option; in each, tiers 1, 6 and 9 side by side
    from straight behind, from three-quarter rear, and from the riding camera. Tall and narrow, for a phone."""
    Image, ImageDraw, font = pillow()
    from PIL import ImageFilter

    INK, SOFT, CREAM, WELL, RED = (38, 38, 38), (122, 114, 106), (254, 248, 241), (244, 236, 226), (200, 60, 40)
    tiers = (1, 6, 9)
    stats = {n: json.load(open(os.path.join(src, "t%d" % n, "stats.json"))) for n in tiers}
    PAD, COL = 24, 688
    W = PAD + 3 * (COL + PAD)
    ROWS = (("behind", "STRAIGHT BEHIND", COL), ("rear", "THREE-QUARTER REAR", COL),
            ("ride", "FROM THE RIDING CAMERA at 620 studs a second (38 studs behind, 7 up, 88\u00b0), cut to the sub", 500))
    BLOCK = 150 + sum(h + 52 for _, _, h in ROWS) + 20
    HEAD = 430
    sheet_ = Image.new("RGB", (W, HEAD + 5 * (BLOCK + PAD)), CREAM)
    d = ImageDraw.Draw(sheet_)
    d.text((PAD + 6, 22), "RIDE A FISH", font=font(34), fill=INK)
    d.text((PAD + 6, 64), "PROPELLER OPTIONS", font=font(84), fill=INK)
    d.text((PAD + 6, 160), "for the toy submarines, 2026-11-23", font=font(34), fill=SOFT)
    now = sum(stats[1]["options"][0]["triangles"].values())
    notes = ["Options only: nothing here is in the game. Pick one, or name what to mix.",
             "Each keeps the red ring, the tier's colours and glowing hub, and spins true (its box is centred on the hub).",
             "One blade is in another colour so a turn can be seen: %s." % ", ".join(
                 "%s on tier %d" % ({"ring": "the ring's red", "white": "white", "hull": "the hull's colour", "accent": "the accent"}[stats[n]["options"][-1]["mark"]], n)
                 for n in tiers),
             "Today's propeller is %d triangles; the count beside each option is its own. See the clip for how each turns." % now]
    for i, line in enumerate(notes):
        d.text((PAD + 6, 222 + i * 46), line, font=font(31), fill=INK if i == 0 else SOFT)
    cut_off = []

    def lay(im, x, y, w, h, grow=1.0):
        box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if grow != 1.0 and box:  # cut to what is drawn, with a little room
            mx, my = int((box[2] - box[0]) * 0.07), int((box[3] - box[1]) * 0.07)
            im = im.crop((max(0, box[0] - mx), max(0, box[1] - my), min(im.width, box[2] + mx), min(im.height, box[3] + my)))
        kf = min(w / im.width, h / im.height)
        im = im.resize((max(1, int(im.width * kf)), max(1, int(im.height * kf))), Image.LANCZOS)
        at = (x + (w - im.width) // 2, y + (h - im.height) // 2)
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sh.putalpha(im.getchannel("A").point(lambda a: a // 5))
        sheet_.paste((60, 40, 30), (at[0] + 6, at[1] + 10), sh.filter(ImageFilter.GaussianBlur(8)).getchannel("A"))
        sheet_.paste(im, at, im)
        return kf

    for i in range(5):
        y = HEAD + i * (BLOCK + PAD)
        d.rounded_rectangle((PAD, y, W - PAD, y + BLOCK), 28, fill=WELL)
        badge = "NOW" if i == 0 else str(i)
        bw = 60 + int(d.textlength(badge, font=font(70)))
        d.rounded_rectangle((PAD + 22, y + 22, PAD + 22 + bw, y + 126), 20, fill=INK)
        d.text((PAD + 22 + bw // 2, y + 74), badge, font=font(70), fill=CREAM, anchor="mm")
        o = stats[1]["options"][i]
        d.text((PAD + 46 + bw, y + 18), NAMES[i] if i else "TODAY'S PROPELLER", font=font(62), fill=INK)
        tri = o["triangles"]["Prop"]
        line = "%s  /  %d triangles%s  /  reaches %.1f of the ring's %.1f studs (tier 1)" % (
            ABOUT[i], tri, "" if i == 0 else " (%d more than today)" % (tri - now), o["reach"], 3.7)
        d.text((PAD + 48 + bw, y + 90), line, font=font(29), fill=SOFT)
        if i == 2:
            d.text((W - PAD - 22, y + 30), "four blades: they line up with the tail's four fins", font=font(24), fill=RED, anchor="ra")
            d.text((W - PAD - 22, y + 60), "four times a turn (tiers 1, 2, 4, 8, 9)", font=font(24), fill=RED, anchor="ra")
        yy = y + 150
        for view, label, h in ROWS:
            d.text((PAD + 26, yy + 6), label, font=font(27), fill=SOFT)
            for c, n in enumerate(tiers):
                x = PAD + PAD // 2 + c * (COL + PAD // 2)
                w = COL - PAD // 2
                d.rounded_rectangle((x, yy + 44, x + w, yy + 44 + h), 18, fill=CREAM)
                im = Image.open(os.path.join(src, "t%d" % n, "o%d_%s.png" % (i, view))).convert("RGBA")
                if view == "ride":
                    kf = lay(im, x + 8, yy + 52, w - 16, h - 16, grow=1.07)
                    share = stats[n]["options"][i]["ride_share"]
                    d.text((x + w - 14, yy + 44 + h - 12), "%d%% of the screen's height at 620" % round(100 * share),
                           font=font(25), fill=SOFT, anchor="rd")
                else:
                    lay(im, x, yy + 44, w, h)
                d.rounded_rectangle((x + 12, yy + 56, x + 12 + 30 + int(d.textlength("TIER %d  %s" % (n, stats[n]["name"].upper()), font=font(24))), yy + 96), 10, fill=INK)
                d.text((x + 27, yy + 62), "TIER %d  %s" % (n, stats[n]["name"].upper()), font=font(24), fill=CREAM)
            yy += h + 52
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet_.save(out, optimize=True)
    print("props: sheet %s %s, %.1f MB" % (out, sheet_.size, os.path.getsize(out) / 1e6))


def strips(src, out):
    """six frames in a row from four moments of the decoded clip, each tile by itself: for looking at the turn"""
    Image, ImageDraw, font = pillow()
    moments = (("dock", 20), ("rising", 170), ("near the cap", 205), ("top", 320))
    for name, f0 in moments:
        frames = [Image.open(os.path.join(src, "f%04d.png" % (f0 + j))).convert("RGB") for j in range(6)]
        page = Image.new("RGB", (6 * 320, 6 * 240), (0, 0, 0))
        for j, fr in enumerate(frames):
            for n in range(6):
                cell = fr.crop(((n % 3) * 640, 120 + (n // 3) * 480, (n % 3) * 640 + 640, 120 + (n // 3) * 480 + 480))
                page.paste(cell.resize((320, 240), Image.LANCZOS), (j * 320, n * 240))
        d = ImageDraw.Draw(page)
        d.text((8, 4), "frames %d to %d (%s): each row one tile, left to right in time" % (f0, f0 + 5, name), font=font(18), fill=(255, 255, 0))
        page.save(os.path.join(out, "strip_%s.png" % name.replace(" ", "_")))
    print("props: strips in", out)


def run_all(work, stills=True):
    """everything, in order; stops at the first step that fails (stills=False: the clip alone)"""
    me = os.path.abspath(__file__)
    blender = os.environ.get("BLENDER", "blender")
    att = os.path.join(ROOT, "docs", "attachments")
    sheet_png = os.path.join(att, "sub-props-options-2026-11-23.png")
    clip = os.path.join(att, "sub-props-options-spin-2026-11-23.mp4")

    def go(jobs):
        procs = [subprocess.Popen(j, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) for j in jobs]
        for j, pr in zip(jobs, procs):
            text = pr.communicate()[0]
            for line in text.splitlines():
                if line.startswith(("props:", "  !")) or "Traceback" in line or "Error" in line:
                    print(line)
            if pr.returncode:
                print(text[-3000:])
                sys.exit("failed: " + " ".join(j[3:]))

    b = [blender, "--background", "--python", me, "--"]
    if stills:
        go([b + ["stills", str(n), os.path.join(work, "t%d" % n)] for n in (1, 6, 9)])
        sheet(work, sheet_png)
    raw = os.path.join(work, "raw")
    total = FPS * 6
    go([b + ["frames", "1", raw, "--range", "%d,%d" % (a, a + total // 4)] for a in range(0, total, total // 4)])
    for old in (os.path.join(work, "clip"), os.path.join(work, "dec")):
        if os.path.isdir(old):
            for n in os.listdir(old):
                os.remove(os.path.join(old, n))
    overlay(raw, os.path.join(work, "clip"))
    go([b + ["encode", os.path.join(work, "clip"), clip]])
    go([b + ["decode", clip, os.path.join(work, "dec"), "--check", os.path.join(raw, "truth.json")]])
    strips(os.path.join(work, "dec"), os.path.join(work, "dec"))


if __name__ == "__main__" and len(sys.argv) > 1 and "--" not in sys.argv:
    if sys.argv[1] == "overlay":
        overlay(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "sheet":
        sheet(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "strips":
        strips(sys.argv[2], sys.argv[3])
    elif sys.argv[1] in ("all", "clip"):
        run_all(sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "work", "sub_props"), stills=sys.argv[1] == "all")
    else:
        sys.exit(__doc__)
    sys.exit(0)

if "--" in sys.argv and __name__ == "__main__":
    blender_part()
