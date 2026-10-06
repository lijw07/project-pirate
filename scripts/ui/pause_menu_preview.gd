extends Node3D
## Review harness: the original buoyancy scene, plus the reusable pause overlay.

var pause_used := false

func _ready() -> void:
	get_window().title = "Project Pirate — Pause Menu Preview"
	$PauseMenu.pause_started.connect(func(): pause_used = true)
	await get_tree().create_timer(6.0).timeout
	if pause_used:
		return
	var camera := $FreeLookCamera as Camera3D
	var height: float = $FillerShip.position.y
	camera.position = Vector3(16, height + 11, 27)
	camera.fov = 45
	camera.look_at(Vector3(-6, height + 3, 0))
	$PauseMenu.open_pause()
