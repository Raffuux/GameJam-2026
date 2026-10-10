extends CanvasLayer
## Interface façon GTA : radar rond qui tourne avec la caméra, nom du quartier en bas à droite,
## compteurs en haut à droite, carte complète sur M.

const Layout := preload("res://scripts/city/layout.gd")
const MapImage := preload("res://scripts/ui/map_image.gd")

const RADAR_SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear_mipmap;
uniform vec2 player_uv;
uniform float rot;
uniform float zoom = 0.16;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	if (d > 0.5) discard;
	float c = cos(rot);
	float s = sin(rot);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * zoom;
	vec2 uv = player_uv + q;
	vec4 col = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) col = vec4(0.12, 0.11, 0.1, 1.0);
	COLOR = mix(col, vec4(0.0, 0.0, 0.0, 1.0), smoothstep(0.46, 0.49, d));
}
"""

var map_tex: ImageTexture
var radar: ColorRect
var radar_overlay: Control
var money_label: Label
var silk_label: Label
var zone_name: Label
var zone_tag: Label
var toast: Label
var hint: Label
var fullmap: Control
var fullmap_overlay: Control
var intro: Control
var landmarks: Array = []
var coins: Array = []

var player: Node3D
var cam_yaw := 0.0
var player_yaw := 0.0
var _banner_t := 0.0
var _toast_t := 0.0


func _anchor(c: Control, preset: int, pos: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y


func _label(text: String, size: int, color: Color = Color.WHITE, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color.BLACK
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.8)
	ls.shadow_offset = Vector2(3, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func setup(texture: ImageTexture, marks: Array, coin_list: Array) -> void:
	map_tex = texture
	landmarks = marks
	coins = coin_list
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	radar = ColorRect.new()
	_anchor(radar, Control.PRESET_BOTTOM_LEFT, Vector2(24, -234), Vector2(210, 210))
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RADAR_SHADER
	sm.shader = sh
	sm.set_shader_parameter("map_tex", map_tex)
	radar.material = sm
	root.add_child(radar)
	radar_overlay = Control.new()
	radar_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	radar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_overlay.draw.connect(_draw_radar_overlay)
	radar.add_child(radar_overlay)

	var counters := VBoxContainer.new()
	_anchor(counters, Control.PRESET_TOP_RIGHT, Vector2(-300, 16), Vector2(280, 80))
	counters.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(counters)
	money_label = _label("$0", 40, Color("7ddc6a"))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counters.add_child(money_label)
	silk_label = _label("Fils tissés : 0", 22)
	silk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counters.add_child(silk_label)

	var banner := VBoxContainer.new()
	_anchor(banner, Control.PRESET_BOTTOM_RIGHT, Vector2(-760, -170), Vector2(720, 120))
	root.add_child(banner)
	zone_name = _label("", 58, Color.WHITE, 14)
	zone_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner.add_child(zone_name)
	zone_tag = _label("", 22)
	zone_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner.add_child(zone_tag)

	toast = _label("", 30, Color("ffe9a8"), 10)
	_anchor(toast, Control.PRESET_CENTER_TOP, Vector2(-500, 150), Vector2(1000, 50))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast)

	hint = _label("", 18)
	_anchor(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -80), Vector2(800, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	var help := _label("ZQSD/WASD bouger · Souris caméra · Espace sauter · Maj sprint · E tisser un fil · M carte · Échap souris", 15, Color(1, 1, 1, 0.8), 4)
	_anchor(help, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -34), Vector2(1000, 24))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(help)

	_build_fullmap(root)
	_build_intro(root)


func _build_fullmap(root: Control) -> void:
	fullmap = ColorRect.new()
	(fullmap as ColorRect).color = Color(0.04, 0.04, 0.03, 0.88)
	fullmap.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullmap.visible = false
	root.add_child(fullmap)
	var tr := TextureRect.new()
	tr.texture = map_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_top = 30
	tr.offset_bottom = -30
	fullmap.add_child(tr)
	fullmap_overlay = Control.new()
	fullmap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullmap_overlay.draw.connect(_draw_fullmap_overlay)
	fullmap.add_child(fullmap_overlay)


func _build_intro(root: Control) -> void:
	intro = ColorRect.new()
	(intro as ColorRect).color = Color(0.03, 0.04, 0.03, 0.82)
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(intro)
	var box := VBoxContainer.new()
	_anchor(box, Control.PRESET_CENTER, Vector2(-450, -220), Vector2(900, 440))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_child(box)
	var title := _label("SPIDER HOOD", 96, Color("f2c230"), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var lines := [
		"Bienvenue en ville. Quatre gangs se partagent les rues.",
		"",
		"ZQSD / WASD : bouger · Maj : sprint · Espace : sauter",
		"Pousse contre un mur pour grimper, n'importe lequel",
		"E : accroche un fil, E encore : il se tend et tu peux marcher dessus",
		"M : carte des territoires",
		"Ramasse les 25 pièces cachées dans les 5 quartiers",
		"",
		"Clique ou appuie sur une touche pour jouer",
	]
	for t in lines:
		var l := _label(t, 22, Color.WHITE, 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)


func hide_intro() -> void:
	intro.visible = false


func intro_visible() -> bool:
	return intro.visible


func toggle_map() -> bool:
	fullmap.visible = not fullmap.visible
	fullmap_overlay.queue_redraw()
	return fullmap.visible


func show_zone(zone: String) -> void:
	var z: Dictionary = Layout.ZONES[zone]
	zone_name.text = z["name"]
	zone_tag.text = z["tagline"]
	zone_tag.label_settings.font_color = z["color"].lightened(0.35)
	_banner_t = 4.0


func show_toast(text: String, seconds: float = 2.0) -> void:
	toast.text = text
	_toast_t = seconds


func set_money(v: int) -> void:
	money_label.text = "$%d" % v


func set_silk(v: int) -> void:
	silk_label.text = "Fils tissés : %d" % v


func update_frame(dt: float, p: Node3D, yaw: float, pyaw: float, silk_len: float, max_silk: float) -> void:
	player = p
	cam_yaw = yaw
	player_yaw = pyaw
	var uv := MapImage.to_px(p.global_position.x, p.global_position.z) / MapImage.SIZE
	var sm := radar.material as ShaderMaterial
	sm.set_shader_parameter("player_uv", uv)
	sm.set_shader_parameter("rot", -yaw)
	radar_overlay.queue_redraw()
	_banner_t -= dt
	var a := clampf(_banner_t, 0.0, 1.0)
	zone_name.modulate.a = a
	zone_tag.modulate.a = a
	_toast_t -= dt
	toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	hint.text = ("Fil : %d / %d  —  E pour le tendre" % [silk_len, max_silk]) if silk_len > 0.0 else ""
	if fullmap.visible:
		fullmap_overlay.queue_redraw()


func _arrow(ci: CanvasItem, at: Vector2, angle: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, s * 0.8), Vector2(0, s * 0.4), Vector2(-s * 0.7, s * 0.8)])
	var xf := Transform2D(angle, at)
	pts = xf * pts
	ci.draw_colored_polygon(pts, Color.WHITE)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color.BLACK, 2.0)


## Convertit une direction du monde (x, z) en direction à l'écran du radar.
func _to_screen(dx: float, dz: float) -> Vector2:
	var c := cos(cam_yaw)
	var s := sin(cam_yaw)
	return Vector2(c * dx - s * dz, s * dx + c * dz)


func _draw_radar_overlay() -> void:
	if player == null:
		return
	var R := radar.size.x / 2.0
	var center := Vector2(R, R)
	var scale := radar.size.x / (MapImage.SIZE * 0.16) * MapImage.PX_PER_UNIT
	# pièces encore à ramasser
	for c in coins:
		if not is_instance_valid(c) or c.get_meta("taken", false):
			continue
		var d: Vector3 = c.global_position - player.global_position
		var sp := center + _to_screen(d.x, d.z) * scale
		if sp.distance_to(center) < R - 10:
			radar_overlay.draw_circle(sp, 4.0, Color("7ddc6a"))
			radar_overlay.draw_arc(sp, 4.0, 0, TAU, 12, Color.BLACK, 1.5)
	var face := _to_screen(sin(player_yaw), cos(player_yaw))
	_arrow(radar_overlay, center, atan2(face.x, -face.y), 10)
	var n := _to_screen(0, -1) * (R - 14) + center
	var f := ThemeDB.fallback_font
	radar_overlay.draw_string_outline(f, n + Vector2(-6, 7), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color.BLACK)
	radar_overlay.draw_string(f, n + Vector2(-6, 7), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _draw_fullmap_overlay() -> void:
	if player == null:
		return
	var area := fullmap_overlay.size - Vector2(0, 60)
	var side := minf(area.x, area.y)
	var origin := Vector2((fullmap_overlay.size.x - side) / 2.0, 30 + (area.y - side) / 2.0)
	var to_map := func(p: Vector3) -> Vector2:
		return origin + MapImage.to_px(p.x, p.z) / MapImage.SIZE * side
	var f := ThemeDB.fallback_font
	# noms des quartiers, une fois par quartier, au centre de ses pâtés
	var sums := {}
	for j in 4:
		for i in 4:
			var z: String = Layout.BLOCKS[j][i]
			if not sums.has(z):
				sums[z] = [Vector2.ZERO, 0]
			sums[z][0] += Layout.block_rect(i, j).get_center()
			sums[z][1] += 1
	for z in sums:
		var c: Vector2 = sums[z][0] / sums[z][1]
		var p: Vector2 = to_map.call(Vector3(c.x, 0, c.y))
		var zd: Dictionary = Layout.ZONES[z]
		var title: String = zd["name"]
		fullmap_overlay.draw_string_outline(f, p + Vector2(-170, 0), title, HORIZONTAL_ALIGNMENT_CENTER, 340, 26, 8, Color.BLACK)
		fullmap_overlay.draw_string(f, p + Vector2(-170, 0), title, HORIZONTAL_ALIGNMENT_CENTER, 340, 26, Color.WHITE)
		if zd["gang"] != "":
			fullmap_overlay.draw_string_outline(f, p + Vector2(-170, 24), zd["gang"], HORIZONTAL_ALIGNMENT_CENTER, 340, 18, 6, Color.BLACK)
			fullmap_overlay.draw_string(f, p + Vector2(-170, 24), zd["gang"], HORIZONTAL_ALIGNMENT_CENTER, 340, 18, zd["color"].lightened(0.3))
	for l in landmarks:
		var p: Vector2 = to_map.call(l["pos"])
		fullmap_overlay.draw_circle(p, 5, Color("f2c230"))
		fullmap_overlay.draw_string_outline(f, p + Vector2(-80, 20), l["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, 14, 4, Color.BLACK)
		fullmap_overlay.draw_string(f, p + Vector2(-80, 20), l["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color("ffe9a8"))
	for c in coins:
		if is_instance_valid(c) and not c.get_meta("taken", false):
			fullmap_overlay.draw_circle(to_map.call(c.global_position), 4, Color("7ddc6a"))
	var face := Vector2(sin(player_yaw), cos(player_yaw))
	_arrow(fullmap_overlay, to_map.call(player.global_position), atan2(face.x, -face.y), 12)
	var legend := "M ou Échap pour fermer"
	fullmap_overlay.draw_string(f, Vector2(0, fullmap_overlay.size.y - 10), legend, HORIZONTAL_ALIGNMENT_CENTER, fullmap_overlay.size.x, 16, Color(1, 1, 1, 0.7))
