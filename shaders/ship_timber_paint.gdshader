shader_type spatial;
render_mode cull_disabled;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec4 paint : source_color = vec4(1.0);
void fragment() {
	vec3 timber = texture(palette, UV).rgb;
	float shade = clamp(dot(timber, vec3(0.2126, 0.7152, 0.0722)) / 0.32, 0.48, 1.30);
	ALBEDO = paint.rgb * shade;
	ROUGHNESS = 0.9;
}
