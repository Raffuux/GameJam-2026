extends RefCounted
## Les constructions de chaque gang, à la place des immeubles humains :
## fourmilières pour la Colonie, tours tendues de grosses toiles pour les Tisseuses,
## tours de déchets pour la Nuée, docks en boîtes de sardines et abris de feuilles pour les Prieurs.
## Chaque fonction construit en local dans le groupe `g` (façade côté +z) et renvoie la hauteur du toit.
## Si le fil des assets fournit `gang_<gang>_<n>.glb` (n = 1, 2, 3...), le modèle est pris en priorité.

const Builder := preload("res://scripts/city/builder.gd")
const Props := preload("res://scripts/city/props.gd")


static func build(b: Builder, zone: String, g: Node3D, size: Vector2, h: float) -> float:
	var got := _try_models(b, zone, g, size, h)
	if got > 0.0:
		return got
	match zone:
		"colonie":
			return anthill(b, g, size, h)
		"tisseuses":
			return web_tower(b, g, size, h) if b.rng.randf() < 0.45 else draped_tower(b, g, size, h)
		"nuee":
			var roll := b.rng.randf()
			if roll < 0.35:
				return can_tower(b, g, size, h)
			if roll < 0.6:
				return bottle_tower(b, g, size, h)
			return carton(b, g, size, h)
		"prieurs":
			return sardine_tin(b, g, size, h) if b.rng.randf() < 0.55 else leaf_shelter(b, g, size, h)
	return 0.0


## Modèles dédiés du fil des assets, s'ils existent : gang_colonie_1.glb, gang_colonie_2.glb...
static func _try_models(b: Builder, zone: String, g: Node3D, size: Vector2, h: float) -> float:
	var names := []
	for n in range(1, 6):
		if ResourceLoader.exists("res://assets/models/gang_%s_%d.glb" % [zone, n]):
			names.append("gang_%s_%d" % [zone, n])
	if names.is_empty() or b.rng.randf() < 0.3:
		return 0.0
	var got := b.model(b.pick(names), Vector3.ZERO, 0.0, Vector3(size.x, h, size.y), true, g, "building")
	return got.y


# ---------- Colonie : fourmilières ----------

## Un dôme de terre en gradins, percé d'entrées, hérissé d'aiguilles de pin et de brindilles.
static func anthill(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var r := minf(size.x, size.y) * 0.5
	var height := clampf(h * 0.9, r * 0.8, r * 1.7)
	var tiers := 6
	var dirt := [Color("8a6a48"), Color("7d5f40"), Color("94744f"), Color("6f5338")]
	var y := 0.0
	for k in tiers:
		var t0 := float(k) / tiers
		var t1 := float(k + 1) / tiers
		var r0 := r * (1.0 - t0 * t0 * 0.85)
		var r1 := r * (1.0 - t1 * t1 * 0.85)
		var th := height / tiers
		b.cyl(Vector3(0, y, 0), r1, r0, th, b.mat(dirt[k % dirt.size()], 1.0), true, 14, g, "building" if k == 0 else "")
		y += th
	# cratère au sommet
	b.cyl(Vector3(0, y - 0.2, 0), r * 0.12, r * 0.12, 0.4, Color("1a1410"), false, 10, g)
	# entrées : des trous sombres tout autour, une grande côté rue
	b.sphere(Vector3(0, r * 0.18, r * 0.95), r * 0.22, b.mat(Color("140f0b"), 1.0), Vector3(1.2, 0.8, 0.5), false, g)
	for k in b.rng.randi_range(2, 4):
		var a := b.rand(0, TAU)
		var ty := b.rand(0.25, 0.7)
		var rr := r * (1.0 - ty * ty * 0.85) * 0.97
		b.sphere(Vector3(sin(a) * rr, height * ty, cos(a) * rr), r * 0.09, b.mat(Color("140f0b"), 1.0), Vector3(1.0, 0.8, 0.6), false, g)
	# aiguilles de pin et brindilles plantées dans la terre
	for k in b.rng.randi_range(6, 12):
		var a := b.rand(0, TAU)
		var ty := b.rand(0.1, 0.8)
		var rr := r * (1.0 - ty * ty * 0.85) * 0.9
		var stick: MeshInstance3D = b.cyl(Vector3.ZERO, 0.6, 0.9, b.rand(r * 0.4, r * 0.9), b.mat(b.pick([Color("a0702a"), Color("6b4a22"), Color("c08a3a")])), false, 5, g)
		stick.position = Vector3(sin(a) * rr, height * ty, cos(a) * rr)
		stick.rotation = Vector3(b.rand(-0.9, 0.9), 0, b.rand(-0.9, 0.9))
	# petits monticules au pied
	for k in b.rng.randi_range(1, 3):
		var a := b.rand(0, TAU)
		var p := Vector3(sin(a) * r * 1.05, 0, cos(a) * r * 1.05)
		b.cyl(p, r * 0.08, r * 0.3, r * 0.35, b.mat(dirt[1], 1.0), true, 10, g)
	return height


# ---------- Tisseuses : tours et grosses toiles ----------

## Une toile ronde en vrais rubans (visible de loin), dans le plan local XY du nœud renvoyé.
static func web_mesh(r: float, width: float, spokes: int = 14, rings: int = 9) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := func(a: Vector2, c: Vector2) -> void:
		var d := (c - a).normalized()
		var n := Vector2(-d.y, d.x) * width * 0.5
		for v in [a + n, c + n, c - n, a + n, c - n, a - n]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(v.x, v.y, 0))
	for k in spokes:
		var a := k / float(spokes) * TAU
		seg.call(Vector2.ZERO, Vector2(cos(a), sin(a)) * r)
	# la spirale de capture, légèrement affaissée entre les rayons
	for ring in range(1, rings + 1):
		var rr := ring / float(rings) * r
		for k in spokes:
			var a1 := k / float(spokes) * TAU
			var a2 := (k + 1) / float(spokes) * TAU
			var p1 := Vector2(cos(a1), sin(a1)) * rr
			var p2 := Vector2(cos(a2), sin(a2)) * rr
			var mid := (p1 + p2) * 0.5 * 0.9
			seg.call(p1, mid)
			seg.call(mid, p2)
	return st.commit()


static func _silk_mat(b: Builder) -> Material:
	return b.mat(Color(0.96, 0.97, 1.0, 0.85), 0.3, {
		"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA,
		"cull_mode": BaseMaterial3D.CULL_DISABLED,
		"emission_enabled": true, "emission": Color("9aa4b8"), "emission_energy_multiplier": 0.5,
	})


static func web(b: Builder, parent: Node3D, center: Vector3, r: float, rot_y: float, tilt: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = web_mesh(r, maxf(0.5, r * 0.018))
	mi.material_override = _silk_mat(b)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center
	mi.rotation = Vector3(tilt, rot_y, 0)
	parent.add_child(mi)
	return mi


## Un cocon de soie suspendu (on peut grimper dessus).
static func cocoon(b: Builder, parent: Node3D, pos: Vector3, r: float) -> void:
	b.sphere(pos, r, b.mat(Color("ecebe6"), 0.6), Vector3(1.0, 1.7, 1.0), true, parent)
	b.cyl(pos + Vector3(0, r * 1.5, 0), 0.25, 0.25, r * 2.0, _silk_mat(b), false, 4, parent)


## Trois ou quatre brindilles géantes plantées en faisceau, reliées par de grandes toiles et des cocons.
static func web_tower(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var height := h * 1.15
	var bark := b.mat(Color("3a2c22"), 1.0)
	var n := b.rng.randi_range(3, 4)
	var tops := []
	var feet := []
	for k in n:
		var a := k / float(n) * TAU + b.rand(-0.3, 0.3)
		var foot := Vector3(sin(a) * size.x * 0.42, 0, cos(a) * size.y * 0.42)
		var top := Vector3(sin(a) * size.x * 0.12, height * b.rand(0.85, 1.0), cos(a) * size.y * 0.12)
		feet.append(foot)
		tops.append(top)
		_beam(b, g, foot, top, b.rand(2.2, 3.2), bark, k == 0)
	# grandes toiles tendues entre chaque paire de brindilles
	for k in n:
		var p: Vector3 = (feet[k] + tops[k]) * 0.5
		var q: Vector3 = (feet[(k + 1) % n] + tops[(k + 1) % n]) * 0.5
		var mid := (p + q) * 0.5
		var r := p.distance_to(q) * 0.55
		web(b, g, mid + Vector3(0, b.rand(-height * 0.15, height * 0.2), 0), r, atan2(q.x - p.x, q.z - p.z) - PI / 2.0)
	# toile au sommet, presque à plat : une plateforme
	web(b, g, Vector3(0, height * 0.9, 0), minf(size.x, size.y) * 0.4, 0.0, -PI / 2.0)
	b.box(Vector3(0, height * 0.9 - 0.3, 0), Vector3(size.x * 0.35, 0.6, size.y * 0.35), Color(0, 0, 0, 0), true, 0.0, g).visible = false
	for k in b.rng.randi_range(2, 4):
		cocoon(b, g, Vector3(b.rand(-size.x * 0.2, size.x * 0.2), b.rand(height * 0.25, height * 0.7), b.rand(-size.y * 0.2, size.y * 0.2)), b.rand(4.0, 7.0))
	# fils d'ancrage jusqu'au sol, on peut y marcher
	for k in 2:
		var top: Vector3 = tops[k]
		var ground := Vector3(top.x * 4.0, 0.5, top.z * 4.0 + size.y * 0.3)
		b.silk(g.transform * (top + Vector3(0, -4, 0)), g.transform * ground, b.root)
	return height


## Une tour sombre de l'ancien quartier, emmaillotée de soie : voiles sur les étages hauts, toiles géantes sur les façades.
static func draped_tower(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	b.box(Vector3.ZERO, Vector3(size.x, h, size.y), b.mat(Color(b.pick(["2e2a35", "3d3646", "4b3f57"])), 0.9), true, 0.0, g, "building")
	b.box(Vector3(0, h, 0), Vector3(size.x + 2, 1.5, size.y + 2), b.mat(Color("1f1c24"), 0.9), true, 0.0, g)
	# fenêtres violettes allumées
	for k in b.rng.randi_range(3, 7):
		b.box(Vector3(b.rand(-size.x * 0.35, size.x * 0.35), b.rand(10, h - 10), size.y / 2.0 + 0.2), Vector3(5, 7, 0.3), b.glow(Color("b07ad6"), 1.6), false, 0.0, g, "", false)
	# voile de soie autour du haut de la tour
	var veil_h := h * b.rand(0.35, 0.6)
	var veil := b.mat(Color(0.95, 0.95, 1.0, 0.28), 0.3, {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA, "cull_mode": BaseMaterial3D.CULL_DISABLED})
	b.box(Vector3(0, h - veil_h, 0), Vector3(size.x + 3, veil_h + 3, size.y + 3), veil, false, 0.0, g, "", false)
	# toile géante sur la façade côté rue
	web(b, g, Vector3(0, h * 0.5, size.y / 2.0 + 1.0), minf(size.x * 0.6, h * 0.45), 0.0)
	# une toile en coin, entre la tour et le sol
	var corner := Vector3(size.x / 2.0, 0, size.y / 2.0)
	web(b, g, corner + Vector3(6, h * 0.25, 6), h * 0.22, PI / 4.0, 0.25)
	# fils d'ancrage depuis le toit
	for s in [-1.0, 1.0]:
		var top := Vector3(s * size.x / 2.0, h, size.y / 2.0)
		var ground := Vector3(s * (size.x / 2.0 + 10.0), 0.5, size.y / 2.0 + h * 0.35)
		b.silk(g.transform * top, g.transform * ground, b.root)
	if b.rng.randf() < 0.5:
		cocoon(b, g, Vector3(size.x / 2.0 + 4.0, h * 0.6, 0), 5.0)
	return h


## Une poutre (brindille, poteau) entre deux points locaux, avec collision.
static func _beam(b: Builder, g: Node3D, from: Vector3, to: Vector3, r: float, m: Material, record: bool) -> void:
	var length := from.distance_to(to)
	var mi: MeshInstance3D = b.cyl(Vector3.ZERO, r * 0.7, r, length, m, true, 7, g, "")
	var body := mi.get_parent() as Node3D
	body.position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		body.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	if record:
		b.record_footprint(g.transform * Vector3((from.x + to.x) * 0.5, 0, (from.z + to.z) * 0.5), Vector3(r * 6, 0, r * 6), g.rotation.y, to.y, "building")


# ---------- Nuée : tours de déchets ----------

## Canettes géantes empilées, cabossées, avec des fenêtres percées.
static func can_tower(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var r := minf(size.x, size.y) * 0.48
	var colors := [Color("d62828"), Color("2a9d8f"), Color("f4a261"), Color("e9e3d6"), Color("2f6fd6")]
	var y := 0.0
	var n := clampi(int(h / (r * 1.6)), 1, 4)
	for k in n:
		var ch := r * b.rand(1.5, 1.9)
		var col: Color = b.pick(colors)
		var rr := r * (1.0 - k * 0.06)
		var off := Vector3(b.rand(-2, 2), y, b.rand(-2, 2))
		b.cyl(off, rr, rr, ch, b.mat(col, 0.35, {"metallic": 0.6}), true, 18, g, "building" if k == 0 else "")
		b.cyl(off + Vector3(0, ch * 0.4, 0), rr + 0.2, rr + 0.2, ch * 0.15, b.mat(Color("f2f2f2"), 0.4, {"metallic": 0.5}), false, 18, g)
		b.cyl(off + Vector3(0, ch, 0), rr * 0.8, rr, 1.5, b.mat(Color("c9c9c9"), 0.3, {"metallic": 0.8}), true, 18, g)
		for w in b.rng.randi_range(2, 4):
			var a := b.rand(-0.8, 0.8)
			b.box(off + Vector3(sin(a) * rr, b.rand(4, ch - 8), cos(a) * rr), Vector3(5, 6, 0.6), b.glow(Color("ffd98a"), 1.2), false, a, g, "", false)
		y += ch + 1.5
	# languette d'ouverture au sommet
	b.box(Vector3(r * 0.2, y, 0), Vector3(r * 0.5, 0.8, r * 0.25), b.mat(Color("bdbdbd"), 0.3, {"metallic": 0.8}), true, 0.0, g)
	return y


## Une bouteille en plastique géante, debout, habitée.
static func bottle_tower(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var got := b.model("plastic_bottle", Vector3.ZERO, b.rand(0, TAU), Vector3(size.x * 0.9, h * 1.2, size.y * 0.9), true, g, "building")
	if got != Vector3.ZERO:
		return got.y
	var r := minf(size.x, size.y) * 0.4
	var plastic := b.mat(Color(0.6, 0.85, 0.75, 0.55), 0.1, {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA})
	b.cyl(Vector3.ZERO, r, r, h * 0.7, plastic, true, 16, g, "building")
	b.cyl(Vector3(0, h * 0.7, 0), r * 0.25, r, h * 0.2, plastic, true, 16, g)
	b.cyl(Vector3(0, h * 0.9, 0), r * 0.3, r * 0.3, h * 0.08, b.mat(Color("2f6fd6")), true, 12, g)
	b.cyl(Vector3(0, h * 0.25, 0), r + 0.3, r + 0.3, h * 0.2, b.mat(Color("2a9d6f")), false, 16, g)
	return h * 0.98


## Un carton détrempé reconverti en immeuble : scotch, fenêtres découpées au cutter, inscription.
static func carton(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var hh := h * 0.8
	var cardboard := b.mat(b.pick([Color("b8925e"), Color("a8844f"), Color("c49e68")]), 1.0)
	b.box(Vector3.ZERO, Vector3(size.x, hh, size.y), cardboard, true, 0.0, g, "building")
	# rabats ouverts sur le dessus
	for s in [-1.0, 1.0]:
		var flap: MeshInstance3D = b.box(Vector3.ZERO, Vector3(size.x, 0.8, size.y * 0.45), cardboard, false, 0.0, g)
		flap.position = Vector3(0, hh + size.y * 0.15, s * (size.y / 2.0 + size.y * 0.12))
		flap.rotation.x = s * 0.9
	b.box(Vector3(0, hh - 0.1, 0), Vector3(size.x + 0.4, 0.4, 6), b.mat(Color("d9c48a"), 0.4), false, 0.0, g)
	b.box(Vector3(0, hh * 0.5, size.y / 2.0 + 0.05), Vector3(6, hh, 0.2), b.mat(Color("d9c48a"), 0.4), false, 0.0, g)
	for k in b.rng.randi_range(3, 6):
		b.box(Vector3(b.rand(-size.x * 0.38, size.x * 0.38), b.rand(6, hh - 10), size.y / 2.0 + 0.1), Vector3(6, 6, 0.2), Color("1a1a1a"), false, 0.0, g, "", false)
	b.label(b.pick(["FRAGILE", "CE CÔTÉ EN HAUT", "NUÉE", "↑↑"]), Vector3(0, hh * 0.75, size.y / 2.0 + 0.3), Color("2a2a2a"), 120, 0.0, g)
	for k in 3:
		Props.trash_bag(b, g.transform * Vector3(b.rand(-size.x * 0.5, size.x * 0.5), 0, size.y / 2.0 + 3.0), b.rand(5, 9))
	return hh


# ---------- Prieurs : docks et abris de feuilles ----------

## Une boîte de sardines géante : fer-blanc, couvercle à moitié enroulé, étiquette.
static func sardine_tin(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var hh := clampf(h * 0.45, 16.0, 30.0)
	var tin := b.mat(Color("b9c0c6"), 0.3, {"metallic": 0.85})
	b.box(Vector3.ZERO, Vector3(size.x, hh, size.y), tin, true, 0.0, g, "building")
	b.box(Vector3(0, hh, 0), Vector3(size.x - 4, 0.6, size.y - 4), b.mat(Color("8f979e"), 0.3, {"metallic": 0.85}), true, 0.0, g)
	# couvercle enroulé sur l'arrière
	var roll := b.cyl(Vector3.ZERO, 4.0, 4.0, size.x - 4, tin, false, 12, g)
	roll.rotation.z = PI / 2.0
	roll.position = Vector3(0, hh + 4.0, -size.y / 2.0 + 4.0)
	var lid: MeshInstance3D = b.box(Vector3.ZERO, Vector3(size.x - 4, 0.5, size.y * 0.5), tin, true, 0.0, g)
	lid.get_parent().position = Vector3(0, hh + size.y * 0.15, -size.y * 0.12)
	lid.get_parent().rotation.x = -0.6
	# étiquette rouge et bleue des Prieurs
	b.box(Vector3(0, hh * 0.15, size.y / 2.0 + 0.1), Vector3(size.x * 0.9, hh * 0.7, 0.2), b.mat(Color("d63a2f")), false, 0.0, g, "", false)
	b.label("SARDINES DES PRIEURS", Vector3(0, hh * 0.5, size.y / 2.0 + 0.35), Color("f2e6c8"), 110, 0.0, g)
	# porte de quai
	b.box(Vector3(size.x * 0.3, 0, size.y / 2.0 + 0.2), Vector3(14, 12, 0.4), Color("3a3f45"), false, 0.0, g, "", false)
	return hh + 1.0


## Un temple de mantes : une grande feuille posée en toit sur des tiges, comme une pagode.
static func leaf_shelter(b: Builder, g: Node3D, size: Vector2, h: float) -> float:
	var stem := b.mat(Color("5f8a3a"), 0.8)
	var hh := h * 0.8
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.cyl(Vector3(sx * size.x * 0.38, 0, sz * size.y * 0.38), 1.8, 2.4, hh, stem, true, 8, g)
	# salle centrale en écorce
	b.box(Vector3.ZERO, Vector3(size.x * 0.6, hh * 0.45, size.y * 0.6), b.mat(Color("6b4f36"), 1.0), true, 0.0, g, "building")
	b.box(Vector3(0, 0, size.y * 0.3 + 0.1), Vector3(10, 14, 0.4), Color("1a120c"), false, 0.0, g, "", false)
	# toits de feuilles, en étages
	var leaf_colors := [Color("4f8a2a"), Color("6aa33a"), Color("3f7424")]
	for k in 2:
		var y := hh * (0.55 if k == 0 else 1.0)
		var s := 1.25 - k * 0.35
		b.sphere(Vector3(0, y, 0), 1.0, b.mat(leaf_colors[k]), Vector3(size.x * 0.6 * s, 4.0, size.y * 0.6 * s), false, g)
		b.box(Vector3(0, y - 1.0, 0), Vector3(size.x * s, 2.0, size.y * s), Color(0, 0, 0, 0), true, 0.0, g).visible = false
		# nervure centrale
		b.box(Vector3(0, y + 2.5, 0), Vector3(1.2, 1.0, size.y * 1.1 * s), b.mat(Color("cfe0a0")), false, 0.0, g, "", false)
	# lanternes rouges (baies)
	for k in 4:
		var a := k / 4.0 * TAU + PI / 4.0
		b.sphere(Vector3(sin(a) * size.x * 0.45, hh * 0.45, cos(a) * size.y * 0.45), 2.5, b.glow(Color("d63a2f"), 1.5), Vector3.ONE, false, g)
	return hh + 4.0
