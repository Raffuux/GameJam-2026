extends Node3D
## Première cinématique : le héros (araignée sauteuse) attend pour traverser la Rue du Nord, dans
## La Toile. Trois Tisseuses passent en low rider, s'arrêtent, se moquent de lui parce qu'il ne sait
## pas tisser, et repartent. Il fait demi-tour, passe devant la caméra, qui se replace derrière lui
## et devient la caméra du jeu.
## Jouée en temps réel avec les vrais modèles. Bandes noires de cinéma au début, retirées à la fin.
## Échap passe la cinématique.

signal finished

const Layout := preload("res://scripts/city/layout.gd")

const ROAD_NAME := "Rue du Nord"
## Tronçon de la rue où peut se jouer la scène (ligne droite, en plein dans La Toile). On y prend
## l'endroit le plus loin des coins sales, pour qu'aucun tas d'ordures ne bouche les plans.
const STREET_FROM_X := -520.0
const STREET_TO_X := -390.0
const CAR_PATH := "res://assets/vehicles/pimpmobile/pimpmobile.glb"
const RIDER_MODEL := "spider_tisseuses"
const LEAF_MODEL := "fallen_leaf"
const VIOLET := Color("8e44ad")
const UP := Vector3.UP

const CAR_LEN := 11.0
## Distance du centre de la voie au milieu de la rue (voie côté héros).
const LANE := 6.5
const HERO_WALK := 4.5
const BAR_RATIO := 0.12

## Les répliques : pas encore écrites, les voix seront générées plus tard. Chaque créneau a la durée
## de sa réplique ; si un son `assets/audio/cinematics/intro_<id>.ogg` (ou .wav) existe, il est joué.
## [id, qui parle (0 conductrice, 1 passagère, 2 arrière, -1 toutes), durée en secondes]
const LINES := {
	"replique_1": [0, 1.6],
	"replique_2": [1, 2.2],
	"replique_3": [2, 2.2],
	"rires": [-1, 2.4],
}
const VOICE_DIR := "res://assets/audio/cinematics/intro_%s"

var spider: CharacterBody3D
var follow_cam: Node3D
var hud: CanvasLayer
var city
var builder
var hero # hero_model.gd, ou null si le modèle n'est pas là

var cam: Camera3D
var _cam_fn := Callable()
var _shot_t := 0.0
var _smooth := 0.0
var _look := Vector3.ZERO

var ui: CanvasLayer
var bar_top: ColorRect
var bar_bottom: ColorRect
var fade: ColorRect
var voice: AudioStreamPlayer
var _speaker := -2
var skip_hint: Label
var bar_h := 90.0

# repère de la rue : O au milieu de la chaussée, D le long de la rue (vers l'est), S vers le trottoir du héros
var O := Vector3.ZERO
var D := Vector3.FORWARD
var S := Vector3.RIGHT
var road_half := 14.0

var car: Node3D
var caisse: Node3D
var wheels: Array = []
var riders: Array = []
var car_speed := 0.0
var _car_prev := Vector3.ZERO
var hop := 0.0 # 0 = la caisse ne bouge pas, 1 = suspension hydraulique qui saute

var leaves: Array = []
var t := 0.0
var _done := false
var _ending := false
var _tweens: Array = []
var _hero_end_dir := Vector3.ZERO


## Lance la cinématique. `main` garde le contrôle du joueur coupé tant que ce nœud existe.
func play(p_spider: CharacterBody3D, p_follow_cam: Node3D, p_hud: CanvasLayer, p_city) -> void:
	spider = p_spider
	follow_cam = p_follow_cam
	hud = p_hud
	city = p_city
	builder = city.b if city else null
	for c in spider.model.get_children():
		if c.has_method("walk"):
			hero = c
	if hero:
		hero.auto = false
	_street_frame()
	_build_ui()
	_build_camera()
	_build_car()
	_clear_road()
	_scatter_leaves()
	hud.visible = false
	_run()


# ---------- Mise en place ----------

func _street_frame() -> void:
	for r in Layout.ROADS:
		if r[0] != ROAD_NAME:
			continue
		road_half = r[1] / 2.0
		var pts := Layout.sample_road(r[2], 6.0)
		var best := -1
		var best_score := -INF
		for i in range(2, pts.size() - 2):
			if pts[i].x < STREET_FROM_X or pts[i].x > STREET_TO_X:
				continue
			var score := INF
			for d in (city._dirty if city else []):
				score = minf(score, pts[i].distance_to(d[0]))
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			best = pts.size() / 2
		var a := pts[maxi(best - 2, 0)]
		var b := pts[mini(best + 2, pts.size() - 1)]
		O = Vector3(pts[best].x, 0, pts[best].y)
		D = Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	S = Vector3(-D.z, 0, D.x)
	O.y = _ground(O)


## Hauteur du sol (chaussée, trottoir) sous un point. On tire bas pour ne pas toucher les toiles tendues.
func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 12.0, p.z), Vector3(p.x, -20.0, p.z))
	q.exclude = [spider.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if hit else 0.5


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground(p), p.z)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	bar_h = get_viewport().get_visible_rect().size.y * BAR_RATIO
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0.0
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0.0
	for c in [bar_top, bar_bottom]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(c)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	skip_hint = Label.new()
	skip_hint.text = "Échap : passer"
	skip_hint.add_theme_font_size_override("font_size", 16)
	skip_hint.modulate = Color(1, 1, 1, 0.0)
	skip_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_hint.offset_left = -170.0
	skip_hint.offset_top = 14.0
	ui.add_child(skip_hint)
	ui.add_child(fade)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	cam.far = 12000.0
	add_child(cam)
	cam.make_current()


## Le low rider : la pimpmobile peinte en violet Tisseuses, vitres claires pour voir l'équipage,
## caisse abaissée sur ses roues et montée sur une suspension hydraulique.
func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	caisse = Node3D.new()
	car.add_child(caisse)
	if ResourceLoader.exists(CAR_PATH):
		var inst: Node3D = load(CAR_PATH).instantiate()
		car.add_child(inst)
		var box := _aabb_of(inst, car)
		inst.scale = Vector3.ONE * (CAR_LEN / maxf(box.size.z, 0.001))
		box = _aabb_of(inst, car)
		inst.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		for n in inst.get_children():
			if String(n.name).begins_with("Wheel"):
				wheels.append(n)
			else:
				n.reparent(caisse, true)
		for mi in caisse.find_children("*", "MeshInstance3D", true, false):
			_paint(mi)
	else:
		# pas de modèle : une caisse violette toute simple
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.6, 2.2, CAR_LEN)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = VIOLET
		mi.material_override = m
		mi.position.y = 1.6
		caisse.add_child(mi)
	# l'équipage : la conductrice à gauche, une passagère à côté (côté héros), une à l'arrière
	var seats := [Vector3(-1.0, 2.15, -0.6), Vector3(1.0, 2.15, -0.6), Vector3(0.9, 2.25, 2.4)]
	var turns := [0.0, PI / 2.0, PI / 2.0]
	for k in seats.size():
		var holder := Node3D.new()
		caisse.add_child(holder)
		holder.position = seats[k]
		var size = builder.model(RIDER_MODEL, Vector3.ZERO, 0.0, Vector3(0, 0, 2.8), false, holder) if builder else Vector3.ZERO
		if size == Vector3.ZERO:
			_fallback_rider(holder)
		# le modèle regarde vers +Z, la voiture vers -Z
		holder.rotation.y = PI - turns[k]
		for ap in holder.find_children("*", "AnimationPlayer", true, false):
			ap.speed_scale = 0.0
		riders.append(holder)
	caisse.position.y = -0.2
	car.visible = false


func _paint(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m == null:
			continue
		if m.resource_name == "WindowAtlas":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.55, 0.6, 0.75, 0.12)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.metallic_specular = 1.0
			mi.set_surface_override_material(s, glass)
		elif m.resource_name == "PaintAtlas" and m is StandardMaterial3D:
			var paint := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			paint.albedo_color = VIOLET
			paint.metallic = 0.5
			paint.roughness = 0.3
			mi.set_surface_override_material(s, paint)


func _fallback_rider(holder: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.2
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2a1838")
	mi.material_override = m
	mi.position.y = 0.6
	holder.add_child(mi)


func _aabb_of(n: Node3D, ref: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := ref.global_transform.affine_inverse()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (inv * m.global_transform) * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## Les petits déchets posés sur la chaussée de la scène (papiers, canettes...) sont retirés :
## la voiture passerait au travers et ils bouchent les plans.
func _clear_road() -> void:
	if builder == null:
		return
	for n in builder.root.get_children():
		if not n is Node3D:
			continue
		var rel: Vector3 = n.global_position - O
		if absf(rel.dot(S)) > road_half + 1.0 or rel.dot(D) < -190.0 or rel.dot(D) > 60.0:
			continue
		var box := _aabb_of(n, n)
		if box.size.length() > 0.0 and box.size.x < 20.0 and box.size.z < 20.0 and box.size.y < 20.0:
			n.queue_free()


## Des feuilles mortes sur la chaussée et le trottoir ; le low rider les soulève en passant.
## Elles restent dans la ville après la cinématique.
func _scatter_leaves() -> void:
	if builder == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var parent := get_parent() as Node3D
	for k in 26:
		var along := rng.randf_range(-45.0, 30.0)
		var across := rng.randf_range(-road_half + 2.0, road_half + 9.0)
		var p := _on_ground(O + D * along + S * across)
		var holder := Node3D.new()
		parent.add_child(holder)
		holder.position = p
		var size = builder.model(LEAF_MODEL, Vector3.ZERO, 0.0, Vector3(0, 0, rng.randf_range(3.0, 5.5)), false, holder)
		if size == Vector3.ZERO:
			holder.queue_free()
			return
		holder.rotation = Vector3(0, rng.randf() * TAU, 0)
		leaves.append({"node": holder, "floor": p.y, "vel": Vector3.ZERO, "spin": Vector3.ZERO, "air": false})


# ---------- Le déroulé ----------

func _run() -> void:
	var walk_from := _on_ground(O + S * (road_half + 4.5) - D * 26.0)
	var curb := _on_ground(O + S * (road_half + 1.6))
	_place_hero(walk_from, D)

	# 1. On suit le héros par derrière quand il arrive sur la rue.
	_tween_prop(fade, "color:a", 0.0, 1.6)
	_bars(true, 1.0)
	_tween_prop(skip_hint, "modulate:a", 0.55, 1.0).set_delay(1.0)
	_cam_follow()
	await _walk_hero(walk_from, curb, HERO_WALK)
	if _done:
		return

	# 2. Il s'arrête au bord du trottoir, se tourne vers la chaussée et attend.
	_turn_hero(-S, 0.6)
	hero_play("idle-loop")
	var over := curb + S * 3.5 + D * 2.2 + UP * 1.5
	_cam_shot(over, over + D * 0.6 - S * 0.3, func(_k): return curb - S * 6.0 - D * 12.0 + UP * 0.4, 3.2, 0.6)
	await _wait(1.6)
	if _done:
		return

	# 3. Le low rider arrive de la gauche et ralentit devant lui.
	var stop := O + S * LANE + D * 1.0
	_drive_car(O + S * LANE - D * 170.0, stop, 6.0, Tween.EASE_OUT, Tween.TRANS_CUBIC)
	await _wait(1.6)
	if _done:
		return
	# dans l'axe de la voie : la voiture arrive droit sur nous
	var low := O + D * 26.0 + S * LANE + UP * 1.6
	_cam_shot(low, low - D * 3.0, func(_k): return car.global_position + UP * 2.0, 4.6, 0.0)
	await _wait(4.4)
	if _done:
		return

	# 4. Ils se croisent le regard. Les Tisseuses se tournent vers lui et se moquent.
	hop = 0.25
	var shoulder := curb + S * 3.0 - D * 3.5 + UP * 2.6
	_cam_shot(shoulder, shoulder + D * 0.6, func(_k): return car.global_position + UP * 1.8 + S * 1.0, 6.0, 0.0)
	await _wait(0.8)
	await _say("replique_1")
	if _done:
		return
	await _say("replique_2")
	if _done:
		return

	# 5. Contrechamp : le héros, vu depuis la voiture, baisse la tête.
	var from_car := car.global_position + S * 3.4 + D * 2.2 + UP * 2.4
	_cam_shot(from_car, from_car + UP * 0.3, func(_k): return spider.global_position + UP * 0.7, 3.2, 0.0)
	await _wait(0.3)
	_tween_prop(spider.model, "rotation:x", 0.22, 1.0).set_delay(1.0)
	await _say("replique_3")
	if _done:
		return

	# 6. Plan large : ils rigolent, la voiture saute sur ses vérins.
	# depuis le trottoir d'en face, pour ne pas filmer à travers les herbes du terrain vague
	var wide := O - D * 14.0 - S * (road_half + 4.0) + UP * 4.5
	_cam_shot(wide, wide + D * 3.0, func(_k): return (car.global_position + spider.global_position) / 2.0 + UP * 1.5, 5.0, 0.0)
	hop = 1.0
	for r in riders:
		for ap in r.find_children("*", "AnimationPlayer", true, false):
			ap.speed_scale = 2.5
	await _say("rires")
	if _done:
		return
	for r in riders:
		for ap in r.find_children("*", "AnimationPlayer", true, false):
			ap.speed_scale = 0.0

	# 7. Ils repartent dans un nuage de feuilles.
	hop = 0.6
	_drive_car(car.global_position, car.global_position + D * 230.0, 4.5, Tween.EASE_IN, Tween.TRANS_QUAD)
	await _wait(1.6)
	if _done:
		return

	# 8. Il se tourne et repart : il passe devant la caméra, qui pivote avec lui.
	hop = 0.0
	_tween_prop(spider.model, "rotation:x", 0.0, 0.5)
	_turn_hero(-D, 0.7)
	await _wait(0.5)
	if _done:
		return
	var away := _on_ground(curb + S * 3.0 - D * 30.0)
	var cam_spot := _on_ground(curb + S * 1.0 - D * 9.0) + UP * 1.0
	_cam_shot(cam_spot, cam_spot + S * 0.3, func(_k): return spider.global_position + UP * 0.8, 6.0, 0.25)
	_walk_hero(curb, away, HERO_WALK)
	await _wait(3.4)
	if _done:
		return

	# 9. La caméra repasse derrière lui et devient la caméra du jeu.
	_finish(false)


# ---------- Le héros ----------

func hero_play(anim_name: String) -> void:
	if hero:
		hero.play(anim_name)


func _place_hero(p: Vector3, facing: Vector3) -> void:
	spider.global_position = p
	spider.velocity = Vector3.ZERO
	_face(facing)


func _face(dir: Vector3) -> void:
	spider._yaw = atan2(dir.x, dir.z)
	spider.model.rotation.y = spider._yaw


func _turn_hero(dir: Vector3, dur: float) -> void:
	var to: float = spider._yaw + wrapf(atan2(dir.x, dir.z) - spider._yaw, -PI, PI)
	var set_yaw := func(y: float) -> void:
		spider._yaw = y
		spider.model.rotation.y = y
	var tw := _tween()
	tw.tween_method(set_yaw, spider._yaw, to, dur).set_trans(Tween.TRANS_SINE)
	if hero:
		hero.walk(2.0)
		tw.tween_callback(func(): hero_play("idle-loop"))


func _walk_hero(from: Vector3, to: Vector3, speed: float) -> void:
	var dir := (to - from)
	dir.y = 0.0
	_face(dir.normalized())
	if hero:
		hero.walk(speed)
	var tw := _tween()
	tw.tween_method(func(k: float): spider.global_position = _on_ground(from.lerp(to, k)), 0.0, 1.0, dir.length() / speed)
	await tw.finished
	if not _done:
		hero_play("idle-loop")


# ---------- La voiture ----------

func _drive_car(from: Vector3, to: Vector3, dur: float, ease_type: int, trans: int) -> void:
	car.visible = true
	car.global_position = _on_ground(from)
	_car_prev = car.global_position
	car.look_at(car.global_position + D, UP)
	var tw := _tween()
	tw.tween_method(func(k: float): car.global_position = _on_ground(from.lerp(to, k)), 0.0, 1.0, dur).set_ease(ease_type).set_trans(trans)


func _update_car(dt: float) -> void:
	if car == null or not car.visible:
		return
	var moved := car.global_position - _car_prev
	_car_prev = car.global_position
	car_speed = moved.length() / maxf(dt, 0.0001)
	for w in wheels:
		w.rotate_object_local(Vector3.RIGHT, -moved.length() / 1.3)
	# suspension hydraulique : la caisse rebondit, l'avant plus que l'arrière
	var bounce := absf(sin(t * 7.5)) * hop
	caisse.position.y = -0.2 + bounce * 0.9
	caisse.rotation.x = sin(t * 7.5) * 0.06 * hop
	for k in riders.size():
		var talk := 1.0 if _speaker == k or _speaker == -1 else 0.0
		riders[k].position.y = [2.15, 2.15, 2.25][k] + absf(sin(t * 11.0 + k)) * 0.25 * maxf(hop, talk * 0.6)
	if (car.global_position - O).length() > 200.0 and car_speed > 1.0:
		car.visible = false


func _update_leaves(dt: float) -> void:
	for l in leaves:
		var n: Node3D = l["node"]
		if not is_instance_valid(n):
			continue
		if not l["air"] and car and car.visible and car_speed > 6.0:
			var d := n.global_position - car.global_position
			d.y = 0.0
			if d.length() < 7.5:
				l["air"] = true
				l["vel"] = D * car_speed * randf_range(0.25, 0.5) + d.normalized() * randf_range(2.0, 6.0) + UP * randf_range(5.0, 11.0)
				l["spin"] = Vector3(randf_range(-6, 6), randf_range(-8, 8), randf_range(-6, 6))
		if l["air"]:
			var v: Vector3 = l["vel"]
			v.y -= 18.0 * dt
			v.x *= 1.0 - dt * 1.5
			v.z *= 1.0 - dt * 1.5
			v.y = maxf(v.y, -6.0)
			l["vel"] = v
			n.global_position += v * dt
			n.rotation += l["spin"] * dt
			if n.global_position.y <= l["floor"] and v.y < 0.0:
				n.global_position.y = l["floor"]
				n.rotation = Vector3(0, n.rotation.y, 0)
				l["air"] = false


# ---------- Caméra, bandes, sous-titres ----------

func _cam_follow() -> void:
	_shot_t = 0.0
	_smooth = 4.0
	_cam_fn = func(_k: float) -> Array:
		var f := Vector3(sin(spider._yaw), 0, cos(spider._yaw))
		var p := spider.global_position
		return [p - f * 6.5 + UP * 2.4, p + f * 5.0 + UP * 0.8]
	var r: Array = _cam_fn.call(0.0)
	cam.global_position = r[0]
	_look = r[1]
	cam.look_at(_look, UP)


## Un plan : la caméra glisse de `from` à `to` pendant `dur` et regarde ce que renvoie `look`.
## `smooth` > 0 adoucit le passage depuis le plan précédent (sinon c'est un cut).
func _cam_shot(from: Vector3, to: Vector3, look: Callable, dur: float, smooth: float) -> void:
	_shot_t = 0.0
	_smooth = 0.0 if smooth <= 0.0 else 1.0 / smooth
	_cam_fn = func(time: float) -> Array:
		var k := smoothstep(0.0, 1.0, clampf(time / dur, 0.0, 1.0))
		return [from.lerp(to, k), look.call(k)]
	if smooth <= 0.0:
		var r: Array = _cam_fn.call(0.0)
		cam.global_position = r[0]
		_look = r[1]
		cam.look_at(_look, UP)


func _update_camera(dt: float) -> void:
	if not _cam_fn.is_valid():
		return
	_shot_t += dt
	var r: Array = _cam_fn.call(_shot_t)
	if _smooth > 0.0:
		var a := 1.0 - exp(-dt * _smooth)
		cam.global_position = cam.global_position.lerp(r[0], a)
		_look = _look.lerp(r[1], a)
	else:
		cam.global_position = r[0]
		_look = r[1]
	if cam.global_position.distance_to(_look) > 0.01:
		cam.look_at(_look, UP)


func _bars(show: bool, dur: float) -> void:
	_tween_prop(bar_top, "offset_bottom", bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)
	_tween_prop(bar_bottom, "offset_top", -bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)


## Un créneau de réplique : la Tisseuse qui parle s'agite un peu, et sa voix est jouée si elle existe.
func _say(id: String) -> void:
	var line: Array = LINES[id]
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(VOICE_DIR % id + ext):
			voice.stream = load(VOICE_DIR % id + ext)
			voice.play()
			break
	_speaker = line[0]
	await _wait(line[1])
	_speaker = -2
	if not _done:
		await _wait(0.25)


# ---------- Fin : retour au jeu ----------

func _finish(skipped: bool) -> void:
	if _ending:
		return
	_ending = true
	_done = true
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	voice.stop()
	skip_hint.visible = false
	spider.model.rotation.x = 0.0
	if skipped:
		fade.color.a = 0.0
		var curb := _on_ground(O + S * (road_half + 1.6))
		_place_hero(_on_ground(curb + S * 3.0 - D * 18.0), -D)
		car.visible = false
	hero_play("idle-loop")
	var f := Vector3(sin(spider._yaw), 0, cos(spider._yaw))
	follow_cam.yaw = atan2(-f.x, -f.z)
	follow_cam.pitch = -0.35
	follow_cam.distance = 10.0
	follow_cam.global_position = spider.global_position + Vector3(0, 1.4, 0)
	# la caméra de la cinématique rejoint en douceur celle du jeu, pendant que les bandes se retirent
	var blend := 0.7 if skipped else 2.0
	_cam_fn = Callable()
	var start := cam.global_transform
	_bars(false, blend * 0.8)
	hud.visible = true
	var hud_root := hud.get_child(0) as CanvasItem
	if hud_root:
		hud_root.modulate.a = 0.0
		create_tween().tween_property(hud_root, "modulate:a", 1.0, blend)
	var tw := create_tween()
	tw.tween_method(func(k: float): cam.global_transform = start.interpolate_with(follow_cam.camera.global_transform, k), 0.0, 1.0, blend).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished
	follow_cam.camera.make_current()
	if hero:
		hero.auto = true
	finished.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _ending:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish(true)


func _process(dt: float) -> void:
	t += dt
	_update_car(dt)
	_update_leaves(dt)
	if not _ending:
		_update_camera(dt)


func _tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _tween_prop(obj: Object, prop: String, value: Variant, dur: float) -> PropertyTweener:
	return _tween().tween_property(obj, prop, value, dur)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
