extends CharacterBody3D
## L'araignée jouable : marche, sprint, saut, escalade de tout ce qui est vertical, et fils de soie.

const Builder := preload("res://scripts/city/builder.gd")

const WALK := 20.0
const SPRINT := 42.0
const CLIMB := 16.0
const GRAVITY := 70.0
const JUMP := 26.0
const MAX_SILK := 250.0
const MODEL_PATH := "res://assets/models/epeire.glb"

signal silk_changed(count: int)
signal message(text: String)

var cam_yaw := 0.0
var climbing := false
var wall_normal := Vector3.ZERO
var model: Node3D
var legs: Array = []
var gait := 0.0
var anchor = null # Vector3 quand un fil est accroché
var silk_count := 0
var builder: Builder
var draft: MeshInstance3D
var _pitch := 0.0
var _yaw := PI


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.8
	cs.shape = sh
	cs.position.y = 0.8
	add_child(cs)
	floor_snap_length = 1.5
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.02
	model = Node3D.new()
	model.rotation_order = EULER_ORDER_YXZ
	add_child(model)
	if ResourceLoader.exists(MODEL_PATH):
		var inst: Node3D = load(MODEL_PATH).instantiate()
		# le modèle regarde vers +Z et fait 1,8 de long : on le ramène à ~1,5 cm
		inst.scale = Vector3.ONE * 0.85
		model.add_child(inst)
		_find_legs(inst)
	else:
		_procedural_model()
	draft = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.15
	cm.height = 1.0
	cm.radial_segments = 5
	draft.mesh = cm
	draft.visible = false
	draft.top_level = true
	add_child(draft)


func _find_legs(n: Node) -> void:
	for c in n.get_children():
		if c is Node3D and String(c.name).begins_with("Leg_") and String(c.name).length() <= 6:
			legs.append({"node": c, "base": c.rotation, "phase": PI if (String(c.name).unicode_at(5) + String(c.name).unicode_at(4)) % 2 else 0.0})
		_find_legs(c)


## Araignée en primitives si le modèle .glb n'est pas là.
func _procedural_model() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b1d14")
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color("8e44ad")
	var add_sphere := func(r: float, pos: Vector3, scl: Vector3, m: Material) -> void:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2
		mi.mesh = s
		mi.material_override = m
		mi.position = pos
		mi.scale = scl
		model.add_child(mi)
	add_sphere.call(0.38, Vector3(0, 0.55, 0.25), Vector3(1, 0.75, 1.1), dark)
	add_sphere.call(0.6, Vector3(0, 0.7, -0.55), Vector3(1, 0.85, 1.2), dark)
	add_sphere.call(0.15, Vector3(0, 1.2, -0.45), Vector3(1.6, 0.4, 1), accent)
	for i in 4:
		for side in [1.0, -1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.2, 0.53, 0.38 - i * 0.12)
			hip.rotation.y = side * [-0.9, -0.3, 0.25, 0.8][i] + (PI if side < 0 else 0.0)
			model.add_child(hip)
			var leg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.06
			cm.height = 1.5
			leg.mesh = cm
			leg.material_override = dark
			leg.rotation.z = -1.0
			leg.position = Vector3(0.6, 0.0, 0)
			hip.add_child(leg)
			legs.append({"node": hip, "base": hip.rotation, "phase": PI if (i + int(side > 0)) % 2 else 0.0})


func _physics_process(dt: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var wish := right * input.x - fwd * input.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	var sprint := Input.is_action_pressed("sprint")
	var speed := SPRINT if sprint else WALK

	if climbing:
		var into := -wish.dot(wall_normal)
		var tangent := wish + wall_normal * into
		velocity = tangent * speed * 0.5 - wall_normal * 6.0 + Vector3.UP * into * CLIMB * (1.7 if sprint else 1.0)
		if Input.is_action_just_pressed("jump"):
			velocity = wall_normal * 22.0 + Vector3.UP * JUMP * 0.7
			climbing = false
		move_and_slide()
		if climbing:
			var found := false
			for k in get_slide_collision_count():
				var n := get_slide_collision(k).get_normal()
				if absf(n.y) < 0.6:
					wall_normal = Vector3(n.x, 0, n.z).normalized()
					found = true
			if not found:
				if into > 0.1:
					# arrivée en haut du mur : petit bond par-dessus le rebord
					velocity = -wall_normal * 16.0 + Vector3.UP * 12.0
				climbing = false
			elif is_on_floor() and into < -0.1:
				climbing = false
	else:
		var accel := 12.0 if is_on_floor() else 3.0
		var hv := Vector3(velocity.x, 0, velocity.z).lerp(wish * speed, 1.0 - exp(-accel * dt))
		velocity.x = hv.x
		velocity.z = hv.z
		velocity.y = maxf(velocity.y - GRAVITY * dt, -150.0)
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
		move_and_slide()
		# on pousse contre un mur : on grimpe
		for k in get_slide_collision_count():
			var n := get_slide_collision(k).get_normal()
			if absf(n.y) < 0.6:
				var nh := Vector3(n.x, 0, n.z).normalized()
				if wish.dot(-nh) > 0.5:
					climbing = true
					wall_normal = nh
					break

	if Input.is_action_just_pressed("silk"):
		_toggle_silk()
	_update_silk()
	_animate(dt, wish)


func _animate(dt: float, wish: Vector3) -> void:
	var target_pitch := 0.0
	var target_yaw := _yaw
	if climbing:
		target_yaw = atan2(-wall_normal.x, -wall_normal.z)
		target_pitch = -PI / 2.0
	elif wish.length() > 0.1 and Vector2(velocity.x, velocity.z).length() > 1.0:
		target_yaw = atan2(velocity.x, velocity.z)
	_yaw = lerp_angle(_yaw, target_yaw, minf(1.0, dt * 12.0))
	_pitch = lerpf(_pitch, target_pitch, minf(1.0, dt * 10.0))
	model.rotation = Vector3(_pitch, _yaw, 0)
	model.position = -wall_normal * 0.7 + Vector3(0, 0.8, 0) * absf(sin(_pitch)) if climbing else Vector3.ZERO
	var speed01 := (absf(velocity.y) / CLIMB) if climbing else Vector2(velocity.x, velocity.z).length() / SPRINT
	speed01 = clampf(speed01, 0.0, 1.0)
	gait += dt * (4.0 + speed01 * 16.0) * minf(1.0, speed01 * 3.0)
	var amp := minf(1.0, speed01 * 2.5)
	for leg in legs:
		var node: Node3D = leg["node"]
		var base: Vector3 = leg["base"]
		var s := sin(gait + leg["phase"])
		node.rotation = base + Vector3(0, s * 0.35 * amp, maxf(0.0, cos(gait + leg["phase"])) * 0.3 * amp)


# ---------- Fils de soie ----------

func silk_point() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)


func _toggle_silk() -> void:
	if anchor == null:
		anchor = silk_point()
		draft.visible = true
		message.emit("Fil accroché ! Va plus loin et appuie encore sur E pour le tendre")
		return
	var here := silk_point()
	if (anchor as Vector3).distance_to(here) > 3.0:
		builder.silk(anchor, here)
		silk_count += 1
		silk_changed.emit(silk_count)
		message.emit("Fil tendu ! Tu peux marcher dessus")
	anchor = null
	draft.visible = false


func _update_silk() -> void:
	if anchor == null:
		return
	var a: Vector3 = anchor
	var here := silk_point()
	var length := a.distance_to(here)
	if length > MAX_SILK:
		anchor = null
		draft.visible = false
		message.emit("Le fil a cassé, trop long !")
		return
	if length < 0.05:
		return
	draft.global_position = (a + here) / 2.0
	var up := Vector3.UP if absf((here - a).normalized().y) < 0.99 else Vector3.FORWARD
	draft.look_at(here, up)
	draft.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	draft.scale = Vector3(1, length, 1)


func silk_length() -> float:
	return (anchor as Vector3).distance_to(silk_point()) if anchor != null else 0.0
