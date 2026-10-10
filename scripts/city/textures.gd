extends RefCounted
## Textures générées au lancement (pas de fichiers image à gérer pour la jam).

## Façade avec 4 x 4 fenêtres, en niveaux de gris pour pouvoir la teinter par immeuble.
static func windows(lit_ratio: float = 0.3, seed: int = 1) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.92, 0.92))
	var cell := s / 4
	for cx in 4:
		for cy in 4:
			var lit := rng.randf() < lit_ratio
			var c := Color(1.0, 0.86, 0.5) if lit else Color(0.16, 0.2, 0.27)
			img.fill_rect(Rect2i(cx * cell + 7, cy * cell + 6, cell - 14, cell - 12), c)
			# reflet sur la vitre
			if not lit:
				img.fill_rect(Rect2i(cx * cell + 9, cy * cell + 8, 4, cell - 16), Color(0.3, 0.38, 0.48))
	# ligne d'étage plus sombre
	for cy in 4:
		img.fill_rect(Rect2i(0, cy * cell, s, 2), Color(0.75, 0.75, 0.75))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func bricks() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.5, 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bh := 16
	var bw := 32
	for row in s / bh:
		var off := (bw / 2) if row % 2 else 0
		for col in range(-1, s / bw + 1):
			var x := col * bw + off
			var shade := rng.randf_range(-0.06, 0.06)
			var c := Color(0.62 + shade, 0.3 + shade * 0.6, 0.22 + shade * 0.4)
			var r := Rect2i(x + 1, row * bh + 1, bw - 2, bh - 2).intersection(Rect2i(0, 0, s, s))
			if r.size.x > 0:
				img.fill_rect(r, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func noise(color_a: Color, color_b: Color, freq: float = 0.08, size: int = 256) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 3
	n.frequency = freq
	var gray := n.get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, color_a.lerp(color_b, gray.get_pixel(x, y).r))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Matériau qui plaque la texture en coordonnées monde : les fenêtres gardent leur taille quel que soit l'immeuble.
static var _grime: ImageTexture


## Crasse : taches, coulures et petits points sombres, autour de 0,8 (multiplie la couleur de base).
static func grime() -> ImageTexture:
	if _grime:
		return _grime
	var s := 256
	var big := FastNoiseLite.new()
	big.seed = 11
	big.frequency = 0.012
	big.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 12
	fine.frequency = 0.18
	var a := big.get_seamless_image(s, s)
	var f := fine.get_seamless_image(s, s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := 0.62 + a.get_pixel(x, y).r * 0.3 + f.get_pixel(x, y).r * 0.12
			# coulures verticales
			v -= maxf(0.0, sin(x * 0.21) * sin(x * 0.047 + 1.3)) * 0.06 * (y / float(s))
			if rng.randf() < 0.012:
				v -= 0.18
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.94))
	img.generate_mipmaps()
	_grime = ImageTexture.create_from_image(img)
	return _grime


## Ajoute la crasse en détail (multiplication), plaquée en coordonnées monde.
static func add_grime(m: StandardMaterial3D, scale: float = 1.0 / 45.0) -> void:
	m.detail_enabled = true
	m.detail_albedo = grime()
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	if not m.uv1_triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale


static func world_mat(tex: Texture2D, tint: Color, scale: float, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	add_grime(m)
	return m
