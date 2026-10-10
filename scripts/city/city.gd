extends RefCounted
## Construit toute la ville : sol, rues, trottoirs, immeubles par quartier, lieux spéciaux,
## décor de fond façon GTA. Tout est déterministe (graine fixe), la ville est la même à chaque partie.

const Layout := preload("res://scripts/city/layout.gd")
const Builder := preload("res://scripts/city/builder.gd")
const Props := preload("res://scripts/city/props.gd")
const Tex := preload("res://scripts/city/textures.gd")

var b: Builder
var facade_mats := {}
var puddle_center := Vector3(460, 0, -460)
const PUDDLE_R := 125.0

## Couleurs des immeubles et hauteurs [min, max] par quartier.
const STYLE := {
	"centre": {"colors": ["c9c3b5", "a7b4c2", "d8cfc0", "8fa3b8", "e2dccf", "b7a99a"], "h": [140.0, 380.0], "lots": 2},
	"tisseuses": {"colors": ["4b3f57", "3d3646", "5a4d66", "2e2a35", "54485e"], "h": [70.0, 180.0], "lots": 3},
	"prieurs": {"colors": ["8d6e57", "7a6a5a", "9a8a73", "6e5a4a"], "h": [35.0, 70.0], "lots": 2},
	"nuee": {"colors": ["7d8a8f", "6b7378", "8a8f7d", "5f676b"], "h": [40.0, 110.0], "lots": 2},
	"colonie": {"colors": ["b5835a", "c49a6c", "a8714a", "9a6a48"], "h": [30.0, 90.0], "lots": 2},
}


func build(parent: Node3D) -> Builder:
	b = Builder.new(parent)
	var win_tex := Tex.windows(0.3, 11)
	for zone in STYLE:
		var list := []
		for hex in STYLE[zone]["colors"]:
			list.append(Tex.world_mat(win_tex, Color(hex), 1.0 / 24.0))
		facade_mats[zone] = list
	_ground()
	_roads()
	for j in 4:
		for i in 4:
			_block(i, j)
	_tisseuses_webs()
	_backdrop()
	return b


# ---------- Sol et rues ----------

func _ground() -> void:
	var asphalt := Tex.world_mat(Tex.noise(Color("34363a"), Color("4a4c50"), 0.09), Color.WHITE, 1.0 / 60.0, 0.95)
	b.box(Vector3(0, -20, 0), Vector3(6000, 20, 6000), asphalt, true, 0.0, null, "", false)


func _roads() -> void:
	var paint := b.mat(Color("e8d36a"), 0.7)
	var white := b.mat(Color("eeeeee"), 0.7)
	var dashes := []
	var stripes := []
	for c in Layout.ROADS:
		var t := -Layout.HALF
		while t < Layout.HALF:
			var near_crossing := false
			for r in Layout.ROADS:
				if absf(t + 6.0 - r) < 26.0:
					near_crossing = true
			if not near_crossing:
				dashes.append(Transform3D(Basis(), Vector3(c, 0.05, t + 6.0)))
				dashes.append(Transform3D(Basis().rotated(Vector3.UP, PI / 2.0), Vector3(t + 6.0, 0.05, c)))
			t += 20.0
		# passages piétons de chaque côté des carrefours
		for r in Layout.ROADS:
			for side in [-1.0, 1.0]:
				for k in 6:
					var off := -15.0 + k * 6.0
					stripes.append(Transform3D(Basis(), Vector3(c + off, 0.06, r + side * 29.0)))
					stripes.append(Transform3D(Basis().rotated(Vector3.UP, PI / 2.0), Vector3(r + side * 29.0, 0.06, c + off)))
	_multimesh(Vector3(1.2, 0.1, 12.0), paint, dashes)
	_multimesh(Vector3(3.0, 0.1, 12.0), white, stripes)


func _multimesh(size: Vector3, material: Material, transforms: Array) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mmi)


# ---------- Pâtés de maisons ----------

func _block(i: int, j: int) -> void:
	var r := Layout.block_rect(i, j)
	var zone := Layout.zone_of_block(i, j)
	var special: String = Layout.SPECIAL.get(Vector2i(i, j), "")
	var zc: Color = Layout.ZONES[zone]["color"]
	if special == "puddle":
		_puddle(r)
		return
	var concrete := b.mat(Color("9d9a94").lerp(zc, 0.12), 0.95)
	var center := Vector3(r.get_center().x, 0, r.get_center().y)
	b.box(center, Vector3(r.size.x, Layout.CURB_H, r.size.y), concrete, true, 0.0, null, "sidewalk", false)
	_sidewalk_props(r, zone)
	match special:
		"bank":
			_bank(r)
		"park":
			_park(r)
		"dumpster":
			_dump(r)
		"construction":
			_construction(r)
		_:
			_lots(r, zone)


func _sidewalk_props(r: Rect2, zone: String) -> void:
	var y := Layout.CURB_H
	var inset := 5.0
	var corners := [
		Vector3(r.position.x + inset, y, r.position.y + inset),
		Vector3(r.end.x - inset, y, r.position.y + inset),
		Vector3(r.position.x + inset, y, r.end.y - inset),
		Vector3(r.end.x - inset, y, r.end.y - inset),
	]
	for k in corners.size():
		Props.streetlight(b, corners[k], [PI * 0.75, -PI * 0.75, PI * 0.25, -PI * 0.25][k])
	# bouches d'incendie et lampadaires le long des trottoirs qui donnent sur une rue
	for edge in 4:
		var horizontal := edge < 2
		var fixed: float = [r.position.y + inset, r.end.y - inset, r.position.x + inset, r.end.x - inset][edge]
		var a: float = r.position.x if horizontal else r.position.y
		var length: float = r.size.x if horizontal else r.size.y
		var t := 50.0
		while t < length - 40.0:
			var p := Vector3(a + t, y, fixed) if horizontal else Vector3(fixed, y, a + t)
			if absf(p.x) > Layout.HALF - 10.0 or absf(p.z) > Layout.HALF - 10.0:
				t += 80.0
				continue
			var roll := b.rng.randf()
			if roll < 0.3:
				Props.hydrant(b, p)
			elif roll < 0.55:
				Props.soda_can(b, p, b.pick([Color("d62828"), Color("2a9d8f"), Color("f4a261"), Color("e9e3d6")]), b.rng.randf() < 0.4)
			elif roll < 0.7:
				Props.trash_bag(b, p, b.rand(5, 8))
			elif roll < 0.8:
				Props.flag(b, p, Layout.ZONES[zone]["color"]) if Layout.ZONES[zone]["gang"] != "" else Props.bench(b, p, 0.0 if horizontal else PI / 2.0)
			t += b.rand(50, 90)
	# déchets dans la rue
	for k in 6:
		var p := Vector3(b.rand(r.position.x - 18, r.end.x + 18), 0, b.rand(r.position.y - 18, r.end.y + 18))
		if r.has_point(Vector2(p.x, p.z)) or absf(p.x) > Layout.HALF - 5 or absf(p.z) > Layout.HALF - 5:
			continue
		match k % 3:
			0:
				Props.bottle_cap(b, p, b.pick([Color("c8312a"), Color("2a6fd6"), Color("e0b23a"), Color("2a9d6f")]))
			1:
				Props.cigarette_butt(b, p)
			2:
				Props.paper_ball(b, p, b.rand(1.5, 3.5))


## Remplit l'intérieur du pâté avec une grille d'immeubles.
func _lots(r: Rect2, zone: String) -> void:
	var st: Dictionary = STYLE[zone]
	var n: int = st["lots"]
	var inner := r.grow(-22.0)
	var gap := 12.0 if n == 2 else 9.0
	var lot := Vector2((inner.size.x - gap * (n - 1)) / n, (inner.size.y - gap * (n - 1)) / n)
	var y := Layout.CURB_H
	var gang: String = Layout.ZONES[zone]["gang"]
	var color: Color = Layout.ZONES[zone]["color"]
	for ix in n:
		for iz in n:
			var c := Vector2(inner.position.x + lot.x * (ix + 0.5) + gap * ix, inner.position.y + lot.y * (iz + 0.5) + gap * iz)
			var size := Vector2(lot.x * b.rand(0.78, 1.0), lot.y * b.rand(0.78, 1.0))
			var h := b.rand(st["h"][0], st["h"][1])
			if zone == "centre" and ix == iz:
				h *= 1.25
			var base := Vector3(c.x, y, c.y)
			if zone == "prieurs":
				_warehouse(base, size, h, color)
			else:
				_building(base, size, h, zone)
			if b.rng.randf() < 0.6:
				b.spot(zone, base + Vector3(0, h + 2, 0))
			# marques de gang : drapeau sur le toit et tag sur la façade sud
			if gang != "":
				if b.rng.randf() < 0.5:
					Props.flag(b, base + Vector3(size.x * 0.3, h, size.y * 0.3), color, 24.0)
				if b.rng.randf() < 0.6:
					var tag := gang.split(" ")[1].to_upper()
					var l := b.label(tag, base + Vector3(b.rand(-size.x * 0.2, size.x * 0.2), b.rand(8, 18), size.y / 2.0 + 0.3), color, 140, 0.0)
					l.rotation.z = b.rand(-0.15, 0.15)
			if zone == "tisseuses" and b.rng.randf() < 0.5:
				Props.neon(b, base + Vector3(0, b.rand(20, 40), size.y / 2.0 + 0.4), Vector3(size.x * 0.6, 1.2, 0.4), color)
			# ruelles : poubelles et déchets entre les immeubles
			if b.rng.randf() < 0.5:
				Props.trash_bag(b, base + Vector3(size.x / 2.0 + gap / 2.0, 0, b.rand(-lot.y / 3.0, lot.y / 3.0)), b.rand(4, 6))


func _building(base: Vector3, size: Vector2, h: float, zone: String) -> void:
	var m: Material = b.pick(facade_mats[zone])
	b.box(base, Vector3(size.x, h, size.y), m, true, 0.0, null, "building")
	# corniche et toit
	var roof := b.mat(Color("3b3b3e"), 0.9)
	b.box(base + Vector3(0, h, 0), Vector3(size.x + 2, 1.5, size.y + 2), roof, true)
	# détails de toit : clim, château d'eau, antenne
	for k in b.rng.randi_range(1, 3):
		var p := base + Vector3(b.rand(-size.x * 0.3, size.x * 0.3), h + 1.5, b.rand(-size.y * 0.3, size.y * 0.3))
		match b.rng.randi_range(0, 2):
			0:
				b.box(p, Vector3(8, 5, 6), Color("9aa0a6"), true)
			1:
				b.cyl(p, 5, 5, 9, Color("7a5a3a"), true, 10)
				b.cyl(p + Vector3(0, 9, 0), 0.5, 5.5, 3, Color("5a4030"), false, 10)
			2:
				b.cyl(p, 0.3, 0.4, 18, Color("888888"), false, 4)
	# auvent coloré en bas pour les quartiers de gang
	if Layout.ZONES[zone]["gang"] != "" and b.rng.randf() < 0.5:
		b.box(base + Vector3(0, 14, size.y / 2.0 + 3), Vector3(size.x * 0.5, 1, 6), b.mat(Layout.ZONES[zone]["color"]), true)


## Entrepôt des docks : une boîte à chaussures avec un logo, plus large que haute.
func _warehouse(base: Vector3, size: Vector2, h: float, color: Color) -> void:
	var body := b.mat(b.pick([Color("c8a27a"), Color("b48a62"), Color("d0b48c")]))
	b.box(base, Vector3(size.x, h, size.y), body, true, 0.0, null, "building")
	b.box(base + Vector3(0, h, 0), Vector3(size.x + 3, 4, size.y + 3), b.mat(Color("8a6a4a")), true)
	b.box(base + Vector3(0, 0, size.y / 2.0), Vector3(size.x * 0.4, h * 0.6, 0.6), Color("5a4a3a"), false)
	b.label("PRIEURS & CIE", base + Vector3(0, h * 0.8, size.y / 2.0 + 0.4), color, 120)


# ---------- Lieux spéciaux ----------

## La banque : temple néoclassique, colonnes en crayons, pièces d'or.
func _bank(r: Rect2) -> void:
	var y := Layout.CURB_H
	var c := Vector3(r.get_center().x, y, r.get_center().y + 10)
	var marble := b.mat(Color("ece6da"), 0.5)
	var w := 160.0
	var d := 110.0
	var h := 100.0
	b.box(c, Vector3(w + 30, 6, d + 40), marble, true, 0.0, null, "landmark")
	b.box(c + Vector3(0, 0, d / 2.0 + 18), Vector3(w + 30, 3, 10), marble, true) # marche
	b.box(c + Vector3(0, 6, -10), Vector3(w, h, d - 20), marble, true, 0.0, null, "building")
	# colonnes en crayons
	for k in 8:
		var x := -w / 2.0 + 10 + k * (w - 20) / 7.0
		b.cyl(c + Vector3(x, 6, d / 2.0 - 4), 4.2, 4.2, h - 12, b.mat(Color("f2c230")), true, 6)
		b.cyl(c + Vector3(x, 6 + h - 12, d / 2.0 - 4), 0.1, 4.2, 6, Color("f0d0a0"), false, 6)
	b.box(c + Vector3(0, 6 + h - 6, 0), Vector3(w + 10, 8, d + 4), marble, true)
	var pr := PrismMesh.new()
	pr.size = Vector3(w + 10, 30, d + 4)
	var mi := MeshInstance3D.new()
	mi.mesh = pr
	mi.material_override = marble
	mi.position = c + Vector3(0, 6 + h + 2 + 15, 0)
	b.root.add_child(mi)
	b.label("BANQUE CENTRALE", c + Vector3(0, 6 + h - 2, d / 2.0 + 2.2), Color("2b2b2b"), 220)
	b.label("$", c + Vector3(0, 6 + h + 14, d / 2.0 + 2.2), Color("e0b23a"), 400)
	# porte du coffre : une capsule géante
	b.cyl(c + Vector3(0, 6, d / 2.0 - 25), 22, 22, 3, b.mat(Color("8a8f96"), 0.3, {"metallic": 0.8}), false, 21).rotation.x = PI / 2.0
	# piles de pièces devant
	for k in 6:
		var p := c + Vector3(-70 + k * 28, 6, d / 2.0 + 10)
		for s in b.rng.randi_range(2, 5):
			b.cyl(p + Vector3(0, s * 2.2, 0), 9.5, 9.5, 2.0, b.mat(Color("d9a92a"), 0.35, {"metallic": 0.8}), true, 20)
	b.spot("centre", c + Vector3(0, 6 + h + 34, 0))
	b.spot("centre", c + Vector3(0, 6 + h + 4, d / 2.0 + 2))
	b.landmark("La Banque", c)
	# une tour derrière la banque
	_building(Vector3(r.position.x + 40, y, r.position.y + 35), Vector2(60, 50), 320.0, "centre")


func _park(r: Rect2) -> void:
	var y := Layout.CURB_H
	var c := Vector3(r.get_center().x, y, r.get_center().y)
	b.box(c, Vector3(r.size.x - 24, 1.2, r.size.y - 24), b.mat(Color("5d8f36")), true, 0.0, null, "park")
	# fontaine : une capsule de bouteille géante remplie d'eau
	b.cyl(c + Vector3(0, 1.2, 0), 32, 32, 8, b.mat(Color("c8312a"), 0.4, {"metallic": 0.5}), true, 24)
	b.cyl(c + Vector3(0, 1.2, 0), 29, 29, 8.4, b.mat(Color("5aa0c8"), 0.05, {"metallic": 0.2}), false, 24)
	b.cyl(c + Vector3(0, 9.6, 0), 2, 3, 20, Color("cfcfcf"), true, 8)
	# arbres : des brocolis, évidemment
	for k in 7:
		var a := k / 7.0 * TAU
		var p := c + Vector3(cos(a) * 85, 1.2, sin(a) * 85)
		b.cyl(p, 5, 7, 40, Color("8fb35a"), true, 8)
		for f in 5:
			b.sphere(p + Vector3(b.rand(-12, 12), 48 + b.rand(-4, 8), b.rand(-12, 12)), b.rand(12, 17), Color("3f7a2a"), Vector3.ONE, false)
		b.spot("centre", p + Vector3(0, 42, 0)) if k % 3 == 0 else null
	for k in 4:
		var a := k / 4.0 * TAU + 0.4
		Props.bench(b, c + Vector3(cos(a) * 50, 1.2, sin(a) * 50), -a + PI / 2.0)
	Props.giant_hydrant(b, Vector3(r.position.x + 40, y + 1.2, r.position.y + 40))
	b.spot("centre", Vector3(r.position.x + 40, y + 72, r.position.y + 40))
	b.landmark("Le Parc", c)


func _dump(r: Rect2) -> void:
	var y := Layout.CURB_H
	var c := Vector3(r.get_center().x, y, r.get_center().y)
	Props.dumpster(b, c + Vector3(0, 0, -20), 0.2)
	b.spot("nuee", c + Vector3(0, 138, -20))
	for k in 10:
		var a := b.rand(0, TAU)
		Props.trash_bag(b, c + Vector3(cos(a) * b.rand(95, 120), 0, sin(a) * b.rand(85, 110)), b.rand(12, 22))
	Props.pizza_slice(b, c + Vector3(-90, 0, 90), 0.6)
	Props.apple_core(b, c + Vector3(80, 0, 95))
	b.spot("nuee", c + Vector3(80, 14, 95))
	# cabanes en bâche bleue
	for k in 3:
		var p := c + Vector3(-100 + k * 30, 0, 100)
		b.box(p, Vector3(22, 14, 18), Color("2f6fd6"), true)
		b.box(p + Vector3(0, 14, 0), Vector3(24, 1, 20), Color("23539f"), true)
	Props.flag(b, c + Vector3(-100, 0, -100), Layout.ZONES["nuee"]["color"], 50)
	b.label("NUÉE", c + Vector3(0, 40, 31.4), Layout.ZONES["nuee"]["color"], 300).rotation.y = 0.2


func _construction(r: Rect2) -> void:
	var y := Layout.CURB_H
	var c := Vector3(r.get_center().x, y, r.get_center().y)
	var orange: Color = Layout.ZONES["colonie"]["color"]
	# immeuble en construction : poteaux et dalles, on grimpe d'étage en étage
	var frame := c + Vector3(-50, 0, -40)
	for floor_i in 5:
		var fy := floor_i * 30.0
		b.box(frame + Vector3(0, fy, 0), Vector3(90, 2, 80), Color("a8a49c"), true, 0.0, null, "building" if floor_i == 0 else "")
		if floor_i < 4:
			for px in [-40.0, 40.0]:
				for pz in [-35.0, 35.0]:
					b.box(frame + Vector3(px, fy + 2, pz), Vector3(4, 28, 4), Color("8f8b84"), true)
	b.spot("colonie", frame + Vector3(0, 124, 0))
	# grue : un mât et une flèche
	var crane := c + Vector3(80, 0, -90)
	b.box(crane, Vector3(8, 220, 8), b.mat(orange), true)
	b.box(crane + Vector3(-50, 220, 0), Vector3(150, 6, 6), b.mat(orange), true)
	b.box(crane + Vector3(-118, 120, 0), Vector3(0.4, 100, 0.4), Color("333333"), false)
	b.box(crane + Vector3(-118, 112, 0), Vector3(14, 8, 14), Color("8a8a8a"), true)
	b.spot("colonie", crane + Vector3(-110, 228, 0))
	b.landmark("La Grue", crane)
	# piles de briques humaines
	for k in 3:
		var p := c + Vector3(70, 0, 40 + k * 30)
		for s in 3:
			b.box(p + Vector3(0, s * 6.5, 0), Vector3(22, 6.5, 10.5), Color("a8503a"), true, b.rand(-0.1, 0.1))
	# tas de sable et fourmilières
	b.cyl(c + Vector3(-80, 0, 80), 0, 50, 35, Color("d6b77a"), true, 14)
	for k in 3:
		var p := c + Vector3(b.rand(-30, 40), 0, b.rand(40, 110))
		b.cyl(p, 3, 18, 14, Color("7a5a3a"), true, 12)
		b.cyl(p + Vector3(0, 13.9, 0), 2.5, 2.5, 0.3, Color("111111"), false, 10)
	for k in 8:
		Props.traffic_cone(b, c + Vector3(b.rand(-110, 110), 0, b.rand(-110, 110)))
	b.spot("colonie", c + Vector3(-80, 36, 80))
	Props.flag(b, c + Vector3(-110, 0, -110), orange, 60)
	b.label("COLONIE", frame + Vector3(0, 10, 40.5), orange, 260)


## Le port des Prieurs : une flaque d'eau de pluie, des quais en bâtons de glace, des conteneurs.
func _puddle(r: Rect2) -> void:
	puddle_center = Vector3(r.get_center().x, 0, r.get_center().y)
	var water := b.mat(Color("3b6f8a"), 0.05, {"metallic": 0.3, "transparency": BaseMaterial3D.TRANSPARENCY_ALPHA, "albedo_color": Color(0.23, 0.44, 0.54, 0.85)})
	# l'eau est solide : une araignée marche sur l'eau
	b.cyl(puddle_center + Vector3(0, -0.2, 0), PUDDLE_R, PUDDLE_R, 0.6, water, true, 48, null, "water")
	var red: Color = Layout.ZONES["prieurs"]["color"]
	# quais (trottoirs) côté ouest et sud
	var quay := b.mat(Color("8f8a80"), 0.95)
	b.box(Vector3(r.position.x + 12, 0, r.get_center().y), Vector3(24, Layout.CURB_H, r.size.y), quay, true, 0.0, null, "sidewalk")
	b.box(Vector3(r.get_center().x, 0, r.end.y - 12), Vector3(r.size.x, Layout.CURB_H, 24), quay, true, 0.0, null, "sidewalk")
	# pontons en bâtons de glace
	for k in 3:
		var z := puddle_center.z - 60 + k * 55
		b.box(Vector3(r.position.x + 24 + 45, 2.5, z), Vector3(90, 1.2, 10), Color("e3c58d"), true, 0.0, null, "sidewalk")
		b.spot("prieurs", Vector3(r.position.x + 24 + 85, 6, z)) if k == 1 else null
	# bateaux : coquilles de noix
	for k in 3:
		var p := puddle_center + Vector3(b.rand(-50, 50), 0.3, b.rand(-50, 50))
		b.sphere(p, 18, Color("7a5230"), Vector3(1.3, 0.45, 0.9), true)
		Props.flag(b, p + Vector3(0, 6, 0), red, 25)
	b.spot("prieurs", puddle_center + Vector3(0, 2, 0))
	# conteneurs : des boîtes d'allumettes empilées sur le quai sud
	for k in 5:
		for s in b.rng.randi_range(1, 3):
			var col: Color = b.pick([red, Color("2a6fd6"), Color("2a9d6f"), Color("e0b23a")])
			b.box(Vector3(r.position.x + 50 + k * 40, Layout.CURB_H + s * 12.0 - 12.0, r.end.y - 12), Vector3(34, 12, 18), col, true)
	b.spot("prieurs", Vector3(r.position.x + 130, Layout.CURB_H + 38, r.end.y - 12))
	b.label("PRIEURS", puddle_center + Vector3(0, 1, 0), red, 600).rotation.x = -PI / 2.0
	b.landmark("La Flaque", puddle_center)


## Des toiles tendues entre les toits de La Toile : des passerelles pour qui sait tisser.
func _tisseuses_webs() -> void:
	var tops := []
	for f in b.footprints:
		if f["kind"] != "building":
			continue
		var c: Vector2 = f["rect"].get_center()
		if Layout.zone_at(c.x, c.y) == "tisseuses":
			tops.append(Vector3(c.x, f["top"], c.y))
	var made := 0
	for a in tops:
		for o in tops:
			if made >= 10 or a == o or a.x > o.x:
				continue
			var d := Vector2(a.x - o.x, a.z - o.z).length()
			if d > 50.0 and d < 130.0 and b.rng.randf() < 0.6:
				b.silk(a + Vector3(0, 1.6, 0), o + Vector3(0, 1.6, 0))
				Props.web_decor(b, (a + o) / 2.0 - Vector3(0, 25, 0), 14.0, atan2(o.x - a.x, o.z - a.z) + PI / 2.0)
				made += 1
	if tops.size() > 0:
		b.spot("tisseuses", tops[0] + Vector3(0, 2, 0))


# ---------- Décor de fond ----------

## Les immeubles des humains autour de la ruelle, puis les gratte-ciel au loin, comme le skyline de Los Santos.
func _backdrop() -> void:
	var brick := Tex.world_mat(Tex.bricks(), Color(1, 1, 1), 1.0 / 40.0)
	var human_win := Tex.world_mat(Tex.windows(0.25, 5), Color("8f877a"), 1.0 / 220.0)
	var H := Layout.HALF
	# murs de briques de la ruelle (nord, ouest, est) et trottoir humain au sud
	for w in [
		b.box(Vector3(0, 0, -H - 30), Vector3(2 * H + 120, 900, 60), brick, true),
		b.box(Vector3(-H - 30, 0, 0), Vector3(60, 900, 2 * H + 120), brick, true),
		b.box(Vector3(H + 30, 0, 0), Vector3(60, 900, 2 * H + 120), brick, true),
	]:
		w.add_to_group("alley_walls")
	# au sud, la façade d'une boutique humaine avec sa vitrine
	b.box(Vector3(0, 0, H + 30), Vector3(2 * H + 120, 900, 60), Tex.world_mat(Tex.bricks(), Color("c8b8a8"), 1.0 / 40.0), true).add_to_group("alley_walls")
	b.box(Vector3(-200, 60, H + 0.5), Vector3(500, 300, 2), b.mat(Color("2f4a63"), 0.15, {"metallic": 0.5}), false).add_to_group("alley_walls")
	b.box(Vector3(-200, 360, H - 40), Vector3(540, 8, 80), b.mat(Color("2a6f4a")), true).add_to_group("alley_walls")
	b.label("ÉPICERIE", Vector3(-200, 400, H - 0.5), Color("f2f2f2"), 900, PI).add_to_group("alley_walls")
	# fenêtres et escalier de secours sur les murs
	for x in [-350.0, 0.0, 350.0]:
		b.box(Vector3(x, 450, -H + 0.5), Vector3(180, 220, 2), b.mat(Color("2f4a63"), 0.2, {"metallic": 0.4}), false).add_to_group("alley_walls")
		for k in 3:
			b.box(Vector3(x + 150, 200 + k * 220, -H + 25), Vector3(140, 3, 50), Color("2b2b2b"), true).add_to_group("alley_walls")
	# skyline
	for k in 60:
		var a := k / 60.0 * TAU + b.rand(-0.04, 0.04)
		var dist := b.rand(1900, 4200)
		var pos := Vector3(cos(a) * dist, 0, sin(a) * dist)
		var w := b.rand(250, 700)
		var h := b.rand(1200, 6000) if pos.z < 0 else b.rand(800, 3000)
		var m := human_win if k % 3 else Tex.world_mat(Tex.windows(0.15, k), Color(b.pick(["6f8299", "7c8a99", "9a9182", "56657a"])), 1.0 / 260.0)
		b.box(pos, Vector3(w, h, w * b.rand(0.6, 1.2)), m, false, a, null, "", false)
