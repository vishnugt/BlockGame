shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 base_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.01;
uniform vec4 shade_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.4;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float light_intensity = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, NdotL);

	vec3 diffuse = mix(shade_color.rgb, base_color.rgb, light_intensity);

	float rim_dot = 1.0 - dot(NORMAL, VIEW);
	float rim_intensity = rim_dot * pow(NdotL, 0.1);
	rim_intensity = smoothstep(rim_threshold - 0.05, rim_threshold + 0.05, rim_intensity);
	vec3 rim = rim_color.rgb * rim_intensity * rim_amount;

	DIFFUSE_LIGHT += diffuse * ATTENUATION * LIGHT_COLOR + rim;
}
