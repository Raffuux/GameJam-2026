extends Node3D
## First cutscene, played in real time on the sunny forest streets with the real models.
## The jumping spider walks up Spider Hood Boulevard and waits at the next crossing. Three Tisseuses
## pull up in a purple lowrider, laugh at him because he cannot weave, and drive off. He turns
## back, passes the camera, and the camera settles behind him as the play-mode camera.
##
## Cinema bars slide in at the start and out at the end. No text and no radar on screen.
## The lines are not written yet: each one is a timed slot, and a voice file dropped in
## voices/ (see LINES) plays in it. Escape skips.

signal finished

const RIDER_MODEL := "res://experiments/intro_cutscene/models/spider_tisseuses.glb"
const CAR_SCENE := "res://assets/vehicles/pimpmobile/pimpmobile_glass.tscn"
const TRAFFIC = preload("res://experiments/sunny_forest/roads/traffic.gd")
const VOICE_PATH := "res://experiments/intro_cutscene/voices/%s"
const UP := Vector3.UP

## Where it happens: the hero comes up main_entry and waits at the n3_1 crossing, the car comes along
## the cross street (these routes, west to east) and stops in front of him.
const CROSSING := "n3_1"
const CROSS_STREET := ["h1_1", "h1_2", "h1_3", "h1_4"]
const VIOLET := Color("6f2f8f")
const BAR_RATIO := 0.12
## Traffic cars closer than this to the crossing are moved away before the scene starts.
const CLEAR_RADIUS := 1.2

## [voice file (without extension), who speaks (0 driver, 1 passenger, 2 back seat, -1 all), seconds]
const LINES := {
    "line_1": [0, 1.6],
    "line_2": [1, 2.2],
    "line_3": [2, 2.2],
    "laugh": [-1, 2.4],
}

var game: Node3D        # play_game.gd
var world: Node3D       # sunny_forest.gd
var spider: CharacterBody3D
var camera: Camera3D

var ui: CanvasLayer
var bar_top: ColorRect
var bar_bottom: ColorRect
var fade: ColorRect
var bar_h := 90.0
var voice: AudioStreamPlayer

# street frame: J the crossing, F north up the boulevard, R its right, D east along the cross street
var J := Vector3.ZERO
var F := Vector3.FORWARD
var R := Vector3.RIGHT
var D := Vector3.RIGHT
var cross_half := 0.07
var curb := Vector3.ZERO
var lane_path := PackedVector3Array()
var lane_arc := PackedFloat32Array()

var car: Node3D
var car_body: Array = []     # the car's body nodes (not the wheels), bounced by the hydraulics
var car_wheels: Array = []
var riders: Array = []
var car_s := 0.0
var _car_prev := 0.0
var car_speed := 0.0
var hop := 0.0
var _speaker := -2

var leaves: Array = []
var t := 0.0
var _cam_fn := Callable()
var _shot_t := 0.0
var _smooth := 0.0
var _look := Vector3.ZERO
var _walk_target = null
var _done := false
var _ending := false
var _tweens: Array = []
var _hidden_traffic := false


func play(p_game: Node3D) -> void:
    game = p_game
    world = game.world
    spider = game.spider
    camera = world.camera
    # The play mode is paused: no input, no camera, no radar. The spider keeps its own physics,
    # so its legs walk for real while we steer it.
    game.set_process(false)
    game.set_physics_process(false)
    game.set_process_unhandled_input(false)
    game.prompt.visible = false
    world.minimap.visible = false
    _street_frame()
    _clear_traffic()
    _build_ui()
    _build_car()
    _scatter_leaves()
    _run()


# ---------- Set-up ----------

func _route(id: String) -> Dictionary:
    for route in world.road_network.routes:
        if route.id == id:
            return route
    return {}


func _v3(p: Vector2) -> Vector3:
    return Vector3(p.x, 0.0, p.y)


func _street_frame() -> void:
    J = _v3(world.road_network.junctions[CROSSING])
    var boulevard := _route("main_entry")
    var start: Vector2 = boulevard.curve.get_point_position(0)
    F = (J - _v3(start)).normalized()
    R = F.cross(UP)
    cross_half = float(_route(CROSS_STREET[1]).width) * 0.5
    # the cross street, west to east, on its eastbound lane (the hero's side)
    var points := PackedVector2Array()
    for id in CROSS_STREET:
        var route := _route(id)
        if route.is_empty():
            continue
        var baked: PackedVector2Array = route.curve.get_baked_points()
        for k in baked.size():
            if points.is_empty() or points[-1].distance_to(baked[k]) > 0.002:
                points.append(baked[k])
    var lane := TRAFFIC.LANE_SHARE * cross_half * 2.0
    var arc := 0.0
    for k in points.size():
        var a := points[maxi(k - 1, 0)]
        var b := points[mini(k + 1, points.size() - 1)]
        var tangent := (b - a).normalized()
        var p := _v3(points[k]) + Vector3(-tangent.y, 0.0, tangent.x) * lane
        if k > 0:
            arc += p.distance_to(lane_path[-1])
        lane_path.append(p)
        lane_arc.append(arc)
    D = (_lane_at(_lane_closest(J) + 0.05) - _lane_at(_lane_closest(J) - 0.05)).normalized()
    curb = J - F * (cross_half + 0.03) + R * 0.05


func _lane_at(s: float) -> Vector3:
    s = clampf(s, 0.0, lane_arc[-1])
    for k in range(1, lane_arc.size()):
        if lane_arc[k] >= s:
            var u := (s - lane_arc[k - 1]) / maxf(lane_arc[k] - lane_arc[k - 1], 0.00001)
            return lane_path[k - 1].lerp(lane_path[k], u)
    return lane_path[-1]


func _lane_closest(p: Vector3) -> float:
    var best := 0
    for k in lane_path.size():
        if lane_path[k].distance_to(p) < lane_path[best].distance_to(p):
            best = k
    return lane_arc[best]


## Traffic is frozen during the scene, and cars near the crossing are moved elsewhere first.
func _clear_traffic() -> void:
    var traffic = world.traffic
    if traffic == null:
        return
    var here := Vector2(J.x, J.z)
    var saved = traffic.avoid_point
    traffic.avoid_point = here
    for car_entry in traffic.cars:
        for attempt in 8:
            if car_entry.pos.distance_to(here) > CLEAR_RADIUS:
                break
            traffic._place(car_entry)
    traffic.avoid_point = saved
    traffic.process_mode = Node.PROCESS_MODE_DISABLED
    _hidden_traffic = true


func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 50   # under the CRT filter, which covers everything
    add_child(ui)
    bar_h = get_viewport().get_visible_rect().size.y * BAR_RATIO
    bar_top = ColorRect.new()
    bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    bar_top.offset_bottom = 0.0
    bar_bottom = ColorRect.new()
    bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bar_bottom.offset_top = 0.0
    fade = ColorRect.new()
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    for c in [bar_top, bar_bottom, fade]:
        c.color = Color.BLACK
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ui.add_child(c)
    voice = AudioStreamPlayer.new()
    add_child(voice)


## The lowrider: the Pimpmobile at traffic size, painted purple, with clear windows to see the
## crew, and hydraulics that bounce its body.
func _build_car() -> void:
    car = Node3D.new()
    car.name = "TisseusesLowrider"
    add_child(car)
    var scene := load(CAR_SCENE) as PackedScene
    var model: Node3D = scene.instantiate()
    model.set("paint_color", VIOLET)
    model.set("glass_opacity", 0.22)
    model.scale = Vector3.ONE * TRAFFIC.CAR_SCALE
    # the model's origin sits behind its centre; put the centre on our origin
    model.position = Vector3(0, 0, TRAFFIC.CENTER_AHEAD * TRAFFIC.CAR_SCALE)
    car.add_child(model)
    for node in model.find_children("*", "Node3D", true, false):
        if node.get_parent() == model.get_node_or_null("Model"):
            if String(node.name).begins_with("Wheel"):
                car_wheels.append(node)
            else:
                car_body.append([node, node.transform])
    # the crew: driver on the left, one passenger on the hero's side, one in the back
    var seats := [Vector3(-0.0075, 0.019, -0.003), Vector3(0.0075, 0.019, -0.003), Vector3(0.006, 0.02, 0.016)]
    var turns := [0.0, -PI / 2.0, -PI / 2.0]
    for k in seats.size():
        var holder := Node3D.new()
        car.add_child(holder)
        holder.position = seats[k]
        holder.set_meta("seat", seats[k])
        if ResourceLoader.exists(RIDER_MODEL):
            var rider: Node3D = load(RIDER_MODEL).instantiate()
            holder.add_child(rider)
            _fit(rider, holder, 0.018)
            for ap in rider.find_children("*", "AnimationPlayer", true, false):
                ap.speed_scale = 0.0
        # the model faces +Z, the car -Z
        holder.rotation.y = PI + turns[k]
        riders.append(holder)
    car.visible = false


## Scales `node` so its longest side is `size`, standing on the holder's origin.
func _fit(node: Node3D, holder: Node3D, size: float) -> void:
    var box := _aabb_of(node, holder)
    node.scale = Vector3.ONE * size / maxf(maxf(box.size.x, box.size.z), 0.00001)
    box = _aabb_of(node, holder)
    node.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)


func _aabb_of(n: Node3D, ref: Node3D) -> AABB:
    var out := AABB()
    var first := true
    var inv := ref.global_transform.affine_inverse()
    for m in n.find_children("*", "MeshInstance3D", true, false):
        var a: AABB = (inv * m.global_transform) * m.get_aabb()
        out = a if first else out.merge(a)
        first = false
    return out


## Dead leaves around the crossing. The lowrider blows them up as it passes. They stay afterwards.
func _scatter_leaves() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var colors := [Color("9a5a25"), Color("b8742c"), Color("7b4a22"), Color("c49a3a"), Color("8d3f1f")]
    for k in 34:
        var p := J + D * rng.randf_range(-0.5, 0.4) + D.cross(UP) * rng.randf_range(-cross_half - 0.02, cross_half + 0.02)
        if k > 22:
            # a few more along the boulevard where the hero walks
            p = J - F * rng.randf_range(cross_half + 0.02, 0.5) + R * rng.randf_range(-0.09, 0.09)
        var leaf := MeshInstance3D.new()
        leaf.mesh = _leaf_mesh(rng.randf_range(0.012, 0.022))
        var mat := StandardMaterial3D.new()
        mat.albedo_color = colors[rng.randi() % colors.size()]
        mat.roughness = 0.9
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        leaf.material_override = mat
        world.add_child(leaf)
        leaf.global_position = p + UP * 0.0006
        leaf.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
        leaves.append({"node": leaf, "floor": 0.0006, "vel": Vector3.ZERO, "spin": Vector3.ZERO, "air": false})


## A flat leaf: pointed oval with a slight fold along its middle.
func _leaf_mesh(length: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := 7
    var half := length * 0.5
    var ring := []
    for i in n + 1:
        var u := float(i) / n
        var z := lerpf(-half, half, u)
        var w := sin(u * PI) * length * 0.28
        ring.append([Vector3(-w, 0.0, z), Vector3(0.0, length * 0.05 * sin(u * PI), z), Vector3(w, 0.0, z)])
    for i in n:
        for side in [[0, 1], [1, 2]]:
            var a: Vector3 = ring[i][side[0]]
            var b: Vector3 = ring[i][side[1]]
            var c: Vector3 = ring[i + 1][side[0]]
            var d: Vector3 = ring[i + 1][side[1]]
            for v in [a, b, d, a, d, c]:
                st.set_normal(UP)
                st.add_vertex(v)
    return st.commit()


# ---------- The scene ----------

func _run() -> void:
    var walk_from := curb - F * 0.42
    _place_hero(walk_from, F)

    # 1. Follow the hero from behind as he comes up the boulevard.
    _tween_prop(fade, "color:a", 0.0, 1.6)
    _bars(true, 1.0)
    _cam_follow()
    await _walk_hero(curb)
    if _done:
        return

    # 2. He stops at the crossing and waits, looking down the street to his left.
    await _turn_hero(-D * 0.35 + F, 0.5)
    var over := curb - F * 0.075 + R * 0.035 + UP * 0.028
    _cam_shot(over, over - R * 0.01, func(_k): return J - D * 0.45 + UP * 0.012, 3.0, 0.6)
    await _wait(1.4)
    if _done:
        return

    # 3. The lowrider comes along the cross street and slows to a stop in front of him.
    var stop_s := _lane_closest(curb)
    _drive_car(stop_s - 1.0, stop_s, 6.0, Tween.EASE_OUT, Tween.TRANS_CUBIC)
    await _wait(1.6)
    if _done:
        return
    var low := _lane_at(stop_s + 0.17) + UP * 0.007
    _cam_shot(low, low - D * 0.02, func(_k): return car.global_position + UP * 0.008, 4.6, 0.0)
    await _wait(4.4)
    if _done:
        return

    # 4. Their eyes meet. The Tisseuses turn to him and mock him.
    _turn_hero(F, 0.4)
    hop = 0.25
    var shoulder := curb - F * 0.07 - R * 0.03 + UP * 0.042
    _cam_shot(shoulder, shoulder + F * 0.01, func(_k): return car.global_position.lerp(spider.global_position, 0.3) + UP * 0.014, 6.0, 0.0)
    await _wait(0.8)
    await _say("line_1")
    if _done:
        return
    await _say("line_2")
    if _done:
        return

    # 5. Reverse shot from the car: the hero, small, looking up at them.
    var from_car := car.global_position + (curb - car.global_position).normalized() * 0.03 + UP * 0.028 + D * 0.02
    _cam_shot(from_car, from_car + UP * 0.003, func(_k): return spider.global_position + UP * 0.008, 3.0, 0.0)
    await _wait(0.3)
    await _say("line_3")
    if _done:
        return

    # 6. Wide shot: they laugh, the car jumps on its hydraulics.
    # from the far corner of the crossing, on the road so no grass blade gets in the way
    var wide := J + F * 0.03 - D * 0.085 + UP * 0.026
    _cam_shot(wide, wide + D * 0.012, func(_k): return (car.global_position + spider.global_position) * 0.5 + UP * 0.01, 5.0, 0.0)
    hop = 1.0
    for r in riders:
        for ap in r.find_children("*", "AnimationPlayer", true, false):
            ap.speed_scale = 2.5
    await _say("laugh")
    if _done:
        return
    for r in riders:
        for ap in r.find_children("*", "AnimationPlayer", true, false):
            ap.speed_scale = 0.0

    # 7. They drive off in a swirl of leaves.
    hop = 0.6
    _drive_car(car_s, car_s + 1.6, 4.5, Tween.EASE_IN, Tween.TRANS_QUAD)
    await _wait(1.6)
    if _done:
        return

    # 8. He turns back and leaves: he walks past the camera, which turns to follow him.
    hop = 0.0
    var away := curb - F * 0.5
    var cam_spot := curb - F * 0.2 - R * 0.025 + UP * 0.01
    _cam_shot(cam_spot, cam_spot - R * 0.004, func(_k): return spider.global_position + UP * 0.008, 6.0, 0.25)
    await _turn_hero(-F, 0.6)
    _walk_hero(away)
    await _wait(3.2)
    if _done:
        return

    # 9. The camera slips behind him and becomes the play camera.
    _finish(false)


# ---------- The hero ----------

func _place_hero(p: Vector3, facing: Vector3) -> void:
    spider.global_position = Vector3(p.x, 0.0, p.z)
    spider.velocity = Vector3.ZERO
    spider.move_input = Vector3.ZERO
    spider.heading = atan2(-facing.x, -facing.z)
    spider.rotation.y = spider.heading
    spider.model.snap_feet()


## The spider walks on its own physics (so its legs step for real) toward `to`.
func _walk_hero(to: Vector3) -> void:
    _walk_target = Vector3(to.x, 0.0, to.z)
    while _walk_target != null and not _done:
        await get_tree().physics_frame


func _turn_hero(dir: Vector3, dur: float) -> void:
    var to: float = spider.heading + angle_difference(spider.heading, atan2(-dir.x, -dir.z))
    var set_heading := func(h: float) -> void:
        spider.heading = h
        spider.rotation.y = h
    var tw := _tween()
    tw.tween_method(set_heading, spider.heading, to, dur).set_trans(Tween.TRANS_SINE)
    await tw.finished


func _steer_hero() -> void:
    if _walk_target == null:
        spider.move_input = Vector3.ZERO
        return
    var to: Vector3 = _walk_target - spider.global_position
    to.y = 0.0
    if to.length() < 0.006:
        spider.move_input = Vector3.ZERO
        _walk_target = null
        return
    # slow down over the last few centimetres so it stops on its mark
    spider.move_input = to.normalized() * clampf(to.length() / 0.03, 0.25, 1.0)


# ---------- The car ----------

func _drive_car(from_s: float, to_s: float, dur: float, ease_type: int, trans: int) -> void:
    car.visible = true
    car_s = from_s
    _car_prev = from_s
    _place_car(from_s)
    var tw := _tween()
    tw.tween_method(_place_car, from_s, to_s, dur).set_ease(ease_type).set_trans(trans)


func _place_car(s: float) -> void:
    car_s = s
    var p := _lane_at(s)
    var ahead := _lane_at(s + 0.01) - _lane_at(s - 0.01)
    car.global_position = p
    if ahead.length() > 0.001:
        car.look_at(p + ahead, UP)


func _update_car(dt: float) -> void:
    if not is_instance_valid(car) or not car.visible:
        return
    var moved := car_s - _car_prev
    _car_prev = car_s
    car_speed = absf(moved) / maxf(dt, 0.0001)
    for w in car_wheels:
        w.rotate_object_local(Vector3.RIGHT, -moved / (0.3 * TRAFFIC.CAR_SCALE))
    # hydraulics: the body bounces, the front more than the back
    var bounce := absf(sin(t * 7.5)) * hop
    for entry in car_body:
        var node: Node3D = entry[0]
        var rest: Transform3D = entry[1]
        var tilt := Basis(Vector3.RIGHT, sin(t * 7.5) * 0.06 * hop)
        node.transform = Transform3D(tilt * rest.basis, tilt * rest.origin + Vector3(0, bounce * 0.18, 0))
    for k in riders.size():
        var talk := 1.0 if _speaker == k or _speaker == -1 else 0.0
        var seat: Vector3 = riders[k].get_meta("seat")
        riders[k].position = seat + UP * (bounce * 0.18 * TRAFFIC.CAR_SCALE + absf(sin(t * 11.0 + k)) * 0.0015 * maxf(hop, talk))
    if car_s > lane_arc[-1] - 0.05:
        car.visible = false


func _update_leaves(dt: float) -> void:
    for l in leaves:
        var n: Node3D = l.node
        if not is_instance_valid(n):
            continue
        if not l.air and is_instance_valid(car) and car.visible and car_speed > 0.05:
            var d := n.global_position - car.global_position
            d.y = 0.0
            if d.length() < 0.05:
                l.air = true
                l.vel = D * car_speed * randf_range(0.3, 0.6) + d.normalized() * randf_range(0.02, 0.06) + UP * randf_range(0.06, 0.12)
                l.spin = Vector3(randf_range(-6, 6), randf_range(-8, 8), randf_range(-6, 6))
        if l.air:
            var v: Vector3 = l.vel
            v.y = maxf(v.y - 0.25 * dt, -0.05)
            v.x *= 1.0 - dt * 1.5
            v.z *= 1.0 - dt * 1.5
            l.vel = v
            n.global_position += v * dt
            n.rotation += l.spin * dt
            if n.global_position.y <= l.floor and v.y < 0.0:
                n.global_position.y = l.floor
                n.rotation = Vector3(0, n.rotation.y, 0)
                l.air = false


# ---------- Camera, bars, lines ----------

func _cam_follow() -> void:
    _shot_t = 0.0
    _smooth = 4.0
    _cam_fn = func(_k: float) -> Array:
        var f := Vector3(-sin(spider.heading), 0, -cos(spider.heading))
        var p := spider.global_position
        return [p - f * 0.1 + UP * 0.03, p + f * 0.08 + UP * 0.01]
    var r: Array = _cam_fn.call(0.0)
    camera.global_position = r[0]
    _look = r[1]
    camera.look_at(_look, UP)


## One shot: the camera glides from `from` to `to` over `dur` and looks at what `look` returns.
## `smooth` > 0 eases in from the previous shot instead of cutting.
func _cam_shot(from: Vector3, to: Vector3, look: Callable, dur: float, smooth: float) -> void:
    _shot_t = 0.0
    _smooth = 0.0 if smooth <= 0.0 else 1.0 / smooth
    _cam_fn = func(time: float) -> Array:
        var k := smoothstep(0.0, 1.0, clampf(time / dur, 0.0, 1.0))
        return [from.lerp(to, k), look.call(k)]
    if smooth <= 0.0:
        var r: Array = _cam_fn.call(0.0)
        camera.global_position = r[0]
        _look = r[1]
        camera.look_at(_look, UP)


func _update_camera(dt: float) -> void:
    if not _cam_fn.is_valid():
        return
    _shot_t += dt
    var r: Array = _cam_fn.call(_shot_t)
    if _smooth > 0.0:
        var a := 1.0 - exp(-dt * _smooth)
        camera.global_position = camera.global_position.lerp(r[0], a)
        _look = _look.lerp(r[1], a)
    else:
        camera.global_position = r[0]
        _look = r[1]
    if camera.global_position.distance_to(_look) > 0.0001:
        camera.look_at(_look, UP)


func _bars(show: bool, dur: float) -> void:
    _tween_prop(bar_top, "offset_bottom", bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)
    _tween_prop(bar_bottom, "offset_top", -bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)


## A line's slot: the Tisseuse who speaks bobs a little, and her voice plays if the file exists.
func _say(id: String) -> void:
    var line: Array = LINES[id]
    var length: float = line[1]
    for ext in [".ogg", ".wav", ".mp3"]:
        if ResourceLoader.exists(VOICE_PATH % id + ext):
            voice.stream = load(VOICE_PATH % id + ext)
            voice.play()
            # a longer recording keeps the shot going until it ends
            length = maxf(length, voice.stream.get_length())
            break
    _speaker = line[0]
    await _wait(length)
    _speaker = -2
    if not _done:
        await _wait(0.25)


# ---------- The end: back to play ----------

func _finish(skipped: bool) -> void:
    if _ending:
        return
    _ending = true
    _done = true
    for tw in _tweens:
        if tw.is_valid():
            tw.kill()
    _tweens.clear()
    voice.stop()
    _walk_target = null
    spider.move_input = Vector3.ZERO
    if skipped:
        fade.color.a = 0.0
        car.visible = false
        _place_hero(curb - F * 0.3, -F)
    # the play camera sits behind the spider, facing the way it faces
    game.yaw = spider.heading
    game.pitch = -0.22
    var blend := 0.7 if skipped else 2.0
    _cam_fn = Callable()
    var start := camera.global_transform
    _bars(false, blend * 0.8)
    var blend_to := func(k: float) -> void:
        game._update_camera(0.0)
        camera.global_transform = start.interpolate_with(camera.global_transform, k)
    var tw := create_tween()
    tw.tween_method(blend_to, 0.0, 1.0, blend).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    await tw.finished
    if _hidden_traffic:
        world.traffic.process_mode = Node.PROCESS_MODE_INHERIT
    world.minimap.visible = true
    game.set_process(true)
    game.set_physics_process(true)
    game.set_process_unhandled_input(true)
    finished.emit()
    ui.queue_free()
    car.queue_free()


func _input(event: InputEvent) -> void:
    if _ending:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        _finish(true)


func _physics_process(_dt: float) -> void:
    if not _ending:
        _steer_hero()


func _process(dt: float) -> void:
    t += dt
    _update_car(dt)
    _update_leaves(dt)
    if not _ending:
        _update_camera(dt)


func _tween() -> Tween:
    var tw := create_tween()
    _tweens.append(tw)
    return tw


func _tween_prop(obj: Object, prop: String, value: Variant, dur: float) -> PropertyTweener:
    return _tween().tween_property(obj, prop, value, dur)


func _wait(s: float) -> void:
    await get_tree().create_timer(s, false).timeout
