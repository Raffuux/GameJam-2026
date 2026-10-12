extends RefCounted
## Silk for the mission cutscenes, built in code: Web Smith's failed webs, the cocoon he gets
## tangled in, and the web that finally holds. Every thread is a thin white cylinder.

const SILK := Color("f4f1e8")
const TWIG := Color("6b4a2b")


## One straight thread from `a` to `b`, in `parent`'s space.
static func thread(parent: Node3D, a: Vector3, b: Vector3, radius := 0.00025, color := SILK) -> MeshInstance3D:
    var line := MeshInstance3D.new()
    var tube := CylinderMesh.new()
    tube.top_radius = radius
    tube.bottom_radius = radius
    tube.height = maxf(a.distance_to(b), 0.00001)
    tube.radial_segments = 4
    tube.rings = 1
    line.mesh = tube
    line.material_override = _material(color)
    parent.add_child(line)
    var dir := (b - a).normalized()
    var side := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
    var x := side.cross(dir).normalized()
    line.transform = Transform3D(Basis(x, dir, x.cross(dir)), (a + b) * 0.5)
    return line


## A thread that sags between `a` and `b` by `sag` metres, in `pieces` straight bits.
static func sagging(parent: Node3D, a: Vector3, b: Vector3, sag: float, pieces := 5, radius := 0.00025) -> void:
    var prev := a
    for i in range(1, pieces + 1):
        var u := float(i) / pieces
        var p := a.lerp(b, u) + Vector3.DOWN * sag * sin(u * PI)
        thread(parent, prev, p, radius)
        prev = p


## Web Smith's failed web: two twigs stuck in the ground `width` apart and a few crooked,
## sagging threads between them, one of them snapped and hanging. Faces -Z; its base is the origin.
static func messy_web(width: float, height: float, seed := 7) -> Node3D:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var web := Node3D.new()
    web.name = "MessyWeb"
    var left := Vector3(-width * 0.5, 0, 0)
    var right := Vector3(width * 0.5, 0, 0)
    for base in [left, right]:
        thread(web, base, base + Vector3(rng.randf_range(-0.1, 0.1) * width, height, 0), height * 0.035, TWIG)
    for k in 6:
        var a := left + Vector3(0, rng.randf_range(0.25, 0.95) * height, 0)
        var b := right + Vector3(0, rng.randf_range(0.25, 0.95) * height, 0)
        sagging(web, a, b, rng.randf_range(0.05, 0.3) * height)
    # one snapped thread hanging down from the right twig
    var top := right + Vector3(0, height * 0.8, 0)
    thread(web, top, top + Vector3(-width * 0.12, -height * 0.55, 0.002))
    return web


## A messy ball of silk around something `radius` wide: what Web Smith gets tangled in.
static func cocoon(radius: float, seed := 3) -> Node3D:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var ball := Node3D.new()
    ball.name = "Cocoon"
    for k in 90:
        var a := _on_sphere(rng) * radius * rng.randf_range(0.8, 1.15)
        var b := _on_sphere(rng) * radius * rng.randf_range(0.8, 1.15)
        thread(ball, a, b, radius * 0.007)
    return ball


## A round web, `radius` wide, between anchor threads: the one that finally holds. Faces -Z.
static func orb_web(radius: float, spokes := 12, turns := 7) -> Node3D:
    var web := Node3D.new()
    web.name = "OrbWeb"
    var r := radius * 0.012
    var ends: Array[Vector3] = []
    for i in spokes:
        var a := TAU * i / spokes
        ends.append(Vector3(cos(a), sin(a), 0) * radius)
        thread(web, Vector3.ZERO, ends[-1], r)
    for k in range(1, turns + 1):
        var f := float(k) / turns
        for i in spokes:
            thread(web, ends[i] * f, ends[(i + 1) % spokes] * f, r * 0.8)
    return web


static func _on_sphere(rng: RandomNumberGenerator) -> Vector3:
    var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
    return v.normalized() if v.length() > 0.01 else Vector3.UP


static func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.6
    return mat
