shader_type canvas_item;

uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// 1. Obtenemos el color de la textura (el cuadrado morado/blanco)
	vec4 tex_color = texture(TEXTURE, UV);

	// 2. Mezclamos el color de la textura con el color del Flash
	// Usamos tex_color.rgb * COLOR.rgb para que el MODULATE (rojo) funcione
	vec3 final_color = mix(tex_color.rgb * COLOR.rgb, flash_color.rgb, flash_modifier);

	// 3. Aplicamos el resultado manteniendo la transparencia original
	COLOR = vec4(final_color, tex_color.a * COLOR.a);
}