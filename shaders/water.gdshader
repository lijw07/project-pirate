shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, world_vertex_coords;

#define MAX_WAVES 8
#include "res://shaders/ship_wake.gdshaderinc"

global uniform float ocean_time;
global uniform vec3 ocean_focus;

group_uniforms Colors;
uniform vec3 trough_color : source_color = vec3(0.12, 0.44, 0.75);
uniform vec3 swell_color : source_color = vec3(0.2, 0.6, 0.855);
uniform vec3 crest_color : source_color = vec3(0.36, 0.71, 0.92);
uniform vec3 pattern_color : source_color = vec3(0.75, 0.9, 0.98);
uniform vec3 shallow_color : source_color = vec3(0.518, 0.757, 0.914);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.62, 0.88);
group_uniforms;

group_uniforms HeightBands;
uniform float trough_band = -0.5;
uniform float crest_band = 0.6;
uniform float color_band_softness : hint_range(0.0, 0.5) = 0.08;
group_uniforms;

group_uniforms SurfacePattern;
uniform float pattern_density = 0.7;
uniform float pattern_threshold : hint_range(0.0, 1.0) = 0.94;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

group_uniforms ToonLighting;
uniform float light_band : hint_range(-1.0, 1.0) = 0.15;
uniform float band_softness : hint_range(0.0, 0.5) = 0.05;
group_uniforms;

group_uniforms Whitecaps;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform float foam_noise_scale = 18.0;
uniform float foam_edge_softness : hint_range(0.0, 0.2) = 0.03;
uniform float whitecap_strength = 1.0;
uniform float wave_height_sigma = 1.0;
uniform float whitecap_start_sigma = 1.0;
uniform float whitecap_full_sigma = 1.8;
group_uniforms;

group_uniforms Shore;
uniform float shore_foam_depth = 1.2;
uniform float shallow_depth = 5.0;
group_uniforms;

group_uniforms Fade;
uniform float vertex_wave_fade_min;
uniform float vertex_wave_fade_max;
uniform float foam_fade_min;
uniform float foam_fade_max;
group_uniforms;

group_uniforms WaveParameters;
uniform int WaveCount : hint_range(0, 8) = 0;
uniform float WaveSteepnesses[MAX_WAVES];
uniform float WaveAmplitudes[MAX_WAVES];
uniform float WaveDirectionsDegrees[MAX_WAVES];
uniform float WaveFrequencies[MAX_WAVES];
uniform float WaveSpeeds[MAX_WAVES];
uniform float WavePhases[MAX_WAVES];
group_uniforms;

group_uniforms UVWaveParameters;
uniform int UVWaveCount : hint_range(0, 8) = 0;
uniform float UVWaveSteepnesses[MAX_WAVES];
uniform float UVWaveAmplitudes[MAX_WAVES];
uniform float UVWaveDirectionsDegrees[MAX_WAVES];
uniform float UVWaveFrequencies[MAX_WAVES];
uniform float UVWaveSpeeds[MAX_WAVES];
uniform float UVWavePhases[MAX_WAVES];
group_uniforms;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying float height_ratio;
varying float foam_fade;
varying vec2 foam_uv;

vec2 wave_direction(float degrees) {
	return vec2(sin(radians(degrees)), cos(radians(degrees)));
}

float wave_angle(vec2 position, float t, float frequency, vec2 direction, float speed, float phase_degrees) {
	return TAU * frequency * dot(direction, position) + speed * (t + radians(phase_degrees));
}

vec3 gerstner_offset(vec2 position, float t, float steepness, float amplitude, float direction_degrees, float frequency, float speed, float phase_degrees) {
	vec2 direction = wave_direction(direction_degrees);
	float angle = wave_angle(position, t, frequency, direction, speed, phase_degrees);
	float horizontal = steepness * amplitude * cos(angle);
	return vec3(horizontal * direction.x, steepness * sin(angle), horizontal * direction.y);
}

void add_gerstner_tangents(inout vec3 tangent_x, inout vec3 tangent_z, vec2 position, float t, float steepness, float amplitude, float direction_degrees, float frequency, float speed, float phase_degrees, float weight) {
	vec2 direction = wave_direction(direction_degrees);
	float angle = wave_angle(position, t, frequency, direction, speed, phase_degrees);
	float slope = TAU * frequency * steepness * weight;
	float lean = amplitude * sin(angle);
	tangent_x += slope * vec3(-lean * direction.x * direction.x, direction.x * cos(angle), -lean * direction.x * direction.y);
	tangent_z += slope * vec3(-lean * direction.x * direction.y, direction.y * cos(angle), -lean * direction.y * direction.y);
}

vec2 warped_foam_uv(vec2 rest_position) {
	vec2 uv = rest_position / foam_noise_scale;
	vec2 warp = vec2(0.0);
	for (int i = 0; i < UVWaveCount; i++) {
		warp += gerstner_offset(uv, ocean_time, UVWaveSteepnesses[i], UVWaveAmplitudes[i], UVWaveDirectionsDegrees[i], UVWaveFrequencies[i], UVWaveSpeeds[i], UVWavePhases[i]).xz;
	}
	return uv + warp;
}

void vertex() {
	vec2 rest_position = VERTEX.xz;
	float focus_distance = distance(rest_position, ocean_focus.xz);
	float wave_fade = smoothstep(vertex_wave_fade_max, vertex_wave_fade_min, focus_distance);
	vec3 offset = vec3(0.0);
	vec3 tangent_x = vec3(1.0, 0.0, 0.0);
	vec3 tangent_z = vec3(0.0, 0.0, 1.0);
	float weight = 1.0 / float(max(WaveCount, 1));
	for (int i = 0; i < WaveCount; i++) {
		offset += weight * gerstner_offset(rest_position, ocean_time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
		add_gerstner_tangents(tangent_x, tangent_z, rest_position, ocean_time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i], weight);
	}
	offset *= wave_fade;
	VERTEX += offset;
	wake_world = VERTEX.xz;
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(cross(tangent_z, tangent_x)), wave_fade));
	height_ratio = offset.y / wave_height_sigma;
	foam_fade = smoothstep(foam_fade_max, foam_fade_min, focus_distance);
	foam_uv = warped_foam_uv(rest_position);
}

float depth_below_surface(vec2 screen_uv, mat4 inv_projection_matrix, vec3 view_vertex) {
	float raw_depth = textureLod(depth_texture, screen_uv, 0.0).r;
	vec4 view = inv_projection_matrix * vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0);
	return -view.z / view.w + view_vertex.z;
}

float crisp(float edge, float value) {
	return smoothstep(edge - foam_edge_softness, edge + foam_edge_softness, value);
}

float height_band(float edge) {
	return smoothstep(edge - color_band_softness, edge + color_band_softness, height_ratio);
}

vec3 banded_water() {
	vec3 water = mix(trough_color, swell_color, height_band(trough_band));
	return mix(water, crest_color, height_band(crest_band));
}

float surface_pattern() {
	float pattern = texture(foam_noise, foam_uv * pattern_density + vec2(0.37, 0.61)).a;
	return pattern_strength * foam_fade * crisp(pattern_threshold, pattern);
}

void fragment() {
	float noise = texture(foam_noise, foam_uv).a;
	float depth = depth_below_surface(SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX);

	vec3 water = mix(banded_water(), pattern_color, surface_pattern());
	water = mix(water, shallow_color, crisp(0.5, 1.0 - depth / shallow_depth));

	float crest = whitecap_strength * foam_fade * smoothstep(whitecap_start_sigma, whitecap_full_sigma, height_ratio);
	float shore = 1.0 - clamp(depth / shore_foam_depth, 0.0, 1.0);
	float foam = max(crisp(1.0 + foam_edge_softness - crest, noise), crisp(1.0 + foam_edge_softness - shore, noise));

	vec2 wake = ribbon_wake(wake_world);
	water = mix(water, vec3(0.48, 0.79, 0.90), wake.y);
	ALBEDO = mix(water, foam_color, max(foam, wake.x));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	ALPHA = 1.0;
}

void light() {
	float lit = smoothstep(light_band - band_softness, light_band + band_softness, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR * ATTENUATION / PI;
}
