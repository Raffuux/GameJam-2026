extends Node3D
## Le héros : l'araignée sauteuse au bandana (fil des assets), avec ses animations d'attente,
## de marche et de saut. Remplace le modèle de `spider.gd` et suit sa vitesse en jeu.
## Pendant une cinématique, `auto = false` et c'est la cinématique qui choisit l'animation.

const MODEL_PATH := "res://assets/spider_variants/jumping_spider_bandana.glb"
## Le modèle fait 1,9 de long : on le ramène à ~1,5 cm comme l'araignée du jeu.
const SCALE := 0.8
## Vitesse au sol de "walk-loop" joué à vitesse 1, une fois le modèle mis à l'échelle.
const WALK_ANIM_SPEED := 0.5 * SCALE

var auto := true
var anim: AnimationPlayer
var _air := false


## Pose le héros sur l'araignée jouable. Renvoie null si le modèle n'est pas là (on garde l'ancien).
static func attach(spider: Node3D) -> Node3D:
	if not ResourceLoader.exists(MODEL_PATH):
		return null
	var hero := new()
	for c in spider.model.get_children():
		c.queue_free()
	# les pattes de l'ancien modèle ne sont plus à animer
	spider.legs.clear()
	spider.model.add_child(hero)
	return hero


func _ready() -> void:
	var inst: Node3D = load(MODEL_PATH).instantiate()
	# le modèle regarde vers -Z, l'araignée du jeu vers +Z
	inst.rotation.y = PI
	inst.scale = Vector3.ONE * SCALE
	add_child(inst)
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		play("idle-loop")


func play(name: String, speed: float = 1.0, blend: float = 0.2) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if anim.current_animation != name:
		anim.play(name, blend)
	anim.speed_scale = speed


## Marche à `ground_speed` unités par seconde : la cadence suit, sans aller jusqu'au flou.
func walk(ground_speed: float) -> void:
	play("walk-loop", clampf(ground_speed / WALK_ANIM_SPEED / 8.0, 0.8, 3.5))


func _process(_dt: float) -> void:
	var body := get_parent().get_parent() as CharacterBody3D
	if not auto or body == null or not body.is_physics_processing():
		return
	if body.get("climbing"):
		walk(maxf(8.0, body.velocity.length()))
		return
	if not body.is_on_floor():
		if not _air:
			_air = true
			# on saute directement à l'envol, l'accroupi est déjà passé
			play("jump", 1.4, 0.05)
			anim.seek(0.45, true)
		return
	_air = false
	var hs := Vector2(body.velocity.x, body.velocity.z).length()
	if hs > 1.5:
		walk(hs)
	else:
		play("idle-loop")
