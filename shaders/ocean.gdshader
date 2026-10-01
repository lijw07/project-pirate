shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

#define MAX_WAVES 8
#define MAX_CALM_ZONES 16
#define MAX_HULL_MASKS 16

const float GRAVITY = 9.81;
const float SKY_DEPTH = 10000.0;

uniform vec4 waves[MAX_WAVES];
uniform int wave_count = 0;
uniform float wave_amplitude = 1.0;
instance uniform float wave_time = 0.0;

uniform vec4 calm_zones[MAX_CALM_ZONES];
uniform int calm_zone_count = 0;
uniform float calm_residual = 0.15;

uniform vec4 hull_mask_frames[MAX_HULL_MASKS];
uniform vec4 hull_mask_sizes[MAX_HULL_MASKS];
uniform int hull_mask_count = 0;

group_uniforms colors;
uniform vec3 shallow_color : source_color = vec3(0.30, 0.76, 0.74);
uniform vec3 deep_color : source_color = vec3(0.04, 0.36, 0.50);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.80, 0.86);
uniform vec3 foam_color : source_color = vec3(0.94, 0.98, 0.96);
uniform float depth_fade_distance : hint_range(0.1, 50.0) = 7.0;
uniform float shallow_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float horizon_blend : hint_range(0.0, 1.0) = 0.3;

group_uniforms surface_pattern;
uniform float pattern_scale = 0.03;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 pattern_drift = vec2(0.015, 0.008);

group_uniforms crest_foam;
uniform float crest_foam_stretch : hint_range(0.0, 1.0) = 0.78;
uniform float crest_foam_softness : hint_range(0.01, 1.0) = 0.12;
uniform float crest_foam_scale = 0.6;

group_uniforms shore_foam;
uniform float shore_edge_width : hint_range(0.0, 5.0) = 0.5;
uniform float shore_band_spacing : hint_range(0.1, 10.0) = 1.4;
uniform float shore_band_width : hint_range(0.01, 0.9) = 0.16;
uniform float shore_band_reach : hint_range(0.0, 30.0) = 4.5;
uniform float shore_band_speed = 0.3;

group_uniforms lighting;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float water_specular : hint_range(0.0, 1.0) = 0.3;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 surface_world;
varying float crest_height;
varying float surface_stretch;

vec3 gerstner(vec4 wave, vec2 point, float time, inout vec3 tangent, inout vec3 binormal) {
	float k = TAU / wave.w;
	float speed = sqrt(GRAVITY / k);
	vec2 heading = wave.xy;
	float phase = k * (dot(heading, point) - speed * time);
	float steepness = wave.z;
	float amplitude = steepness / k;
	float s = sin(phase);
	float c = cos(phase);
	tangent += vec3(-heading.x * heading.x * steepness * s, heading.x * steepness * c, -heading.x * heading.y * steepness * s);
	binormal += vec3(-heading.x * heading.y * steepness * s, heading.y * steepness * c, -heading.y * heading.y * steepness * s);
	return vec3(heading.x * amplitude * c, amplitude * s, heading.y * amplitude * c);
}

float wave_scale_at(vec2 point) {
	float scale = 1.0;
	for (int i = 0; i < MAX_CALM_ZONES; i++) {
		if (i >= calm_zone_count) {
			break;
		}
		vec4 zone = calm_zones[i];
		float blend = smoothstep(zone.z, zone.w, distance(point, zone.xy));
		scale = min(scale, mix(calm_residual, 1.0, blend));
	}
	return scale;
}

bool inside_hull(vec2 point) {
	for (int i = 0; i < MAX_HULL_MASKS; i++) {
		if (i >= hull_mask_count) {
			break;
		}
		vec4 frame = hull_mask_frames[i];
		vec2 relative = point - frame.xy;
		vec2 local = vec2(dot(relative, vec2(frame.w, -frame.z)), dot(relative, frame.zw));
		vec2 normalized = local / hull_mask_sizes[i].xy;
		if (dot(normalized, normalized) < 1.0) {
			return true;
		}
	}
	return false;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float bottom = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += weight * value_noise(p);
		p *= 2.03;
		weight *= 0.5;
	}
	return total;
}

float scene_world_height(vec2 screen_uv, mat4 inv_projection, mat4 inv_view) {
	float raw_depth = texture(depth_texture, screen_uv).r;
	if (raw_depth <= 0.0) {
		return -SKY_DEPTH;
	}
	vec4 view_position = inv_projection * vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0);
	view_position.xyz /= view_position.w;
	return (inv_view * vec4(view_position.xyz, 1.0)).y;
}

float shore_bands(float water_depth, float noise) {
	float band_coord = water_depth / shore_band_spacing + wave_time * shore_band_speed + noise;
	float line = fract(band_coord);
	float mask = smoothstep(0.0, 0.04, line) * (1.0 - smoothstep(shore_band_width, shore_band_width + 0.04, line));
	return mask * (1.0 - smoothstep(0.0, shore_band_reach, water_depth));
}

void vertex() {
	vec3 grid_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent_slope = vec3(0.0);
	vec3 binormal_slope = vec3(0.0);
	vec3 offset = vec3(0.0);
	for (int i = 0; i < MAX_WAVES; i++) {
		if (i >= wave_count) {
			break;
		}
		offset += gerstner(waves[i], grid_world.xz, wave_time, tangent_slope, binormal_slope);
	}
	float scale = wave_scale_at(grid_world.xz);
	offset *= scale;
	vec3 tangent = vec3(1.0, 0.0, 0.0) + tangent_slope * scale;
	vec3 binormal = vec3(0.0, 0.0, 1.0) + binormal_slope * scale;
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	TANGENT = normalize(tangent);
	BINORMAL = normalize(binormal);
	surface_world = grid_world + offset;
	surface_stretch = tangent.x * binormal.z - tangent.z * binormal.x;
	crest_height = offset.y / max(wave_amplitude, 0.001);
}

void fragment() {
	if (inside_hull(surface_world.xz)) {
		discard;
	}
	float floor_height = scene_world_height(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float water_depth = max(surface_world.y - floor_height, 0.0);
	float depth_blend = smoothstep(0.0, 1.0, clamp(water_depth / depth_fade_distance, 0.0, 1.0));

	vec3 color = mix(shallow_color, deep_color, depth_blend);
	float pattern = fbm(surface_world.xz * pattern_scale + pattern_drift * wave_time);
	color = mix(color, deep_color * 0.82, smoothstep(0.5, 0.78, pattern) * pattern_strength);
	color = mix(color, shallow_color, clamp(crest_height, 0.0, 1.0) * 0.25);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	color = mix(color, horizon_color, fresnel * horizon_blend);

	float foam_noise = fbm(surface_world.xz * crest_foam_scale + vec2(wave_time * 0.05));
	float crest_mask = smoothstep(0.0, crest_foam_softness, crest_foam_stretch - surface_stretch);
	float crest_foam = crest_mask * smoothstep(0.42, 0.58, foam_noise);
	float shore_edge = 1.0 - smoothstep(0.0, shore_edge_width, water_depth);
	float shore_foam = max(shore_edge, shore_bands(water_depth, foam_noise * 0.6));
	float foam = clamp(max(shore_foam, crest_foam), 0.0, 1.0);

	ALBEDO = mix(color, foam_color, foam);
	ALPHA = max(mix(shallow_alpha, 1.0, depth_blend), foam);
	ROUGHNESS = mix(water_roughness, 0.9, foam);
	SPECULAR = water_specular;
	METALLIC = 0.0;
}
