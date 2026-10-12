extends "res://experiments/m3_rescue_cutscene/m3_rescue_cutscene.gd"
## Final cutscene (script lines M3-14 and FIN-01 to FIN-06), right after the rescue, at the foot of
## the same rock. The young spider sits safe in the round web Web Smith spun in mid-air: "You spun
## that? But you a jumper!" The girl from the gas station runs up: it's you who saved my brother?
## Not too bad for a jumper... I guess you can weave. Hit my line sometime, Web Smith. She walks off,
## smiling. Bug Smoke, who saw it all: she gave you her NUMBER?! "Told y'all. Keep your eight eyes
## open." The camera rises over the rock and the picture fades to black, then back to play.
##
## The rock, the ledge and the young spider come from the rescue cutscene's script.

const GIRL_MODEL := "res://experiments/gas_cutscene/models/spider_girl.glb"
const BUG_MODEL := "res://experiments/sunset_cutscene/models/spider_durag.glb"

var web: Node3D
var web_center := Vector3.ZERO


func _init() -> void:
    lines = {
        "M3-14": ["young", 4.0],
        "FIN-01": ["girl", 3.4],
        "FIN-02": ["hero", 2.9],
        "FIN-03": ["girl", 3.7],
        "FIN-04": ["girl", 2.5],
        "FIN-05": ["bug", 2.8],
        "FIN-06": ["hero", 2.7],
    }


func _setup() -> void:
    super._setup()
    # No more swinging: the thread is gone, the young spider sits in the web that held.
    swing = 0.0
    for child in pivot.get_children():
        if child is MeshInstance3D:
            child.queue_free()
    web_center = foot + out * 0.02 + UP * 0.03
    web = SILK.orb_web(0.026)
    world.add_child(web)
    web.global_position = web_center
    web.global_basis = Basis(UP, atan2(-out.x, -out.z))
    # anchor threads: up to the ledge, down to the ground on both sides
    SILK.thread(world, web_center + UP * 0.026, ledge)
    SILK.thread(world, web_center - UP * 0.026 + side * 0.01, foot + out * 0.03 + side * 0.03)
    SILK.thread(world, web_center - UP * 0.026 - side * 0.01, foot + out * 0.03 - side * 0.03)
    var young: Node3D = actors.young.node
    young.reparent(world, true)
    _place("young", web_center - UP * 0.006 + out * 0.002, out)
    _place_hero(hero_spot + side * 0.02, -out)
    var girl_from := hero_spot + out * 0.3 + side * 0.08
    _actor("girl", GIRL_MODEL, girl_from, -out)
    var bug_from := hero_spot + out * 0.25 - side * 0.12
    _actor("bug", BUG_MODEL, bug_from, -out)


func _run() -> void:
    var hero := spider.global_position
    var girl_at := hero + out * 0.045 + side * 0.012
    var bug_at := hero + out * 0.012 - side * 0.04

    # 1. The young spider, safe in the web: you spun that? But you a jumper!
    _tween_prop(fade, "color:a", 0.0, 1.2)
    _bars(true, 0.8)
    var in_front := web_center + out * 0.05 + side * 0.012 + UP * 0.002
    _cam_shot(in_front, in_front - out * 0.012, func(_k): return web_center, 4.5)
    await _wait(0.6)
    await _say("M3-14")
    if _done:
        return

    # 2. The girl runs up.
    var wide := hero + out * 0.1 - side * 0.05 + UP * 0.03
    _cam_shot(wide, wide + side * 0.01, func(_k): return _pos("girl").lerp(hero, 0.5) + UP * 0.01, 4.0)
    await _walk("girl", girl_at, 2.2, hero - girl_at)
    if _done:
        return
    await _turn_hero(girl_at - hero, 0.4)

    # 3. It's you who saved my brother? / Well yeah... I tried my best.
    _close_on(girl_at, hero - girl_at, 3.4, 0.6)
    await _say("FIN-01")
    if _done:
        return
    _close_on(hero, girl_at - hero, 3.0, -0.6)
    await _say("FIN-02")
    if _done:
        return

    # 4. Not too bad for a jumper. I guess you can weave. Hit my line sometime, Web Smith.
    _close_on(girl_at, hero - girl_at, 4.0, 0.5, 0.034)
    await _say("FIN-03")
    if _done:
        return
    var two := (hero + girl_at) * 0.5 + (girl_at - hero).normalized().cross(UP) * 0.06 + UP * 0.022
    _cam_shot(two, two + UP * 0.003, func(_k): return _pos("girl").lerp(hero, 0.5) + UP * 0.008, 4.0)
    _walk("girl", girl_at + out * 0.3 + side * 0.1, 4.0)
    await _wait(0.5)
    await _say("FIN-04")
    if _done:
        return

    # 5. Bug Smoke slides up beside him: Bro... she gave you her NUMBER?!
    _walk("bug", bug_at, 1.6, hero - bug_at)
    var both := (hero + bug_at) * 0.5 + out * 0.06 + UP * 0.02
    _cam_shot(both, both - out * 0.008, func(_k): return (hero + bug_at) * 0.5 + UP * 0.008, 5.0)
    await _wait(1.6)
    if _done:
        return
    await _say("FIN-05")
    if _done:
        return

    # 6. Close on Web Smith, smiling: told y'all. Keep your eight eyes open.
    await _turn_hero(out, 0.4)
    _close_on(hero, out, 3.0, 0.3, 0.03)
    await _say("FIN-06")
    if _done:
        return

    # 7. The camera rises over the rock, the picture fades to black.
    var low := hero + out * 0.07 + UP * 0.02
    _cam_shot(low, low + out * 0.15 + UP * 0.2, func(_k): return foot.lerp(ledge, 0.3), 5.0)
    await _wait(2.0)
    if _done:
        return
    await _tween_prop(fade, "color:a", 1.0, 2.4).finished
    await _wait(1.5)
    if _done:
        return
    actors.girl.node.visible = false
    # he faces along the rock, so the play camera behind him is not inside it
    _place_hero(spider.global_position, side)
    _finish(false)


func _on_skip() -> void:
    actors.girl.node.visible = false
    _place_hero(hero_spot + side * 0.02, side)
