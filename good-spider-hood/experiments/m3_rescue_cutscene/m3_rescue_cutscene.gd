extends "res://experiments/cutscene_kit/mission_cutscene.gd"
## Mission 3, second cutscene: the young spider in danger (script lines M3-10 and M3-11).
## The big rock at the end of rock lane B. Web Smith wanders along its foot. A cry: a young weaver
## who can't weave yet hangs from the rock's edge on one thread, swinging over the drop. Web Smith
## panics, looks around for somebody... ain't nobody comin'. "Aight. Jump, Smith." The camera settles
## behind him as the play camera: the rescue is gameplay. The young spider keeps hanging there.

const YOUNG_MODEL := "res://experiments/sunset_cutscene/models/spider_bandana.glb"
const YOUNG_SIZE := 0.55
const SILK = preload("res://experiments/cutscene_kit/silk.gd")
## The landmark rock nearest this junction is the one.
const NEAR := "rock_b_end"
const HANG := 0.03        # the young spider's thread, in metres

var rock_center := Vector3.ZERO
var out := Vector3.FORWARD    # from the rock toward the lane, flat
var side := Vector3.RIGHT
var ledge := Vector3.ZERO     # the top edge the young spider hangs from
var foot := Vector3.ZERO      # on the ground below it
var hero_spot := Vector3.ZERO
var pivot: Node3D             # the thread swings around the ledge
var swing := 0.3              # how far it swings (radians)


func _init() -> void:
    lines = {
        "M3-10": ["young", 2.4],
        "M3-11": ["hero", 7.0],
    }


func _setup() -> void:
    _find_rock()
    here = foot
    pivot = Node3D.new()
    pivot.name = "YoungSpiderThread"
    world.add_child(pivot)
    pivot.global_position = ledge
    SILK.thread(pivot, Vector3.ZERO, Vector3.DOWN * HANG)
    var young := _actor("young", YOUNG_MODEL, ledge + Vector3.DOWN * (HANG + 0.006), out, YOUNG_SIZE)
    young.reparent(pivot, true)
    _place_hero(hero_spot - side * 0.07, side)


## The landmark rock nearest NEAR: its top edge on the side facing the lane is the ledge.
func _find_rock() -> void:
    var j := _junction(NEAR)
    var best: Node3D = null
    for child in world.get_children():
        if child is Node3D and child.has_meta("landmark") and child.get_meta("landmark"):
            if best == null or child.global_position.distance_to(j) < best.global_position.distance_to(j):
                best = child
    if best == null:
        # no rock: a ledge in the air above the junction, so the scene still plays
        rock_center = j
        out = Vector3.FORWARD
        side = out.cross(UP)
        ledge = j + UP * 0.08
        foot = j + out * 0.05
        hero_spot = foot
        return
    rock_center = best.global_position
    out = j - rock_center
    out.y = 0.0
    out = out.normalized()
    side = out.cross(UP)
    var top := -INF
    var points := PackedVector3Array()
    for m in best.find_children("*", "MeshInstance3D", true, false):
        var xf: Transform3D = m.global_transform
        for v in (m.mesh as Mesh).get_faces():
            var w := xf * v
            points.append(w)
            top = maxf(top, w.y)
    # the outermost point toward the lane, high up on the rock
    var reach := -INF
    for w in points:
        if w.y > top * 0.75 and (w - rock_center).dot(out) > reach:
            reach = (w - rock_center).dot(out)
            ledge = w
    ledge += out * 0.004
    foot = Vector3(ledge.x, 0.0, ledge.z)
    hero_spot = foot + out * 0.06


func _run() -> void:
    var young_pos := func(): return actors.young.node.global_position

    # 1. Day. Web Smith wanders along the foot of the big rock.
    _tween_prop(fade, "color:a", 0.0, 1.4)
    _bars(true, 1.0)
    var follow := hero_spot - side * 0.14 + out * 0.03 + UP * 0.02
    _cam_shot(follow, follow + side * 0.03, func(_k): return spider.global_position + UP * 0.008, 4.0)
    await _walk_hero(hero_spot)
    if _done:
        return

    # 2. A cry from above. The young spider hangs from the edge on one thread, over the drop.
    var under := foot + out * 0.035 + side * 0.02 + UP * 0.006
    _cam_shot(under, under + UP * 0.004, func(_k): return young_pos.call() + UP * 0.004, 4.0)
    await _say("M3-10")
    if _done:
        return

    # 3. Wide: the rock, the thread, the hero small at its foot looking up.
    _turn_hero(foot - spider.global_position, 0.4)
    var wide := hero_spot + out * 0.085 + side * 0.04 + UP * 0.028
    _cam_shot(wide, wide - out * 0.01, func(_k): return foot.lerp(ledge, 0.5), 3.0)
    await _wait(1.6)
    if _done:
        return

    # 4. Close on him: somebody do somethin'! He looks around... ain't nobody comin'. Jump, Smith.
    _close_on(hero_spot, -out, 7.5, 0.5, 0.035)
    _say("M3-11")
    await _turn_hero(side, 0.5)
    await _wait(0.6)
    await _turn_hero(-side, 0.7)
    await _wait(0.6)
    await _turn_hero(foot - spider.global_position, 0.5)
    while _speaker != "" and not _done:
        await get_tree().process_frame
    if _done:
        return
    await _wait(0.3)
    if _done:
        return

    # 5. The camera settles behind him, looking up at the rock: the rescue is played.
    _finish(false)


func _on_skip() -> void:
    _place_hero(hero_spot, foot - hero_spot)


func _process(dt: float) -> void:
    super._process(dt)
    if is_instance_valid(pivot):
        # the thread swings from the ledge, the young spider kicking at the end of it
        pivot.global_basis = Basis(side, sin(t * 1.6) * swing * 0.5) * Basis(out, sin(t * 1.1) * swing * 0.25)
