class_name OrbitCamera
extends Camera3D

const TARGET_GROUP := &"camera_targets"

@export var target: Node3D
@export_range(5.0, 500.0, 0.5, "suffix:m") var distance := 55.0
@export_range(5.0, 500.0, 0.5, "suffix:m") var min_distance := 12.0
@export_range(5.0, 1000.0, 0.5, "suffix:m") var max_distance := 260.0
@export_range(-89.0, -5.0, 0.5, "degrees") var pitch_degrees := -32.0
@export var yaw_degrees := 35.0
@export var orbit_sensitivity := 0.25
@export var zoom_factor := 1.12
@export var pan_speed := 40.0
@export var follow_smoothing := 6.0
@export var free_pan_enabled := true

@export_group("Chase")
@export var chase_target_motion := false
@export_range(0.0, 10.0, 0.1, "suffix:s") var chase_delay := 1.5
@export_range(0.1, 10.0, 0.1, "suffix:1/s") var chase_speed := 1.2
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var chase_min_speed := 1.0

var _focus := Vector3.ZERO
var _seconds_since_orbit := INF


func _ready() -> void:
	if target != null:
		_focus = target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_orbit(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		_zoom(event.button_index)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.physical_keycode)


func _process(delta: float) -> void:
	_seconds_since_orbit += delta
	if target != null:
		_focus = _focus.lerp(target.global_position, 1.0 - exp(-follow_smoothing * delta))
		_chase(delta)
	elif free_pan_enabled:
		_focus += _pan_direction() * pan_speed * delta
	var orbit := Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	global_position = _focus + orbit * Vector3(0.0, 0.0, distance)
	look_at(_focus)


func cycle_target() -> void:
	var targets := get_tree().get_nodes_in_group(TARGET_GROUP)
	if targets.is_empty():
		return
	var next_index := (targets.find(target) + 1) % targets.size()
	target = targets[next_index]


func _chase(delta: float) -> void:
	var body := target as RigidBody3D
	if not chase_target_motion or body == null or _seconds_since_orbit < chase_delay:
		return
	var travel := Vector2(body.linear_velocity.x, body.linear_velocity.z)
	if travel.length() < chase_min_speed:
		return
	var behind_yaw := atan2(-travel.x, -travel.y)
	var blend := 1.0 - exp(-chase_speed * delta)
	yaw_degrees = rad_to_deg(lerp_angle(deg_to_rad(yaw_degrees), behind_yaw, blend))


func _orbit(relative: Vector2) -> void:
	_seconds_since_orbit = 0.0
	yaw_degrees -= relative.x * orbit_sensitivity
	pitch_degrees = clampf(pitch_degrees - relative.y * orbit_sensitivity, -89.0, -5.0)


func _zoom(button: MouseButton) -> void:
	if button == MOUSE_BUTTON_WHEEL_UP:
		distance = clampf(distance / zoom_factor, min_distance, max_distance)
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		distance = clampf(distance * zoom_factor, min_distance, max_distance)


func _handle_key(key: Key) -> void:
	if key == KEY_TAB:
		cycle_target()
	elif key == KEY_HOME:
		var overview := get_parent().get_node_or_null("Overview") as Node3D
		if overview != null:
			target = overview
			distance = 465.0
			pitch_degrees = -55.0
			yaw_degrees = 23.0
	elif key == KEY_ESCAPE:
		target = null


func _pan_direction() -> Vector3:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var heading := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	return heading * Vector3(input.x, 0.0, input.y).limit_length(1.0)
