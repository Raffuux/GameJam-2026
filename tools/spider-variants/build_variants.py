"""Builds dressed-up versions of the good-spider-hood jumping spider.

Takes the rigged spider (assets/spider/jumping_spider.blend of good-spider-hood, left
untouched) and adds accessories parented to its bones, so the idle / walk / jump
animations and the procedural IK legs keep working:

  durag_<colour>    satin durag with long tails on the carapace
  bandana_<colour>  paisley bandana tied over the lower face (Grove Street style)
  cap_<colour>      baseball cap with a flat brim and a letter on the front
                    (colours: green, purple, red, blue, black)
  joint   big fat cone joint held in the chelicerae, glowing end and smoke
  skull   realistic black-and-grey skull tattoos painted into the pixel-art atlas
  girl    red stilettos on all eight feet, bigger eyes and long curled lashes

Everything follows the source style: smooth shapes, small pixel-art textures sampled
with nearest filtering. Blender is Z-up and the spider faces +Y (Godot: -Z forward).

Run with Blender 4.2+ (or the bpy module):
    blender -b --python build_variants.py -- <jumping_spider.blend> <out_dir> [variant ...]
Writes <out_dir>/jumping_spider_<variant>.blend (Godot imports it directly, like the
original) and <out_dir>/jumping_spider_<variant>.glb.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-2:]
SRC, OUT = argv[0], argv[1]
VARIANTS = argv[2:] or [f"{kind}_{c}" for kind in ("durag", "bandana", "cap", "capback") for c in ("green", "purple", "red", "blue", "black")] + ["joint", "skull", "girl"]


# --------------------------------------------------------------------------- helpers
def load():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects["JumpingSpiderRig"]
    body = bpy.data.objects["JumpingSpider"]
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return rig, body


def pixel_image(name, ramp, size=16, seed=1, pattern=None):
    """Small pixel-art texture: a dark-to-light ramp picked by noise (and an optional
    pattern(u, v) -> 0..1 that pushes toward the light end)."""
    rnd = random.Random(seed)
    img = bpy.data.images.new(name, size, size, alpha=True)
    px = []
    for y in range(size):
        for x in range(size):
            t = 0.35 + 0.3 * rnd.random()
            if pattern:
                t = max(0.0, min(1.0, t + pattern(x / size, y / size)))
            c = ramp[min(len(ramp) - 1, int(t * len(ramp)))]
            px += [c[0] / 255, c[1] / 255, c[2] / 255, 1.0]
    img.pixels = px
    img.pack()
    return img


def material(name, ramp, rough=0.6, metal=0.0, emit=None, alpha=1.0, seed=1, pattern=None, size=16):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = pixel_image(name + "_px", ramp, size=size, seed=seed, pattern=pattern)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


def hexes(*cs):
    return [tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in cs]


# Colourways for the headwear (Grove green, Ballas purple, red, blue, black).
COLORS = {"green": "1d6a2c", "purple": "5e2580", "red": "a3141e", "blue": "1f4fae", "black": "202026"}


def shades(hex_, ks):
    """Ramp of a colour: one hex per brightness factor, black kept readable."""
    base = [int(hex_[i:i + 2], 16) for i in (0, 2, 4)]
    out = []
    for k in ks:
        c = [min(255, int(v * k + (14 if hex_ == COLORS["black"] else 0) * (k - 0.4))) for v in base]
        out.append("%02x%02x%02x" % tuple(max(0, x) for x in c))
    return hexes(*out)


def add(kind, **kw):
    getattr(bpy.ops.mesh, f"primitive_{kind}_add")(**kw)
    return bpy.context.active_object


def finish(obj, mat, rig, bone, name):
    """Bake the transform into the mesh, smooth it and parent it to a bone in place."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    obj.name = obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    b = rig.data.bones[bone]
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_parent_inverse = (rig.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))).inverted()
    return obj


def align(obj, a, b):
    """Point a +Z primitive from a to b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj.location = (a + b) / 2
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return d.length


def rod(a, b, r1, r2=None, verts=10):
    o = add("cone", vertices=verts, radius1=r1, radius2=r2 if r2 is not None else r1, depth=1)
    o.scale.z = align(o, a, b)
    return o


def surface(body):
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(body, dg)


def eye_centers(body):
    """The four big front eyes: centres of the glossy surface above the chelicerae."""
    me = body.data
    pts = [body.matrix_world @ me.vertices[i].co for p in me.polygons if p.material_index == 1 for i in p.vertices]
    pts = [p for p in pts if p.z > 0.5]
    cents = [-0.19, -0.07, 0.07, 0.19]
    for _ in range(10):
        groups = [[] for _ in cents]
        for p in pts:
            groups[min(range(4), key=lambda k: abs(p.x - cents[k]))].append(p)
        cents = [sum(g, Vector()).x / len(g) for g in groups]
    out = []
    for g in groups:
        c = sum(g, Vector()) / len(g)
        r = max((Vector((p.x, 0, p.z)) - Vector((c.x, 0, c.z))).length for p in g)
        front = max(p.y for p in g)
        out.append((c, r, front))
    return out


def enlarge_eyes(body, eyes, k):
    """Scale the glossy eye bulges up around their centres (the mesh keeps its skinning)."""
    me = body.data
    inv = body.matrix_world.inverted()
    idx = {i for p in me.polygons if p.material_index == 1 for i in p.vertices}
    for i in idx:
        co = body.matrix_world @ me.vertices[i].co
        if co.z <= 0.5:
            continue
        c, r, front = min(eyes, key=lambda e: abs(e[0].x - co.x))
        me.vertices[i].co = inv @ (c + (co - c) * k)
    me.update()


# --------------------------------------------------------------------------- variants
def durag(rig, body, color="purple"):
    satin = material(f"durag_{color}", shades(COLORS[color], (0.45, 0.72, 1.0, 1.3, 1.7)), rough=0.3, seed=3,
                     pattern=lambda u, v: 0.35 * math.sin(u * math.pi * 6) ** 8)
    # Cap: the top of an ellipsoid shrink-wrapped onto the carapace, behind the eyes.
    cap = add("uv_sphere", segments=32, ring_count=16, radius=1, location=(0, 0.19, 0.36))
    cap.scale = (0.37, 0.34, 0.4)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.5 or v.co.y > 0.44], context="VERTS")
    bm.to_mesh(cap.data)
    bm.free()
    sw = cap.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = body
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.offset = 0.022
    sol = cap.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.015
    bpy.context.view_layer.objects.active = cap
    for m in list(cap.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    finish(cap, satin, rig, "body", "durag_cap")
    # Seam on top, the knot at the back of the head and two long tails lying on
    # the abdomen (ribbons following its surface).
    seam = rod((0, 0.4, 0.745), (0, 0.0, 0.66), 0.016, verts=6)
    finish(seam, satin, rig, "body", "durag_seam")
    knot = add("uv_sphere", segments=12, ring_count=8, radius=0.07, location=(0, 0.0, 0.62))
    knot.scale = (1.2, 0.8, 0.7)
    finish(knot, satin, rig, "body", "durag_knot")
    bvh = surface(body)
    for side in (1, -1):
        bm = bmesh.new()
        rows = []
        steps = 16
        for i in range(steps + 1):
            t = i / steps
            y = 0.0 - 0.78 * t
            x = side * (0.03 + 0.12 * t) + 0.025 * math.sin(t * 7 + side)
            w = 0.05 - 0.012 * t
            row = []
            for dx in (-w, w):
                hit = bvh.ray_cast(Vector((x + dx, y, 2)), Vector((0, 0, -1)))
                z = (hit[0].z if hit[0] else 0.3) + 0.025
                row.append(bm.verts.new((x + dx, y, z)))
            rows.append(row)
        uvl = bm.loops.layers.uv.new()
        for i, (r0, r1) in enumerate(zip(rows, rows[1:])):
            f = bm.faces.new((r0[0], r0[1], r1[1], r1[0]))
            for loop, (u, v) in zip(f.loops, ((0, i), (1, i), (1, i + 1), (0, i + 1))):
                loop[uvl].uv = (u * 0.25, v / steps)
        me = bpy.data.meshes.new("tail")
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("tail", me)
        bpy.context.collection.objects.link(obj)
        sol = obj.modifiers.new("thick", "SOLIDIFY")
        sol.thickness = 0.012
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier="thick")
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        finish(obj, satin, rig, "abdomen", f"durag_tail_{'R' if side > 0 else 'L'}")


def joint(rig, body):
    """A big fat cone joint held in the chelicerae: twisted crutch end in the mouth,
    wide lit end with ash and a glowing ember, smoke rising."""
    paper = material("joint_paper", hexes("cfc6b0", "e4dcc8", "f2ecdf", "fbf8f0"), rough=0.85, seed=5,
                     pattern=lambda u, v: -0.3 if abs(u - 0.5) < 0.04 else 0)
    crutch = material("joint_crutch", hexes("8a6a3a", "a8844e", "c4a066"), rough=0.9, seed=6)
    ember = material("joint_ember", hexes("ff4a12", "ff7a1e", "ffb43a", "ffe08a"), rough=0.6, emit=4, seed=7)
    ash = material("joint_ash", hexes("3a3633", "5a5550", "7c7670", "9a948c"), rough=1, seed=8)
    smoke = material("joint_smoke", hexes("8a8784", "a5a29e", "c2bfbb"), rough=1, alpha=0.4, seed=9)
    mouth = Vector((0.03, 0.6, 0.28))
    d = Vector((0.3, 0.92, 0.12)).normalized()
    length = 0.8
    tip = mouth + d * length
    finish(rod(mouth - d * 0.02, mouth + d * 0.12, 0.034, 0.04, verts=10), crutch, rig, "body", "joint_crutch")
    # The cone: thin at the mouth, fat at the lit end, with a slight bulge.
    cone = rod(mouth + d * 0.12, tip - d * 0.05, 0.042, 0.1, verts=16)
    finish(cone, paper, rig, "body", "joint_paper")
    finish(rod(tip - d * 0.05, tip, 0.1, 0.085, verts=16), ash, rig, "body", "joint_ash")
    glow = add("cylinder", vertices=16, radius=0.07, depth=0.02)
    align(glow, tip - d * 0.005, tip + d * 0.012)
    glow.scale.z = 0.02
    finish(glow, ember, rig, "body", "joint_ember")
    # Thick smoke rising from the lit end.
    for i, (dx, dz, r) in enumerate([(0.0, 0.1, 0.06), (0.05, 0.24, 0.08), (-0.02, 0.42, 0.1), (0.05, 0.62, 0.12)]):
        puff = add("ico_sphere", subdivisions=2, radius=r, location=tip + Vector((dx, 0.03 * i, dz)))
        finish(puff, smoke, rig, "body", f"joint_smoke_{i}")
    light = bpy.data.lights.new("joint_glow", "POINT")
    light.color = (1, 0.45, 0.15)
    light.energy = 0.05
    lo = bpy.data.objects.new("joint_glow", light)
    bpy.context.collection.objects.link(lo)
    lo.location = tip + d * 0.05
    b = rig.data.bones["body"]
    lo.parent = rig
    lo.parent_type = "BONE"
    lo.parent_bone = "body"
    lo.matrix_parent_inverse = (rig.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))).inverted()


def paisley(u, v):
    """Paisley bandana print, two motifs per tile: a teardrop with a dark outline,
    a light centre dot and a few light specks around."""
    a, b = (u * 2) % 1, (v * 2) % 1
    flip = (int(u * 2) + int(v * 2)) % 2
    if flip:
        a, b = 1 - a, 1 - b
    dx, dy = a - 0.42, b - 0.42
    # Teardrop: a circle stretched into a curled tail toward the top right.
    r = math.hypot(dx, dy)
    tail = max(0, (dx + dy) * 0.7)
    rr = r - tail * 0.35
    if rr < 0.07:
        return 0.9
    if rr < 0.17:
        return 0.0 if rr > 0.12 else 0.9 * (int((a + b) * 20) % 2)
    if rr < 0.22:
        return -0.9
    if (int(a * 16) * 7 + int(b * 16) * 3) % 11 == 0:
        return 0.9
    return 0.0


def bandana(rig, body, color="green"):
    """Grove Street style: a paisley bandana tied over the lower face like a mask,
    covering the chelicerae, knotted at the back of the head."""
    cloth = material(f"bandana_{color}", shades(COLORS[color], (0.4, 1.0, 1.2)) + hexes("e6e2d8"), rough=0.85, seed=21,
                     pattern=paisley, size=32)
    bvh = surface(body)
    # Triangle of cloth in front of the face: rows from just under the eyes down to a point.
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new()
    rows = []
    top, bottom, half = 0.53, -0.02, 0.37
    nz, nx = 12, 12
    for i in range(nz + 1):
        t = i / nz
        z = top + (bottom - top) * t
        w = half * (1 - t) ** 0.9 + 0.015
        row = []
        for j in range(nx + 1):
            x = -w + 2 * w * j / nx
            hit = bvh.ray_cast(Vector((x, 3, z)), Vector((0, -1, 0)))
            y = (hit[0].y if hit[0] else 0.55) + 0.06
            # Hang straight down in front of the chelicerae, wrap back at the sides.
            y = max(y, 0.66 - 0.5 * (x / half) ** 2) if z < 0.4 else y
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(nz):
        for j in range(nx):
            f = bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
            for loop, (uu, vv) in zip(f.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                loop[uvl].uv = (uu / nx * 2, 1 - vv / nz * 2)
    me = bpy.data.meshes.new("bandana_mask")
    bm.to_mesh(me)
    bm.free()
    mask = bpy.data.objects.new("bandana_mask", me)
    bpy.context.collection.objects.link(mask)
    sol = mask.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.014
    bpy.context.view_layer.objects.active = mask
    bpy.ops.object.modifier_apply(modifier="thick")
    finish(mask, cloth, rig, "body", "bandana_mask")
    # Band around the head at the top edge, from the cheeks to the knot at the back.
    pts = []
    for k in range(25):
        ang = math.radians(-20 + 220 * k / 24)  # from the right cheek round the back to the left cheek
        dirv = Vector((math.cos(ang), math.sin(ang) * -1, 0))
        # Cast from inside the head outward, so the legs never get in the way.
        o = Vector((0, 0.18, 0.53))
        hit = bvh.ray_cast(o, dirv, 0.6)
        p = (hit[0] if hit[0] else o + dirv * 0.35) + dirv * 0.03
        pts.append((p.x, p.y, p.z))
    curve = bpy.data.curves.new("band", "CURVE")
    curve.dimensions = "3D"
    sp = curve.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for pt, c in zip(sp.points, pts):
        pt.co = (*c, 1)
    curve.bevel_depth = 0.03
    curve.bevel_resolution = 1
    band = bpy.data.objects.new("bandana_band", curve)
    bpy.context.collection.objects.link(band)
    bpy.ops.object.select_all(action="DESELECT")
    band.select_set(True)
    bpy.context.view_layer.objects.active = band
    bpy.ops.object.convert(target="MESH")
    band = bpy.context.active_object
    finish(band, cloth, rig, "body", "bandana_band")
    # Knot and two short tails at the back of the head.
    back = bvh.ray_cast(Vector((0, -1.5, 0.55)), Vector((0, 1, 0)))[0] or Vector((0, -0.1, 0.55))
    knot = add("uv_sphere", segments=10, ring_count=6, radius=0.055, location=back + Vector((0, -0.04, 0.02)))
    finish(knot, cloth, rig, "body", "bandana_knot")
    for k in (1, -1):
        tail = add("cube", size=1, location=back + Vector((k * 0.05, -0.1, -0.03)))
        tail.scale = (0.06, 0.14, 0.012)
        tail.rotation_euler = (0.5, 0, k * 0.4)
        finish(tail, cloth, rig, "body", f"bandana_tail_{'R' if k > 0 else 'L'}")


def skull_shade(u, v):
    """Black-and-grey realistic skull with crossbones in [-1, 1]^2 (v up).
    Returns ink amount 0..1 (0 = no ink) and a light level for the shading."""
    def ell(x, y, cx, cy, rx, ry):
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2

    cran = ell(u, v, 0, 0.22, 0.62, 0.58)
    jaw = ell(u, v, 0, -0.42, 0.36, 0.26)
    cheek = min(ell(u, v, -0.34, -0.12, 0.2, 0.18), ell(u, v, 0.34, -0.12, 0.2, 0.18))
    inside = cran < 1 or jaw < 1 or cheek < 1 or (abs(u) < 0.3 and -0.45 < v < 0.1)
    bones = False
    for s in (1, -1):
        # Crossbones behind the skull.
        t = (u * s + (v + 0.25) * 1.0)
        w = abs(u * s - (v + 0.25)) / 1.414
        if w < 0.08 and abs(t) < 1.25:
            bones = True
        for e in (-1, 1):
            ex, ey = e * 0.62 * s, -0.25 + e * 0.62
            if ell(u, v, ex - 0.06 * s * e, ey + 0.06 * e, 0.11, 0.11) < 1 or ell(u, v, ex + 0.06 * s * e, ey - 0.06 * e, 0.11, 0.11) < 1:
                bones = True
    if not inside:
        if bones:
            return 1.0, 0.55
        return 0.0, 0.0
    # Soft shading: lit from the top left, darker towards the rim (black-and-grey style).
    light = 0.82 - 0.45 * max(0, min(cran, jaw + 0.3) - 0.35) + 0.18 * (v - u) * 0.5
    # Eye sockets: dark, with a soft rim.
    for s in (-1, 1):
        e = ell(u, v, s * 0.24, 0.02, 0.19, 0.17)
        if e < 1:
            light = 0.05 + 0.35 * e ** 2
    # Nose: an upside-down heart.
    if abs(u) < 0.09 * (1 - (v + 0.32) / 0.2) and -0.32 < v < -0.12:
        light = 0.12
    # Teeth with dark gaps, and the temple shadows.
    if -0.56 < v < -0.36 and abs(u) < 0.3:
        light = 0.15 if (abs(v + 0.46) < 0.02 or int((u + 0.3) / 0.075) % 2 == 0 and abs(((u + 0.3) % 0.075) - 0.0375) > 0.03) else 0.85
    if abs(u) > 0.42 and v > -0.05:
        light -= 0.25
    return 1.0, max(0.05, min(1.0, light))


def skull(rig, body):
    """Paint skull tattoos into a copy of the pixel-art atlas: a big skull and crossbones
    on the abdomen and a small skull on the carapace behind the eyes."""
    me = body.data
    src = next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    W, H = src.size
    px = list(src.pixels)
    uv = me.uv_layers.active.data
    ink = [(18, 16, 15), (60, 56, 52), (110, 104, 98), (170, 164, 156), (225, 220, 210)]
    designs = [  # (centre, half width, half height, up axis) in model space, on the top surface
        (Vector((0, -0.5, 0.0)), 0.3, 0.34, 1),
        (Vector((0, 0.16, 0.0)), 0.15, 0.15, 1),
    ]
    def paint(x, y, p, n):
        if n.z < 0.25:
            return
        for c, hw, hh, up in designs:
            u = (p.x - c.x) / hw
            v = (p.y - c.y) / hh * up  # +v points to the head, so the skull reads from the camera behind
            if abs(u) <= 1 and abs(v) <= 1:
                a, light = skull_shade(u, v)
                if a:
                    col = ink[min(4, int(light * 5))]
                    i = (y * W + x) * 4
                    px[i:i + 3] = [col[0] / 255, col[1] / 255, col[2] / 255]
    for poly in me.polygons:
        if poly.material_index != 0:
            continue
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            tri = [loops[0], loops[k], loops[k + 1]]
            uvs = [uv[l].uv * Vector((W, H)) for l in tri]
            ps = [body.matrix_world @ me.vertices[me.loops[l].vertex_index].co for l in tri]
            n = (body.matrix_world.to_3x3() @ poly.normal).normalized()
            x0, x1 = int(min(q.x for q in uvs)), int(max(q.x for q in uvs)) + 1
            y0, y1 = int(min(q.y for q in uvs)), int(max(q.y for q in uvs)) + 1
            (ax, ay), (bx, by), (cx, cy) = uvs
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            for y in range(max(0, y0), min(H, y1)):
                for x in range(max(0, x0), min(W, x1)):
                    qx, qy = x + 0.5, y + 0.5
                    w0 = ((by - cy) * (qx - cx) + (cx - bx) * (qy - cy)) / den
                    w1 = ((cy - ay) * (qx - cx) + (ax - cx) * (qy - cy)) / den
                    w2 = 1 - w0 - w1
                    if min(w0, w1, w2) < -0.02:
                        continue
                    paint(x, y, ps[0] * w0 + ps[1] * w1 + ps[2] * w2, n)
    img = bpy.data.images.new("jumping_spider_atlas_skull", W, H)
    img.pixels = px
    img.pack()
    for mat in me.materials:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = img


def girl(rig, body):
    red = material("heel_red", hexes("6e0a12", "a3101e", "d11a2a", "f04a55"), rough=0.2, seed=11)
    black = material("lash_black", hexes("050505", "121212", "222222"), rough=0.35, seed=12)
    eyes = eye_centers(body)
    enlarge_eyes(body, eyes, 1.3)
    eyes = eye_centers(body)
    # Red stilettos on all eight feet.
    for side in ("R", "L"):
        for k in range(1, 5):
            b = rig.data.bones[f"leg_{side}{k}_tarsus"]
            tip = rig.matrix_world @ b.tail_local
            head = rig.matrix_world @ b.head_local
            d = (tip - head).normalized()
            out = Vector((d.x, d.y, 0)).normalized()
            n = f"heel_{side}{k}"
            finish(rod(tip - d * 0.17, tip + d * 0.01, 0.058, 0.05, verts=12), red, rig, b.name, n + "_shoe")
            heel_top = tip - out * 0.15 + Vector((0, 0, 0.13))
            finish(rod(Vector((heel_top.x, heel_top.y, tip.z - 0.02)), heel_top, 0.011, 0.024, verts=8), red, rig, b.name, n + "_heel")
            sole = rod(tip + Vector((0, 0, 0.0)), heel_top, 0.022, 0.03, verts=6)
            sole.scale.x = 2.0
            finish(sole, red, rig, b.name, n + "_sole")
    # Long curled lashes over the four front eyes, flicked out at the outer corners.
    for c, r, front in eyes:
        outer = 1 if c.x > 0 else -1
        count = 7 if abs(c.x) < 0.12 else 5
        for j in range(count):
            t = j / (count - 1)
            a = math.radians(30 + 120 * t)
            if outer < 0:
                a = math.pi - a  # mirror so the long ones sit on the outer side
            base = Vector((c.x + math.cos(a) * r * 0.92, front - 0.03, c.z + math.sin(a) * r * 0.92))
            length = 0.05 + 0.035 * (1 - t)  # longer toward the outer corner
            radial = Vector((math.cos(a), 0, math.sin(a)))
            # Out from the eye, then curling up and back: a 4-point curve with a taper.
            p0 = base
            p1 = p0 + (radial * 0.5 + Vector((0, 0.9, 0.1))).normalized() * length * 0.45
            p2 = p1 + (radial * 0.4 + Vector((0, 0.35, 0.9))).normalized() * length * 0.35
            p3 = p2 + (radial * 0.2 + Vector((0, -0.4, 0.9))).normalized() * length * 0.25
            curve = bpy.data.curves.new("lash", "CURVE")
            curve.dimensions = "3D"
            sp = curve.splines.new("NURBS")
            sp.points.add(3)
            for pt, q, rad in zip(sp.points, (p0, p1, p2, p3), (1.0, 0.8, 0.5, 0.15)):
                pt.co = (*q, 1)
                pt.radius = rad
            sp.order_u = 3
            sp.use_endpoint_u = True
            curve.bevel_depth = 0.008
            curve.bevel_resolution = 1
            curve.resolution_u = 4
            lash = bpy.data.objects.new("lash", curve)
            bpy.context.collection.objects.link(lash)
            bpy.ops.object.select_all(action="DESELECT")
            lash.select_set(True)
            bpy.context.view_layer.objects.active = lash
            bpy.ops.object.convert(target="MESH")
            finish(bpy.context.active_object, black, rig, "body", f"lash_{round(c.x, 2)}_{j}")


def cap(rig, body, color="green", back=False):
    """Baseball cap: a dome over the carapace, a flat brim over the eyes, a top button
    and a white letter on the front panel. `back` turns it around (brim and letter
    at the rear)."""
    s = -1 if back else 1
    felt = material(f"cap_{color}", shades(COLORS[color], (0.5, 0.8, 1.0, 1.15)), rough=0.8, seed=31)
    white = material("cap_logo", hexes("d8d4ca", "ece8de", "f8f6f0"), rough=0.6, seed=32)
    cy, cz, rx, ry, rz = 0.25, 0.66, 0.31, 0.3, 0.26
    crown = add("uv_sphere", segments=32, ring_count=16, radius=1, location=(0, cy, cz))
    crown.scale = (rx, ry, rz)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(crown.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cz - 0.01], context="VERTS")
    bm.to_mesh(crown.data)
    bm.free()
    sol = crown.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.02
    bpy.context.view_layer.objects.active = crown
    bpy.ops.object.modifier_apply(modifier="thick")
    bpy.ops.object.shade_smooth()
    finish(crown, felt, rig, "body", "cap_crown")
    # Half-disc brim from the dome, tilted down (up when worn backwards) and curved at the sides.
    bm = bmesh.new()
    y0, depth, half = ry * 0.8, 0.32, 0.28
    pts = [(half * math.cos(t), depth * math.sin(t)) for t in (math.pi * k / 16 for k in range(17))]
    verts = []
    for x, d in pts:
        lift = 0.1 * d if back else -0.12 * max(0, d - 0.1)
        verts.append(bm.verts.new((x, cy + s * (y0 + d), cz + 0.01 + lift - 0.05 * (x / half) ** 2)))
    bm.faces.new(verts[::s])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x * 2 + 0.5, loop.vert.co.y * 2)
    mesh = bpy.data.meshes.new("cap_brim")
    bm.to_mesh(mesh)
    bm.free()
    brim = bpy.data.objects.new("cap_brim", mesh)
    bpy.context.collection.objects.link(brim)
    bpy.ops.object.select_all(action="DESELECT")
    brim.select_set(True)
    bpy.context.view_layer.objects.active = brim
    sol = brim.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.025
    bpy.ops.object.modifier_apply(modifier="thick")
    finish(brim, felt, rig, "body", "cap_brim")
    button = add("uv_sphere", segments=10, ring_count=6, radius=0.035, location=(0, cy, cz + rz + 0.01))
    button.scale.z = 0.6
    finish(button, felt, rig, "body", "cap_button")
    # A white letter on the front panel, facing along the dome normal.
    t = math.radians(52)
    dy, dz = ry * math.sin(t), rz * math.cos(t)
    tilt = math.atan2(dy / ry ** 2, dz / rz ** 2)
    font = bpy.data.curves.new("cap_logo", "FONT")
    font.body = "S"
    font.size = 0.15
    font.extrude = 0.008
    font.align_x = "CENTER"
    font.align_y = "CENTER"
    logo = bpy.data.objects.new("cap_logo", font)
    bpy.context.collection.objects.link(logo)
    logo.location = (0, cy + s * (dy + 0.022 * math.sin(tilt)), cz + dz + 0.022 * math.cos(tilt))
    logo.rotation_mode = "ZYX"  # spin the letter about its normal first, then tilt
    logo.rotation_euler = (-s * tilt, 0, math.pi if s > 0 else 0)
    bpy.ops.object.select_all(action="DESELECT")
    logo.select_set(True)
    bpy.context.view_layer.objects.active = logo
    bpy.ops.object.convert(target="MESH")
    logo = bpy.context.active_object
    finish(logo, white, rig, "body", "cap_logo")


BUILDERS = {"durag": durag, "bandana": bandana, "cap": cap, "capback": lambda r, b, c: cap(r, b, c, back=True), "joint": joint, "skull": skull, "girl": girl}

for name in VARIANTS:
    rig, body = load()
    kind, _, color = name.partition("_")
    BUILDERS[kind](rig, body, color) if color else BUILDERS[kind](rig, body)
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"jumping_spider_{name}.blend"), compress=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"jumping_spider_{name}.glb"), export_format="GLB",
                              export_animations=True, export_lights=True)
    print("built", name)
