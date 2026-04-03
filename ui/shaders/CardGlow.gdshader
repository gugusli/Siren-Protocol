shader_type canvas_item;

uniform vec4 glow_color : hint_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	vec4 glow = glow_color * glow_intensity * pulse * tex_color.a;
	COLOR = tex_color + glow;
}
