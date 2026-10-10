@tool
extends Node3D
## Aperçu de la ville dans l'éditeur : la ville est générée en code au lancement, donc la scène
## principale paraît vide dans l'éditeur. Ouvrir scenes/city_preview.tscn pour la voir sans lancer
## le jeu. La caméra « VueDuCiel » cadre toute la ville (case « Aperçu » en haut de la vue 3D).
## Rien n'est enregistré dans la scène (les nœuds générés n'ont pas de propriétaire).

const City := preload("res://scripts/city/city.gd")

## Cocher pour reconstruire la ville après une modification des scripts.
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			_build()

var _root: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Ville"
	add_child(_root)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -24, 0)
	sun.light_color = Color("ffc58a")
	sun.shadow_enabled = true
	_root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6f7f8f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8a7c6c")
	env.environment.ambient_light_energy = 0.6
	_root.add_child(env)
	City.new().build(_root)
