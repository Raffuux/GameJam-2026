"""Builds dressed-up versions of the good-spider-hood jumping spider.

Takes the rigged spider (assets/spider/jumping_spider.blend of good-spider-hood, left
untouched) and adds accessories parented to its bones, so the idle / walk / jump
animations and the procedural IK legs keep working:

  durag   satin durag with long tails on the carapace
  joint   long hand-rolled cigarette held in the chelicerae, glowing tip and smoke
  skull   realistic black-and-grey skull tattoos painted into the pixel-art atlas
  girl    red stilettos on all eight feet, eyelashes, a bow and four handbags

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
VARIANTS = argv[2:] or ["durag", "joint", "skull", "girl"]


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


# --------------------------------------------------------------------------- variants
def durag(rig, body):
    satin = material("durag_satin", hexes("2a0f3a", "45185e", "5e2580", "7d3aa6", "a35fcc"), rough=0.3, seed=3,
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
    paper = material("joint_paper", hexes("cfc6b0", "e4dcc8", "f2ecdf", "fbf8f0"), rough=0.85, seed=5,
                     pattern=lambda u, v: -0.25 if int(v * 16) % 5 == 0 else 0)
    crutch = material("joint_crutch", hexes("8a6a3a", "a8844e", "c4a066"), rough=0.9, seed=6)
    ember = material("joint_ember", hexes("ff4a12", "ff7a1e", "ffb43a", "ffe08a"), rough=0.6, emit=4, seed=7)
    ash = material("joint_ash", hexes("3a3633", "5a5550", "7c7670"), rough=1, seed=8)
    smoke = material("joint_smoke", hexes("8a8784", "a5a29e", "c2bfbb"), rough=1, alpha=0.4, seed=9)
    mouth = Vector((0.02, 0.6, 0.3))
    d = Vector((0.32, 0.92, 0.2)).normalized()
    length = 0.72
    tip = mouth + d * length
    finish(rod(mouth, mouth + d * 0.1, 0.03, 0.033), crutch, rig, "body", "joint_crutch")
    finish(rod(mouth + d * 0.1, tip - d * 0.03, 0.033, 0.046, verts=12), paper, rig, "body", "joint_paper")
    finish(rod(tip - d * 0.03, tip, 0.046, 0.04, verts=12), ash, rig, "body", "joint_ash")
    glow = add("uv_sphere", segments=10, ring_count=6, radius=0.036, location=tip)
    finish(glow, ember, rig, "body", "joint_ember")
    # A few puffs of smoke curling up from the tip.
    for i, (dx, dz, r) in enumerate([(0.0, 0.08, 0.035), (0.04, 0.19, 0.05), (-0.01, 0.33, 0.06)]):
        puff = add("ico_sphere", subdivisions=2, radius=r, location=tip + Vector((dx, 0.02 * i, dz)))
        finish(puff, smoke, rig, "body", f"joint_smoke_{i}")
    light = bpy.data.lights.new("joint_glow", "POINT")
    light.color = (1, 0.45, 0.15)
    light.energy = 0.03
    lo = bpy.data.objects.new("joint_glow", light)
    bpy.context.collection.objects.link(lo)
    lo.location = tip
    b = rig.data.bones["body"]
    lo.parent = rig
    lo.parent_type = "BONE"
    lo.parent_bone = "body"
    lo.matrix_parent_inverse = (rig.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))).inverted()


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
    pink = material("bow_pink", hexes("b0386e", "d9559a", "f07ab8", "ffa8d4"), rough=0.5, seed=13)
    gold = material("bag_gold", hexes("8a6414", "c9971e", "f0c64a"), rough=0.25, metal=1, seed=14)
    bags = [
        material("bag_pink", hexes("a8306a", "d04a8c", "ec73ad"), rough=0.4, seed=15),
        material("bag_red", hexes("6a0c14", "9a1420", "c42230"), rough=0.3, seed=16),
        material("bag_leopard", hexes("3a2210", "c48a3c", "dca456", "e8bc72"), rough=0.6, seed=17,
                 pattern=lambda u, v: -0.9 if (math.sin(u * 37) + math.sin(v * 41 + u * 9)) > 1.3 else 0.2),
        material("bag_black", hexes("0c0c0e", "1c1c20", "303036"), rough=0.3, seed=18),
    ]
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
    # Eyelashes over the four front eyes, curling up and out.
    for c, r, front in eye_centers(body):
        for j in range(5):
            a = math.radians(45 + 22.5 * j)
            base = Vector((c.x + math.cos(a) * r * 0.8, front - 0.025, c.z + math.sin(a) * r * 0.8))
            outw = Vector((math.cos(a) * 0.6, 1.0, math.sin(a) * 0.6 + 0.25)).normalized()
            finish(rod(base, base + outw * (0.035 + 0.012 * (j % 2)), 0.008, 0.0015, verts=5), black, rig, "body", f"lash_{j}_{round(c.x, 2)}")
    # A pink bow on top of the head, a little to the side.
    bow_c = Vector((0.14, 0.24, 0.71))
    for k in (1, -1):
        loop = add("uv_sphere", segments=12, ring_count=8, radius=1, location=bow_c + Vector((k * 0.07, 0, 0.01)))
        loop.scale = (0.07, 0.035, 0.05)
        loop.rotation_euler.y = k * 0.35
        finish(loop, pink, rig, "body", f"bow_{'R' if k > 0 else 'L'}")
    knot = add("uv_sphere", segments=10, ring_count=6, radius=0.03, location=bow_c)
    finish(knot, pink, rig, "body", "bow_knot")
    # Four handbags hooked on the front legs.
    for (side, k), mat in zip([("R", 1), ("L", 1), ("R", 2), ("L", 2)], bags):
        b = rig.data.bones[f"leg_{side}{k}_tibia"]
        h = rig.matrix_world @ b.head_local
        t = rig.matrix_world @ b.tail_local
        mid = h.lerp(t, 0.45)
        axis = (t - h).normalized()
        out = Vector((mid.x, mid.y - 0.1, 0)).normalized()
        handle = add("torus", major_radius=0.09, minor_radius=0.013, major_segments=16, minor_segments=6, location=mid + out * 0.05 - Vector((0, 0, 0.06)))
        handle.rotation_mode = "QUATERNION"
        handle.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis)
        finish(handle, gold if k == 2 else mat, rig, b.name, f"bag_{side}{k}_handle")
        out = Vector((mid.x, mid.y - 0.1, 0)).normalized()  # away from the body
        bag = add("cube", size=1, location=mid + out * 0.1 - Vector((0, 0, 0.2)))
        bag.scale = (0.2, 0.09, 0.15)
        bag.rotation_euler.z = math.atan2(out.y, out.x) + math.pi / 2
        bev = bag.modifiers.new("round", "BEVEL")
        bev.width = 0.025
        bev.segments = 3
        bpy.context.view_layer.objects.active = bag
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bpy.ops.object.modifier_apply(modifier="round")
        finish(bag, mat, rig, b.name, f"bag_{side}{k}")
        clasp = add("cube", size=0.035, location=mid + out * 0.15 - Vector((0, 0, 0.15)))
        finish(clasp, gold, rig, b.name, f"bag_{side}{k}_clasp")


BUILDERS = {"durag": durag, "joint": joint, "skull": skull, "girl": girl}

for name in VARIANTS:
    rig, body = load()
    BUILDERS[name](rig, body)
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"jumping_spider_{name}.blend"), compress=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"jumping_spider_{name}.glb"), export_format="GLB",
                              export_animations=True, export_lights=True)
    print("built", name)
