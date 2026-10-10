extends RefCounted
## Petites briques pour construire la ville en code : boîtes, cylindres, textes,
## avec leurs collisions. Garde aussi la trace de ce qu'il faut dessiner sur la minimap.

const Layout := preload("res://scripts/city/layout.gd")

var root: Node3D
var rng := RandomNumberGenerator.new()
var _mats := {}
## Emprises au sol pour la minimap : { rect: Rect2, top: float, kind: String }
var footprints: Array = []
## Endroits où cacher des pièces, par quartier.
var coin_spots := {}
## Repères nommés affichés sur la grande carte : { name, pos }
var landmarks: Array = []


func _init(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "City"
	parent.add_child(root)
	rng.seed = 2026


func mat(color: Color, rough: float = 0.85, extra: Dictionary = {}) -> StandardMaterial3D:
	var key := color.to_html() + str(rough) + str(extra)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	for k in extra:
		m.set(k, extra[k])
	_mats[key] = m
	return m


func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	return mat(color, 0.5, {"emission_enabled": true, "emission": color, "emission_energy_multiplier": energy})


func _as_mat(m) -> Material:
	return mat(m) if m is Color else m


func _attach(node: Node3D, parent: Node3D) -> void:
	(parent if parent else root).add_child(node)


func _record(mi: MeshInstance3D, kind: String) -> void:
	var g: AABB = mi.global_transform * mi.get_aabb()
	footprints.append({"rect": Rect2(g.position.x, g.position.z, g.size.x, g.size.z), "top": g.end.y, "kind": kind})


func _body_or_mesh(mesh: Mesh, material, pos: Vector3, rot_y: float, shape: Shape3D, parent: Node3D, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _as_mat(material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shape:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = rot_y
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		_attach(body, parent)
	else:
		mi.position = pos
		mi.rotation.y = rot_y
		_attach(mi, parent)
	return mi


## Boîte posée par le centre de sa face du bas.
func box(bottom: Vector3, size: Vector3, material, solid: bool = true, rot_y: float = 0.0, parent: Node3D = null, kind: String = "", shadow: bool = true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var shape: BoxShape3D = null
	if solid:
		shape = BoxShape3D.new()
		shape.size = size
	var mi := _body_or_mesh(bm, material, bottom + Vector3(0, size.y / 2.0, 0), rot_y, shape, parent, shadow)
	if kind != "":
		_record(mi, kind)
	return mi


## Cylindre (ou cône si r_top = 0) posé par le centre de sa base.
func cyl(bottom: Vector3, r_top: float, r_bottom: float, height: float, material, solid: bool = true, segments: int = 12, parent: Node3D = null, kind: String = "") -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	var shape: CylinderShape3D = null
	if solid:
		shape = CylinderShape3D.new()
		shape.radius = max(r_top, r_bottom)
		shape.height = height
	var mi := _body_or_mesh(cm, material, bottom + Vector3(0, height / 2.0, 0), 0.0, shape, parent, true)
	if solid:
		mi.position = Vector3.ZERO
	if kind != "":
		_record(mi, kind)
	return mi


func sphere(center: Vector3, radius: float, material, scale: Vector3 = Vector3.ONE, solid: bool = true, parent: Node3D = null) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	var shape: SphereShape3D = null
	if solid:
		shape = SphereShape3D.new()
		shape.radius = radius * min(scale.x, min(scale.y, scale.z))
	var mi := _body_or_mesh(sm, material, center, 0.0, shape, parent, true)
	mi.scale = scale
	if solid:
		mi.position = Vector3.ZERO
	return mi


## Un groupe vide, pour assembler un objet composé (benne, banque...) en coordonnées locales.
func group(pos: Vector3, rot_y: float = 0.0, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_attach(g, parent)
	return g


func label(text: String, pos: Vector3, color: Color, size: int = 96, rot_y: float = 0.0, parent: Node3D = null, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.05
	l.modulate = color
	l.outline_size = int(size / 6.0)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos
	l.rotation.y = rot_y
	l.double_sided = false
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_attach(l, parent)
	return l


## Fil de soie tendu entre deux points : on peut marcher dessus.
func silk(a: Vector3, b: Vector3, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	var length := a.distance_to(b)
	_attach(body, parent)
	body.global_position = (a + b) / 2.0
	if length > 0.01:
		var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD
		body.look_at(b, up)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.4, length)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = length
	cm.radial_segments = 5
	mi.mesh = cm
	mi.rotation.x = PI / 2.0
	mi.material_override = mat(Color("f2f4f7"), 0.3, {"emission_enabled": true, "emission": Color("8090a0"), "emission_energy_multiplier": 0.4})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return body


func spot(zone: String, pos: Vector3) -> void:
	if not coin_spots.has(zone):
		coin_spots[zone] = []
	coin_spots[zone].append(pos)


func landmark(name: String, pos: Vector3) -> void:
	landmarks.append({"name": name, "pos": pos})


func rand(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]
