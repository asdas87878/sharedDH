"""Reads a creature's game GLB (art/creatures/<Folder>/game/<Name>.glb) without Blender: one mesh to a part, in the
creature's own space (studs, +Y up, the head toward -Z), as plain lists. Used by upload_void.py.
  parts(path) -> [{"name", "origin" [x, y, z] (the part's pivot in the creature's space),
                   "positions" [[x, y, z]...] (about the origin), "normals" [[x, y, z]...],
                   "colours" [[r, g, b]...] (0..1, as stored: linear), "triangles" [[a, b, c]...]}]
"""
import json
import struct

FORMATS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def _quat_turn(q, v):
    x, y, z, w = q
    vx, vy, vz = v
    # v + 2 * cross(q.xyz, cross(q.xyz, v) + w * v)
    cx, cy, cz = y * vz - z * vy + w * vx, z * vx - x * vz + w * vy, x * vy - y * vx + w * vz
    return [vx + 2 * (y * cz - z * cy), vy + 2 * (z * cx - x * cz), vz + 2 * (x * cy - y * cx)]


def parts(path):
    data = open(path, "rb").read()
    assert data[:4] == b"glTF", path + " is not a GLB"
    length = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20 : 20 + length])
    start = 20 + length + 8
    blob = data[start : start + struct.unpack("<I", data[20 + length : 24 + length])[0]]

    def read(index):
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        fmt, width = FORMATS[acc["componentType"]], WIDTHS[acc["type"]]
        size = struct.calcsize(fmt) * width
        stride = view.get("byteStride") or size
        at = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        rows = [struct.unpack_from("<%d%s" % (width, fmt), blob, at + i * stride) for i in range(acc["count"])]
        if acc.get("normalized"):
            top = {"B": 255.0, "H": 65535.0}[fmt]
            rows = [tuple(v / top for v in row) for row in rows]
        return rows

    out = []

    def walk(index, at, turn, scale):
        node = doc["nodes"][index]
        t = node.get("translation", [0, 0, 0])
        assert "matrix" not in node, "a matrix on a node: not handled"
        here = [a + b for a, b in zip(at, _quat_turn(turn, [t[i] * scale[i] for i in range(3)]))]
        r = node.get("rotation", [0, 0, 0, 1])
        assert turn == [0, 0, 0, 1] or r == [0, 0, 0, 1], "turned nodes in a chain: not handled"
        here_turn = r if turn == [0, 0, 0, 1] else turn
        s = node.get("scale", [1, 1, 1])
        here_scale = [a * b for a, b in zip(scale, s)]
        if "mesh" in node:
            mesh = doc["meshes"][node["mesh"]]
            positions, normals, colours, triangles = [], [], [], []
            for prim in mesh["primitives"]:
                base = len(positions)
                attrs = prim["attributes"]
                for p in read(attrs["POSITION"]):
                    positions.append(_quat_turn(here_turn, [p[i] * here_scale[i] for i in range(3)]))
                for n in read(attrs["NORMAL"]):
                    normals.append(_quat_turn(here_turn, list(n)))
                if "COLOR_0" in attrs:
                    colours.extend([list(c[:3]) for c in read(attrs["COLOR_0"])])
                else:
                    colours.extend([[1.0, 1.0, 1.0]] * (len(positions) - base))
                flat = [row[0] + base for row in read(prim["indices"])]
                triangles.extend([flat[i : i + 3] for i in range(0, len(flat), 3)])
            out.append({
                "name": node["name"], "origin": here, "positions": positions, "normals": normals,
                "colours": colours, "triangles": triangles,
            })
        for child in node.get("children", []):
            walk(child, here, here_turn, here_scale)

    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        walk(root, [0, 0, 0], [0, 0, 0, 1], [1, 1, 1])
    return out
