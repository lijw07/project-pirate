shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#define MAX_WAVES 8
#define MAX_CALM_ZONES 16
#define MAX_HULL_MASKS 16
#define MAX_WAKE_POINTS 96

const float GRAVITY = 9.81;
const float SKY_DEPTH = 10000.0;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

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

uniform vec4 wake_points[MAX_WAKE_POINTS];
uniform int wake_point_count = 0;

group_uniforms colors;
uniform vec3 shallow_color : source_color = vec3(0.30, 0.76, 0.74);
uniform vec3 deep_color : source_color = vec3(0.04, 0.36, 0.50);
uniform vec3 fresnel_color : source_color = vec3(0.55, 0.80, 0.86);
uniform vec3 foam_color : source_color = vec3(0.94, 0.98, 0.96);
uniform float fresnel_power : hint_range(0.5, 10.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.45;

group_uniforms surface_texture;
uniform sampler2D albedo_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float albedo_luma_mean = 0.352;
uniform float albedo_contrast : hint_range(0.0, 20.0) = 4.5;
uniform float texture_scale : hint_range(1.0, 200.0) = 36.0;
uniform vec2 texture_drift = vec2(0.012, 0.008);
uniform float texture_wobble : hint_range(0.0, 0.2) = 0.05;
uniform float texture_wobble_speed = 0.6;

group_uniforms clarity;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float absorption : hint_range(0.0, 2.0) = 0.35;
uniform float clarity : hint_range(0.0, 1.0) = 0.75;

group_uniforms refraction;
uniform sampler2D refraction_texture : filter_linear_mipmap, repeat_enable;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.03;
uniform float refraction_reference_distance = 40.0;
uniform vec2 refraction_drift = vec2(-0.02, 0.03);

group_uniforms foam;
uniform sampler2D foam_texture : hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform float foam_texture_scale : hint_range(1.0, 200.0) = 18.0;
uniform float foam_line_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float foam_patch_scale = 0.012;
uniform float foam_patch_coverage : hint_range(0.0, 1.0) = 0.58;
uniform vec2 foam_patch_drift = vec2(0.004, -0.003);
uniform float crest_foam_stretch : hint_range(0.0, 1.0) = 0.8;
uniform float crest_foam_softness : hint_range(0.01, 1.0) = 0.15;
uniform float shore_foam_reach : hint_range(0.0, 20.0) = 4.0;
uniform float shore_edge_width : hint_range(0.0, 5.0) = 0.4;

group_uniforms distance_fade;
uniform float detail_fade_start = 150.0;
uniform float detail_fade_end = 700.0;

group_uniforms ship_wake;
uniform float wake_lifetime = 7.0;
uniform float wake_spread_ratio : hint_range(0.0, 1.0) = 0.33;
uniform float wake_half_width = 1.8;
uniform float wake_arm_width = 0.8;
uniform float wake_reference_speed = 12.0;
uniform float wake_trail_strength : hint_range(0.0, 1.0) = 0.7;
uniform float wake_ripple_height = 0.12;
uniform float wake_ripple_wavelength = 2.4;
uniform float hull_foam_width = 1.6;
uniform float hull_foam_idle : hint_range(0.0, 1.0) = 0.15;

group_uniforms lighting;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float water_specular : hint_range(0.0, 1.0) = 0.35;

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

float hull_ellipse_distance(int index, vec2 point) {
	vec4 frame = hull_mask_frames[index];
	vec2 relative = point - frame.xy;
	vec2 local = vec2(dot(relative, vec2(frame.w, -frame.z)), dot(relative, frame.zw));
	return length(local / hull_mask_sizes[index].xy);
}

bool inside_hull(vec2 point) {
	for (int i = 0; i < MAX_HULL_MASKS; i++) {
		if (i >= hull_mask_count) {
			break;
		}
		if (hull_ellipse_distance(i, point) < 1.0) {
			return true;
		}
	}
	return false;
}

float hull_foam(vec2 point) {
	float foam = 0.0;
	for (int i = 0; i < MAX_HULL_MASKS; i++) {
		if (i >= hull_mask_count) {
			break;
		}
		vec4 size = hull_mask_sizes[i];
		float band_end = 1.0 + hull_foam_width / min(size.x, size.y);
		float edge = 1.0 - smoothstep(1.0, band_end, hull_ellipse_distance(i, point));
		float strength = mix(hull_foam_idle, 1.0, clamp(size.z / wake_reference_speed, 0.0, 1.0));
		foam = max(foam, edge * strength);
	}
	return foam;
}

struct WakeHit {
	float distance_squared;
	vec2 away;
	float birth;
	float speed;
};

WakeHit no_wake_hit() {
	return WakeHit(-1.0, vec2(0.0), 0.0, 0.0);
}

WakeHit nearer_wake_hit(WakeHit nearest, vec2 point, vec4 head, vec4 tail) {
	vec2 segment = tail.xy - head.xy;
	float length_squared = max(dot(segment, segment), 0.0001);
	float along = clamp(dot(point - head.xy, segment) / length_squared, 0.0, 1.0);
	vec2 away = point - (head.xy + segment * along);
	float distance_squared = dot(away, away);
	if (nearest.distance_squared >= 0.0 && distance_squared >= nearest.distance_squared) {
		return nearest;
	}
	return WakeHit(distance_squared, away, mix(head.z, tail.z, along), mix(head.w, tail.w, along));
}

void apply_wake_hit(WakeHit hit, inout float arm_foam, inout float trail_foam, inout float ripple, inout vec2 ripple_slope, inout float ripple_envelope) {
	if (hit.distance_squared < 0.0) {
		return;
	}
	float age = max(wave_time - hit.birth, 0.0);
	float life = 1.0 - age / wake_lifetime;
	if (life <= 0.0) {
		return;
	}
	float distance_to_path = sqrt(hit.distance_squared);
	float strength = clamp(hit.speed / wake_reference_speed, 0.0, 1.0) * life;
	float arm_offset = wake_half_width + hit.speed * wake_spread_ratio * age;
	float arm_width = wake_arm_width * (1.0 + age * 0.35);
	float from_arm = distance_to_path - arm_offset;
	arm_foam = max(arm_foam, (1.0 - smoothstep(0.0, arm_width, abs(from_arm))) * strength * life);
	float trail_width = wake_half_width * (1.0 + age * 0.3);
	trail_foam = max(trail_foam, (1.0 - smoothstep(0.0, trail_width, distance_to_path)) * strength * wake_trail_strength);
	float envelope = exp(-from_arm * from_arm / (arm_width * arm_width * 6.0)) * strength * wake_ripple_height;
	if (envelope <= ripple_envelope) {
		return;
	}
	ripple_envelope = envelope;
	float phase = TAU * from_arm / wake_ripple_wavelength;
	vec2 outward = distance_to_path > 0.001 ? hit.away / distance_to_path : vec2(0.0);
	ripple = cos(phase) * envelope;
	ripple_slope = -sin(phase) * TAU / wake_ripple_wavelength * envelope * outward;
}

void sample_wake(vec2 point, out float arm_foam, out float trail_foam, out float ripple, out vec2 ripple_slope) {
	arm_foam = 0.0;
	trail_foam = 0.0;
	ripple = 0.0;
	ripple_slope = vec2(0.0);
	float ripple_envelope = 0.0;
	WakeHit nearest = no_wake_hit();
	for (int i = 0; i < MAX_WAKE_POINTS - 1; i++) {
		if (i + 1 >= wake_point_count) {
			break;
		}
		vec4 head = wake_points[i];
		vec4 tail = wake_points[i + 1];
		if (head.w < 0.0) {
			apply_wake_hit(nearest, arm_foam, trail_foam, ripple, ripple_slope, ripple_envelope);
			nearest = no_wake_hit();
		} else if (tail.w >= 0.0) {
			nearest = nearer_wake_hit(nearest, point, head, tail);
		}
	}
	apply_wake_hit(nearest, arm_foam, trail_foam, ripple, ripple_slope, ripple_envelope);
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

vec2 surface_uv(vec2 world_xz, float scale, vec2 drift) {
	vec2 uv = world_xz / scale;
	vec2 wobble = vec2(sin(uv.y * TAU * 0.9 + wave_time * texture_wobble_speed), sin(uv.x * TAU * 0.6 + wave_time * texture_wobble_speed * 0.5));
	return uv + wobble * texture_wobble + drift * wave_time;
}

float scene_world_height(vec2 screen_uv, mat4 inv_projection, mat4 inv_view) {
	float raw_depth = textureLod(depth_texture, screen_uv, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	bool is_sky = raw_depth >= 1.0;
	vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
#else
	bool is_sky = raw_depth <= 0.0;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
#endif
	if (is_sky) {
		return -SKY_DEPTH;
	}
	vec4 view_position = inv_projection * vec4(ndc, 1.0);
	view_position.xyz /= view_position.w;
	return (inv_view * vec4(view_position.xyz, 1.0)).y;
}

vec2 refracted_screen_uv(vec2 screen_uv, float camera_distance) {
	vec2 uv = surface_uv(surface_world.xz, texture_scale * 0.5, refraction_drift);
	vec2 distortion = texture(refraction_texture, uv).rg - 0.5;
	float falloff = clamp(refraction_reference_distance / max(camera_distance, 0.001), 0.0, 1.0);
	return screen_uv + distortion * refraction_strength * falloff;
}

float foam_lines(vec2 world_xz) {
	float alpha = texture(foam_texture, surface_uv(world_xz, foam_texture_scale, texture_drift)).a;
	return smoothstep(foam_line_threshold - 0.1, foam_line_threshold + 0.1, alpha);
}

float foam_patches(vec2 world_xz) {
	float field = fbm(world_xz * foam_patch_scale + foam_patch_drift * wave_time);
	return smoothstep(foam_patch_coverage, foam_patch_coverage + 0.12, field);
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
	float wake_arms;
	float wake_trail;
	float wake_ripple;
	vec2 wake_slope;
	sample_wake(grid_world.xz, wake_arms, wake_trail, wake_ripple, wake_slope);
	offset.y += wake_ripple;
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
	float camera_distance = distance(CAMERA_POSITION_WORLD, surface_world);
	float detail = 1.0 - smoothstep(detail_fade_start, detail_fade_end, camera_distance);

	vec2 screen_uv = refracted_screen_uv(SCREEN_UV, camera_distance);
	float floor_height = scene_world_height(screen_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (floor_height > surface_world.y) {
		screen_uv = SCREEN_UV;
		floor_height = scene_world_height(screen_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	}
	float water_depth = max(surface_world.y - floor_height, 0.0);
	float opacity = 1.0 - exp(-water_depth * absorption);

	vec3 color = mix(shallow_color, deep_color, opacity);
	float albedo_luma = dot(texture(albedo_texture, surface_uv(surface_world.xz, texture_scale, texture_drift)).rgb, LUMA);
	color *= 1.0 + (albedo_luma - albedo_luma_mean) * albedo_contrast * detail;
	color = mix(color, shallow_color, clamp(crest_height, 0.0, 1.0) * 0.2);
	float wake_arms;
	float wake_trail;
	float wake_ripple;
	vec2 wake_slope;
	sample_wake(surface_world.xz, wake_arms, wake_trail, wake_ripple, wake_slope);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(-wake_slope.x, 0.0, -wake_slope.y, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	color = mix(color, fresnel_color, fresnel * fresnel_strength);

	float transmission = (1.0 - opacity) * clarity * (1.0 - fresnel);
	vec3 seen_below = textureLod(screen_texture, screen_uv, opacity * 3.0).rgb * shallow_color;

	float lines = foam_lines(surface_world.xz);
	float crest_mask = smoothstep(0.0, crest_foam_softness, crest_foam_stretch - surface_stretch);
	float open_sea_foam = max(crest_mask, foam_patches(surface_world.xz)) * lines * detail;
	float shore_reach = 1.0 - smoothstep(0.0, shore_foam_reach, water_depth);
	float shore_edge = 1.0 - smoothstep(0.0, shore_edge_width, water_depth);
	float shore_foam = max(shore_edge, shore_reach * lines);
	float wake_foam = max(wake_arms * mix(0.55, 1.0, lines), wake_trail * mix(0.3, 1.0, lines));
	float ship_foam = max(wake_foam, hull_foam(surface_world.xz) * mix(0.6, 1.0, lines));
	float foam = clamp(max(max(open_sea_foam, shore_foam), ship_foam), 0.0, 1.0);

	float surface_weight = (1.0 - transmission) * (1.0 - foam);
	ALBEDO = color * surface_weight + foam_color * foam;
	EMISSION = seen_below * transmission * (1.0 - foam);
	ALPHA = 1.0;
	ROUGHNESS = mix(water_roughness, 0.9, foam);
	SPECULAR = water_specular * (1.0 - foam);
	METALLIC = 0.0;
}
