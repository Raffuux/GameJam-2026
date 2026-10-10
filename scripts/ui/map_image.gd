extends RefCounted
## Dessine la carte vue de dessus une seule fois, avec chaque territoire teinté de la couleur de son gang.

const Layout := preload("res://scripts/city/layout.gd")

const PX_PER_UNIT := 0.5
const SIZE := 600 # pixels, pour 1200 unités


static func to_px(x: float, z: float) -> Vector2:
	return Vector2((x + Layout.HALF) * PX_PER_UNIT, (z + Layout.HALF) * PX_PER_UNIT)


static func _fill(img: Image, rect: Rect2, color: Color) -> void:
	var p := to_px(rect.position.x, rect.position.y)
	var r := Rect2i(int(p.x), int(p.y), maxi(1, int(ceil(rect.size.x * PX_PER_UNIT))), maxi(1, int(ceil(rect.size.y * PX_PER_UNIT))))
	img.fill_rect(r.intersection(Rect2i(0, 0, SIZE, SIZE)), color)


static func _tint(base: Color, x: float, z: float, amount: float) -> Color:
	return base.lerp(Layout.ZONES[Layout.zone_at(x, z)]["color"], amount)


static func render(footprints: Array, puddle_center: Vector3, puddle_r: float) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# rues : chaque case de 300 x 300 prend la teinte de son quartier
	for j in 4:
		for i in 4:
			var cell := Rect2(-Layout.HALF + i * 300.0, -Layout.HALF + j * 300.0, 300, 300)
			var c := cell.get_center()
			_fill(img, cell, _tint(Color("2e3034"), c.x, c.y, 0.35))
	var order := {"sidewalk": 0, "park": 1, "water": 2, "building": 3, "landmark": 4}
	var sorted := footprints.duplicate()
	sorted.sort_custom(func(a, b): return order.get(a["kind"], 5) < order.get(b["kind"], 5))
	for f in sorted:
		var r: Rect2 = f["rect"]
		var c := r.get_center()
		match f["kind"]:
			"sidewalk":
				_fill(img, r, _tint(Color("8a8780"), c.x, c.y, 0.45))
			"park":
				_fill(img, r, Color("5d8f36"))
			"building":
				var k := clampf(f["top"] / 400.0, 0.0, 1.0)
				_fill(img, r, _tint(Color("4a4d55").darkened(k * 0.4), c.x, c.y, 0.25))
			"landmark":
				_fill(img, r, Color("f2c230").darkened(0.15))
	# la flaque, en rond
	var pc := to_px(puddle_center.x, puddle_center.z)
	var pr := puddle_r * PX_PER_UNIT
	for y in range(int(pc.y - pr), int(pc.y + pr) + 1):
		for x in range(int(pc.x - pr), int(pc.x + pr) + 1):
			if Vector2(x, y).distance_to(pc) <= pr and x >= 0 and y >= 0 and x < SIZE and y < SIZE:
				img.set_pixel(x, y, Color("3b7f9f"))
	# frontières des territoires
	for j in 4:
		for i in 4:
			var z: String = Layout.BLOCKS[j][i]
			if i < 3 and Layout.BLOCKS[j][i + 1] != z:
				img.fill_rect(Rect2i(int((i + 1) * 300 * PX_PER_UNIT) - 1, int(j * 300 * PX_PER_UNIT), 2, int(300 * PX_PER_UNIT)), Color(1, 1, 1, 0.8))
			if j < 3 and Layout.BLOCKS[j + 1][i] != z:
				img.fill_rect(Rect2i(int(i * 300 * PX_PER_UNIT), int((j + 1) * 300 * PX_PER_UNIT) - 1, int(300 * PX_PER_UNIT), 2), Color(1, 1, 1, 0.8))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
