extends "res://experiments/cutscene_kit/mission_cutscene.gd"
## Mission 3, first cutscene: Unc on the curb (script lines M3-01 to M3-09).
## Night, at the crossing where the Tisseuses mocked him (n3_1). Web Smith sits alone on the edge
## of the boulevard, facing the street. Unc, the old wise spider with his cane, walks up and sits
## beside him. They talk: he looked like a fool, twice; every spider that ever spun something looked
## like a fool first; Spida Jesus and his one thread; silk spins for somebody; you a jumper, who
## better to catch 'em? Unc gets up and walks off without a word. "...For somebody." The camera
## settles behind the hero as the play camera, for his walk. It stays night afterwards.

const UNC_MODEL := "res://experiments/m3_unc_cutscene/models/jumping_spider_old_hunched.glb"
const CROSSING := "n3_1"

var J := Vector3.ZERO     # the crossing
var F := Vector3.FORWARD  # up the boulevard, toward the crossing
var R := Vector3.RIGHT
var seat := Vector3.ZERO  # where the hero sits, at the edge of the cross street
var unc_seat := Vector3.ZERO


func _init() -> void:
    lines = {
        "M3-01": ["unc", 2.1],
        "M3-02": ["hero", 2.4],
        "M3-03": ["unc", 2.3],
        "M3-04": ["hero", 4.6],
        "M3-05": ["unc", 7.9],
        "M3-06": ["unc", 11.5],
        "M3-07": ["unc", 10.4],
        "M3-08": ["unc", 8.2],
        "M3-09": ["hero", 1.5],
    }


func _setup() -> void:
    J = _junction(CROSSING)
    var start: Vector2 = _route("main_entry").curve.get_point_position(0)
    F = (J - _v3(start)).normalized()
    R = F.cross(UP)
    var cross_half := float(_route("h1_2").width) * 0.5
    seat = J - F * (cross_half + 0.012) - R * 0.02
    unc_seat = seat + R * 0.042
    here = J
    _night()
    _place_hero(seat, F)
    _actor("unc", UNC_MODEL, seat - F * 0.4 + R * 0.06, F)
    actors.unc.node.visible = false


func _run() -> void:
    var mid := (seat + unc_seat) * 0.5

    # 1. From across the street: the hero alone at the edge of the boulevard, at night.
    _tween_prop(fade, "color:a", 0.0, 2.0)
    _bars(true, 1.2)
    var across := J + F * 0.07 - R * 0.01 + UP * 0.02
    _cam_shot(across, across - F * 0.015, func(_k): return seat + UP * 0.008, 5.0)
    await _wait(3.4)
    if _done:
        return

    # 2. Unc walks up behind him, leaning on his cane, and sits beside him.
    actors.unc.node.visible = true
    var behind := seat - F * 0.11 - R * 0.03 + UP * 0.025
    _cam_shot(behind, behind + F * 0.01, func(_k): return _pos("unc").lerp(seat, 0.5) + UP * 0.008, 6.0)
    await _walk("unc", unc_seat, 4.0, F)
    if _done:
        return

    # 3. Yo Smith, you aight? / Nah, Unc. / Tell me what's on yo mind. / I looked like a fool. Twice.
    _close_on(unc_seat, F, 3.0, 0.6)
    await _say("M3-01")
    if _done:
        return
    _close_on(seat, F, 3.0, -0.6)
    await _say("M3-02")
    if _done:
        return
    _close_on(unc_seat, F, 3.0, 0.5)
    await _say("M3-03")
    if _done:
        return
    _close_on(seat, F, 5.0, -0.5)
    await _say("M3-04")
    if _done:
        return

    # 4. Two-shot from the street: a fool? Every spida that ever spun somethin' looked like a fool first.
    var front := mid + F * 0.06 + UP * 0.016
    _cam_shot(front, front - F * 0.01, func(_k): return mid + UP * 0.008, 8.0)
    await _say("M3-05")
    if _done:
        return

    # 5. Slow push in on Unc: Spida Jesus hung on one thread for three days.
    var far := unc_seat + (F + R * 0.7).normalized() * 0.05 + UP * 0.014
    var near := unc_seat + (F + R * 0.7).normalized() * 0.03 + UP * 0.012
    _cam_shot(far, near, func(_k): return unc_seat + UP * 0.009, 11.5)
    await _say("M3-06")
    if _done:
        return

    # 6. Close on the hero listening, then on Unc: silk don't spin for pride. It spins for somebody.
    _close_on(seat, F, 3.0, -0.7, 0.032)
    await _wait(1.6)
    if _done:
        return
    _close_on(unc_seat, F, 10.0, 0.6, 0.034)
    await _say("M3-07")
    if _done:
        return

    # 7. Two-shot: you a jumper. Who better to catch 'em?
    _cam_shot(front + R * 0.01, front - F * 0.012, func(_k): return mid + UP * 0.008, 9.0)
    await _say("M3-08")
    if _done:
        return

    # 8. He gets up and leaves without a word, back down the boulevard into the dark.
    _turn("unc", -F, 0.6)
    await _wait(0.7)
    if _done:
        return
    _walk("unc", unc_seat - F * 0.5 + R * 0.04, 5.0)
    var wide := seat + F * 0.03 - R * 0.06 + UP * 0.02
    _cam_shot(wide, wide + UP * 0.003, func(_k): return _pos("unc").lerp(seat, 0.4) + UP * 0.008, 4.0)
    await _wait(3.0)
    if _done:
        return

    # 9. Close on the hero, alone again: ...For somebody.
    _close_on(seat, F, 3.0, -0.4, 0.028)
    await _wait(0.4)
    await _say("M3-09")
    if _done:
        return
    actors.unc.node.visible = false
    await _wait(0.8)
    if _done:
        return

    # 10. He gets up; the camera settles behind him and becomes the play camera.
    await _turn_hero(-F, 0.8)
    _finish(false)


func _on_skip() -> void:
    actors.unc.node.visible = false
    _place_hero(seat, -F)
