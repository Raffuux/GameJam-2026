extends Node3D
## Point d'entrée : construit la ville, place l'araignée, la caméra, l'interface et les pièces.

const Layout := preload("res://scripts/city/layout.gd")
const City := preload("res://scripts/city/city.gd")
const Spider := preload("res://scripts/player/spider.gd")
const FollowCamera := preload("res://scripts/player/follow_camera.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const MapImage := preload("res://scripts/ui/map_image.gd")
const FilmLook := preload("res://scripts/fx/film_look.gd")

const COINS_PER_ZONE := 5
const COIN_VALUE := 100

var city: City
var spider: Spider
var cam: FollowCamera
var hud: Hud
var coins: Array = []
var money := 0
var current_zone := ""
var t := 0.0


func _ready() -> void:
	_setup_input()
	_setup_environment()
	city = City.new()
	var b = city.build(self)

	spider = Spider.new()
	spider.builder = b
	add_child(spider)
	spider.global_position = Layout.SPAWN + Vector3(0, 2, 0)

	cam = FollowCamera.new()
	add_child(cam)
	cam.setup(spider)

	_place_coins(b)
	_place_gang_members(b)

	add_child(FilmLook.new())
	hud = Hud.new()
	add_child(hud)
	hud.setup(MapImage.render(b.footprints, city.puddle_center, Layout.PUDDLE_R), b.landmarks, coins)
	spider.message.connect(func(text): hud.show_toast(text, 2.2))
	spider.silk_changed.connect(func(n): hud.set_silk(n))

	if OS.get_cmdline_user_args().size() > 0:
		_run_test_mode(OS.get_cmdline_user_args())


func _setup_input() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"silk": [KEY_E],
		"map": [KEY_M],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var ev := InputEventKey.new()
			# touches physiques : ZQSD sur un clavier AZERTY tombe au même endroit que WASD
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


## Fin de journée sous un ciel lourd, brume de pollution : une ambiance de rue sombre et sale.
func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2b3d55")
	sky_mat.sky_horizon_color = Color("b08a68")
	sky_mat.ground_horizon_color = Color("7a6450")
	sky_mat.ground_bottom_color = Color("201c18")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_exposure = 0.84
	env.ambient_light_energy = 0.4
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color("8a7c6c")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("8f7a63")
	env.fog_density = 0.0006
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffc58a")
	sun.light_energy = 0.95
	sun.rotation = Vector3(deg_to_rad(-24), deg_to_rad(-140), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 700.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


## Les pièces : 5 par quartier, piochées parmi les cachettes repérées pendant la construction.
func _place_coins(b) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.2
	mesh.bottom_radius = 2.2
	mesh.height = 0.5
	mesh.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f2c230")
	mat.metallic = 0.8
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color("b88a10")
	mat.emission_energy_multiplier = 0.8
	for zone in Layout.ZONES:
		var spots: Array = b.coin_spots.get(zone, []).duplicate()
		# mélange déterministe
		for k in range(spots.size() - 1, 0, -1):
			var r := rng.randi_range(0, k)
			var tmp = spots[k]
			spots[k] = spots[r]
			spots[r] = tmp
		for k in mini(COINS_PER_ZONE, spots.size()):
			var area := Area3D.new()
			var cs := CollisionShape3D.new()
			var sh := SphereShape3D.new()
			sh.radius = 3.0
			cs.shape = sh
			area.add_child(cs)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.rotation.x = PI / 2.0
			area.add_child(mi)
			add_child(area)
			area.global_position = spots[k] + Vector3(0, 2.5, 0)
			area.set_meta("zone", zone)
			area.body_entered.connect(_on_coin.bind(area))
			coins.append(area)


func _on_coin(body: Node, coin: Area3D) -> void:
	if body != spider or coin.get_meta("taken", false):
		return
	coin.set_meta("taken", true)
	coin.visible = false
	money += COIN_VALUE
	hud.set_money(money)
	var zone: String = coin.get_meta("zone")
	var left := coins.filter(func(c): return c.get_meta("zone") == zone and not c.get_meta("taken", false)).size()
	var name_z: String = Layout.ZONES[zone]["name"]
	hud.show_toast("+$%d   %s : encore %d" % [COIN_VALUE, name_z, left] if left > 0 else "%s : toutes les pièces trouvées !" % name_z, 2.5)


## Des membres de gang (modèles du fil des assets) qui patrouillent sur les trottoirs de leur territoire.
const GANG_MODELS := {
	"tisseuses": ["spider_tisseuses", Vector3(0, 0, 2.2)],
	"prieurs": ["mantis_prieurs", Vector3(0, 0, 7.0)],
	"nuee": ["fly_nuee", Vector3(0, 0, 2.6)],
	"colonie": ["ant_colonie", Vector3(0, 0, 2.6)],
}
const PER_GANG := 10
var gang_members: Array = []


func _place_gang_members(b) -> void:
	for zone in GANG_MODELS:
		var spots: Array = city.sidewalk_points.get(zone, [])
		if spots.is_empty():
			continue
		var step := maxi(1, spots.size() / PER_GANG)
		for k in range(0, spots.size(), step):
			var holder := Node3D.new()
			add_child(holder)
			var spot: Array = spots[k]
			holder.position = spot[0]
			if b.model(GANG_MODELS[zone][0], Vector3.ZERO, 0.0, GANG_MODELS[zone][1], false, holder) == Vector3.ZERO:
				holder.queue_free()
				break
			gang_members.append({"node": holder, "origin": spot[0], "dir": spot[1], "phase": k * 1.7, "range": 18.0})


## Aller-retour le long du trottoir, en se retournant au bout.
func _move_gang_members() -> void:
	for m in gang_members:
		var s: float = t * 0.25 + m["phase"]
		var dir: Vector3 = m["dir"]
		m["node"].position = m["origin"] + dir * sin(s) * m["range"]
		var facing: Vector3 = dir if cos(s) >= 0.0 else -dir
		m["node"].rotation.y = atan2(facing.x, facing.z)


func _unhandled_input(event: InputEvent) -> void:
	if hud.intro_visible():
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			hud.hide_intro()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			current_zone = ""
		return
	if event.is_action_pressed("map") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and hud.fullmap.visible):
		var open: bool = hud.toggle_map()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(dt: float) -> void:
	t += dt
	spider.cam_yaw = cam.yaw
	spider.set_physics_process(not hud.intro_visible() and not hud.fullmap.visible)
	for c in coins:
		c.rotation.y = t * 2.0
	_move_gang_members()
	var p := spider.global_position
	var zone := Layout.zone_at(p.x, p.z)
	if zone != current_zone and not hud.intro_visible():
		current_zone = zone
		hud.show_zone(zone)
	hud.update_frame(dt, spider, cam.yaw, spider._yaw, spider.silk_length(), spider.MAX_SILK)
	if p.y < -200:
		spider.global_position = Layout.SPAWN + Vector3(0, 5, 0)
		spider.velocity = Vector3.ZERO


# ---------- Mode test : captures d'écran automatiques ----------

func _run_test_mode(args: PackedStringArray) -> void:
	var out := "user://shots"
	for a in args:
		if a.begins_with("--shots="):
			out = a.substr(8)
	await get_tree().process_frame
	hud.hide_intro()
	if "--overview" in args:
		await _overview_shots(out)
		get_tree().quit()
		return
	# [nom, x, z, y (ou -1 = surface), yaw caméra, pitch, distance]
	var views := [
		["01-spawn", 25.0, 150.0, -1.0, 0.0, -0.3, 10.0],
		["02-centre-banque", -150.0, 15.0, -1.0, 0.0, -0.25, 60.0],
		["03-toile", -430.0, -320.0, -1.0, 0.8, -0.3, 40.0],
		["04-port", 330.0, -330.0, -1.0, -0.8, -0.35, 120.0],
		["05-decharge", 300.0, 250.0, -1.0, -2.3, -0.3, 150.0],
		["06-chantier", -330.0, 250.0, -1.0, 2.4, -0.45, 160.0],
		["07-vue-haute", 0.0, 0.0, 420.0, 0.6, -0.6, 220.0],
	]
	# les coins sales (tas d'ordures, feux)
	for k in mini(3, city._dirty.size()):
		var d: Vector2 = city._dirty[k][0]
		# caméra placée côté centre-ville, pour ne pas finir dans un mur d'enceinte
		# vue plongeante au-dessus du tas, caméra côté centre-ville (hors des murs d'enceinte)
		var to_c := -d.normalized()
		views.append(["11-sale-%d" % k, d.x, d.y, 25.0, atan2(to_c.x, to_c.y), -0.6, 80.0])
	for v in views:
		spider.set_physics_process(false)
		spider.global_position = Vector3(v[1], v[3] if v[3] >= 0.0 else 8.0, v[2])
		cam.yaw = v[4]
		cam.pitch = v[5]
		cam.distance = v[6]
		cam.global_position = spider.global_position + Vector3(0, 1.4, 0)
		for k in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out + "/" + v[0] + ".png")
		print("shot ", v[0])
	hud.toggle_map()
	hud.update_frame(0.016, spider, cam.yaw, spider._yaw, 0.0, 1.0)
	for k in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/10-carte.png")
	hud.toggle_map()
	# test d'escalade : face au mur de briques nord, on avance
	print("legs animated: ", spider.legs.size(), "  nodes: ", get_tree().get_node_count())
	spider.set_physics_process(true)
	spider.global_position = Vector3(-36, 6, -585)
	cam.yaw = 0.0
	cam.pitch = -0.2
	cam.distance = 14
	for k in 30:
		await get_tree().physics_frame
	var y0 := spider.global_position.y
	Input.action_press("move_forward")
	for k in 240:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var y1 := spider.global_position.y
	for k in 60:
		await get_tree().physics_frame
	print("climb test: y %.1f -> %.1f after 4 s, then %.1f after letting go (climbing=%s)" % [y0, y1, spider.global_position.y, spider.climbing])
	cam.yaw = 0.6
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/08-escalade.png")
	# test du trottoir : depuis la chaussée, on passe sur le trottoir puis le sol en avançant
	spider.climbing = false
	spider.global_position = Vector3(5, 2, 200)
	cam.yaw = -PI / 2.0
	for k in 20:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for k in 120:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	print("curb test: now at %s on_floor=%s" % [spider.global_position, spider.is_on_floor()])
	# test du fil : un fil du trottoir vers le haut d'un lampadaire, puis on marche dessus
	spider.set_physics_process(false)
	spider.global_position = Vector3(20, 8, 130)
	spider._toggle_silk()
	spider.global_position = Vector3(20, 38, 190)
	spider._toggle_silk()
	spider.global_position = Vector3(20, 12, 136)
	spider.velocity = Vector3.ZERO
	spider.set_physics_process(true)
	cam.yaw = PI
	for k in 20:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for k in 90:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	print("silk test: silks=%d, spider at %s" % [spider.silk_count, spider.global_position])
	get_viewport().get_texture().get_image().save_png(out + "/09-fil.png")
	get_tree().quit()


## Vues aériennes de toute la ville (pour présenter la map) : murs de la ruelle cachés, pas de brume.
func _overview_shots(out: String) -> void:
	hud.visible = false
	spider.set_physics_process(false)
	spider.global_position = Vector3(0, 4, 0)
	for w in get_tree().get_nodes_in_group("alley_walls"):
		w.visible = false
	for n in get_children():
		if n is DirectionalLight3D:
			n.directional_shadow_max_distance = 4000.0
		if n is WorldEnvironment:
			n.environment.fog_enabled = false
	cam.target = null
	cam.arm.collision_mask = 0
	cam.camera.near = 3.0
	var views := [
		["vue-sud-est", PI * 0.25, -0.6, 1500.0, false],
		["vue-sud-ouest", -PI * 0.25, -0.6, 1500.0, false],
		["vue-nord", PI, -0.62, 1550.0, false],
		["vue-dessus", 0.0, -PI / 2.0, 3000.0, true],
	]
	for v in views:
		cam.global_position = Vector3(0, 0, 0)
		cam.rotation = Vector3(v[2], v[1], 0)
		cam.arm.spring_length = v[3]
		cam.camera.fov = 50
		if v[4]:
			cam.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.camera.size = 1260.0
		for k in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "/" + v[0] + ".png")
		print("shot ", v[0])
	# gros plans sur les repaires de gangs
	cam.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var k := 0
	for l in city.b.landmarks:
		if not l["name"] in City.HABITAT_NAMES.values():
			continue
		cam.global_position = l["pos"] + Vector3(0, 20, 0)
		cam.rotation = Vector3(-0.42, 0.6 + k * 1.3, 0)
		cam.arm.spring_length = 190.0
		k += 1
		for f in 30:
			await get_tree().process_frame
		var file := "repaire-%d" % k
		get_viewport().get_texture().get_image().save_png(out + "/" + file + ".png")
		print("shot ", file, " ", l["name"])
