extends "res://experiments/intro_cutscene/intro_cutscene.gd"
## Mission 1, closing cutscene: the failed web (script lines M1-09 to M1-12).
## Same crossing as the opening one. Web Smith stands by the web he just spun: two twigs and a few
## sagging threads. The Tisseuses are still parked in their lowrider; they laugh at it, tell him to
## stay bouncy and drive off, normally this time. The camera settles behind him as the play camera.
##
## Everything else (the street, the lowrider and its crew, bars, camera, lines, skip, hand-over to
## play) comes from the opening cutscene's script.

const SILK = preload("res://experiments/cutscene_kit/silk.gd")

var web: Node3D


func _init() -> void:
    keep_car = false
    lines = {
        "M1-09": [-3, 1.8],
        "M1-10": [0, 2.3],
        "M1-11": [1, 2.0],
        "M1-12": [0, 3.2],
    }


func _run() -> void:
    # The lowrider waits where it stopped in the opening scene, the hero stands by his web,
    # beside the boulevard, a little back from the crossing.
    var stop_s := _lane_closest(curb)
    _drive_car(stop_s, stop_s, 0.01, Tween.EASE_OUT, Tween.TRANS_LINEAR)
    var spot := curb - F * 0.06
    web = SILK.messy_web(0.045, 0.032)
    world.add_child(web)
    var web_at := spot + R * 0.03 + F * 0.012
    web.global_position = web_at
    # the web faces the crossing, so the Tisseuses see it side on
    web.global_basis = Basis(UP, atan2(-R.x, -R.z) + 0.5)
    _place_hero(spot, R)

    # 1. Close on the web: it sags, one thread hangs loose. He looks at it.
    _tween_prop(fade, "color:a", 0.0, 1.2)
    _bars(true, 0.8)
    # from beyond the web, looking back at it and at him
    var low := web_at + R * 0.045 - F * 0.035 + UP * 0.013
    _cam_shot(low, low + F * 0.008, func(_k): return web_at.lerp(spot, 0.35) + UP * 0.012, 4.0, 0.0)
    await _wait(1.4)
    if _done:
        return
    await _say("M1-09")
    if _done:
        return

    # 2. Over his shoulder: the Tisseuses in the lowrider, looking at the web.
    _turn_hero(car.global_position - spider.global_position, 0.5)
    var shoulder := spot - F * 0.07 - R * 0.03 + UP * 0.042
    var on_car := func(_k): return car.global_position.lerp(spot, 0.3) + UP * 0.014
    _cam_shot(shoulder, shoulder + F * 0.01, on_car, 4.0, 0.0)
    await _wait(0.4)
    await _say("M1-10")
    if _done:
        return

    # 3. Wide: they laugh at it, the hero and his web small in front of them.
    var wide := spot + R * 0.075 - F * 0.03 + UP * 0.022
    _cam_shot(wide, wide + F * 0.01, func(_k): return (car.global_position + spot) * 0.5 + UP * 0.01, 6.0, 0.0)
    _laughing(true)
    await _say("M1-11")
    _laughing(false)
    if _done:
        return
    await _say("M1-12")
    if _done:
        return

    # 4. They drive off, no hydraulics, the leaves swirl behind them. He watches them go.
    _drive_car(car_s, car_s + 1.6, 4.5, Tween.EASE_IN, Tween.TRANS_QUAD)
    var behind := spot - F * 0.09 + R * 0.02 + UP * 0.02
    _cam_shot(behind, behind + F * 0.01, func(_k): return spider.global_position.lerp(car.global_position, 0.6) + UP * 0.01, 4.0, 0.0)
    await _wait(2.8)
    if _done:
        return
    # he looks at his web one more time, then turns back down the boulevard
    await _turn_hero(web_at - spider.global_position, 0.6)
    await _wait(0.8)
    if _done:
        return
    await _turn_hero(-F, 0.6)
    await _wait(0.3)
    if _done:
        return

    # 5. The camera settles behind him and becomes the play camera.
    _finish(false)
