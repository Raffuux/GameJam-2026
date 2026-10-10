extends RefCounted
## Dessine la carte vue de dessus une seule fois : territoires teintés de la couleur de leur gang,
## rues courbes, immeubles orientés, parc et flaque.

const Layout := preload("res://scripts/city/layout.gd")

const PX_PER_UNIT := 0.5
const SIZE := 600 # pixels, pour 1200 unités


static func to_px(x: float, z: float) -> Vector2:
	return Vector2((x + Layout.HALF) * PX_PER_UNIT, (z + Layout.HALF) * PX_PER_UNIT)


static func _disc(img: Image, c: Vector2, r: float, color: Color) -> void:
	for dy in range(-int(r), int(r) + 1):
		var half := sqrt(maxf(r * r - dy * dy, 0.0))
		var row := Rect2i(int(c.x - half), int(c.y) + dy, int(half * 2.0) + 1, 1)
		img.fill_rect(row.intersection(Rect2i(0, 0, SIZE, SIZE)), color)


## Rectangle orienté (emprise d'immeuble) en pixels.
static func _obb(img: Image, f: Dictionary, color: Color) -> void:
	var c := to_px(f["c"].x, f["c"].y)
	var rot: float = f["rot"]
	var ax := Vector2(cos(rot), -sin(rot))
	var az := Vector2(sin(rot), cos(rot))
	var hx: float = f["hx"] * PX_PER_UNIT
	var hz: float = f["hz"] * PX_PER_UNIT
	var ext := Vector2(hx * absf(ax.x) + hz * absf(az.x), hx * absf(ax.y) + hz * absf(az.y))
	for y in range(maxi(0, int(c.y - ext.y)), mini(SIZE, int(c.y + ext.y) + 1)):
		for x in range(maxi(0, int(c.x - ext.x)), mini(SIZE, int(c.x + ext.x) + 1)):
			var d := Vector2(x + 0.5, y + 0.5) - c
			if absf(d.dot(ax)) <= hx and absf(d.dot(az)) <= hz:
				img.set_pixel(x, y, color)


static func render(footprints: Array, puddle_center: Vector3, puddle_r: float) -> ImageTexture:
	# territoires : une teinte par quartier, calculée à mi-résolution
	var half := SIZE / 2
	var zones := Image.create(half, half, false, Image.FORMAT_RGBA8)
	var ids := []
	for y in half:
		var row := []
		for x in half:
			var wx := (x + 0.5) * 2.0 / PX_PER_UNIT - Layout.HALF
			var wz := (y + 0.5) * 2.0 / PX_PER_UNIT - Layout.HALF
			var z := Layout.zone_at(wx, wz)
			row.append(z)
			zones.set_pixel(x, y, Color("3a3b3e").lerp(Layout.ZONES[z]["color"], 0.42))
		ids.append(row)
	# frontières : un liseré clair là où le quartier change
	for y in half:
		for x in half:
			var z: String = ids[y][x]
			if (x + 1 < half and ids[y][x + 1] != z) or (y + 1 < half and ids[y + 1][x] != z):
				zones.set_pixel(x, y, Color(1, 1, 1, 0.9))
	zones.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	var img := zones
	# rues : trottoir clair puis chaussée sombre
	for pass_i in 2:
		for road in Layout.ROADS:
			var hw: float = road[1] / 2.0
			var r := (hw + 9.0 if pass_i == 0 else hw) * PX_PER_UNIT
			var color := Color("b9b4a8") if pass_i == 0 else Color("2a2b2e")
			for p in Layout.sample_road(road[2], 3.0):
				_disc(img, to_px(p.x, p.y), r, color)
	var order := {"park": 0, "water": 1, "sidewalk": 2, "building": 3, "landmark": 4}
	var sorted := footprints.filter(func(f): return order.has(f["kind"]))
	sorted.sort_custom(func(a, o): return order[a["kind"]] < order[o["kind"]])
	for f in sorted:
		match f["kind"]:
			"park":
				_disc(img, to_px(f["c"].x, f["c"].y), f["hx"] * PX_PER_UNIT, Color("5d8f36"))
			"water":
				_disc(img, to_px(f["c"].x, f["c"].y), f["hx"] * PX_PER_UNIT, Color("3b7f9f"))
			"sidewalk":
				_obb(img, f, Color("e3c58d"))
			"building":
				var k := clampf(f["top"] / 400.0, 0.0, 1.0)
				var zc: Color = Layout.ZONES[Layout.zone_at(f["c"].x, f["c"].y)]["color"]
				_obb(img, f, Color("5a5d66").lerp(zc, 0.3).darkened(k * 0.45))
			"landmark":
				_obb(img, f, Color("f2c230").darkened(0.15))
	if not footprints.any(func(f): return f["kind"] == "water"):
		_disc(img, to_px(puddle_center.x, puddle_center.z), puddle_r * PX_PER_UNIT, Color("3b7f9f"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
