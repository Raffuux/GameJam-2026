extends RefCounted
## Le mobilier urbain et les déchets, à l'échelle d'un insecte (1 unité = 1 cm).
## Chaque fonction pose les meshes ET les collisions. Si un modèle .glb du même nom
## existe dans res://assets/models/, il remplace la version en primitives.

const MODELS_DIR := "res://assets/models/"
const Builder := preload("res://scripts/city/builder.gd")


## Essaie de poser le modèle .glb du thread assets. Renvoie true si c'est fait.
## Les collisions des primitives restent, pour garder un gameplay stable.
static func try_model(b: Builder, model: String, pos: Vector3, rot_y: float = 0.0, scale: float = 1.0) -> bool:
	var path := MODELS_DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * scale
	b.root.add_child(inst)
	return true


# ---------- Rue ----------

static func streetlight(b: Builder, pos: Vector3, rot_y: float) -> void:
	var g: Node3D = b.group(pos, rot_y)
	b.cyl(Vector3.ZERO, 0.5, 0.7, 32.0, Color("3a3f45"), true, 6, g)
	b.box(Vector3(0, 31, -3), Vector3(0.8, 0.8, 7), Color("3a3f45"), false, 0.0, g)
	b.box(Vector3(0, 29.5, -6.5), Vector3(2.4, 1.6, 2.4), b.glow(Color("ffd98a"), 3.0), false, 0.0, g)


static func hydrant(b: Builder, pos: Vector3) -> void:
	if try_model(b, "bouche_incendie", pos):
		b.cyl(pos, 2.0, 2.0, 7.0, Color(), true).visible = false
		return
	var red := Color("c8312a")
	b.cyl(pos, 2.0, 2.2, 6.0, red)
	b.cyl(pos + Vector3(0, 6, 0), 0.6, 2.1, 1.8, red, false)
	b.cyl(pos + Vector3(0, 7.6, 0), 0.5, 0.5, 0.8, Color("e0b23a"), false)
	for s in [-1.0, 1.0]:
		var n: MeshInstance3D = b.cyl(pos + Vector3(s * 2.2, 3.0, 0), 0.7, 0.7, 1.6, red, false)
		n.rotation.z = PI / 2.0


static func soda_can(b: Builder, pos: Vector3, color: Color, lying: bool = false) -> void:
	if not lying and try_model(b, "canette", pos, b.rand(0, TAU)):
		b.cyl(pos, 3.3, 3.3, 12.0, Color(), true).visible = false
		return
	if lying:
		var rot := b.rand(0, TAU)
		var g: Node3D = b.group(pos, rot)
		var m: MeshInstance3D = b.cyl(Vector3(0, 3.3, 0), 3.3, 3.3, 12.0, b.mat(color, 0.35, {"metallic": 0.6}), false, 16, g)
		m.rotation.z = PI / 2.0
		m.position = Vector3(0, 3.3, 0)
		b.box(Vector3.ZERO, Vector3(12, 6.4, 6.4), Color(0, 0, 0, 0), true, 0.0, g).visible = false
	else:
		b.cyl(pos, 3.3, 3.3, 12.0, b.mat(color, 0.35, {"metallic": 0.6}), true, 16)
		b.cyl(pos + Vector3(0, 12, 0), 2.6, 3.3, 0.6, Color("c9c9c9"), false, 16)


static func bottle_cap(b: Builder, pos: Vector3, color: Color) -> void:
	if try_model(b, "capsule", pos, b.rand(0, TAU)):
		b.cyl(pos, 1.6, 1.6, 0.7, Color(), true).visible = false
		return
	b.cyl(pos, 1.6, 1.6, 0.7, b.mat(color, 0.4, {"metallic": 0.5}), true, 14)


static func cigarette_butt(b: Builder, pos: Vector3) -> void:
	var g: Node3D = b.group(pos, b.rand(0, TAU))
	var f: MeshInstance3D = b.cyl(Vector3.ZERO, 0.4, 0.4, 2.2, Color("d9893a"), false, 8, g)
	f.rotation.z = PI / 2.0
	f.position = Vector3(-0.8, 0.4, 0)
	var w: MeshInstance3D = b.cyl(Vector3.ZERO, 0.4, 0.4, 1.4, Color("efe9df"), false, 8, g)
	w.rotation.z = PI / 2.0
	w.position = Vector3(1.0, 0.4, 0)


static func paper_ball(b: Builder, pos: Vector3, r: float) -> void:
	b.sphere(pos + Vector3(0, r * 0.8, 0), r, Color("eeeae0"), Vector3(1, 0.85, 1.1))


static func trash_bag(b: Builder, pos: Vector3, r: float) -> void:
	if try_model(b, "sac_poubelle", pos, b.rand(0, TAU), r / 6.0):
		b.sphere(pos + Vector3(0, r * 0.75, 0), r, Color(), Vector3(1.1, 0.85, 1.0)).visible = false
		return
	b.sphere(pos + Vector3(0, r * 0.75, 0), r, b.mat(Color("1d1f22"), 0.25), Vector3(1.1, 0.85, 1.0))
	b.cyl(pos + Vector3(0, r * 1.45, 0), 0.6, r * 0.25, r * 0.4, b.mat(Color("1d1f22"), 0.25), false, 6)


static func traffic_cone(b: Builder, pos: Vector3) -> void:
	b.box(pos, Vector3(5, 0.6, 5), Color("e8862a"), false)
	b.cyl(pos + Vector3(0, 0.6, 0), 0.4, 2.0, 7.0, Color("e8862a"), true, 10)
	b.cyl(pos + Vector3(0, 3.2, 0), 1.25, 1.45, 1.0, Color("f4f4f4"), false, 10)


static func bench(b: Builder, pos: Vector3, rot_y: float) -> void:
	# deux bâtons de glace posés sur des capsules
	var g: Node3D = b.group(pos, rot_y)
	for s in [-4.0, 4.0]:
		b.cyl(Vector3(s, 0, 0), 1.5, 1.5, 3.0, Color("b0302a"), true, 10, g)
	b.box(Vector3(0, 3, 0), Vector3(11.4, 0.4, 1.0), Color("e3c58d"), true, 0.0, g)
	b.box(Vector3(0, 3, 1.1), Vector3(11.4, 0.4, 1.0), Color("e3c58d"), true, 0.0, g)


static func flag(b: Builder, pos: Vector3, color: Color, h: float = 30.0) -> void:
	b.cyl(pos, 0.35, 0.45, h, Color("bbbbbb"), false, 5)
	b.box(pos + Vector3(4.5, h - 6.0, 0), Vector3(9, 5.5, 0.2), b.mat(color, 0.8, {"cull_mode": BaseMaterial3D.CULL_DISABLED}), false)


static func neon(b: Builder, pos: Vector3, size: Vector3, color: Color, rot_y: float = 0.0) -> void:
	b.box(pos, size, b.glow(color, 4.0), false, rot_y, null, "", false)


static func pizza_slice(b: Builder, pos: Vector3, rot_y: float) -> void:
	var g: Node3D = b.group(pos, rot_y)
	var p := PrismMesh.new()
	p.size = Vector3(30, 40, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.material_override = b.mat(Color("e8b04a"))
	mi.rotation.x = -PI / 2.0
	mi.position.y = 1.0
	g.add_child(mi)
	for k in 4:
		b.cyl(Vector3(b.rand(-5, 5), 2.0, b.rand(-8, 10)), 3.0, 3.0, 0.5, Color("b8322a"), false, 10, g)
	b.box(Vector3(0, 0, 0), Vector3(14, 2.2, 30), Color(), true, 0.0, g).visible = false


static func apple_core(b: Builder, pos: Vector3) -> void:
	b.cyl(pos, 3.5, 4.5, 4.0, Color("efe2b0"), true, 10)
	b.cyl(pos + Vector3(0, 4, 0), 6.5, 3.5, 4.0, Color("b8322a"), true, 12)
	b.cyl(pos + Vector3(0, 8, 0), 0.4, 0.4, 3.0, Color("5a3a22"), false, 5)
	b.cyl(pos + Vector3(0, -4, 0), 3.5, 6.5, 4.0, Color("b8322a"), false, 12).position.y = 2.0


static func web_decor(b: Builder, center: Vector3, r: float, rot_y: float) -> void:
	# toile ronde décorative, en fines lignes
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var spokes := 12
	for k in spokes:
		var a := k / float(spokes) * TAU
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_add_vertex(Vector3(cos(a), sin(a), 0) * r)
	for ring in range(1, 7):
		var rr := ring / 6.0 * r
		for k in spokes:
			var a1 := k / float(spokes) * TAU
			var a2 := (k + 1) / float(spokes) * TAU
			im.surface_add_vertex(Vector3(cos(a1), sin(a1), 0) * rr)
			im.surface_add_vertex(Vector3(cos(a2), sin(a2), 0) * rr * 0.96)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.95, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = center
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mi)


# ---------- Gros repères ----------

## Benne à ordures humaine : 180 x 100 cm, un immeuble à l'échelle des mouches.
static func dumpster(b: Builder, pos: Vector3, rot_y: float) -> void:
	if try_model(b, "benne", pos, rot_y):
		b.box(pos, Vector3(180, 120, 100), Color(), true, rot_y, null, "landmark").visible = false
		b.landmark("La Benne", pos)
		return
	var g: Node3D = b.group(pos, rot_y)
	var green := b.mat(Color("2f6b45"), 0.6, {"metallic": 0.3})
	b.box(Vector3(0, 10, 0), Vector3(180, 110, 100), green, true, 0.0, g, "landmark")
	b.box(Vector3(0, 118, -40), Vector3(184, 4, 30), green, true, -0.0, g)
	var lid: MeshInstance3D = b.box(Vector3(0, 0, 0), Vector3(184, 3, 60), b.mat(Color("1f4a30"), 0.6), false, 0.0, g)
	lid.position = Vector3(0, 140, -48)
	lid.rotation.x = 1.1
	for x in [-80.0, 80.0]:
		for z in [-40.0, 40.0]:
			b.cyl(Vector3(x, 0, z), 7, 7, 10, Color("222222"), true, 12, g)
	b.label("NE PAS NOURRIR LES MOUCHES", Vector3(0, 70, 50.6), Color("f2f2f2"), 64, 0.0, g)
	# tas de déchets qui dépasse
	for k in 7:
		b.sphere(Vector3(b.rand(-70, 70), 120 + b.rand(0, 10), b.rand(-30, 30)), b.rand(18, 30), b.mat(Color("1d1f22"), 0.25), Vector3(1.1, 0.7, 1.0), true, g)
	b.landmark("La Benne", pos)


## Bouche d'incendie humaine, géante pour nous : 70 cm de haut.
static func giant_hydrant(b: Builder, pos: Vector3) -> void:
	var red := b.mat(Color("c8312a"), 0.5, {"metallic": 0.2})
	b.cyl(pos, 13, 15, 6, red, true, 18, null, "landmark")
	b.cyl(pos + Vector3(0, 6, 0), 11, 11, 44, red, true, 18)
	b.cyl(pos + Vector3(0, 50, 0), 12.5, 12.5, 4, red, true, 18)
	b.cyl(pos + Vector3(0, 54, 0), 3, 11, 10, red, true, 18)
	b.cyl(pos + Vector3(0, 64, 0), 2.5, 2.5, 4, b.mat(Color("e0b23a"), 0.4, {"metallic": 0.6}), true, 8)
	for a in [0.0, PI / 2.0, PI]:
		var nz: MeshInstance3D = b.cyl(Vector3.ZERO, 4.5, 4.5, 8, red, false, 12)
		nz.get_parent().remove_child(nz)
		var holder: Node3D = b.group(pos + Vector3(0, 32, 0), a)
		holder.add_child(nz)
		nz.rotation.z = PI / 2.0
		nz.position = Vector3(13, 0, 0)
	# petite fuite qui fait une flaque
	b.cyl(pos + Vector3(30, 0.1, 10), 26, 26, 0.3, b.mat(Color("6aa6c8"), 0.05, {"metallic": 0.2}), false, 24)
	b.landmark("La Bouche d'incendie", pos)
