extends Node3D
## Third cutscene, played in real time at the BUG OIL gas station, placed by this scene beside the
## top street of the sunny forest (h0_4).
## The hero drives along the street, passes the station, turns in and stops at the pumps. He gets
## out to fill up; a beautiful spider (the girl variant) walks out of the shop; their eyes meet,
## he says one line, she giggles, and the camera settles behind him as the play-mode camera. The
## car stays at the pump as a parked car he can get back into.
##
## Cinema bars slide in at the start and out at the end. No text and no radar on screen.
## The lines are not written yet: each one is a timed slot, and a voice file dropped in
## voices/ (see LINES) plays in it. Escape skips.

signal finished

const STATION_MODEL := "res://experiments/gas_cutscene/models/gas_station.glb"
const GIRL_MODEL := "res://experiments/gas_cutscene/models/spider_girl.glb"
const TRAFFIC = preload("res://experiments/sunny_forest/roads/traffic.gd")
const PLAYER_CAR = preload("res://experiments/sunny_forest/play/player_car.gd")
const VOICE_PATH := "res://experiments/gas_cutscene/voices/%s"
const UP := Vector3.UP

## Where the station stands: beside this street, this far along it, on its south side.
const STREET := "h0_4"
const ALONG := 0.5
## The station model is in centimetres, its entrance facing +Z; its slab is 2.5 mm thick.
const STATION_SCALE := 0.01
const STATION_HALF := Vector2(15.15, 12.15)
const SLAB := 0.0025
## Grass is cleared this much wider than the station (cm, each side; front stops at the street).
const CLEAR_MARGIN := Vector2(6.0, 2.0)
const MODEL_SCALE := 0.02     # the same scale as the playable spider
const CLEAR_RADIUS := 1.2
const BAR_RATIO := 0.12
const PAINT := "crimson"

## Spots on the station, in its centimetres (x right, z toward the street).
const CAR_STOP := Vector2(0.0, 3.6)       # the car's middle, between the two pump islands
const HERO_SPOT := Vector2(-3.0, -0.6)    # in front of the left pump island
const PUMP := Vector2(-4.0, 2.2)
const SHOP_DOOR := Vector2(-5.5, -5.0)
const GIRL_SPOT := Vector2(-6.0, -2.6)
const WATCH := Vector2(-13.0, 3.0)        # camera spots: the forecourt's open left corner
const TWO_SHOT := Vector2(-14.0, -0.2)
const PLAY_FROM := Vector2(-13.0, -0.4)   # the play camera starts out from this side

## [voice file (without extension), who speaks ("hero", "girl"), seconds]
const LINES := {
    "fuel": ["", 2.4],          # the pump running (a sound, not a line)
    "line_1": ["hero", 2.8],    # his one line to her
    "giggle": ["girl", 1.6],
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

var station: Node3D
var station_xf := Transform3D()   # station centimetres -> map
var lane_dir := Vector3.LEFT      # the way the car comes along the street

var car_entry: Dictionary = {}    # the traffic car the hero drives; parked at the pump at the end
var car: Node3D                   # its drawn copy
var path := Curve2D.new()
var car_s := 0.0
var _car_prev := 0.0
var in_car := true

var girl: Node3D
var girl_model: Node3D
var girl_anim: AnimationPlayer
var _girl_walk = null
var _girl_from := Vector3.ZERO

var t := 0.0
var _speaker := ""
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
    # The play mode is paused: no input, no camera, no radar.
    game.set_process(false)
    game.set_physics_process(false)
    game.set_process_unhandled_input(false)
    game.prompt.visible = false
    world.minimap.visible = false
    _place_station()
    _clear_grass()
    _take_car()
    _clear_traffic()
    _build_ui()
    _build_path()
    _build_girl()
    _run()


# ---------- Set-up ----------

func _route(id: String) -> Dictionary:
    for route in world.road_network.routes:
        if route.id == id:
            return route
    return {}


func _v3(p: Vector2) -> Vector3:
    return Vector3(p.x, 0.0, p.y)


## A spot on the station (centimetres) on the map, `height` cm above the ground.
func at(p: Vector2, height := 0.0) -> Vector3:
    var w := station_xf * Vector3(p.x, 0.0, p.y)
    return Vector3(w.x, height * STATION_SCALE, w.z)


func _flat(v: Vector3) -> Vector2:
    return Vector2(v.x, v.z)


## The station stands beside the street, its forecourt opening onto it.
func _place_station() -> void:
    var street := _route(STREET)
    var curve: Curve2D = street.curve
    var length := curve.get_baked_length()
    var road := _v3(curve.sample_baked(length * ALONG))
    var tangent := (_v3(curve.sample_baked(length * ALONG + 0.01)) - _v3(curve.sample_baked(length * ALONG - 0.01))).normalized()
    # the south side of the street: the side away from the map's top edge (+Z on the map)
    var toward_road := tangent.cross(UP)
    if toward_road.z < 0.0:
        toward_road = -toward_road
    var center := road - toward_road * (float(street.width) * 0.5 + 0.005 + STATION_HALF.y * STATION_SCALE)
    var basis := Basis(UP.cross(toward_road), UP, toward_road)
    station_xf = Transform3D(basis.scaled(Vector3.ONE * STATION_SCALE), center)
    # the car comes along the street on the station's side, so it turns right into the forecourt
    lane_dir = -tangent if (-tangent).cross(UP).dot(-toward_road) > 0.0 else tangent
    station = (load(STATION_MODEL) as PackedScene).instantiate()
    station.name = "BugOilStation"
    world.add_child(station)
    station.global_transform = Transform3D(basis.scaled(Vector3.ONE * STATION_SCALE), center + UP * -SLAB)


## No grass on the forecourt: its blades are hidden and their collision boxes removed, in the
## forest's world (the spider) and in the traffic's (the cars).
func _clear_grass() -> void:
    var inv := station_xf.affine_inverse()
    var lo := -STATION_HALF - CLEAR_MARGIN
    var hi := Vector2(STATION_HALF.x + CLEAR_MARGIN.x, STATION_HALF.y + 1.0)
    var inside := func(p: Vector3) -> bool:
        var l := inv * Vector3(p.x, 0.0, p.z)
        return l.x > lo.x and l.x < hi.x and l.z > lo.y and l.z < hi.y
    for child in world.get_children():
        if child is MultiMeshInstance3D and String(child.name).begins_with("GrassBlades"):
            var mm: MultiMesh = child.multimesh
            for index in mm.instance_count:
                var xf := mm.get_instance_transform(index)
                if inside.call(xf.origin):
                    mm.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * 0.00001), xf.origin))
    var sets := [[world.grass_bodies, 1.0], [world.sim_grass_bodies, TRAFFIC.WORLD_SCALE]]
    for entry in sets:
        var factor: float = entry[1]
        for body in entry[0].values():
            for index in range(PhysicsServer3D.body_get_shape_count(body) - 1, -1, -1):
                var origin := PhysicsServer3D.body_get_shape_transform(body, index).origin / factor
                if inside.call(origin):
                    PhysicsServer3D.body_remove_shape(body, index)


## The hero's car is one of the traffic's cars, taken off its books. Its drawn copy is moved by hand
## during the scene; at the end the real car is set down at the pump and parked.
func _take_car() -> void:
    var traffic = world.traffic
    if traffic == null or traffic.cars.is_empty():
        return
    car_entry = traffic.cars[0]
    for entry in traffic.cars:
        if entry.proxy.paint == PAINT:
            car_entry = entry
            break
    traffic.cars.erase(car_entry)
    traffic._release(car_entry)
    car = car_entry.proxy


## Traffic is frozen during the scene, and cars near the station are moved elsewhere first.
func _clear_traffic() -> void:
    var traffic = world.traffic
    if traffic == null:
        return
    var here := _flat(at(Vector2.ZERO))
    var saved = traffic.avoid_point
    traffic.avoid_point = here
    for entry in traffic.cars:
        for attempt in 8:
            if entry.pos.distance_to(here) > CLEAR_RADIUS:
                break
            traffic._place(entry)
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


## The car's drive: along the street's lane past the station, then a right turn into the
## forecourt between the pump islands, stopping at the pumps.
func _build_path() -> void:
    var street := _route(STREET)
    var lane := TRAFFIC.LANE_SHARE * float(street.width)
    var front := at(Vector2(CAR_STOP.x, STATION_HALF.y))
    var stop := at(CAR_STOP)
    var into := (stop - front).normalized()        # into the forecourt
    var on_lane := front - into * (float(street.width) * 0.5 + 0.005 - lane)
    var start := on_lane - lane_dir * 0.85
    var turn_in := on_lane - lane_dir * 0.07
    path.add_point(_flat(start), Vector2.ZERO, _flat(lane_dir * 0.3))
    path.add_point(_flat(turn_in), _flat(-lane_dir * 0.2), _flat(lane_dir * 0.045))
    path.add_point(_flat(front + into * 0.01), _flat(-into * 0.045), _flat(into * 0.02))
    path.add_point(_flat(stop), _flat(-into * 0.03), Vector2.ZERO)
    path.bake_interval = 0.002
    car_s = 0.0
    _place_car(0.0)


func _build_girl() -> void:
    girl = Node3D.new()
    girl.name = "GasStationGirl"
    world.add_child(girl)
    girl_model = (load(GIRL_MODEL) as PackedScene).instantiate()
    girl_model.scale = Vector3.ONE * MODEL_SCALE
    girl.add_child(girl_model)
    for ap in girl_model.find_children("*", "AnimationPlayer", true, false):
        girl_anim = ap
    _set_girl(at(SHOP_DOOR), at(GIRL_SPOT) - at(SHOP_DOOR))
    girl.visible = false
    if girl_anim:
        girl_anim.play("idle")


func _set_girl(p: Vector3, facing: Vector3) -> void:
    girl.global_position = Vector3(p.x, 0.0, p.z)
    if facing.length() > 0.0001:
        girl.rotation.y = atan2(-facing.x, -facing.z)


# ---------- The scene ----------

func _run() -> void:
    _seat_hero()

    # 1. The car comes along the street and passes in front of the station.
    _tween_prop(fade, "color:a", 0.0, 1.6)
    _bars(true, 1.0)
    _drive(path.get_baked_length(), 8.0)
    var wide := at(Vector2(-19.0, 11.5), 4.5)
    _cam_shot(wide, at(Vector2(-17.0, 11.0), 4.2), func(_k): return car.global_position.lerp(at(Vector2(2.0, 4.0), 4.0), 0.45), 5.2, 0.0)
    await _wait(5.0)
    if _done:
        return

    # 2. It turns in and rolls up to the pumps, head-on to the camera.
    var shop_front := at(Vector2(-1.5, -2.8), 2.2)
    _cam_shot(shop_front, shop_front + (at(CAR_STOP) - at(Vector2(-1.5, -2.8))).normalized() * 0.004, func(_k): return car.global_position + UP * 0.012, 3.4, 0.0)
    await _wait(3.4)
    if _done:
        return

    # 3. He gets out and fills up.
    var side := at(Vector2(-7.5, -2.5), 3.2)
    _cam_shot(side, side + UP * 0.002, func(_k): return spider.global_position.lerp(at(PUMP, 2.0), 0.35) + UP * 0.008, 4.0, 0.0)
    _unseat_hero()
    await _walk_hero(at(HERO_SPOT))
    if _done:
        return
    await _turn_hero(at(PUMP) - spider.global_position, 0.4)
    _say("fuel")
    await _wait(1.0)
    if _done:
        return

    # 4. A girl walks out of the shop toward him.
    girl.visible = true
    _girl_walk_to(at(GIRL_SPOT), 2.6)
    var h := spider.global_position
    var g := at(GIRL_SPOT)
    # from the forecourt's open corner, clear of the canopy posts and the trash bags
    _cam_shot(at(WATCH, 3.6), at(WATCH + Vector2(0.5, -0.5), 3.4), func(_k): return girl.global_position.lerp(spider.global_position, 0.4) + UP * 0.008, 3.2, 0.0)
    await _wait(1.4)
    if _done:
        return
    await _turn_hero(g - h, 0.6)
    await _wait(1.4)
    if _done:
        return

    # 5. Their eyes meet: close on her, then on him.
    var her := g + (h - g).normalized() * 0.034 + UP * 0.022
    _cam_shot(her, her + UP * 0.001, func(_k): return g + UP * 0.009, 1.8, 0.0)
    await _wait(1.6)
    if _done:
        return
    var him := h + (g - h).normalized() * 0.034 + UP * 0.022
    _cam_shot(him, him + UP * 0.001, func(_k): return h + UP * 0.009, 1.4, 0.0)
    await _wait(1.2)
    if _done:
        return

    # 6. Two-shot from the side: his line, her giggle.
    var mid := (h + g) * 0.5
    var two := at(TWO_SHOT, 3.0)
    _cam_shot(two, at(TWO_SHOT + Vector2(1.5, 0.0), 2.8), func(_k): return mid + UP * 0.008, 6.0, 0.0)
    await _say("line_1")
    if _done:
        return
    await _say("giggle")
    if _done:
        return

    # 7. The camera settles behind him and becomes the play camera.
    _finish(false)


# ---------- The car ----------

func _drive(to_s: float, dur: float) -> void:
    var tw := _tween()
    tw.tween_method(_place_car, car_s, to_s, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Puts the car's middle on the path, `s` metres along it.
func _place_car(s: float) -> void:
    car_s = s
    if car == null:
        return
    var middle := _v3(path.sample_baked(s))
    var ahead := _v3(path.sample_baked(minf(s + 0.01, path.get_baked_length())) - path.sample_baked(maxf(s - 0.01, 0.0)))
    if ahead.length() < 0.0001:
        return
    ahead = ahead.normalized()
    var basis := Basis(UP, atan2(-ahead.x, -ahead.z))
    car.global_transform = Transform3D(basis.scaled(Vector3.ONE * TRAFFIC.CAR_SCALE), middle - ahead * TRAFFIC.CENTER_AHEAD * TRAFFIC.CAR_SCALE)


func _update_car() -> void:
    if car == null:
        return
    var moved := car_s - _car_prev
    _car_prev = car_s
    for pivot in car.get("pivots"):
        for wheel in pivot.get_children():
            wheel.rotate_object_local(Vector3.RIGHT, -moved / (0.33 * TRAFFIC.CAR_SCALE))
    if in_car:
        _seat_hero()


## Sets the real car down where its copy stopped, with the handbrake on, as a parked car.
func _park_car() -> void:
    if car_entry.is_empty():
        return
    _place_car(path.get_baked_length())
    var at_now: Transform3D = car.global_transform
    var ahead := -at_now.basis.z.normalized()
    ahead.y = 0.0
    ahead = ahead.normalized()
    var origin := at_now.origin * TRAFFIC.WORLD_SCALE
    origin.y = 0.15
    var phys: PhysicsCar = car_entry.phys
    phys.reset_to(Transform3D(Basis(UP, atan2(-ahead.x, -ahead.z)), origin))
    phys.throttle = 0.0
    phys.steer = 0.0
    phys.brake = 1.0
    phys.audio_enabled = false
    game.parked.append(car_entry)


# ---------- The hero ----------

## While he drives, the spider sits small in the driver's seat, legs still.
func _seat_hero() -> void:
    if car == null:
        return
    spider.set_active(false)
    spider.visible = true
    spider.scale = Vector3.ONE * 0.45
    var ahead := -car.global_basis.z.normalized()
    var right := ahead.cross(UP)
    var middle := car.global_position + ahead * TRAFFIC.CENTER_AHEAD * TRAFFIC.CAR_SCALE
    spider.global_position = middle - right * 0.0085 - ahead * 0.002 + UP * 0.012
    spider.rotation.y = atan2(-ahead.x, -ahead.z)
    spider.heading = spider.rotation.y


## He gets out by the driver's door.
func _unseat_hero() -> void:
    in_car = false
    spider.scale = Vector3.ONE
    var ahead := -car.global_basis.z.normalized()
    var right := ahead.cross(UP)
    var middle := car.global_position + ahead * TRAFFIC.CENTER_AHEAD * TRAFFIC.CAR_SCALE
    var door := middle - right * 0.032 - ahead * 0.004
    spider.global_position = Vector3(door.x, 0.0, door.z)
    spider.set_active(true)
    spider.heading = atan2(-ahead.x, -ahead.z)
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
    if to.length() < 0.004:
        spider.move_input = Vector3.ZERO
        _walk_target = null
        return
    spider.move_input = to.normalized() * clampf(to.length() / 0.02, 0.3, 0.7)


# ---------- The girl ----------

func _girl_walk_to(to: Vector3, dur: float) -> void:
    _girl_from = girl.global_position
    _girl_walk = to
    if girl_anim:
        girl_anim.play("walk")
    var step := func(k: float) -> void:
        _set_girl(_girl_from.lerp(to, k), to - _girl_from)
    var tw := _tween()
    tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.tween_callback(func() -> void:
        _girl_walk = null
        if girl_anim:
            girl_anim.play("idle"))
    # she turns to him as she arrives
    tw.tween_method(func(k: float) -> void:
        var face := spider.global_position - girl.global_position
        var yaw := atan2(-face.x, -face.z)
        girl.rotation.y = lerp_angle(girl.rotation.y, yaw, k), 0.0, 1.0, 0.5)


func _update_girl() -> void:
    if girl == null or not girl.visible:
        return
    # her giggle: a little bounce
    var bounce := absf(sin(t * 12.0)) * 0.0012 if _speaker == "girl" else 0.0
    girl_model.position.y = bounce


# ---------- Camera, bars, lines ----------

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


## A line's slot: the voice plays if its file exists.
func _say(id: String) -> void:
    var line: Array = LINES[id]
    for ext in [".ogg", ".wav", ".mp3"]:
        if ResourceLoader.exists(VOICE_PATH % id + ext):
            voice.stream = load(VOICE_PATH % id + ext)
            voice.play()
            break
    _speaker = line[0]
    await _wait(line[1])
    _speaker = ""
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
    _speaker = ""
    _walk_target = null
    spider.move_input = Vector3.ZERO
    _park_car()
    if skipped:
        fade.color.a = 0.0
        if in_car:
            _unseat_hero()
        _set_girl(at(GIRL_SPOT), at(HERO_SPOT) - at(GIRL_SPOT))
        girl.visible = true
        if girl_anim:
            girl_anim.play("idle")
        spider.global_position = at(HERO_SPOT)
        var face := at(GIRL_SPOT) - at(HERO_SPOT)
        spider.heading = atan2(-face.x, -face.z)
        spider.rotation.y = spider.heading
        spider.model.snap_feet()
    # the play camera sits behind the spider, on the forecourt's open side, clear of pumps and posts
    var look := at(HERO_SPOT) - at(PLAY_FROM)
    game.yaw = atan2(-look.x, -look.z)
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
    if not _ending:
        _update_car()
        _update_camera(dt)
    _update_girl()


func _tween() -> Tween:
    var tw := create_tween()
    _tweens.append(tw)
    return tw


func _tween_prop(obj: Object, prop: String, value: Variant, dur: float) -> PropertyTweener:
    return _tween().tween_property(obj, prop, value, dur)


func _wait(s: float) -> void:
    await get_tree().create_timer(s, false).timeout
