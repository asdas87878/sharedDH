"""The creature kit's shared pieces (docs/style/03-creature-set.md): colours and materials, mesh helpers, and the views every
creature is judged in (the turnaround, the wireframe, the riding view, the swim loop). Each body plan builds its parts with
these and renders the same views, so every creature looks, rides and swims alike in the pictures:

  fish_kit.py   fish: a chain of rigid segments along the spine, one wave down it
  shell_kit.py  shells (the Sea Turtle): a rigid shell, flippers rowing (docs/style/creatures/SeaTurtle.md)
  disc_kit.py   discs (the Stingray): a body with hinged wing pieces flapping root to tip (docs/style/creatures/Stingray.md)

A spec may set "frame" (default 1): every camera stands that many times further off, for a big or wide creature.
A plan script runs under Blender (--background --python) and imports this from its own folder:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import kit_common as kc
Conventions: units are studs; the creature points to -X, up is +Z, its right side is +Y; every part is a rigid mesh object
whose pivot is its joint (one MeshPart and one Motor6D each in Roblox).
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector


# ---------------------------------------------------------------- colours and materials
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h):
    h = h.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def material(name, hex_colour, roughness=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_rgba(hex_colour)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    return m


# ---------------------------------------------------------------- mesh helpers
def box_bm(size):
    """a box centred on the origin"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return bm


def plate_bm(pts, thickness):
    """a flat plate: the polygon pts (x, z) extruded along Y, centred on y = 0"""
    bm = bmesh.new()
    h = thickness / 2
    a = [bm.verts.new((x, -h, z)) for x, z in pts]
    b = [bm.verts.new((x, h, z)) for x, z in pts]
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def clip_x(pts, x, keep_greater):
    """Sutherland-Hodgman against the line x = const"""
    out = []
    for i in range(len(pts)):
        cur, prev = pts[i], pts[i - 1]
        cin = cur[0] >= x if keep_greater else cur[0] <= x
        pin = prev[0] >= x if keep_greater else prev[0] <= x
        if cin != pin:
            f = (x - prev[0]) / (cur[0] - prev[0])
            out.append((x, prev[1] + f * (cur[1] - prev[1])))
        if cin:
            out.append(cur)
    return out


def clip_half(pts, p, n):
    """Sutherland-Hodgman: keep the part of the polygon pts on the side of the line through p that n points to"""
    out = []
    for i in range(len(pts)):
        cur, prev = pts[i], pts[i - 1]
        dc = (cur[0] - p[0]) * n[0] + (cur[1] - p[1]) * n[1]
        dp = (prev[0] - p[0]) * n[0] + (prev[1] - p[1]) * n[1]
        if (dc >= 0) != (dp >= 0):
            f = dp / (dp - dc)
            out.append((prev[0] + f * (cur[0] - prev[0]), prev[1] + f * (cur[1] - prev[1])))
        if dc >= 0:
            out.append(cur)
    return out


def ray_exit(pts, c, d):
    """how far the ray from c along d runs before it leaves the polygon pts (the farthest crossing of its edges)"""
    far = 0.0
    for i in range(len(pts)):
        ax, az = pts[i - 1]
        bx, bz = pts[i]
        ex, ez = bx - ax, bz - az
        den = d[0] * ez - d[1] * ex
        if abs(den) < 1e-12:
            continue
        t = ((ax - c[0]) * ez - (az - c[1]) * ex) / den
        u = ((ax - c[0]) * d[1] - (az - c[1]) * d[0]) / den
        if t > 0 and 0.0 <= u <= 1.0:
            far = max(far, t)
    return far


def look_from(ob, source, target):
    d = Vector(target) - Vector(source)
    ob.location = source
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def cells_to_bm(cells, size, origin=(0.0, 0.0, 0.0)):
    """A grid of cubes as a mesh: only the faces that show, with touching faces of one colour merged into big rectangles
    ("greedy meshing"), so a voxel model stays cheap. cells: {(i, j, k): material index}. Cell (i, j, k) spans
    x [i, i + 1) * size and z [k, k + 1) * size, and is centred on y = j * size (so a model is symmetric about y = 0 with an
    odd number of cells across), all moved by origin. Returns the bmesh and its number of quads."""
    bm = bmesh.new()
    low = (0.0, -0.5, 0.0)
    quads = 0
    for d in range(3):
        u, v = (d + 1) % 3, (d + 2) % 3
        for sign in (1, -1):
            planes = {}
            for c, col in cells.items():
                n = list(c)
                n[d] += sign
                if tuple(n) not in cells:  # this face shows
                    planes.setdefault(c[d] + (1 if sign > 0 else 0), {})[(c[u], c[v])] = col
            for plane, mask in planes.items():
                done = set()
                for a, b in sorted(mask):
                    if (a, b) in done:
                        continue
                    col = mask[(a, b)]
                    w = 1
                    while mask.get((a + w, b)) == col and (a + w, b) not in done:
                        w += 1
                    h = 1
                    while all(mask.get((a + i, b + h)) == col and (a + i, b + h) not in done for i in range(w)):
                        h += 1
                    for i in range(w):
                        for j in range(h):
                            done.add((a + i, b + j))
                    corners = [(a, b), (a + w, b), (a + w, b + h), (a, b + h)]
                    if sign < 0:
                        corners.reverse()
                    verts = []
                    for cu, cv in corners:
                        g = [0, 0, 0]
                        g[d], g[u], g[v] = plane, cu, cv
                        verts.append(bm.verts.new([origin[i] + (g[i] + low[i]) * size for i in range(3)]))
                    bm.faces.new(verts).material_index = col
                    quads += 1
    return bm, quads


# ---------------------------------------------------------------- one creature's scene
class Kit:
    """One creature's scene: its materials (one per colour area, named by mat_names, coloured from spec["colours"]), the
    collection its parts go in, each part's pivot in world space, and the cameras and lights it's judged by."""

    def __init__(self, spec, out, mat_names, samples=64):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.spec, self.out = spec, out
        os.makedirs(out, exist_ok=True)
        self.scene = bpy.context.scene
        for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                self.scene.render.engine = engine
                break
            except TypeError:
                pass
        self.scene.view_settings.view_transform = "Standard"
        try:
            self.scene.eevee.taa_render_samples = samples
        except AttributeError:
            pass
        colours = spec["colours"]
        fallback = colours.get("lips") or next(iter(colours.values()))
        self.mat_names = mat_names
        self.mats = {name: material(name, colours.get(name, fallback)) for name in mat_names}
        self.collection = bpy.data.collections.new("Fish")
        self.scene.collection.children.link(self.collection)
        self.world_pos = {}  # each object's pivot in world space, before parenting
        self.sun = self.sun_data = None
        self.frame = spec.get("frame", 1.0)  # every camera stands this many times further off (a big or wide creature)

    # ------------------------------------------------ parts
    def new_object(self, name, me=None):
        ob = bpy.data.objects.new(name, me)
        self.collection.objects.link(ob)
        return ob

    def mesh_object(self, name, bm, origin, mats=None):
        """a mesh object whose pivot is at origin; bm is in world space. mats: the material slots (default: every colour
        area, in mat_names order, so a face's material_index is its colour's place in mat_names)"""
        for v in bm.verts:
            v.co -= Vector(origin)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in mats if mats is not None else self.mat_names:
            me.materials.append(self.mats[m])
        for poly in me.polygons:
            poly.use_smooth = False
        ob = self.new_object(name, me)
        ob.location = origin
        self.world_pos[name] = Vector(origin)
        return ob

    def attach(self, child, parent):
        """parent without moving: the child's location becomes relative to the parent's pivot (nothing is rotated yet)"""
        world = self.world_pos.get(child.name, Vector(child.location))
        child.parent = parent
        child.location = world - self.world_pos[parent.name]

    def face(self, bm, verts, colour):
        """a face in one of the colour areas"""
        f = bm.faces.new(verts)
        f.material_index = self.mat_names.index(colour)
        return f

    # ------------------------------------------------ cameras, light, render
    def camera(self, name, ortho=None, lens=50):
        cam = bpy.data.cameras.new(name)
        if ortho:
            cam.type = "ORTHO"
            cam.ortho_scale = ortho
        else:
            cam.lens = lens
        ob = bpy.data.objects.new(name, cam)
        self.scene.collection.objects.link(ob)
        return ob

    def world(self, hex_colour, strength):
        w = bpy.data.worlds.new("World")
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = hex_rgba(hex_colour)
        bg.inputs["Strength"].default_value = strength
        self.scene.world = w
        return w

    def render(self, cam, path, w, h):
        self.scene.camera = cam
        self.scene.render.resolution_x = w
        self.scene.render.resolution_y = h
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    def studio(self):
        """the turnaround's light: a cream studio and a soft key from in front, left and above"""
        self.world("#FEF8F1", 0.55)
        self.sun_data = bpy.data.lights.new("Key", "SUN")
        self.sun_data.energy = 2.2
        self.sun_data.angle = math.radians(14)
        self.sun = bpy.data.objects.new("Key", self.sun_data)
        self.scene.collection.objects.link(self.sun)
        look_from(self.sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
        self.scene.render.image_settings.file_format = "PNG"

    # ------------------------------------------------ the views
    def turnaround(self, front_x, mid_x):
        """hero (3/4), side, front and top on a transparent background, laid out by tools/art/creature_sheet.py.
        front_x: just in front of the creature's nose; mid_x: halfway from there to its tail's end"""
        scene = self.scene
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        ortho, f = self.spec.get("orthoSide", 14.5), self.frame
        hero = self.camera("Hero", lens=75)  # a long lens from further off, so the 3/4 view doesn't bulge
        look_from(hero, (mid_x - 19.5 * f, -22.5 * f, 7.0 * f), (mid_x + 0.3, 0.0, 0.1))
        self.render(hero, os.path.join(self.out, "hero.png"), 1100, 800)
        side = self.camera("Side", ortho=ortho)
        look_from(side, (mid_x, -30.0, 0.5), (mid_x, 0.0, 0.5))
        self.render(side, os.path.join(self.out, "side.png"), 900, 560)
        self.front = self.camera("Front", lens=85)  # perspective, like the concepts' front views
        look_from(self.front, (front_x - 30.0 * f, 0.0, 3.2 * f), (front_x + 2.0, 0.0, 0.2))
        look_from(self.sun, (-10.0, -1.5, 8.0), (0.0, 0.0, 0.0))  # lit from in front and above, like the concepts' front views
        self.render(self.front, os.path.join(self.out, "front.png"), 560, 560)
        look_from(self.sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
        top = self.camera("Top", ortho=ortho)
        top.location = (mid_x, 0.0, 30.0)
        self.render(top, os.path.join(self.out, "top.png"), 900, 420)

    def wire(self, front_x):
        """a head close-up, then the same and the front view with every mesh edge drawn in red (head.png, head_wire.png,
        front_wire.png): to check the topology. Call after turnaround()."""
        head_cam = self.camera("HeadCam", lens=50)
        f = self.frame
        look_from(head_cam, (front_x - 6.5 * f, -7.0 * f, 2.6 * f), (front_x + 1.7, 0.0, 0.1))
        self.render(head_cam, os.path.join(self.out, "head.png"), 900, 800)
        bpy.context.view_layer.update()
        red = material("Wire", "#E0302A")
        red_bsdf = red.node_tree.nodes.get("Principled BSDF")
        red_bsdf.inputs["Emission Color"].default_value = hex_rgba("#E0302A")
        red_bsdf.inputs["Emission Strength"].default_value = 1.0
        wires = []
        for ob in list(self.collection.objects):
            if ob.type != "MESH":
                continue
            me = ob.data.copy()
            me.materials.clear()
            me.materials.append(red)
            for poly in me.polygons:
                poly.material_index = 0
            wire = bpy.data.objects.new(ob.name + "Wire", me)
            self.scene.collection.objects.link(wire)
            wire.matrix_world = ob.matrix_world.copy()
            mod = wire.modifiers.new("Wire", "WIREFRAME")
            mod.thickness = 0.03
            mod.use_even_offset = False  # even offset throws spikes at sharp corners
            mod.use_replace = True
            wires.append(wire)
        self.render(head_cam, os.path.join(self.out, "head_wire.png"), 900, 800)
        look_from(self.sun, (-10.0, -1.5, 8.0), (0.0, 0.0, 0.0))
        self.render(self.front, os.path.join(self.out, "front_wire.png"), 560, 560)
        look_from(self.sun, (-5.0, -7.0, 9.0), (0.0, 0.0, 0.0))
        for wire in wires:
            wire.hide_render = True

    def swim(self, folder, frames, pose, mid_x):
        """a looping swim: for each frame, pose(phase) turns the joints (phase 0 to 2 pi), then the 3/4, top and riding
        cameras render into folder (hero_000.png, top_000.png, ride_000.png...) for tools/art/swim_gif.py"""
        scene = self.scene
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        os.makedirs(folder, exist_ok=True)
        fr = self.frame
        hero = self.camera("Hero", lens=46)  # wide enough for the whole creature
        look_from(hero, (mid_x - 10.5 * fr, -14.5 * fr, 4.4 * fr), (mid_x + 0.3, 0.0, 0.2))
        top = self.camera("Top", ortho=self.spec.get("orthoSwimTop", 12.4))
        top.location = (mid_x, 0.0, 30.0)
        rider_cam = self.camera("Ride")
        rider_cam.data.sensor_fit = "VERTICAL"
        rider_cam.data.angle_y = math.radians(70)
        look_from(rider_cam, (mid_x + 16.0 * fr, 3.0 * fr, 8.0 * fr), (mid_x - 6.0 * fr, 0.0, 0.5))
        for f in range(frames):
            pose(2 * math.pi * f / frames)
            for name, cam, size in (("hero", hero, (560, 410)), ("top", top, (560, 260)), ("ride", rider_cam, (560, 410))):
                self.render(cam, os.path.join(folder, f"{name}_{f:03d}.png"), *size)

    def solid(self, name, size, hex_colour, location, rotation=(0.0, 0.0, 0.0)):
        """a scenery box with its own colour (not one of the creature's parts)"""
        me = bpy.data.meshes.new(name)
        bm = box_bm(size)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material(name, hex_colour))
        ob = bpy.data.objects.new(name, me)
        self.scene.collection.objects.link(ob)
        ob.location = location
        ob.rotation_euler = rotation
        return ob

    def blob(self, name, radius, hex_colour, location, squash=0.8):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material(name, hex_colour))
        ob = bpy.data.objects.new(name, me)
        self.scene.collection.objects.link(ob)
        ob.location = location
        ob.scale = (1.0, 1.0, squash)
        return ob

    @staticmethod
    def add_fog(m, fog_hex, fog_end):
        """Roblox-style linear fog: the surface fades to the fog colour by its distance from the camera, gone at fog_end"""
        nt = m.node_tree
        out = nt.nodes.get("Material Output")
        surface = out.inputs["Surface"].links[0].from_socket
        cam = nt.nodes.new("ShaderNodeCameraData")
        ramp = nt.nodes.new("ShaderNodeMath")
        ramp.operation = "DIVIDE"
        ramp.use_clamp = True
        ramp.inputs[1].default_value = fog_end
        nt.links.new(cam.outputs["View Distance"], ramp.inputs[0])
        glow = nt.nodes.new("ShaderNodeEmission")
        glow.inputs["Color"].default_value = hex_rgba(fog_hex)
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(ramp.outputs[0], mix.inputs["Fac"])
        nt.links.new(surface, mix.inputs[1])
        nt.links.new(glow.outputs["Emission"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])

    def rider(self, seat_x, seat_top, seat_hw):
        """a 5-stud block figure astride the seat: at seat_x, on a back seat_top high and 2 * seat_hw wide where the legs
        hang. Returns its blocks."""
        blocks = [self.solid("RiderTorso", (1.0, 2.0, 2.0), "#3C78D8", (seat_x, 0.0, seat_top + 1.3)),
                  self.solid("RiderHead", (1.2, 1.2, 1.2), "#F2C9A0", (seat_x, 0.0, seat_top + 2.9))]
        for s in (-1, 1):
            blocks.append(self.solid(f"RiderLeg{s:+d}", (1.0, 1.0, 2.0), "#2B2B33", (seat_x, s * (seat_hw + 0.35), seat_top - 0.4),
                                     (s * math.radians(12), 0.0, 0.0)))
            blocks.append(self.solid(f"RiderArm{s:+d}", (1.6, 0.8, 0.8), "#3C78D8", (seat_x - 0.9, s * 1.25, seat_top + 1.6),
                                     (0.0, math.radians(25), 0.0)))
        return blocks

    def seat_view(self, seat_x, seat_top, seat_hw):
        """seat.png: the rider on the seat in the turnaround's light, from the side and above, to check the seat and where
        the legs hang. Call after turnaround()."""
        blocks = self.rider(seat_x, seat_top, seat_hw)
        cam = self.camera("Seat", lens=60)
        look_from(cam, (seat_x - 7.0, -13.0, seat_top + 7.0), (seat_x, 0.0, seat_top + 0.3))
        self.render(cam, os.path.join(self.out, "seat.png"), 760, 620)
        for b in blocks:
            b.hide_render = True
            b.hide_viewport = True

    def ride(self, seat_x, seat_top, seat_hw):
        """the riding view (ride.png): shallow water with Roblox-style fog, coral on sand, a 5-stud block rider sitting at
        seat_x on a back seat_top high and 2 * seat_hw wide, a Tiny and a Big copy ahead, seen by Roblox's default camera
        (field of view 70) from behind and above"""
        scene = self.scene
        scene.render.film_transparent = False
        fog = self.spec.get("rideFog", "#3CBED2")
        self.world(fog, 1.0)
        look_from(self.sun, (-3.0, 2.0, 10.0), (0.0, 0.0, 0.0))
        self.sun_data.energy = 3.0
        floor_z = -7.0
        self.solid("Sand", (600.0, 600.0, 1.0), "#E9DCB0", (0.0, 0.0, floor_z - 0.5))
        for i, (x, y, r, c) in enumerate(
            [(-30, -14, 3.0, "#FF7A8C"), (-46, 10, 4.0, "#FFAA50"), (-62, -6, 3.5, "#B46EE6"), (-20, 16, 2.5, "#5ADCC8"),
             (-80, 18, 5.0, "#FF7A8C"), (-12, -22, 3.0, "#B46EE6"), (-95, -16, 4.5, "#FFAA50")]
        ):
            self.blob(f"Coral{i}", r, c, (x, y, floor_z + r * 0.4))
        self.rider(seat_x, seat_top, seat_hw)
        # more of the same creature nearby, a Tiny and a Big one: the size variants
        for name, scale, loc, yaw in (("Tiny", 0.55, (-16.0, -7.0, 0.5), 8), ("Big", 1.35, (-34.0, 9.0, 3.0), -6)):
            inst = bpy.data.objects.new(name, None)
            inst.instance_type = "COLLECTION"
            inst.instance_collection = self.collection
            inst.location = (loc[0] * self.frame, loc[1] * self.frame, loc[2])
            inst.scale = (scale, scale, scale)
            inst.rotation_euler = (0.0, 0.0, math.radians(yaw))
            scene.collection.objects.link(inst)
        for m in bpy.data.materials:
            self.add_fog(m, fog, self.spec.get("rideFogEnd", 900.0))
        cam = self.camera("Ride")
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(70)  # Roblox's default field of view
        f = self.frame
        look_from(cam, (14.0 * f, 3.0 * f, 6.5 * f), (-6.0 * f, 0.0, 1.0))
        self.render(cam, os.path.join(self.out, "ride.png"), 1280, 720)

    def voxelize(self, size, shade=0.86, skip=("Eye", "Pupil")):
        """Turn every built part into cubes of one size (docs/style/04-voxel-style.md, way A): a cube is filled where its
        centre is inside the part or within 0.3 of a cube of its surface, takes the nearest face's colour, and every other
        layer is a shade darker (the reference's colour in layers). Faces are merged as in cells_to_bm. Parts that aren't
        turned at rest share one world grid; a turned part (a side fin) uses its own. Returns the triangle count."""
        from mathutils.bvhtree import BVHTree

        bpy.context.view_layer.update()
        darks, triangles = {}, 0
        for ob in list(self.collection.objects):
            if ob.type != "MESH" or ob.name.startswith(skip):
                continue
            me = ob.data
            src = bmesh.new()
            src.from_mesh(me)
            src.faces.ensure_lookup_table()
            tree = BVHTree.FromBMesh(src)
            rot, w = ob.matrix_world.to_3x3(), ob.matrix_world.translation
            aligned = all(abs(rot[i][j] - (1.0 if i == j else 0.0)) < 1e-4 for i in range(3) for j in range(3))
            origin = [-(w[i] % size) for i in range(3)] if aligned else [0.0, 0.0, 0.0]
            layer0 = round((w.z + origin[2]) / size) if aligned else 0
            lo = [min(v.co[i] for v in src.verts) for i in range(3)]
            hi = [max(v.co[i] for v in src.verts) for i in range(3)]
            rng = [range(math.floor((lo[i] - origin[i]) / size) - 1, math.ceil((hi[i] - origin[i]) / size) + 2) for i in range(3)]
            count = len(me.materials)
            cells = {}
            for i in rng[0]:
                for j in rng[1]:
                    for k in rng[2]:
                        p = Vector((origin[0] + (i + 0.5) * size, origin[1] + j * size, origin[2] + (k + 0.5) * size))
                        loc, nrm, idx, dist = tree.find_nearest(p)
                        if loc is None:
                            continue
                        if (p - loc).dot(nrm) < 0 or dist < 0.3 * size:
                            cells[(i, j, k)] = src.faces[idx].material_index + (count if (k + layer0) % 2 else 0)
            src.free()
            for _ in range(2):  # drop stray cubes: any with fewer than two neighbours
                stray = [c for c in cells if sum((c[0] + a, c[1] + b, c[2] + d) in cells for a, b, d in
                                                 ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))) < 2]
                for c in stray:
                    del cells[c]
            bm, quads = cells_to_bm(cells, size, origin)
            triangles += 2 * quads
            new = bpy.data.meshes.new(me.name + "Voxel")
            bm.to_mesh(new)
            bm.free()
            for m in list(me.materials):
                new.materials.append(m)
            for m in list(me.materials):
                if m.name not in darks:
                    d = m.copy()
                    d.name = m.name + "Dark"
                    col = d.node_tree.nodes.get("Principled BSDF").inputs["Base Color"]
                    col.default_value = [c * shade * shade for c in col.default_value[:3]] + [1.0]
                    darks[m.name] = d
                new.materials.append(darks[m.name])
            for poly in new.polygons:
                poly.use_smooth = False
            ob.data = new
        return triangles
