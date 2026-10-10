extends Node3D
## Caméra à la troisième personne : la souris tourne autour de l'araignée, la molette zoome.
## Un SpringArm3D évite que la caméra passe à travers les immeubles.

var target: Node3D
var yaw := 0.0
var pitch := -0.35
var distance := 10.0
var arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.3
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	arm.shape = shape
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.1
	camera.far = 12000.0
	arm.add_child(camera)


func setup(t: Node3D) -> void:
	target = t
	arm.add_excluded_object(t.get_rid())
	global_position = t.global_position + Vector3(0, 1.4, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.4, 0.35)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(120.0, distance * 1.1)


func _process(dt: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(target.global_position + Vector3(0, 1.4, 0), 1.0 - exp(-dt * 14.0))
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = distance
