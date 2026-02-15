shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_width : hint_range(0.0, 0.2) = 0.04;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	// Expand vertices along normals (inverted hull method)
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
