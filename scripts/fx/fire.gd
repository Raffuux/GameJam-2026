extends Node3D
## Un feu de déchets : flammes et fumée en particules, lumière orange qui vacille.
## `size` = largeur approximative du foyer (en cm, comme le reste de la ville).

var size := 10.0
var _light: OmniLight3D
var _t := 0.0


func _init(fire_size: float = 10.0) -> void:
	size = fire_size


func _ready() -> void:
	_t = randf() * 10.0
	add_child(_warm(_flames()))
	add_child(_warm(_smoke()))
	_light = OmniLight3D.new()
	_light.light_color = Color("ff8a3a")
	_light.omni_range = size * 9.0
	_light.light_energy = 2.2
	_light.position.y = size * 0.6
	add_child(_light)


func _process(dt: float) -> void:
	_t += dt
	_light.light_energy = 2.2 * (0.85 + 0.2 * sin(_t * 13.0) + 0.12 * sin(_t * 31.0 + 1.3))


## Un disque flou partagé : des flammes et des volutes rondes plutôt que des carrés.
static var _dot: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.45, Color(1, 1, 1, 0.6))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


## `quad` : taille de base des particules. Le rendu Compatibility ignore l'échelle des particules
## en billboard, donc la taille est portée par le mesh lui-même.
func _quad(color_ramp: Gradient, additive: bool, quad: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _soft_dot()
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.render_priority = 1 # les flammes par-dessus la fumée
	q.material = m
	p.mesh = q
	p.color_ramp = color_ramp
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.local_coords = false
	return p


## Démarre le feu déjà bien pris : sans ça, les particules pas encore nées s'affichent
## en tas au pied de l'émetteur (l'échelle zéro est ignorée en billboard).
func _warm(p: CPUParticles3D) -> CPUParticles3D:
	p.preprocess = p.lifetime
	return p


func _flames() -> CPUParticles3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 0.9))
	g.add_point(0.35, Color(1.0, 0.55, 0.15, 0.85))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.1, 0.02, 0.0))
	var p := _quad(g, true, size * 0.75)
	p.amount = 60
	p.lifetime = 0.8
	p.emission_sphere_radius = size * 0.3
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, size * 1.5, 0)
	p.initial_velocity_min = size * 0.8
	p.initial_velocity_max = size * 1.6
	p.scale_amount_min = size * 0.8
	p.scale_amount_max = size * 1.3
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = c
	return p


func _smoke() -> CPUParticles3D:
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.13, 0.12, 0.0))
	g.add_point(0.4, Color(0.2, 0.18, 0.17, 0.3))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.28, 0.27, 0.0))
	var p := _quad(g, false, size * 1.3)
	p.amount = 24
	p.lifetime = 3.5
	p.position.y = size * 1.8
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector3.UP
	p.spread = 18.0
	p.gravity = Vector3(size * 0.15, size * 0.4, 0)
	p.initial_velocity_min = size * 1.4
	p.initial_velocity_max = size * 2.2
	p.scale_amount_min = size * 1.2
	p.scale_amount_max = size * 1.8
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 2.5))
	p.scale_amount_curve = c
	return p
