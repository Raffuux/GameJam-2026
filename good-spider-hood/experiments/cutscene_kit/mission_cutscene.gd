extends Node3D
## Shared base for the mission 3 and final cutscenes, played in real time on the sunny forest map
## with the real models, the same way as the earlier cutscenes: the play mode is paused, cinema
## bars slide in, no text and no radar, Escape skips, and at the end the camera settles behind the
## hero as the play-mode camera.
##
## A scene extends this script and fills in: `lines` (who says each numbered line), `_setup()`
## (where it happens: `here`, the actors), `_run()` (the shots) and `_on_skip()` (where everyone
## ends up if the player skips).

signal finished

const VOICES = preload("res://experiments/voices/voice_lines.gd")
const UP := Vector3.UP
const MODEL_SCALE := 0.02     # the same scale as the playable spider
const BAR_RATIO := 0.12
const CLEAR_RADIUS := 1.2

## Night light, as at the end of the sunset cutscene (sun down, moon up, blue fog).
const NIGHT := {"top": Color("0a0f26"), "horizon": Color("26305c"), "ground": Color("10131f"),
    "fog": Color("1d2546"), "ambient": Color("5a6a9c"), "ambient_energy": 0.9,
    "moon": Color("9fb4ff"), "moon_at": Vector2(54, 16)}

## Each numbered line: [who speaks ("hero" or an actor's name), seconds if the recording is missing]
var lines := {}

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

## Where the scene happens (traffic is cleared around it).
var here := Vector3.ZERO
## name -> {"node": holder, "model": Node3D, "anim": AnimationPlayer or null, "base": local y}
var actors := {}

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
    # The play mode is paused: no input, no camera, no radar. The spider keeps its own physics,
    # so its legs walk for real while we steer it.
    game.set_process(false)
    game.set_physics_process(false)
    game.set_process_unhandled_input(false)
    game.prompt.visible = false
    world.minimap.visible = false
    _build_ui()
    _setup()
    _clear_traffic()
    _run()


# ---------- To fill in ----------

func _setup() -> void:
    pass


func _run() -> void:
    _finish(false)


func _on_skip() -> void:
    pass


# ---------- Set-up helpers ----------

func _route(id: String) -> Dictionary:
    for route in world.road_network.routes:
        if route.id == id:
            return route
    return {}


func _v3(p: Vector2) -> Vector3:
    return Vector3(p.x, 0.0, p.y)


func _junction(id: String) -> Vector3:
    return _v3(world.road_network.junctions[id])


## Traffic is frozen during the scene, and cars near it are moved elsewhere first.
func _clear_traffic() -> void:
    var traffic = world.traffic
    if traffic == null:
        return
    var spot := Vector2(here.x, here.z)
    var saved = traffic.avoid_point
    traffic.avoid_point = spot
    for car_entry in traffic.cars:
        for attempt in 8:
            if car_entry.pos.distance_to(spot) > CLEAR_RADIUS:
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


## Night over the whole map: sky, fog and ambient from the sunset cutscene's night, the sun off and
## a dim blue moonlight. It stays night afterwards.
func _night() -> void:
    var world_env := world.get_node_or_null("SunnyEnvironment") as WorldEnvironment
    var environment := world_env.environment
    var sky := environment.sky.sky_material as ProceduralSkyMaterial
    sky.sky_top_color = NIGHT.top
    sky.sky_horizon_color = NIGHT.horizon
    sky.ground_horizon_color = NIGHT.horizon.darkened(0.25)
    sky.ground_bottom_color = NIGHT.ground
    var ink := world.post.material_override as ShaderMaterial
    ink.set_shader_parameter("fog_color", NIGHT.fog)
    world.fog_color = NIGHT.fog
    environment.ambient_light_color = NIGHT.ambient
    environment.ambient_light_energy = NIGHT.ambient_energy
    var sun := world.get_node_or_null("WarmSun") as DirectionalLight3D
    var moon := DirectionalLight3D.new()
    moon.name = "Moonlight"
    moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
    moon.light_color = NIGHT.moon
    if sun:
        sun.visible = false
        moon.shadow_enabled = sun.shadow_enabled
        moon.directional_shadow_max_distance = sun.directional_shadow_max_distance
        moon.shadow_bias = sun.shadow_bias
        moon.shadow_normal_bias = sun.shadow_normal_bias
    world.add_child(moon)
    var at: Vector2 = NIGHT.moon_at
    var dir := (Vector3.FORWARD.rotated(UP, deg_to_rad(at.x)) * cos(deg_to_rad(at.y)) + UP * sin(deg_to_rad(at.y))).normalized()
    moon.global_basis = Basis.looking_at(-dir, UP)
    var disc := DirectionalLight3D.new()
    disc.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
    disc.light_angular_distance = 1.8
    disc.shadow_enabled = false
    disc.light_color = Color("e8ecff")
    world.add_child(disc)
    disc.global_basis = moon.global_basis


## An actor: one of the spider models, standing at `pos` and facing `facing`, playing its idle.
## `size` scales it against the playable spider (1 = the same size).
func _actor(actor_name: String, model_path: String, pos: Vector3, facing: Vector3, size := 1.0) -> Node3D:
    var holder := Node3D.new()
    holder.name = actor_name
    world.add_child(holder)
    var model: Node3D = load(model_path).instantiate()
    model.scale = Vector3.ONE * MODEL_SCALE * size
    holder.add_child(model)
    # the forest's toon shading turns any small light into a big flat disc
    for light in model.find_children("*", "OmniLight3D", true, false):
        light.free()
    var anim: AnimationPlayer = null
    for ap in model.find_children("*", "AnimationPlayer", true, false):
        anim = ap
    actors[actor_name] = {"node": holder, "model": model, "anim": anim}
    _place(actor_name, pos, facing)
    _anim(actor_name, "idle")
    return holder


func _place(actor_name: String, pos: Vector3, facing := Vector3.ZERO) -> void:
    var holder: Node3D = actors[actor_name].node
    holder.global_position = pos
    if facing.length() > 0.0001:
        holder.rotation.y = atan2(-facing.x, -facing.z)


func _anim(actor_name: String, anim_name: String) -> void:
    var ap: AnimationPlayer = actors[actor_name].anim
    if ap and ap.has_animation(anim_name):
        ap.play(anim_name)


func _pos(actor_name: String) -> Vector3:
    return actors[actor_name].node.global_position


## The actor walks to `to` in `dur` seconds and turns to face `then_face` (if given) once there.
func _walk(actor_name: String, to: Vector3, dur: float, then_face := Vector3.ZERO) -> void:
    var holder: Node3D = actors[actor_name].node
    var from := holder.global_position
    _anim(actor_name, "walk")
    var step := func(k: float) -> void:
        _place(actor_name, from.lerp(to, k), to - from)
    var tw := _tween()
    tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tw.finished
    if _done:
        return
    _anim(actor_name, "idle")
    if then_face.length() > 0.0001:
        await _turn(actor_name, then_face, 0.5)


func _turn(actor_name: String, dir: Vector3, dur: float) -> void:
    var holder: Node3D = actors[actor_name].node
    var yaw := holder.rotation.y + angle_difference(holder.rotation.y, atan2(-dir.x, -dir.z))
    var tw := _tween()
    tw.tween_property(holder, "rotation:y", yaw, dur).set_trans(Tween.TRANS_SINE)
    await tw.finished


# ---------- The hero ----------

func _place_hero(p: Vector3, facing: Vector3) -> void:
    spider.global_position = Vector3(p.x, p.y, p.z)
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


# ---------- Camera, bars, lines ----------

## One shot: the camera glides from `from` to `to` over `dur` and looks at what `look` returns.
## `smooth` > 0 eases in from the previous shot instead of cutting.
func _cam_shot(from: Vector3, to: Vector3, look: Callable, dur: float, smooth := 0.0) -> void:
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


## A close-up on whoever stands at `p` and faces `facing`: from in front of them, off to the
## side by `side` (signed), `dist` away, at head height.
func _close_on(p: Vector3, facing: Vector3, dur: float, side := 0.6, dist := 0.03, height := 0.012) -> void:
    var f := Vector3(facing.x, 0.0, facing.z).normalized()
    var r := f.cross(UP)
    var from := p + (f + r * side).normalized() * dist + UP * height
    _cam_shot(from, from + UP * 0.002 - f * 0.003, func(_k): return p + UP * 0.009, dur)


func _facing_of(actor_name: String) -> Vector3:
    var holder: Node3D = actors[actor_name].node
    return -holder.global_basis.z


func _hero_facing() -> Vector3:
    return Vector3(-sin(spider.heading), 0.0, -cos(spider.heading))


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


## A line: whoever speaks bobs a little, and its recording plays if the file is there. Without
## it the line lasts its `lines` time, in silence.
func _say(id: String) -> void:
    var line: Array = lines[id]
    var length: float = line[1]
    var stream := VOICES.stream(id)
    if stream:
        voice.stream = stream
        voice.play()
        length = stream.get_length()
    _speaker = line[0]
    await _wait(length)
    _speaker = ""
    if not _done:
        await _wait(0.25)


func _update_actors() -> void:
    for actor_name in actors:
        var model: Node3D = actors[actor_name].model
        var talk := 1.0 if _speaker == actor_name else 0.0
        model.position.y = absf(sin(t * 10.0 + model.get_instance_id() % 7)) * 0.0012 * talk


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
    if skipped:
        _on_skip()
    fade.color.a = 0.0 if skipped else fade.color.a
    # the play camera sits behind the spider, facing the way it faces
    game.yaw = spider.heading
    game.pitch = -0.22
    var blend := 0.7 if skipped else 2.0
    _cam_fn = Callable()
    var start := camera.global_transform
    _bars(false, blend * 0.8)
    if fade.color.a > 0.0:
        create_tween().tween_property(fade, "color:a", 0.0, blend)
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
    _update_actors()
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
