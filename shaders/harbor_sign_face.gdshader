shader_type canvas_item;

void fragment() {
	vec4 art = COLOR;
	// Recolor the painted blue face while preserving the warm frame and skull.
	float painted_face = smoothstep(0.015, 0.055, art.b - art.r)
		* smoothstep(0.005, 0.035, art.b - art.g);
	float shading = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 burgundy = vec3(0.24, 0.095, 0.12) * (0.65 + shading * 1.5);
	art.rgb = mix(art.rgb, burgundy, painted_face);
	COLOR = art;
}
