#!/usr/bin/env python3
"""Offline pictures of the 3D auras (look 2), drawn from the game's own numbers: a mock of how Roblox draws particles and
Beams (billboards, flipbooks, depth, LightEmission), over Blender's avatar and fish. Not a Studio capture.

    rojo build -o /tmp/place.rbxl
    lune run tools/auras/volume_dump.luau /tmp/place.rbxl W/dump.json 6
    blender -b --python tools/auras/volume_scene.py -- W/shots <repo> W/dump.json
    python tools/auras/volume_shots.py W/dump.json W/shots out.png                      (the sheet)
    python tools/auras/volume_shots.py W/dump.json W/shots out.png foot12 foot_front    (one scene, one view)
    python tools/auras/volume_shots.py W/dump.json W/shots frames movie                 (its frames: a dump of many times)
(numpy and Pillow)"""
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX = {}


def texture(name):
    if name not in TEX:
        im = Image.open(os.path.join(ROOT, "art", "ui", "aura_volume", name.lower() + ".png"))
        TEX[name] = np.asarray(im)[..., 3].astype(np.float32) / 255
    return TEX[name]


def seq(keys, t):
    ts, vs = [k[0] for k in keys], [k[1] for k in keys]
    return float(np.interp(t, ts, vs))


def unit(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


class View:
    def __init__(self, folder, name, scale):
        m = json.load(open(f"{folder}/views.json"))[name]
        im = Image.open(f"{folder}/{name}.png").convert("RGB")
        self.w, self.h = int(m["w"] * scale), int(m["h"] * scale)
        self.f = m["f"] * scale
        self.img = np.asarray(im.resize((self.w, self.h), Image.LANCZOS)).astype(np.float32) / 255
        z = np.load(f"{folder}/{name}_depth.npy")
        yi = (np.arange(self.h) / scale).astype(int).clip(0, m["h"] - 1)
        xi = (np.arange(self.w) / scale).astype(int).clip(0, m["w"] - 1)
        self.z = z[yi][:, xi]
        self.pos, self.right, self.up, self.fwd = (np.array(m[k]) for k in ("pos", "right", "up", "fwd"))
        self.deep = m["deep"]

    def project(self, p):
        d = p - self.pos
        z = d @ self.fwd
        zz = np.maximum(z, 1e-3)
        return self.w / 2 + self.f * (d @ self.right) / zz, self.h / 2 - self.f * (d @ self.up) / zz, z

    def lit(self, at, color, reach, bright):
        """A PointLight: what is near it takes its colour."""
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        z = np.where(np.isfinite(self.z), self.z, 1e4)
        rx, ry = (xs + 0.5 - self.w / 2) / self.f, -(ys + 0.5 - self.h / 2) / self.f
        p = self.pos + z[..., None] * (self.fwd + rx[..., None] * self.right + ry[..., None] * self.up)
        d = np.linalg.norm(p - at, axis=-1)
        k = np.clip(1 - d / reach, 0, 1) ** 2 * bright * 0.4
        self.img = self.img + self.img * k[..., None] * np.array(color)

    def quad(self, pts, uv, tex, color, alphas, emission):
        """pts: 4 corners in order round; uv: theirs in the picture (pixels); alphas: theirs."""
        x, y, z = self.project(pts)
        if z.min() < 0.3:
            return
        for tri in ((0, 1, 2), (0, 2, 3)):
            self.tri(x[list(tri)], y[list(tri)], z[list(tri)], uv[list(tri)], tex, color, alphas[list(tri)], emission)

    def tri(self, x, y, z, uv, tex, color, al, emission):
        x0, x1 = int(max(np.floor(x.min()), 0)), int(min(np.ceil(x.max()) + 1, self.w))
        y0, y1 = int(max(np.floor(y.min()), 0)), int(min(np.ceil(y.max()) + 1, self.h))
        if x0 >= x1 or y0 >= y1:
            return
        area = (x[1] - x[0]) * (y[2] - y[0]) - (x[2] - x[0]) * (y[1] - y[0])
        if abs(area) < 1e-6:
            return
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        b1 = ((gx - x[0]) * (y[2] - y[0]) - (x[2] - x[0]) * (gy - y[0])) / area
        b2 = ((x[1] - x[0]) * (gy - y[0]) - (gx - x[0]) * (y[1] - y[0])) / area
        b0 = 1 - b1 - b2
        # (the shared edge belongs to one of the two)
        inside = (b0 >= 0) & (b1 >= 0) & (b2 > 0)
        if not inside.any():
            return
        iz = b0 / z[0] + b1 / z[1] + b2 / z[2]
        pz = 1 / np.maximum(iz, 1e-6)
        inside &= pz < self.z[y0:y1, x0:x1]
        u = (b0 * uv[0, 0] / z[0] + b1 * uv[1, 0] / z[1] + b2 * uv[2, 0] / z[2]) * pz
        v = (b0 * uv[0, 1] / z[0] + b1 * uv[1, 1] / z[1] + b2 * uv[2, 1] / z[2]) * pz
        th, tw = tex.shape
        fu, fv = u - 0.5, v - 0.5
        iu, iv = np.floor(fu).astype(int), np.floor(fv).astype(int)
        du, dv = fu - iu, fv - iv
        t = (tex[iv % th, iu % tw] * (1 - du) + tex[iv % th, (iu + 1) % tw] * du) * (1 - dv) + (
            tex[(iv + 1) % th, iu % tw] * (1 - du) + tex[(iv + 1) % th, (iu + 1) % tw] * du) * dv
        a = t * (b0 * al[0] + b1 * al[1] + b2 * al[2]) * inside
        a = np.clip(a, 0, 1)[..., None]
        dst = self.img[y0:y1, x0:x1]
        self.img[y0:y1, x0:x1] = color * a + dst * (1 - a * (1 - emission))

    def out(self, w, h):
        return Image.fromarray((np.clip(self.img, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)


def particles(scene, frame, seed):
    """Every particle alive at the frame's time: its place, its way, its size ..."""
    out = []
    T = frame["T"]
    grow = scene["Shape"]["Grow"]
    at = np.array(scene["Shape"]["At"])
    long = abs(scene["Shape"]["X"] - scene["Shape"]["Z"]) >= 0.4
    for li, l in enumerate(scene["Layers"]):
        rate = 1 / scene["Pulse"] if l["Name"] == "Shock" else l["Rate"]
        if rate <= 0:
            continue
        # (each particle its own luck, by its number: the same one in every picture it is alive in)
        for i in range(int((T - l["Life"][1]) * rate) - 1, int(T * rate) + 1):
            rng = np.random.default_rng((max(i, 0), li, seed))
            born = (i + (0 if l["Name"] == "Shock" else rng.random())) / rate
            age, life = T - born, rng.uniform(*l["Life"])
            if age < 0 or age >= life:
                continue
            k = age / life
            box = np.array(l["Box"]) / 2
            th = rng.random() * 2 * np.pi
            way = np.array([0.0, 1.0, 0.0])
            if l["Place"] in ("Band", "Top"):
                r = np.sqrt(rng.uniform(l["Band"] ** 2, 1))
                p = np.array([np.cos(th) * r * box[0], 0, np.sin(th) * r * box[2]])
            elif l["Place"] == "Flat":
                p = np.zeros(3)
            elif l["Place"] == "Air":
                r = np.sqrt(rng.random())
                p = np.array([np.cos(th) * r * box[0], rng.uniform(-1, 1) * box[1], np.sin(th) * r * box[2]])
            else:
                p = np.array([np.cos(th) * box[0], rng.uniform(-1, 1) * box[1], np.sin(th) * box[2]])
                way = unit(np.array([np.cos(th), 0, np.sin(th)]))
            if l["Spread"]:
                way = unit(way + np.tan(np.radians(l["Spread"])) * rng.uniform(-1, 1, 3) * 0.8)
            speed = rng.uniform(*l["Speed"]) * grow
            drag = l["Drag"]
            dist = speed * (1 - 2 ** (-drag * age)) / (drag * np.log(2)) if drag else speed * age
            p = p + way * dist + np.array([0, 0.5 * l["Accel"] * grow * age * age, 0])
            vel = way * speed * (2 ** (-drag * age)) + np.array([0, l["Accel"] * grow * age, 0])
            if l["Spin"] and not long:
                g = l["Spin"] * frame["Clock"]
                c, s = np.cos(g), np.sin(g)

                def turn(q):
                    return np.array([q[0] * c + q[2] * s, q[1], -q[0] * s + q[2] * c])

                p, vel = turn(p), turn(vel)
            size = seq(l["Size"], k) * grow * (1 + l["Jitter"] * rng.uniform(-1, 1))
            alpha = (1 - seq(l["Fade"], k)) * scene["Strength"]
            col = np.array(l["Color"]) * (1 - k) + np.array(l["Color2"]) * k
            rot = (rng.random() * 2 * np.pi if l["AnyTurn"] else 0) + np.radians(l["Turn"]) * rng.uniform(-1, 1) * age
            total = l["Grid"] ** 2
            if l["Mode"] == "OneShot":
                f = min(int(k * total), total - 1)
            elif l["Mode"] == "Loop":
                f = int(age * l["Fps"] + rng.integers(total)) % total
            else:
                f = int(rng.integers(total))
            out.append({"p": at + p + np.array([0, l["Up"], 0]), "vel": vel, "size": size, "alpha": alpha,
                        "col": np.clip(col * l["Bright"], 0, 1.6), "rot": rot, "frame": f if total > 1 else 0, "l": l})
    return out


def render(folder, scene, view, scale=1.5, frame=0, seed=1):
    V = View(folder, view, scale)
    fr = scene["Frames"][frame]
    at = np.array(scene["Shape"]["At"])
    L = scene.get("Light")
    if L:
        h = min(scene["Shape"]["Height"] * 0.3, 3)
        V.lit(at + np.array([0, h, 0]), L["Color"], min(L["Range"] * scene["Shape"]["Grow"], 45),
              L["Bright"] * fr["Bright"])
    jobs = []
    for p in particles(scene, fr, seed):
        l = p["l"]
        view_dir = unit(V.pos - p["p"])
        f = l["Facing"]
        if f == "Upright":
            u = np.array([0, 1.0, 0])
            r = unit(np.cross(u, view_dir))
            r = r if r @ V.right > 0 else -r
        elif f == "Flat":
            r, u = np.array([1.0, 0, 0]), np.array([0, 0, 1.0])
        elif f == "Along":
            u = unit(p["vel"])
            r = unit(np.cross(u, view_dir))
        else:
            r, u = V.right, V.up
        c, s = np.cos(p["rot"]), np.sin(p["rot"])
        r, u = r * c + u * s, u * c - r * s
        h = p["size"] / 2
        pts = np.array([p["p"] - r * h + u * h, p["p"] + r * h + u * h, p["p"] + r * h - u * h, p["p"] - r * h - u * h])
        tex = texture(l["Picture"])
        n = tex.shape[0] // l["Grid"]
        row, col = divmod(p["frame"], l["Grid"])
        cell = tex[row * n:(row + 1) * n, col * n:(col + 1) * n]
        uv = np.array([[0.5, 0.5], [n - 0.5, 0.5], [n - 0.5, n - 0.5], [0.5, n - 0.5]])
        jobs.append(((p["p"] - V.pos) @ V.fwd, pts, uv, cell, p["col"], np.full(4, p["alpha"]), l["Emission"]))
    tex = texture("Ribbon")
    th, tw = tex.shape
    for s in fr["Strands"]:
        J = s["Joints"]
        n = len(J) - 1
        line, wid, fade = [], [], []
        seg = 16
        for i in range(n):
            a, b = J[i], J[i + 1]
            p0, p3 = np.array(a["At"]), np.array(b["At"])
            p1 = p0 + np.array(a["Along"]) * a["Handle"]
            p2 = p3 - np.array(b["Along"]) * b["Handle"]
            for j in range(seg + (i == n - 1)):
                t = j / seg
                line.append(at + (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3)
                wid.append(a["Width"] * (1 - t) + b["Width"] * t)
                fade.append(np.interp((i + t) / n, np.linspace(0, 1, len(s["Fade"])), s["Fade"]))
        line = np.array(line)
        sides = []
        for j in range(len(line)):
            d = unit(line[min(j + 1, len(line) - 1)] - line[max(j - 1, 0)])
            sides.append(unit(np.cross(d, unit(V.pos - line[j]))) * wid[j] / 2)
        for j in range(len(line) - 1):
            v0 = (j / seg - s["Offset"]) * th
            v1 = ((j + 1) / seg - s["Offset"]) * th
            pts = np.array([line[j] - sides[j], line[j] + sides[j], line[j + 1] + sides[j + 1], line[j + 1] - sides[j + 1]])
            uv = np.array([[0.5, v0], [tw - 0.5, v0], [tw - 0.5, v1], [0.5, v1]])
            jobs.append((((line[j] + line[j + 1]) / 2 - V.pos) @ V.fwd, pts, uv, tex,
                         np.clip((np.array(s["Color"]) + (np.array(s["Head"]) - np.array(s["Color"])) * (j / (len(line) - 1)) ** 2) * fr["Bright"], 0, 1.6),
                         np.array([fade[j], fade[j], fade[j + 1], fade[j + 1]]), s["Emission"]))
    for job in sorted(jobs, key=lambda x: -x[0]):
        V.quad(*job[1:])
    return V


def tile(args):
    folder, scene, view, w, h, frame = args[:6]
    return render(folder, scene, view, args[6] if len(args) > 6 else 1.5, frame).out(w, h)


def font(n):
    for f in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, n)
    return ImageFont.load_default(n)


def movie(scenes, folder, out):
    """Four tiers standing, 1 4 8 12, and three on a shark: every frame of the dump (a GIF, at its times' own pace)."""
    cells = [(f"foot{t}", "foot_front", 300, 407) for t in (1, 4, 8, 12)]
    cells += [(f"HammerheadShark{t}", "HammerheadShark_front", 400, 304) for t in (1, 6, 12)]
    n = len(scenes["foot1"]["Frames"])
    jobs = [(folder, scenes[c[0]], c[1], c[2], c[3], f, 1.0) for f in range(n) for c in cells]
    frames = []
    with ProcessPoolExecutor(10) as ex:
        made = list(ex.map(tile, jobs, chunksize=4))
    for f in range(n):
        sheet = Image.new("RGB", (1200, 407 + 304), (10, 14, 24))
        for i, c in enumerate(cells):
            at = (i * 300, 0) if i < 4 else ((i - 4) * 400, 407)
            sheet.paste(made[f * len(cells) + i], at)
            ImageDraw.Draw(sheet).text((at[0] + 8, at[1] + 6), f"tier {scenes[c[0]]['Tier']}", font=font(17),
                                       fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
        frames.append(sheet)
    ms = int(round((scenes["foot1"]["Frames"][1]["T"] - scenes["foot1"]["Frames"][0]["T"]) * 1000))
    os.makedirs(out, exist_ok=True)
    for i, f in enumerate(frames):
        f.save(f"{out}/{i:03d}.png")
    print(len(frames), "frames", ms, "ms")


def main():
    dump, folder, out = sys.argv[1:4]
    scenes = {s["Name"]: s for s in json.load(open(dump))}
    if sys.argv[4:] == ["movie"]:
        movie(scenes, folder, out)
        return
    if len(sys.argv) > 4:
        V = render(folder, scenes[sys.argv[4]], sys.argv[5], 1.5)
        V.out(int(V.w / 1.5), int(V.h / 1.5)).save(out)
        return
    names = ["Bubble", "Shell", "Tide", "Current", "Reef", "Storm", "Moon", "Lantern", "Ember", "Urchin", "Abyss", "Leviathan"]
    tw, th = 280, 380
    jobs, where = [], []
    cols = 6
    for tier in range(1, 13):
        r, c = divmod(tier - 1, cols)
        for j, view in enumerate(("foot_front", "foot_side")):
            jobs.append((folder, scenes[f"foot{tier}"], view, tw, th, 0))
            where.append((c * tw, (r * 2 + j) * th, f"{tier} {names[tier - 1]}" + (" (front)" if j == 0 else " (side)")))
    W = cols * tw
    y = 4 * th
    rw, rh = W // 3, int(W // 3 * 0.76)
    for tier in (1, 6, 12):
        c = (1, 6, 12).index(tier)
        for j, view in enumerate(("HammerheadShark_front", "HammerheadShark_side")):
            jobs.append((folder, scenes[f"HammerheadShark{tier}"], view, rw, rh, 0))
            where.append((c * rw, y + j * rh, f"riding, {tier} {names[tier - 1]}"))
    oh = int(rw * 9 / 16)
    for c, (nm, tier) in enumerate((("Clownfish", 12), ("HammerheadShark", 12), ("BlueWhale", 12))):
        jobs.append((folder, scenes[f"{nm}{tier}own"], f"{nm}_own", rw, oh, 0))
        where.append((c * rw, y + 2 * rh, f"your own camera, {tier} on {nm}"))
    sheet = Image.new("RGB", (W, y + 2 * rh + oh), (10, 14, 24))
    d = ImageDraw.Draw(sheet)
    with ProcessPoolExecutor(10) as ex:
        for im, (x, yy, text) in zip(ex.map(tile, jobs), where):
            sheet.paste(im, (x, yy))
            d.text((x + 8, yy + 6), text, font=font(17), fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
    sheet.save(out)


if __name__ == "__main__":
    main()
