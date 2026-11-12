"""Writes Roblox's own mesh file ("version 2.00", with vertex colours): what a MeshPart can show straight from a file
in Studio's content folder (rbxasset://...), with nothing uploaded. Used by install.py --local.
  write(path, positions, normals, colours, triangles): positions and normals [[x, y, z]...], colours [[r, g, b]...]
  (0..1), triangles [[a, b, c]...] (0-based corners, counter-clockwise seen from outside)
"""
import struct


def write(path, positions, normals, colours, triangles):
    out = [b"version 2.00\n", struct.pack("<HBBII", 12, 40, 12, len(positions), len(triangles))]
    for p, n, c in zip(positions, normals, colours):
        out.append(struct.pack(
            "<3f3f2f4b4B", p[0], p[1], p[2], n[0], n[1], n[2], 0.0, 0.0, 0, 0, 0, 127,
            *(max(0, min(255, round(v * 255))) for v in c), 255,
        ))
    for a, b, c in triangles:
        out.append(struct.pack("<3I", a, b, c))
    with open(path, "wb") as f:
        f.write(b"".join(out))
