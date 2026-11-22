"""The later lands' far view painted into the sky's face down the lane (2026-11-19, the user: "just make it so it looks
like the screenshots kinda"). Real parts out there can't do it: the hub's air fog hides everything past about 1,100
studs (Config.Look.AirFogEnd), and nearer they would stand in the lane. The sky is never fogged.

Takes the far view rendered alone from the spawn, level, 90 degrees square, on a transparent background
(SKY=1 python tools/map/vista.py blackhole; then the viewer's "skyft" view with RES=1024 TRANSPARENT=1) and lays it over
the sky's front face (SkyboxFt: Roblox's face toward +Z, the lane's way out of the hub). The game tips the sky
Config.Look.SkyTilt degrees toward the lane, which lowers what is painted there by as much, so the far view is painted
that much higher to sit on the horizon. Its lowest edge is feathered into the sky.

usage: python tools/art/sky_vista.py <sky face png> <far view png> <out png> [tilt degrees, default 14]"""
import math
import sys

import numpy as np
from PIL import Image, ImageFilter

face_path, view_path, out_path = sys.argv[1:4]
tilt = float(sys.argv[4]) if len(sys.argv) > 4 else 14.0
face = Image.open(face_path).convert("RGBA")
W = face.width
view = Image.open(view_path).convert("RGBA").resize((W, W), Image.LANCZOS)
# the face's horizon is at its middle row (elevation 0); the sky's tilt lowers what is painted by `tilt` degrees, so
# the far view goes up by tan(tilt) of half the face
shift = int(round(math.tan(math.radians(tilt)) * W / 2))
a = np.asarray(view).astype(float)
alpha = a[..., 3] / 255.0
# feather the bottom: the far view's lowest rows fade into the sky over 4% of the face, so its feet sit in the haze
rows = np.arange(W)
low = np.nonzero(alpha.max(axis=1) > 0.05)[0]
if len(low):
    bottom = low.max()
    fade = np.clip((bottom - rows) / (0.04 * W), 0, 1)[:, None]
    alpha = alpha * fade
a[..., 3] = alpha * 255
view = Image.fromarray(a.astype(np.uint8), "RGBA")
lifted = Image.new("RGBA", (W, W), (0, 0, 0, 0))
lifted.paste(view, (0, -shift), view)
out = Image.alpha_composite(face, lifted)
out.save(out_path)
print(out_path, "shifted up", shift, "px")
