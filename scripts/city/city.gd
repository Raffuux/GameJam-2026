extends RefCounted
## Construit toute la ville : sol, rues courbes avec trottoirs, immeubles alignés le long des rues,
## lieux spéciaux, décor de fond façon GTA. Tout est déterministe (graine fixe).

const Layout := preload("res://scripts/city/layout.gd")
const Builder := preload("res://scripts/city/builder.gd")
const Props := preload("res://scripts/city/props.gd")
const Tex := preload("res://scripts/city/textures.gd")

## Hauteurs des couches de la chaussée (le sol est à 0).
const SIDEWALK_Y := 0.4
const ROAD_Y := 0.55
const SIDEWALK_W := 9.0
const CELL := 60.0

var b: Builder
var facade_mats := {}
var puddle_center := Vector3(Layout.SITES["puddle"]["pos"].x, 0, Layout.SITES["puddle"]["pos"].y)
## Échantillons de toutes les rues : position, demi-largeur, tangente, numéro de rue.
var road_samples: Array = []
var _grid := {}
## Immeubles déjà posés (pour éviter les chevauchements) : { c, hx, hz, rot }
var _placed: Array = []
## Points de trottoir par quartier, pour faire patrouiller les gangs : [pos, direction]
var sidewalk_points := {}

## Couleurs, hauteurs, largeur sur rue, profondeur, écart entre immeubles, par quartier.
const STYLE := {
	"centre": {"colors": ["c9c3b5", "a7b4c2", "d8cfc0", "8fa3b8", "e2dccf", "b7a99a"], "h": [140.0, 380.0], "w": [48.0, 85.0], "d": [45.0, 80.0], "gap": [5.0, 12.0], "model": "building_tower"},
	"tisseuses": {"colors": ["4b3f57", "3d3646", "5a4d66", "2e2a35", "54485e"], "h": [70.0, 180.0], "w": [26.0, 48.0], "d": [30.0, 55.0], "gap": [2.0, 5.0], "model": ""},
	"prieurs": {"colors": ["8d6e57", "7a6a5a", "9a8a73", "6e5a4a"], "h": [35.0, 70.0], "w": [60.0, 100.0], "d": [50.0, 80.0], "gap": [10.0, 22.0], "model": ""},
	"nuee": {"colors": ["7d8a8f", "6b7378", "8a8f7d", "5f676b"], "h": [40.0, 110.0], "w": [38.0, 70.0], "d": [35.0, 65.0], "gap": [8.0, 18.0], "model": "building_carton"},
	"colonie": {"colors": ["b5835a", "c49a6c", "a8714a", "9a6a48"], "h": [30.0, 90.0], "w": [34.0, 64.0], "d": [32.0, 60.0], "gap": [6.0, 16.0], "model": "building_box"},
}


func build(parent: Node3D) -> Builder:
	b = Builder.new(parent)
	var win_tex := Tex.windows(0.3, 11)
	for zone in STYLE:
		var list := []
		for hex in STYLE[zone]["colors"]:
			list.append(Tex.world_mat(win_tex, Color(hex), 1.0 / 24.0))
		facade_mats[zone] = list
	_sample_roads()
	_ground()
	_roads()
	_sites()
	_frontage_buildings()
	_infill_buildings()
	_street_props()
	_territory_markers()
	_tisseuses_webs()
	_backdrop()
	return b


# ---------- Rues : échantillons et requêtes ----------

func _sample_roads() -> void:
	for ri in Layout.ROADS.size():
		var road: Array = Layout.ROADS[ri]
		var pts := Layout.sample_road(road[2], 6.0)
		for k in pts.size():
			var t := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var s := {"p": pts[k], "hw": road[1] / 2.0, "t": t, "road": ri}
			var key := Vector2i(floori(pts[k].x / CELL), floori(pts[k].y / CELL))
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(road_samples.size())
			road_samples.append(s)


func _near_samples(p: Vector2, radius: float) -> Array:
	var out := []
	var r := ceili(radius / CELL)
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for i in range(c.x - r, c.x + r + 1):
		for j in range(c.y - r, c.y + r + 1):
			for idx in _grid.get(Vector2i(i, j), []):
				out.append(road_samples[idx])
	return out


## Distance au bord de la chaussée la plus proche (négative = sur la chaussée), et l'échantillon le plus proche.
## `skip_road` ignore une rue (pour savoir si une rue en croise une autre).
func road_clearance(p: Vector2, skip_road: int = -1, radius: float = 120.0) -> Array:
	var best := INF
	var best_s = null
	for s in _near_samples(p, radius):
		if s["road"] == skip_road:
			continue
		var d: float = p.distance_to(s["p"]) - s["hw"]
		if d < best:
			best = d
			best_s = s
	return [best, best_s]


# ---------- Sol et rues ----------

## Le sol : du béton teinté par quartier, avec des frontières qui se fondent.
func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 100
	var span := Layout.HALF + 40.0
	var step := span * 2.0 / n
	var base := Color("8d8a84")
	var colors := {}
	for j in n + 1:
		for i in n + 1:
			var x := -span + i * step
			var z := -span + j * step
			var col := Color(0, 0, 0)
			# moyenne sur quelques points voisins : frontières adoucies
			for o: Vector2 in [Vector2(0, 0), Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
				col += base.lerp(Layout.ZONES[Layout.zone_at(x + o.x, z + o.y)]["color"], 0.28) / 5.0
			col.a = 1.0
			colors[Vector2i(i, j)] = col
	for j in n:
		for i in n:
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var v := Vector2i(i, j) + c
				st.set_color(colors[v])
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(-span + v.x * step, 0, -span + v.y * step))
	var m := Tex.world_mat(Tex.noise(Color("b9b6b0"), Color("e6e3dc"), 0.07), Color.WHITE, 1.0 / 50.0, 0.95)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(mi)
	# collision : une grande dalle dont le dessus est à 0, invisible sous le sol
	b.box(Vector3(0, -20, 0), Vector3(6000, 19.9, 6000), b.mat(Color("6a6862")), true, 0.0, null, "", false)


## Ruban le long d'une courbe : plat au centre à hauteur `y`, bords en pente douce jusqu'à `y_edge`.
func _ribbon(st: SurfaceTool, pts: PackedVector2Array, hw: float, y: float, bevel: float, y_edge: float) -> void:
	var rows := []
	for k in pts.size():
		var t := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var nrm := Vector2(-t.y, t.x)
		var p := pts[k]
		rows.append([
			Vector3(p.x + nrm.x * (hw + bevel), y_edge, p.y + nrm.y * (hw + bevel)),
			Vector3(p.x + nrm.x * hw, y, p.y + nrm.y * hw),
			Vector3(p.x - nrm.x * hw, y, p.y - nrm.y * hw),
			Vector3(p.x - nrm.x * (hw + bevel), y_edge, p.y - nrm.y * (hw + bevel)),
		])
	for k in rows.size() - 1:
		for c in 3:
			var a: Vector3 = rows[k][c]
			var bb: Vector3 = rows[k][c + 1]
			var cc: Vector3 = rows[k + 1][c + 1]
			var d: Vector3 = rows[k + 1][c]
			for v in [a, bb, cc, a, cc, d]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)


func _roads() -> void:
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var asphalt_st := SurfaceTool.new()
	asphalt_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road in Layout.ROADS:
		var pts := Layout.sample_road(road[2], 4.0)
		var hw: float = road[1] / 2.0
		_ribbon(walk, pts, hw + SIDEWALK_W - 1.5, SIDEWALK_Y, 1.5, 0.0)
		_ribbon(asphalt_st, pts, hw - 0.6, ROAD_Y, 0.6, SIDEWALK_Y - 0.05)
	var sidewalk_mat := Tex.world_mat(Tex.noise(Color("a9a59c"), Color("c4c0b6"), 0.12), Color.WHITE, 1.0 / 30.0, 0.95)
	var asphalt_mat := Tex.world_mat(Tex.noise(Color("34363a"), Color("4a4c50"), 0.09), Color.WHITE, 1.0 / 60.0, 0.95)
	for pair in [[walk, sidewalk_mat], [asphalt_st, asphalt_mat]]:
		var st: SurfaceTool = pair[0]
		var mesh := st.commit()
		pair[1].cull_mode = BaseMaterial3D.CULL_DISABLED
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		b.root.add_child(body)
	_markings()


## Marquages : pointillés jaunes au centre, passages piétons à l'entrée des carrefours.
func _markings() -> void:
	var dashes := []
	var stripes := []
	var y := ROAD_Y + 0.08
	for ri in Layout.ROADS.size():
		var road: Array = Layout.ROADS[ri]
		var hw: float = road[1] / 2.0
		var pts := Layout.sample_road(road[2], 2.0)
		var dist := 0.0
		var next_dash := 10.0
		var was_crossing := false
		for k in range(1, pts.size() - 1):
			var p := pts[k]
			var t := (pts[k + 1] - pts[k - 1]).normalized()
			var ang := atan2(t.x, t.y)
			dist += pts[k].distance_to(pts[k - 1])
			var other: float = road_clearance(p, ri, 60.0)[0]
			var crossing := other < 2.0
			if dist >= next_dash:
				next_dash += 20.0
				if road[1] >= 26.0 and other > 8.0:
					dashes.append(Transform3D(Basis(Vector3.UP, ang), Vector3(p.x, y, p.y)))
			# passage piéton juste avant d'entrer dans un carrefour (ou juste après en être sorti)
			if road[1] >= 18.0 and crossing != was_crossing and k > 3:
				var back := -t * 10.0 if crossing else t * 10.0
				var nrm := Vector2(-t.y, t.x)
				var w := -hw + 3.0
				while w <= hw - 3.0:
					var q := p + back + nrm * w
					stripes.append(Transform3D(Basis(Vector3.UP, ang), Vector3(q.x, y, q.y)))
					w += 5.0
			was_crossing = crossing
	_multimesh(Vector3(1.2, 0.1, 10.0), b.mat(Color("e8d36a"), 0.7), dashes)
	_multimesh(Vector3(2.6, 0.1, 10.0), b.mat(Color("eeeeee"), 0.7), stripes)


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


# ---------- Placement des immeubles ----------

## Axes x et z (vus de dessus) d'un objet tourné de `rot` autour de y.
static func _axes(rot: float) -> Array:
	return [Vector2(cos(rot), -sin(rot)), Vector2(sin(rot), cos(rot))]


## Distance d'un point à un rectangle orienté.
static func _dist_to_obb(p: Vector2, c: Vector2, hx: float, hz: float, rot: float) -> float:
	var ax: Array = _axes(rot)
	var d := p - c
	var lx := absf(d.dot(ax[0])) - hx
	var lz := absf(d.dot(ax[1])) - hz
	return Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()


static func _obb_overlap(a: Dictionary, o: Dictionary, margin: float) -> bool:
	var aa: Array = _axes(a["rot"])
	var oa: Array = _axes(o["rot"])
	var d: Vector2 = o["c"] - a["c"]
	for axis in [aa[0], aa[1], oa[0], oa[1]]:
		var ra: float = a["hx"] * absf(aa[0].dot(axis)) + a["hz"] * absf(aa[1].dot(axis))
		var ro: float = o["hx"] * absf(oa[0].dot(axis)) + o["hz"] * absf(oa[1].dot(axis))
		if absf(d.dot(axis)) > ra + ro + margin:
			return false
	return true


## Est-ce qu'un immeuble rentre ici sans toucher une rue, un lieu spécial, un mur ou un autre immeuble ?
func _fits(f: Dictionary, setback: float, margin: float) -> bool:
	var c: Vector2 = f["c"]
	var ax: Array = _axes(f["rot"])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner: Vector2 = c + ax[0] * f["hx"] * sx + ax[1] * f["hz"] * sz
			if absf(corner.x) > Layout.HALF - 12.0 or absf(corner.y) > Layout.HALF - 12.0:
				return false
	for id in Layout.SITES:
		if _dist_to_obb(Layout.SITES[id]["pos"], c, f["hx"], f["hz"], f["rot"]) < Layout.SITES[id]["r"]:
			return false
	var rad: float = Vector2(f["hx"], f["hz"]).length()
	for s in _near_samples(c, rad + 40.0):
		if _dist_to_obb(s["p"], c, f["hx"], f["hz"], f["rot"]) - s["hw"] < setback:
			return false
	for o in _placed:
		var orad: float = Vector2(o["hx"], o["hz"]).length()
		if c.distance_to(o["c"]) > rad + orad + margin:
			continue
		if _obb_overlap(f, o, margin):
			return false
	return true


## Première passe : une rangée d'immeubles collés à chaque rue, façade tournée vers la chaussée.
func _frontage_buildings() -> void:
	for ri in Layout.ROADS.size():
		var road: Array = Layout.ROADS[ri]
		var hw: float = road[1] / 2.0
		var pts := Layout.sample_road(road[2], 2.0)
		for side: float in [-1.0, 1.0]:
			var k := 1
			while k < pts.size() - 1:
				var p := pts[k]
				var t := (pts[k + 1] - pts[k - 1]).normalized()
				var nrm := Vector2(-t.y, t.x) * side
				var zone := Layout.zone_at(p.x + nrm.x * 40.0, p.y + nrm.y * 40.0)
				var st: Dictionary = STYLE[zone]
				var setback := SIDEWALK_W + 1.0
				var placed := false
				for attempt in 3:
					var w := b.rand(st["w"][0], st["w"][1]) * (1.0 - attempt * 0.25)
					var d := b.rand(st["d"][0], st["d"][1]) * (1.0 - attempt * 0.2)
					var c := p + t * (w / 2.0) + nrm * (hw + setback + d / 2.0 + 0.5)
					var f := {"c": c, "hx": w / 2.0, "hz": d / 2.0, "rot": atan2(-nrm.x, -nrm.y)}
					if _fits(f, setback, st["gap"][0]):
						_placed.append(f)
						_place_building(f, zone)
						k += int((w + b.rand(st["gap"][0], st["gap"][1])) / 2.0)
						placed = true
						break
				if not placed:
					k += 4


## Deuxième passe : on remplit l'arrière des îlots, toujours aligné sur la rue la plus proche.
func _infill_buildings() -> void:
	for n in 2500:
		var c := Vector2(b.rand(-Layout.HALF, Layout.HALF), b.rand(-Layout.HALF, Layout.HALF))
		var near: Array = road_clearance(c, -1, 240.0)
		if near[1] == null or near[0] < 20.0:
			continue
		var s: Dictionary = near[1]
		var to_road: Vector2 = (s["p"] - c).normalized()
		var zone := Layout.zone_at(c.x, c.y)
		var st: Dictionary = STYLE[zone]
		var w := b.rand(st["w"][0], st["w"][1])
		var d := b.rand(st["d"][0], st["d"][1])
		var f := {"c": c, "hx": w / 2.0, "hz": d / 2.0, "rot": atan2(to_road.x, to_road.y)}
		if _fits(f, SIDEWALK_W + 1.0, st["gap"][0] + 2.0):
			_placed.append(f)
			_place_building(f, zone)


func _place_building(f: Dictionary, zone: String) -> void:
	var c: Vector2 = f["c"]
	var g := b.group(Vector3(c.x, 0, c.y), f["rot"])
	var size := Vector2(f["hx"] * 2.0, f["hz"] * 2.0)
	var st: Dictionary = STYLE[zone]
	var h := b.rand(st["h"][0], st["h"][1])
	if zone == "centre":
		# les tours les plus hautes près du cœur de la ville
		h *= lerpf(1.25, 0.75, clampf(c.length() / 350.0, 0.0, 1.0))
	if zone == "prieurs":
		_warehouse(g, size, h)
	else:
		h = _building(g, size, h, zone)
	if b.rng.randf() < 0.5:
		b.spot(zone, g.position + Vector3(0, h + 2, 0))
	var gang: String = Layout.ZONES[zone]["gang"]
	var color: Color = Layout.ZONES[zone]["color"]
	if gang == "":
		return
	if b.rng.randf() < 0.4:
		_gang_flag(zone, Vector3(size.x * 0.3, h, size.y * 0.3), 24.0, g)
	if b.rng.randf() < 0.6:
		var tag := gang.split(" ")[1].to_upper()
		var l := b.label(tag, Vector3(b.rand(-size.x * 0.2, size.x * 0.2), b.rand(8, 18), size.y / 2.0 + 0.3), color, 140, 0.0, g)
		l.rotation.z = b.rand(-0.15, 0.15)
	if zone == "tisseuses" and b.rng.randf() < 0.5:
		b.box(Vector3(0, b.rand(20, 40), size.y / 2.0 + 0.4), Vector3(size.x * 0.6, 1.2, 0.4), b.glow(color, 4.0), false, 0.0, g, "", false)
	# poubelles dans les ruelles entre les immeubles
	if b.rng.randf() < 0.35:
		var p := g.transform * Vector3(size.x / 2.0 + 3.0, 0, b.rand(-size.y / 3.0, size.y / 3.0))
		Props.trash_bag(b, p, b.rand(4, 6))


## Un immeuble de ville en local (façade côté +z). Renvoie sa hauteur réelle.
func _building(g: Node3D, size: Vector2, h: float, zone: String) -> float:
	var model_name: String = STYLE[zone]["model"]
	if model_name != "" and b.rng.randf() < 0.25:
		var got := b.model(model_name, Vector3.ZERO, 0.0, Vector3(size.x, h, size.y), true, g, "building")
		if got != Vector3.ZERO:
			return got.y
	var m: Material = b.pick(facade_mats[zone])
	b.box(Vector3.ZERO, Vector3(size.x, h, size.y), m, true, 0.0, g, "building")
	# corniche et toit
	b.box(Vector3(0, h, 0), Vector3(size.x + 2, 1.5, size.y + 2), b.mat(Color("3b3b3e"), 0.9), true, 0.0, g)
	# détails de toit : clim, château d'eau, antenne
	for k in b.rng.randi_range(1, 3):
		var p := Vector3(b.rand(-size.x * 0.3, size.x * 0.3), h + 1.5, b.rand(-size.y * 0.3, size.y * 0.3))
		match b.rng.randi_range(0, 2):
			0:
				b.box(p, Vector3(8, 5, 6), Color("9aa0a6"), true, 0.0, g)
			1:
				b.cyl(p, 5, 5, 9, Color("7a5a3a"), true, 10, g)
				b.cyl(p + Vector3(0, 9, 0), 0.5, 5.5, 3, Color("5a4030"), false, 10, g)
			2:
				b.cyl(p, 0.3, 0.4, 18, Color("888888"), false, 4, g)
	# rez-de-chaussée : vitrine sombre, et auvent de la couleur du gang
	b.box(Vector3(0, 0, size.y / 2.0), Vector3(size.x * 0.7, 11, 0.6), b.mat(Color("2f4a63"), 0.15, {"metallic": 0.5}), false, 0.0, g)
	if Layout.ZONES[zone]["gang"] != "" and b.rng.randf() < 0.5:
		b.box(Vector3(0, 13, size.y / 2.0 + 3), Vector3(size.x * 0.6, 1, 6), b.mat(Layout.ZONES[zone]["color"]), true, 0.0, g)
	return h


## Entrepôt des docks : une boîte à chaussures avec un logo, plus large que haute.
func _warehouse(g: Node3D, size: Vector2, h: float) -> void:
	var color: Color = Layout.ZONES["prieurs"]["color"]
	b.box(Vector3.ZERO, Vector3(size.x, h, size.y), b.mat(b.pick([Color("c8a27a"), Color("b48a62"), Color("d0b48c")])), true, 0.0, g, "building")
	b.box(Vector3(0, h, 0), Vector3(size.x + 3, 4, size.y + 3), b.mat(Color("8a6a4a")), true, 0.0, g)
	b.box(Vector3(0, 0, size.y / 2.0), Vector3(size.x * 0.4, h * 0.6, 0.6), Color("5a4a3a"), false, 0.0, g)
	b.label("PRIEURS & CIE", Vector3(0, h * 0.8, size.y / 2.0 + 0.4), color, 120, 0.0, g)


## Drapeau du gang : le modèle du fil des assets, sinon un mât et un tissu de couleur.
func _gang_flag(zone: String, pos: Vector3, h: float, parent: Node3D = null) -> void:
	if b.model("flag_" + zone, pos, b.rand(0, TAU), Vector3(0, h, 0), false, parent) != Vector3.ZERO:
		return
	var world := parent.transform * pos if parent else pos
	Props.flag(b, world, Layout.ZONES[zone]["color"], h)


# ---------- Trottoirs ----------

func _street_props() -> void:
	for ri in Layout.ROADS.size():
		var road: Array = Layout.ROADS[ri]
		var hw: float = road[1] / 2.0
		var pts := Layout.sample_road(road[2], 2.0)
		for side: float in [-1.0, 1.0]:
			var k := 4 + b.rng.randi_range(0, 10)
			var count := 0
			while k < pts.size() - 4:
				var p := pts[k]
				var t := (pts[k + 1] - pts[k - 1]).normalized()
				var nrm := Vector2(-t.y, t.x) * side
				var q := p + nrm * (hw + 4.5)
				k += b.rng.randi_range(14, 30)
				if absf(q.x) > Layout.HALF - 10.0 or absf(q.y) > Layout.HALF - 10.0:
					continue
				if road_clearance(q, ri, 60.0)[0] < 6.0 or _in_site(q, 10.0):
					continue
				var zone := Layout.zone_at(q.x, q.y)
				var pos := Vector3(q.x, SIDEWALK_Y, q.y)
				if not sidewalk_points.has(zone):
					sidewalk_points[zone] = []
				sidewalk_points[zone].append([pos, Vector3(t.x, 0, t.y)])
				count += 1
				if count % 3 == 0:
					# le bras du lampadaire (côté -z) au-dessus de la chaussée
					Props.streetlight(b, pos, atan2(nrm.x, nrm.y))
					continue
				var roll := b.rng.randf()
				if roll < 0.25:
					Props.hydrant(b, pos)
				elif roll < 0.45:
					Props.soda_can(b, pos, b.pick([Color("d62828"), Color("2a9d8f"), Color("f4a261"), Color("e9e3d6")]), b.rng.randf() < 0.4)
				elif roll < 0.6:
					Props.trash_bag(b, pos, b.rand(5, 8))
				elif roll < 0.72:
					if Layout.ZONES[zone]["gang"] != "":
						_gang_flag(zone, pos, 30.0)
					else:
						Props.bench(b, pos, atan2(-nrm.x, -nrm.y))
				elif roll < 0.8:
					Props.paper_ball(b, pos, b.rand(1.5, 3.0))
		# déchets sur la chaussée
		for n in pts.size() / 25:
			var p := pts[b.rng.randi_range(0, pts.size() - 1)]
			var off := Vector2(b.rand(-hw, hw), b.rand(-hw, hw)) * 0.8
			var pos := Vector3(p.x + off.x, ROAD_Y, p.y + off.y)
			if absf(pos.x) > Layout.HALF - 5.0 or absf(pos.z) > Layout.HALF - 5.0:
				continue
			match n % 3:
				0:
					Props.bottle_cap(b, pos, b.pick([Color("c8312a"), Color("2a6fd6"), Color("e0b23a"), Color("2a9d6f")]))
				1:
					Props.cigarette_butt(b, pos)
				2:
					Props.paper_ball(b, pos, b.rand(1.5, 3.5))


func _in_site(p: Vector2, margin: float = 0.0) -> bool:
	for id in Layout.SITES:
		if p.distance_to(Layout.SITES[id]["pos"]) < Layout.SITES[id]["r"] - margin:
			return true
	return false


## Là où une rue entre dans un territoire de gang : une borne aux couleurs du gang de chaque côté, et une bande peinte.
func _territory_markers() -> void:
	for ri in Layout.ROADS.size():
		var road: Array = Layout.ROADS[ri]
		var hw: float = road[1] / 2.0
		var pts := Layout.sample_road(road[2], 4.0)
		var prev := Layout.zone_at(pts[0].x, pts[0].y)
		for k in range(1, pts.size() - 1):
			var zone := Layout.zone_at(pts[k].x, pts[k].y)
			if zone == prev:
				continue
			var entering := zone if Layout.ZONES[zone]["gang"] != "" else prev
			prev = zone
			if Layout.ZONES[entering]["gang"] == "":
				continue
			var t := (pts[k + 1] - pts[k - 1]).normalized()
			for side: float in [-1.0, 1.0]:
				var nrm := Vector2(-t.y, t.x) * side
				var q := pts[k] + nrm * (hw + 4.5)
				if road_clearance(q, ri, 60.0)[0] < 5.0 or absf(q.x) > Layout.HALF - 10.0 or absf(q.y) > Layout.HALF - 10.0:
					continue
				var pos := Vector3(q.x, SIDEWALK_Y, q.y)
				if b.model("marker_" + entering, pos, atan2(-nrm.x, -nrm.y), Vector3(0, 9, 0)) == Vector3.ZERO:
					b.cyl(pos, 2.2, 2.6, 8.0, b.mat(Layout.ZONES[entering]["color"]), true, 10)
			var c := pts[k]
			b.box(Vector3(c.x, ROAD_Y + 0.05, c.y), Vector3(hw * 2.0 - 2.0, 0.1, 3.0), b.mat(Layout.ZONES[entering]["color"], 0.7), false, atan2(-t.x, -t.y), null, "", false)


# ---------- Lieux spéciaux ----------

## Un groupe posé sur un lieu spécial, tourné pour que son entrée (+z) regarde la rue la plus proche.
func _site_group(id: String) -> Node3D:
	var c: Vector2 = Layout.SITES[id]["pos"]
	var near: Array = road_clearance(c, -1, 300.0)
	var rot := 0.0
	if near[1] != null:
		var dir: Vector2 = near[1]["p"] - c
		rot = atan2(dir.x, dir.y)
	return b.group(Vector3(c.x, 0, c.y), rot)


func _sites() -> void:
	_bank(_site_group("bank"))
	_park(_site_group("park"))
	_dump(_site_group("dumpster"))
	_construction(_site_group("construction"))
	_puddle()


## La banque : temple néoclassique, colonnes en crayons, pièces d'or.
func _bank(g: Node3D) -> void:
	var marble := b.mat(Color("ece6da"), 0.5)
	var w := 160.0
	var d := 110.0
	var h := 100.0
	b.box(Vector3.ZERO, Vector3(w + 30, 6, d + 40), marble, true, 0.0, g, "landmark")
	b.box(Vector3(0, 0, d / 2.0 + 18), Vector3(w + 30, 3, 10), marble, true, 0.0, g)
	b.box(Vector3(0, 6, -10), Vector3(w, h, d - 20), marble, true, 0.0, g, "building")
	for k in 8:
		var x := -w / 2.0 + 10 + k * (w - 20) / 7.0
		b.cyl(Vector3(x, 6, d / 2.0 - 4), 4.2, 4.2, h - 12, b.mat(Color("f2c230")), true, 6, g)
		b.cyl(Vector3(x, 6 + h - 12, d / 2.0 - 4), 0.1, 4.2, 6, Color("f0d0a0"), false, 6, g)
	b.box(Vector3(0, 6 + h - 6, 0), Vector3(w + 10, 8, d + 4), marble, true, 0.0, g)
	var pr := PrismMesh.new()
	pr.size = Vector3(w + 10, 30, d + 4)
	var mi := MeshInstance3D.new()
	mi.mesh = pr
	mi.material_override = marble
	mi.position = Vector3(0, 6 + h + 2 + 15, 0)
	g.add_child(mi)
	b.label("BANQUE CENTRALE", Vector3(0, 6 + h - 2, d / 2.0 + 2.2), Color("2b2b2b"), 220, 0.0, g)
	b.label("$", Vector3(0, 6 + h + 14, d / 2.0 + 2.2), Color("e0b23a"), 400, 0.0, g)
	b.cyl(Vector3(0, 6, d / 2.0 - 25), 22, 22, 3, b.mat(Color("8a8f96"), 0.3, {"metallic": 0.8}), false, 21, g).rotation.x = PI / 2.0
	for k in 6:
		var p := Vector3(-70 + k * 28, 6, d / 2.0 + 10)
		for s in b.rng.randi_range(2, 5):
			b.cyl(p + Vector3(0, s * 2.2, 0), 9.5, 9.5, 2.0, b.mat(Color("d9a92a"), 0.35, {"metallic": 0.8}), true, 20, g)
	b.spot("centre", g.transform * Vector3(0, 6 + h + 34, 0))
	b.spot("centre", g.transform * Vector3(0, 6 + h + 4, d / 2.0 + 2))
	b.landmark("La Banque", g.position)


func _park(g: Node3D) -> void:
	b.cyl(Vector3.ZERO, 88, 88, 1.2, b.mat(Color("5d8f36")), true, 28, g, "park")
	# fontaine : une capsule de bouteille géante remplie d'eau
	b.cyl(Vector3(0, 1.2, 0), 32, 32, 8, b.mat(Color("c8312a"), 0.4, {"metallic": 0.5}), true, 24, g)
	b.cyl(Vector3(0, 1.2, 0), 29, 29, 8.4, b.mat(Color("5aa0c8"), 0.05, {"metallic": 0.2}), false, 24, g)
	b.cyl(Vector3(0, 9.6, 0), 2, 3, 20, Color("cfcfcf"), true, 8, g)
	# arbres : des brocolis, évidemment
	for k in 7:
		var a := k / 7.0 * TAU
		var p := Vector3(cos(a) * 64, 1.2, sin(a) * 64)
		b.cyl(p, 5, 7, 40, Color("8fb35a"), true, 8, g)
		for f in 5:
			b.sphere(p + Vector3(b.rand(-12, 12), 48 + b.rand(-4, 8), b.rand(-12, 12)), b.rand(12, 17), Color("3f7a2a"), Vector3.ONE, false, g)
		if k % 3 == 0:
			b.spot("centre", g.transform * (p + Vector3(0, 42, 0)))
	for k in 4:
		var a := k / 4.0 * TAU + 0.4
		Props.bench(b, g.transform * Vector3(cos(a) * 45, 1.2, sin(a) * 45), g.rotation.y - a + PI / 2.0)
	var hyd := g.transform * Vector3(-40, 1.2, 40)
	Props.giant_hydrant(b, hyd)
	b.spot("centre", hyd + Vector3(0, 70, 0))
	b.landmark("Le Parc", g.position)


func _dump(g: Node3D) -> void:
	Props.dumpster(b, g.transform * Vector3(0, 0, -15), g.rotation.y)
	b.spot("nuee", g.transform * Vector3(0, 138, -15))
	for k in 12:
		var a := b.rand(0, TAU)
		var p := g.transform * Vector3(cos(a) * b.rand(95, 115), 0, sin(a) * b.rand(80, 100))
		if road_clearance(Vector2(p.x, p.z))[0] > 18.0:
			Props.trash_bag(b, p, b.rand(12, 20))
	Props.pizza_slice(b, g.transform * Vector3(-75, 0, 70), g.rotation.y + 0.6)
	var apple := g.transform * Vector3(70, 0, 75)
	Props.apple_core(b, apple)
	b.spot("nuee", apple + Vector3(0, 14, 0))
	# cabanes en bâche bleue
	for k in 3:
		var p := Vector3(-90 + k * 30, 0, 60)
		b.box(p, Vector3(22, 14, 18), Color("2f6fd6"), true, 0.0, g)
		b.box(p + Vector3(0, 14, 0), Vector3(24, 1, 20), Color("23539f"), true, 0.0, g)
	_gang_flag("nuee", Vector3(-95, 0, -80), 50.0, g)
	b.label("NUÉE", Vector3(0, 40, 40), Layout.ZONES["nuee"]["color"], 300, 0.0, g)


func _construction(g: Node3D) -> void:
	var orange: Color = Layout.ZONES["colonie"]["color"]
	# immeuble en construction : poteaux et dalles, on grimpe d'étage en étage
	var frame := Vector3(-35, 0, -30)
	for floor_i in 5:
		var fy := floor_i * 30.0
		b.box(frame + Vector3(0, fy, 0), Vector3(90, 2, 80), Color("a8a49c"), true, 0.0, g, "building" if floor_i == 0 else "")
		if floor_i < 4:
			for px in [-40.0, 40.0]:
				for pz in [-35.0, 35.0]:
					b.box(frame + Vector3(px, fy + 2, pz), Vector3(4, 28, 4), Color("8f8b84"), true, 0.0, g)
	b.model("scaffolding", frame + Vector3(0, 0, 46), 0.0, Vector3(80, 120, 0), true, g)
	b.spot("colonie", g.transform * (frame + Vector3(0, 124, 0)))
	# grue : un mât et une flèche
	var crane := Vector3(60, 0, -60)
	b.box(crane, Vector3(8, 220, 8), b.mat(orange), true, 0.0, g)
	b.box(crane + Vector3(-50, 220, 0), Vector3(150, 6, 6), b.mat(orange), true, 0.0, g)
	b.box(crane + Vector3(-118, 120, 0), Vector3(0.4, 100, 0.4), Color("333333"), false, 0.0, g)
	b.box(crane + Vector3(-118, 112, 0), Vector3(14, 8, 14), Color("8a8a8a"), true, 0.0, g)
	b.spot("colonie", g.transform * (crane + Vector3(-110, 228, 0)))
	b.landmark("La Grue", g.transform * crane)
	# piles de briques humaines
	for k in 3:
		var p := Vector3(60, 0, 20 + k * 25)
		for s in 3:
			b.box(p + Vector3(0, s * 6.5, 0), Vector3(22, 6.5, 10.5), Color("a8503a"), true, b.rand(-0.1, 0.1), g)
	# tas de sable et fourmilières
	b.cyl(Vector3(-60, 0, 60), 0, 40, 30, Color("d6b77a"), true, 14, g)
	b.spot("colonie", g.transform * Vector3(-60, 31, 60))
	if b.model("anthill", Vector3(10, 0, 70), 0.0, Vector3(40, 0, 40), true, g) == Vector3.ZERO:
		b.cyl(Vector3(10, 0, 70), 3, 18, 14, Color("7a5a3a"), true, 12, g)
	for k in 8:
		Props.traffic_cone(b, g.transform * Vector3(b.rand(-90, 90), 0, b.rand(-90, 90)))
	_gang_flag("colonie", Vector3(-90, 0, -90), 60.0, g)
	b.label("COLONIE", frame + Vector3(0, 10, 40.5), orange, 260, 0.0, g)


## Le port des Prieurs : une flaque d'eau de pluie, des pontons en bâtons de glace, des conteneurs.
func _puddle() -> void:
	var water := b.mat(Color("3b6f8a"), 0.05, {"metallic": 0.3, "transparency": BaseMaterial3D.TRANSPARENCY_ALPHA, "albedo_color": Color(0.23, 0.44, 0.54, 0.85)})
	# bord de quai en béton, puis l'eau : elle est solide, une araignée marche sur l'eau
	b.cyl(puddle_center, Layout.PUDDLE_R + 10, Layout.PUDDLE_R + 10, 0.3, b.mat(Color("8f8a80"), 0.95), false, 48)
	b.cyl(puddle_center + Vector3(0, 0.05, 0), Layout.PUDDLE_R, Layout.PUDDLE_R, 0.5, water, true, 48, null, "water")
	var red: Color = Layout.ZONES["prieurs"]["color"]
	# pontons en bâtons de glace, en étoile depuis la rive
	for a in [PI * 0.8, PI, PI * 1.2, PI * 0.5, PI * 0.3]:
		var dir := Vector3(cos(a), 0, sin(a))
		var mid := puddle_center + dir * (Layout.PUDDLE_R - 34.0)
		b.box(Vector3(mid.x, 0.5, mid.z), Vector3(10, 1.2, 84), Color("e3c58d"), true, atan2(dir.x, dir.z), null, "sidewalk")
	b.spot("prieurs", puddle_center + Vector3(-Layout.PUDDLE_R + 40, 4, 0))
	# bateaux : coquilles de noix
	for k in 3:
		var p := puddle_center + Vector3(b.rand(-40, 40), 0.4, b.rand(-40, 40))
		b.sphere(p, 18, Color("7a5230"), Vector3(1.3, 0.45, 0.9), true)
		Props.flag(b, p + Vector3(0, 6, 0), red, 25)
	b.spot("prieurs", puddle_center + Vector3(0, 2, 0))
	# conteneurs : des boîtes d'allumettes empilées sur la rive
	for k in 5:
		var a := PI * 0.55 + k * 0.2
		var p := puddle_center + Vector3(cos(a), 0, sin(a)) * (Layout.PUDDLE_R + 14.0)
		if road_clearance(Vector2(p.x, p.z))[0] < 20.0:
			continue
		for s in b.rng.randi_range(1, 3):
			var col: Color = b.pick([red, Color("2a6fd6"), Color("2a9d6f"), Color("e0b23a")])
			b.box(p + Vector3(0, s * 12.0 - 12.0, 0), Vector3(34, 12, 18), col, true, -a + PI / 2.0)
		if k == 2:
			b.spot("prieurs", p + Vector3(0, 38, 0))
	b.label("PRIEURS", puddle_center + Vector3(0, 0.7, 0), red, 600).rotation.x = -PI / 2.0
	b.landmark("La Flaque", puddle_center)


## Des toiles tendues entre les toits de La Toile : des passerelles pour qui sait tisser.
func _tisseuses_webs() -> void:
	var tops := []
	for f in b.footprints:
		if f["kind"] != "building":
			continue
		var c: Vector2 = f["c"]
		if Layout.zone_at(c.x, c.y) == "tisseuses":
			tops.append(Vector3(c.x, f["top"], c.y))
	var made := 0
	for a in tops:
		for o in tops:
			if made >= 14 or a == o or a.x > o.x:
				continue
			var d := Vector2(a.x - o.x, a.z - o.z).length()
			if d > 40.0 and d < 110.0 and b.rng.randf() < 0.5:
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
