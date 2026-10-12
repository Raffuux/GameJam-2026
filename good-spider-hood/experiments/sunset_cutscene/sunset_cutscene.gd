extends Node3D
## Second cutscene, played in real time in the clearing at the end of the rock lane.
## Sunset. The jumping spider sits with five friends (durag, cap, bandana, girl, skull) and a joint
## in his mouth. His friend tells him to stop sleeping on it and pass it; he does and they laugh.
## The sun sets and the moon rises in fast motion, then we are back on the group at night, each with
## a joint of a different size, still laughing, and the camera settles behind the hero as the
## play-mode camera. It stays night afterwards.
##
## Cinema bars slide in at the start and out at the end. No text and no radar on screen.
## The lines are not written yet: each one is a timed slot, and a voice file dropped in
## voices/ (see LINES) plays in it. Escape skips.

signal finished

const MODELS := "res://experiments/sunset_cutscene/models/spider_%s.glb"
const VOICE_PATH := "res://experiments/sunset_cutscene/voices/%s"
const UP := Vector3.UP
const EMBER := Color("ff5a1a")
const EMBER_HOT := Color("ffd27a")

## Where it happens: the clearing at the dead end of the rock lane, the lane leading out of it.
const CLEARING := "rock_a_end"
const LANE := "rock_a_lane"
const RING := 0.042          # the friends sit on a circle this wide (m) around the clearing
const MODEL_SCALE := 0.02    # the same scale as the playable spider
const CLEAR_RADIUS := 1.2
const BAR_RATIO := 0.12

## Around the circle from the lane, every 60 degrees: the hero, then his friends.
## [model, accessory, joint length in the last shot (m), 0 = none]
const CREW := [
    ["hero", "", 0.0],
    ["durag", "", 0.010],     # the friend who asks for the joint and gets it
    ["bandana", "", 0.006],
    ["joint", "cap", 0.0],    # the cap friend; his model has its own big joint, shown in the last shot
    ["girl", "", 0.008],
    ["skull", "", 0.014],
]
const FRIEND := 1

## [voice file (without extension), who speaks (index in CREW, -1 all), seconds]
const LINES := {
    "line_1": [1, 2.6],
    "laugh_1": [-1, 2.2],
    "laugh_2": [-1, 3.0],
}

## Mouth and head top in model units (the base spider mesh, facing -Z).
const MOUTH := Vector3(0.0, 0.29, -0.72)
const HEAD_TOP := Vector3(0.0, 0.62, -0.16)

## Time of day: 0 golden sunset, 0.55 sun on the horizon, 1 night under the moon.
## Sun and moon are [azimuth from the lane (deg), elevation (deg)].
const SKY_KEYS := [
    {"k": 0.0, "top": Color("56679a"), "horizon": Color("f0a15c"), "ground": Color("5a3f30"), "fog": Color("d79a68"),
        "sun": Color("ffb06a"), "sun_energy": 1.5, "sun_at": Vector2(25, 9), "ambient": Color("cfa58e"), "ambient_energy": 0.55,
        "moon_at": Vector2(62, -9), "moon_energy": 0.0},
    {"k": 0.55, "top": Color("343a6c"), "horizon": Color("e3683f"), "ground": Color("3c2a2c"), "fog": Color("a9584a"),
        "sun": Color("ff6a3a"), "sun_energy": 0.8, "sun_at": Vector2(20, 0.5), "ambient": Color("9b7290"), "ambient_energy": 0.45,
        "moon_at": Vector2(60, -3), "moon_energy": 0.0},
    {"k": 1.0, "top": Color("0a0f26"), "horizon": Color("26305c"), "ground": Color("10131f"), "fog": Color("1d2546"),
        "sun": Color("ff6a3a"), "sun_energy": 0.0, "sun_at": Vector2(16, -7), "ambient": Color("5a6a9c"), "ambient_energy": 0.9,
        "moon_at": Vector2(54, 16), "moon_energy": 1.0},
]

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

# C the clearing centre, L the way out along the lane (horizontal unit vector)
var C := Vector3.ZERO
var L := Vector3.FORWARD

var crew: Array = []          # per CREW entry: {"node": Node3D holder (the spider itself for the hero), "pos", "facing"}
var hero_joint: Node3D
var last_joints: Array = []   # shown in the last shot
var embers: Array = []        # [ember material, joint]

var sky_material: ProceduralSkyMaterial
var environment: Environment
var sun: DirectionalLight3D
var sun_disc: DirectionalLight3D
var moon_disc: DirectionalLight3D
var moon: DirectionalLight3D
var ink: ShaderMaterial
var time_of_day := 0.0

var t := 0.0
var _speaker := -2
var _laugh := 0.0
var _cam_fn := Callable()
var _shot_t := 0.0
var _smooth := 0.0
var _look := Vector3.ZERO
var _done := false
var _ending := false
var _tweens: Array = []
var _hidden_traffic := false
var _joint_passed := false


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
    _clearing_frame()
    _clear_traffic()
    _build_ui()
    _build_sky()
    _build_crew()
    set_time(0.0)
    _run()


# ---------- Set-up ----------

func _route(id: String) -> Dictionary:
    for route in world.road_network.routes:
        if route.id == id:
            return route
    return {}


func _v3(p: Vector2) -> Vector3:
    return Vector3(p.x, 0.0, p.y)


func _clearing_frame() -> void:
    C = _v3(world.road_network.junctions[CLEARING])
    var lane := _route(LANE)
    var baked: PackedVector2Array = lane.curve.get_baked_points()
    # the lane's last 15 cm, pointing out of the clearing
    var out := C
    var walked := 0.0
    for k in range(baked.size() - 1, 0, -1):
        walked += baked[k].distance_to(baked[k - 1])
        out = _v3(baked[k - 1])
        if walked > 0.15:
            break
    L = (out - C).normalized()


func _around(angle_deg: float) -> Vector3:
    return L.rotated(UP, deg_to_rad(angle_deg))


## Traffic is frozen during the scene, and cars near the clearing are moved elsewhere first.
func _clear_traffic() -> void:
    var traffic = world.traffic
    if traffic == null:
        return
    var here := Vector2(C.x, C.z)
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


## The forest's sun keeps lighting the scene; two sky-only lights draw the sun and moon discs,
## and a dim moonlight takes over at night.
func _build_sky() -> void:
    var world_env := world.get_node_or_null("SunnyEnvironment") as WorldEnvironment
    environment = world_env.environment
    sky_material = environment.sky.sky_material as ProceduralSkyMaterial
    sky_material.sun_angle_max = 9.0
    sky_material.sun_curve = 0.1
    sun = world.get_node_or_null("WarmSun") as DirectionalLight3D
    sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
    ink = world.post.material_override as ShaderMaterial
    sun_disc = _sky_light(3.2)
    moon_disc = _sky_light(1.8)
    moon_disc.light_color = Color("e8ecff")
    moon = DirectionalLight3D.new()
    moon.name = "Moonlight"
    moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
    moon.light_color = Color("9fb4ff")
    moon.shadow_enabled = sun.shadow_enabled
    moon.directional_shadow_max_distance = sun.directional_shadow_max_distance
    moon.shadow_bias = sun.shadow_bias
    moon.shadow_normal_bias = sun.shadow_normal_bias
    world.add_child(moon)


func _sky_light(size_deg: float) -> DirectionalLight3D:
    var light := DirectionalLight3D.new()
    light.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
    light.light_angular_distance = size_deg
    light.shadow_enabled = false
    world.add_child(light)
    return light


## The direction toward a point in the sky, [azimuth from the lane, elevation] in degrees.
func _sky_dir(at: Vector2) -> Vector3:
    var flat := _around(at.x)
    return (flat * cos(deg_to_rad(at.y)) + UP * sin(deg_to_rad(at.y))).normalized()


func _aim(light: DirectionalLight3D, toward: Vector3) -> void:
    # a directional light shines along its -Z, so -Z points away from the sky spot
    light.global_basis = Basis.looking_at(-toward, UP if absf(toward.y) < 0.99 else Vector3.FORWARD)


## Sets the whole sky, light and fog for a time of day between 0 (sunset) and 1 (night).
func set_time(k: float) -> void:
    time_of_day = clampf(k, 0.0, 1.0)
    var a: Dictionary = SKY_KEYS[0]
    var b: Dictionary = SKY_KEYS[-1]
    for i in SKY_KEYS.size() - 1:
        if time_of_day <= SKY_KEYS[i + 1].k:
            a = SKY_KEYS[i]
            b = SKY_KEYS[i + 1]
            break
    var u := smoothstep(0.0, 1.0, (time_of_day - a.k) / maxf(b.k - a.k, 0.0001))
    sky_material.sky_top_color = a.top.lerp(b.top, u)
    sky_material.sky_horizon_color = a.horizon.lerp(b.horizon, u)
    sky_material.ground_horizon_color = a.horizon.lerp(b.horizon, u).darkened(0.25)
    sky_material.ground_bottom_color = a.ground.lerp(b.ground, u)
    var fog: Color = a.fog.lerp(b.fog, u)
    ink.set_shader_parameter("fog_color", fog)
    world.fog_color = fog
    environment.ambient_light_color = a.ambient.lerp(b.ambient, u)
    environment.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, u)
    var sun_dir := _sky_dir(a.sun_at.lerp(b.sun_at, u))
    var sun_energy := lerpf(a.sun_energy, b.sun_energy, u)
    _aim(sun, sun_dir)
    _aim(sun_disc, sun_dir)
    sun.light_color = a.sun.lerp(b.sun, u)
    # below the horizon the sun stops lighting the ground
    sun.light_energy = sun_energy * smoothstep(-2.0, 3.0, rad_to_deg(asin(sun_dir.y)))
    sun.visible = sun.light_energy > 0.001
    sun_disc.light_color = sun.light_color
    sun_disc.light_energy = 3.0 * smoothstep(-3.0, 0.0, rad_to_deg(asin(sun_dir.y)))
    var moon_dir := _sky_dir(a.moon_at.lerp(b.moon_at, u))
    var moon_energy := lerpf(a.moon_energy, b.moon_energy, u)
    _aim(moon, moon_dir)
    _aim(moon_disc, moon_dir)
    moon.light_energy = moon_energy
    moon.visible = moon_energy > 0.001
    moon_disc.light_energy = 1.1 * smoothstep(-3.0, 1.0, rad_to_deg(asin(moon_dir.y)))


## The crew sits on a circle around the clearing, facing its centre. The hero is the playable
## spider, on the lane side, so the play camera ends up behind him in the lane.
func _build_crew() -> void:
    for k in CREW.size():
        var out := _around(k * 60.0)
        var pos := C + out * RING
        var facing := -out
        var entry := {"pos": pos, "facing": facing}
        if CREW[k][0] == "hero":
            _place_hero(pos, facing)
            entry.node = spider
            hero_joint = _make_joint(0.011)
            _hold_in_mouth(spider.model, hero_joint, spider)
        else:
            var holder := Node3D.new()
            holder.name = "Friend_" + CREW[k][0]
            add_child(holder)
            holder.global_position = pos
            holder.rotation.y = atan2(-facing.x, -facing.z)
            var model: Node3D = load(MODELS % CREW[k][0]).instantiate()
            model.scale = Vector3.ONE * MODEL_SCALE
            holder.add_child(model)
            for ap in model.find_children("*", "AnimationPlayer", true, false):
                ap.play("idle")
                ap.seek(randf() * 1.5, true)
                ap.speed_scale = 0.7
            if CREW[k][1] == "cap":
                _add_cap(model)
            # the forest's toon shading turns any small light into a big flat disc: embers only glow
            for light in model.find_children("*", "OmniLight3D", true, false):
                light.free()
            # the model with its own joint hides it until the last shot
            for n in model.find_children("joint_*", "", true, false):
                n.visible = false
                last_joints.append(n)
            if CREW[k][2] > 0.0 and k != FRIEND:
                var j := _make_joint(CREW[k][2])
                _hold_in_mouth(model, j, holder)
                j.visible = false
                last_joints.append(j)
            entry.node = holder
            entry.model = model
        crew.append(entry)


func _place_hero(p: Vector3, facing: Vector3) -> void:
    spider.global_position = Vector3(p.x, 0.0, p.z)
    spider.velocity = Vector3.ZERO
    spider.move_input = Vector3.ZERO
    spider.heading = atan2(-facing.x, -facing.z)
    spider.rotation.y = spider.heading
    spider.model.snap_feet()


## A bone attachment on the model's body bone, so what it carries follows the idle breathing.
func _body_anchor(model: Node3D, fallback: Node3D) -> Node3D:
    var skeletons := model.find_children("*", "Skeleton3D", true, false)
    if skeletons.is_empty():
        return fallback
    var skeleton: Skeleton3D = skeletons[0]
    var bone := skeleton.find_bone("body")
    if bone < 0:
        return fallback
    var anchor := BoneAttachment3D.new()
    anchor.bone_name = "body"
    skeleton.add_child(anchor)
    anchor.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
    return anchor


## Puts a joint between the spider's fangs, pointing forward and a little up and to the side.
func _hold_in_mouth(model: Node3D, joint: Node3D, fallback: Node3D) -> void:
    var anchor := _body_anchor(model, fallback)
    anchor.add_child(joint)
    var face := model.global_transform * Transform3D(Basis(), MOUTH)
    joint.global_transform = Transform3D(face.basis.orthonormalized() * Basis(UP, -0.35) * Basis(Vector3.RIGHT, 0.22), face.origin)


## A red cap with its peak forward.
func _add_cap(model: Node3D) -> void:
    var cap := Node3D.new()
    cap.name = "Cap"
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("c3302b")
    mat.roughness = 0.8
    var crown := MeshInstance3D.new()
    var dome := SphereMesh.new()
    dome.radius = 0.26
    dome.height = 0.26
    dome.is_hemisphere = true
    dome.radial_segments = 16
    dome.rings = 6
    crown.mesh = dome
    crown.material_override = mat
    crown.scale = Vector3(1.0, 0.9, 1.1)
    cap.add_child(crown)
    var peak := MeshInstance3D.new()
    var brim := CylinderMesh.new()
    brim.top_radius = 0.2
    brim.bottom_radius = 0.2
    brim.height = 0.025
    brim.radial_segments = 16
    peak.mesh = brim
    var peak_mat := mat.duplicate()
    peak_mat.albedo_color = Color("1d1d22")
    peak.material_override = peak_mat
    peak.scale = Vector3(1.0, 1.0, 0.8)
    peak.position = Vector3(0, 0.01, -0.22)
    cap.add_child(peak)
    var button := MeshInstance3D.new()
    var ball := SphereMesh.new()
    ball.radius = 0.035
    ball.height = 0.07
    button.mesh = ball
    button.material_override = peak_mat
    button.position = Vector3(0, 0.235, 0)
    cap.add_child(button)
    var anchor := _body_anchor(model, model)
    anchor.add_child(cap)
    cap.global_transform = model.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.12), HEAD_TOP)


## A cone of paper, narrow at the mouth, with a glowing tip and smoke.
func _make_joint(length: float) -> Node3D:
    var joint := Node3D.new()
    joint.name = "Joint"
    var paper := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.height = length
    # rotated below so its top is the burning end
    cone.top_radius = length * 0.13
    cone.bottom_radius = length * 0.07
    cone.radial_segments = 10
    cone.rings = 1
    paper.mesh = cone
    var paper_mat := StandardMaterial3D.new()
    paper_mat.albedo_color = Color("f1ece0")
    paper_mat.roughness = 0.9
    paper.material_override = paper_mat
    # the cylinder stands on Y: lay it along -Z with its narrow end at the mouth
    paper.rotation.x = -PI / 2.0
    paper.position = Vector3(0, 0, -length * 0.5)
    joint.add_child(paper)
    var tip := Vector3(0, 0, -length)
    var ember := MeshInstance3D.new()
    var ball := SphereMesh.new()
    ball.radius = length * 0.12
    ball.height = length * 0.16
    ember.mesh = ball
    var ember_mat := StandardMaterial3D.new()
    ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ember_mat.albedo_color = EMBER
    ember.material_override = ember_mat
    ember.position = tip
    joint.add_child(ember)
    embers.append([ember_mat, joint])
    var smoke := CPUParticles3D.new()
    smoke.name = "Smoke"
    smoke.position = tip
    smoke.amount = 10
    smoke.lifetime = 2.6
    smoke.local_coords = false
    smoke.preprocess = 2.6
    var puff := QuadMesh.new()
    puff.size = Vector2.ONE * length * 0.3
    var smoke_mat := StandardMaterial3D.new()
    smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    # hashed transparency stays in the opaque pass, so the ink post-process keeps it
    smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
    smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    smoke_mat.vertex_color_use_as_albedo = true
    smoke_mat.albedo_color = Color(0.92, 0.92, 0.95, 0.5)
    var soft := GradientTexture2D.new()
    soft.fill = GradientTexture2D.FILL_RADIAL
    soft.fill_from = Vector2(0.5, 0.5)
    soft.fill_to = Vector2(1.0, 0.5)
    soft.width = 32
    soft.height = 32
    var falloff := Gradient.new()
    falloff.set_color(0, Color(1, 1, 1, 1))
    falloff.set_color(1, Color(1, 1, 1, 0))
    soft.gradient = falloff
    smoke_mat.albedo_texture = soft
    puff.material = smoke_mat
    smoke.mesh = puff
    smoke.direction = Vector3.UP
    smoke.spread = 18.0
    smoke.gravity = Vector3(0, length * 0.35, 0)
    smoke.initial_velocity_min = length * 0.25
    smoke.initial_velocity_max = length * 0.6
    smoke.damping_min = length * 0.1
    smoke.damping_max = length * 0.2
    smoke.scale_amount_min = 0.6
    smoke.scale_amount_max = 1.0
    var grow := Curve.new()
    grow.add_point(Vector2(0, 0.4))
    grow.add_point(Vector2(1, 2.6))
    smoke.scale_amount_curve = grow
    var fade_out := Gradient.new()
    fade_out.set_color(0, Color(1, 1, 1, 0.9))
    fade_out.set_color(1, Color(1, 1, 1, 0.0))
    smoke.color_ramp = fade_out
    joint.add_child(smoke)
    return joint


# ---------- The scene ----------

func _run() -> void:
    var hero: Vector3 = crew[0].pos
    var pal: Vector3 = crew[FRIEND].pos

    # 1. Push in on the group down the lane, the sun low behind the camera.
    _tween_prop(fade, "color:a", 0.0, 1.8)
    _bars(true, 1.2)
    var from := C + L * 0.26 + UP * 0.075
    var to := C + L * 0.10 + UP * 0.055
    _cam_shot(from, to, func(_k): return C + UP * 0.008, 6.0, 0.0)
    _tween_time(0.0, 0.08, 14.0)
    await _wait(5.6)
    if _done:
        return

    # 2. The hero smoking, the sunset behind him: a long pull, the tip glows, smoke.
    var side := L.cross(UP)
    var close := hero - L * 0.042 + side * 0.008 + UP * 0.010
    _cam_shot(close, close + L * 0.008, func(_k): return hero - L * 0.01 + UP * 0.008, 4.5, 0.0)
    await _wait(0.8)
    _puff(hero_joint, 1.6)
    await _wait(3.2)
    if _done:
        return

    # 3. Wide: his friend tells him to stop sleeping on it and pass it. He does, they laugh.
    var mid := (hero + pal) * 0.5
    var wide := C - (mid - C).normalized() * 0.03 + UP * 0.03
    _cam_shot(wide, wide + UP * 0.003, func(_k): return mid + UP * 0.008, 7.0, 0.0)
    await _wait(0.4)
    await _say("line_1")
    if _done:
        return
    await _turn_hero(pal - hero, 0.5)
    await _pass_joint(crew[FRIEND].model, crew[FRIEND].node)
    if _done:
        return
    _turn_hero(C - hero, 0.6)
    await _say("laugh_1")
    if _done:
        return

    # 4. Fast motion: the sun sets, the moon rises.
    var high := C + L * 0.05 + UP * 0.6
    var sky_look := high + _around(38.0) * 1.0 + UP * 0.13
    _cam_shot(high, high + UP * 0.02, func(_k): return sky_look, 4.8, 0.0)
    await _wait(0.6)
    _tween_time(time_of_day, 1.0, 3.6)
    await _wait(4.2)
    if _done:
        return

    # 5. Back on the group at night: everyone has a joint now, they laugh.
    for j in last_joints:
        j.visible = true
    var above := C + L * 0.02 + UP * 0.1
    var low := C + L * 0.085 + UP * 0.03
    _cam_shot(above, low, func(_k): return C + UP * 0.006, 5.0, 0.0)
    await _wait(0.6)
    await _say("laugh_2")
    if _done:
        return
    await _wait(0.8)
    if _done:
        return

    # 6. The camera settles behind the hero and becomes the play camera.
    _finish(false)


# ---------- The hero and the joint ----------

func _turn_hero(dir: Vector3, dur: float) -> void:
    var to: float = spider.heading + angle_difference(spider.heading, atan2(-dir.x, -dir.z))
    var set_heading := func(h: float) -> void:
        spider.heading = h
        spider.rotation.y = h
    var tw := _tween()
    tw.tween_method(set_heading, spider.heading, to, dur).set_trans(Tween.TRANS_SINE)
    await tw.finished


## The joint leaves the hero's mouth and arcs over to his friend's.
func _pass_joint(model: Node3D, holder: Node3D) -> void:
    var start := hero_joint.global_transform
    hero_joint.reparent(self, true)
    var anchor := _body_anchor(model, holder)
    var target_holder := Node3D.new()
    anchor.add_child(target_holder)
    var face := model.global_transform * Transform3D(Basis(), MOUTH)
    target_holder.global_transform = Transform3D(face.basis.orthonormalized() * Basis(UP, 0.35) * Basis(Vector3.RIGHT, 0.22), face.origin)
    var arc := func(k: float) -> void:
        var goal := target_holder.global_transform
        var p := start.origin.lerp(goal.origin, k) + UP * sin(k * PI) * 0.012
        hero_joint.global_transform = Transform3D(start.basis.slerp(goal.basis, k), p)
    var tw := _tween()
    tw.tween_method(arc, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tw.finished
    if _done:
        return
    hero_joint.reparent(target_holder, false)
    hero_joint.transform = Transform3D()
    _joint_passed = true
    _puff(hero_joint, 1.2)


## A pull on the joint: the tip flares, then smoke billows out.
func _puff(joint: Node3D, dur: float) -> void:
    for e in embers:
        if e[1] != joint:
            continue
        var mat: StandardMaterial3D = e[0]
        var tw := _tween()
        var glow := func(v: float) -> void:
            mat.albedo_color = EMBER.lerp(EMBER_HOT, v)
        tw.tween_method(glow, 0.0, 1.0, dur * 0.6)
        tw.tween_method(glow, 1.0, 0.0, dur * 0.4)
    var smoke := joint.get_node_or_null("Smoke") as CPUParticles3D
    if smoke:
        var base := smoke.amount
        smoke.amount = base * 3
        await _wait(dur)
        if is_instance_valid(smoke):
            smoke.amount = base


func _update_crew() -> void:
    # the one speaking bobs; when they all laugh everyone shakes
    for k in range(1, crew.size()):
        var talk := 1.0 if _speaker == k or _speaker == -1 else 0.0
        var amount := maxf(talk * 0.7, _laugh)
        var holder: Node3D = crew[k].node
        holder.global_position = crew[k].pos + UP * absf(sin(t * 10.0 + k * 1.7)) * 0.0018 * amount
        for ap in crew[k].model.find_children("*", "AnimationPlayer", true, false):
            ap.speed_scale = 0.7 + 1.8 * amount


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


func _tween_time(from: float, to: float, dur: float) -> void:
    var tw := _tween()
    tw.tween_method(set_time, from, to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _bars(show: bool, dur: float) -> void:
    _tween_prop(bar_top, "offset_bottom", bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)
    _tween_prop(bar_bottom, "offset_top", -bar_h if show else 0.0, dur).set_trans(Tween.TRANS_SINE)


## A line's slot: whoever speaks bobs a little (everyone for a laugh), and the voice plays if
## the file exists. The slot lasts its LINES time, or the recording's length if that is longer.
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
    _laugh = 1.0 if line[0] == -1 else 0.0
    await _wait(length)
    _speaker = -2
    _laugh = 0.0
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
    _speaker = -2
    _laugh = 0.0
    if skipped:
        fade.color.a = 0.0
        set_time(1.0)
        for j in last_joints:
            j.visible = true
        if not _joint_passed:
            # it ends up with the friend, as if the pass had happened
            hero_joint.queue_free()
            var j := _make_joint(0.011)
            _hold_in_mouth(crew[FRIEND].model, j, crew[FRIEND].node)
        _place_hero(crew[0].pos, -L)
    # the play camera sits behind the spider, facing the way it faces
    game.yaw = spider.heading
    game.pitch = -0.22
    var blend := 0.7 if skipped else 2.2
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


func _process(dt: float) -> void:
    t += dt
    _update_crew()
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
