extends CanvasLayer
## Post-traitement plein écran sous l'interface : grain de film animé, vignettage,
## couleurs un peu désaturées et contrastées, teinte chaude et sale.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.0;
uniform float vignette = 0.65;
uniform float contrast = 1.08;
uniform float saturation = 0.8;
uniform vec3 tint = vec3(1.03, 0.97, 0.88);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	vec2 d = SCREEN_UV - 0.5;
	c *= clamp(1.0 - dot(d, d) * vignette * 2.0, 0.0, 1.0);
	// grain : plus visible dans les tons moyens et sombres, comme sur une pellicule
	float n = hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * vec2(17.0, 31.0)) - 0.5;
	c += n * grain * (1.1 - l * 0.6);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""


func _ready() -> void:
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	rect.material = m
	add_child(rect)
