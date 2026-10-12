extends Node3D
## The sunny forest play mode, opened by the first cutscene. Run intro_game.tscn (F6).
## Command line: append -- --cutscene-shots=<folder> to save a frame every half second, then quit.

const PLAY_SCENE := preload("res://experiments/sunny_forest/play/play_game.tscn")
const CUTSCENE := preload("res://experiments/intro_cutscene/intro_cutscene.gd")

var game: Node3D
var cutscene: Node3D

func _ready() -> void:
    game = PLAY_SCENE.instantiate()
    add_child(game)
    cutscene = CUTSCENE.new()
    cutscene.name = "IntroCutscene"
    add_child(cutscene)
    cutscene.finished.connect(func() -> void: cutscene = null)
    cutscene.play(game)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cutscene-shots="):
            _shots(arg.substr(17))

func _shots(folder: String) -> void:
    var k := 0
    while cutscene != null and k < 200:
        await get_tree().create_timer(0.5).timeout
        get_viewport().get_texture().get_image().save_png(folder + "/cine-%02d.png" % k)
        k += 1
    await get_tree().create_timer(1.5).timeout
    get_viewport().get_texture().get_image().save_png(folder + "/cine-fin.png")
    get_tree().quit()
