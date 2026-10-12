extends "res://experiments/gas_cutscene/gas_cutscene.gd"
## Mission 2, closing cutscene: turned down (script lines M2-27 to M2-31).
## Same BUG OIL station as the pick-up. His heart-shaped web fell on him: Web Smith sits tangled in
## a ball of silk in front of the weaver and still tries to be smooth. She tells him to bounce and
## walks back into the shop. In the car Bug Smoke and the gang crack up. Muffled, he asks if
## somebody can cut him down. Fade to black; he is free again when the play camera takes over.
##
## Everything else (the station, the car and the gang, the girl, bars, camera, lines, hand-over to
## play) comes from the pick-up cutscene's script.

const SILK = preload("res://experiments/cutscene_kit/silk.gd")

var cocoon: Node3D


func _init() -> void:
    lines = {
        "M2-27": ["hero", 3.0],
        "M2-28": ["girl", 3.4],
        "M2-29": ["bug", 4.3],
        "M2-30": ["gang", 3.2],
        "M2-31": ["hero", 1.8],
    }


func _run() -> void:
    # The car is parked at the pump with the gang inside, he stands where he talked to her,
    # wrapped in the silk of his heart-shaped web.
    _place_car(path.get_baked_length())
    _unseat_hero()
    var h := at(TALK_SPOT)
    var g := at(GIRL_SPOT)
    spider.global_position = h
    var face := g - h
    spider.heading = atan2(-face.x, -face.z)
    spider.rotation.y = spider.heading
    spider.model.snap_feet()
    # frozen in place (no walking), but still drawn
    spider.set_active(false)
    spider.visible = true
    _set_girl(g, h - g)
    girl.visible = true
    cocoon = SILK.cocoon(0.015)
    world.add_child(cocoon)
    cocoon.global_position = h + UP * 0.009
    var dir := face.normalized()
    # toward the street, as in the pick-up scene
    var across := dir.cross(UP)
    if across.dot(at(Vector2(0.0, 1.0)) - at(Vector2.ZERO)) < 0.0:
        across = -across

    # 1. Close on him in the ball of silk, still smooth.
    _tween_prop(fade, "color:a", 0.0, 1.0)
    _bars(true, 0.8)
    var him := h + dir * 0.02 - across * 0.022 + UP * 0.018
    _cam_shot(him, him + UP * 0.002, func(_k): return h + UP * 0.01, 4.0, 0.0)
    await _wait(0.8)
    await _say("M2-27")
    if _done:
        return

    # 2. Close on her: she doesn't want no fake weaver. She walks back into the shop.
    var her := g - dir * 0.02 + across * 0.022 + UP * 0.016
    _cam_shot(her, her + UP * 0.001, func(_k): return girl.global_position + UP * 0.009, 3.4, 0.0)
    await _say("M2-28")
    if _done:
        return
    _girl_walk_to(at(SHOP_DOOR), 3.0)
    var mid := (h + g) * 0.5
    var two := mid - across * 0.04 + UP * 0.026
    _cam_shot(two, two + across * 0.004, func(_k): return girl.global_position.lerp(h, 0.5) + UP * 0.008, 3.0, 0.0)
    await _wait(2.6)
    girl.visible = false
    if _done:
        return

    # 3. In the car, Bug Smoke and the gang crack up.
    var seat := _gang_seat(0)
    var window := seat + _car_ahead() * 0.04 + _car_right() * 0.006 + UP * 0.02
    _cam_shot(window, window - _car_ahead() * 0.004, func(_k): return seat.lerp(_gang_seat(1), 0.3) + UP * 0.004, 8.0, 0.0)
    await _say("M2-29")
    if _done:
        return
    await _say("M2-30")
    if _done:
        return

    # 4. Back on him, alone in his web: can somebody cut me down?
    _cam_shot(him + UP * 0.006, him, func(_k): return h + UP * 0.01, 3.0, 0.0)
    await _wait(0.4)
    await _say("M2-31")
    if _done:
        return
    await _wait(0.6)
    if _done:
        return

    # 5. Fade to black; he is out of the silk when the play camera takes over.
    await _tween_prop(fade, "color:a", 1.0, 0.8).finished
    _finish(false)


func _update_gang() -> void:
    # the whole gang laughs with Bug Smoke
    for k in gang.size():
        var model: Node3D = gang[k][1]
        var talk := 1.0 if _speaker == "gang" or (k == 0 and _speaker == "bug") else 0.0
        model.position.y = absf(sin(t * 10.0 + k)) * 0.0015 / TRAFFIC.CAR_SCALE * talk


func _finish(skipped: bool) -> void:
    if _ending:
        return
    super._finish(skipped)
    girl.visible = false
    if is_instance_valid(cocoon):
        cocoon.queue_free()
    spider.set_active(true)
    fade.color.a = 1.0
    create_tween().tween_property(fade, "color:a", 0.0, 0.8)
