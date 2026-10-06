// Ribbon V: world-space history follows the displaced ocean surface.
uniform int wake_count = 0;
uniform vec4 wake_points[32]; // x, z, emission time, speed strength
uniform float wake_time = 0.0;
uniform vec4 wake_bounds = vec4(0.0);
uniform vec4 wake_hull = vec4(0.0, 0.0, 0.0, 1.0);
varying vec2 wake_world;

vec2 ribbon_wake(vec2 position) {
	if (wake_count < 2 || position.x < wake_bounds.x || position.y < wake_bounds.y || position.x > wake_bounds.z || position.y > wake_bounds.w) {
		return vec2(0.0);
	}
	vec2 relative_to_hull = position - wake_hull.xy;
	float hull_along = dot(relative_to_hull, wake_hull.zw);
	float hull_across = abs(dot(relative_to_hull, vec2(wake_hull.w, -wake_hull.z)));
	float hull_half_width = 1.7 * (1.0 - smoothstep(1.0, 4.3, hull_along));
	if (hull_along > -3.3 && hull_along < 4.3 && hull_across < hull_half_width) {
		return vec2(0.0);
	}
	float nearest = 10000.0;
	float age = 0.0;
	float strength = 0.0;
	float path_length = 0.0;
	float behind_bow = 0.0;
	for (int i = 0; i < 31; i++) {
		if (i >= wake_count - 1) { break; }
		vec4 a = wake_points[i];
		vec4 b = wake_points[i + 1];
		vec2 segment = b.xy - a.xy;
		float length_squared = dot(segment, segment);
		if (length_squared < 0.0001) { continue; }
		float along = clamp(dot(position - a.xy, segment) / length_squared, 0.0, 1.0);
		float segment_length = sqrt(length_squared);
		float distance_to_path = distance(position, mix(a.xy, b.xy, along));
		if (distance_to_path < nearest) {
			nearest = distance_to_path;
			age = wake_time - mix(a.z, b.z, along);
			strength = mix(a.w, b.w, along);
			behind_bow = path_length + along * segment_length;
		}
		path_length += segment_length;
	}
	float fade = (1.0 - smoothstep(2.7 * 0.42, 2.7, age)) * strength;
	// Open from a point at the bow to the hull shoulders, then spread aft.
	// Distance keeps the V angle steady when the ship's speed changes on swells.
	float width = 1.8 * smoothstep(0.0, 3.5, behind_bow) + behind_bow * 0.1;
	float edge = abs(nearest - width);
	float foam = (1.0 - smoothstep(0.16, 0.55, edge)) * 0.93;
	foam = max(foam, (1.0 - smoothstep(0.10, 0.34, abs(nearest - width * 0.68))) * 0.22);
	float tint = (1.0 - smoothstep(0.0, width, nearest)) * 0.18;
	return vec2(foam, tint) * fade;
}
