class_name ShipSails
extends Node

@export var movement: ShipMovement
@export var rig: Node3D
@export var sail_name_prefix := "sail"
@export_range(0.0, 1.0, 0.01) var furled_scale := 0.12
@export_range(0.1, 10.0, 0.1, "suffix:1/s") var furl_speed := 1.5

var _sails: Array[MeshInstance3D] = []
var _rest_transforms: Array[Transform3D] = []
var _unfurled := 0.0


func _ready() -> void:
	for sail in rig.find_children(sail_name_prefix + "*", "MeshInstance3D", true, false):
		_sails.append(sail)
		_rest_transforms.append(sail.transform)
	_unfurled = movement.sail_fraction()
	_apply_furl()


func _process(delta: float) -> void:
	var target := movement.sail_fraction()
	if is_equal_approx(_unfurled, target):
		return
	_unfurled = move_toward(_unfurled, target, furl_speed * delta)
	_apply_furl()


func _apply_furl() -> void:
	var height_scale := lerpf(furled_scale, 1.0, _unfurled)
	for i in _sails.size():
		_sails[i].transform = _furled_transform(_rest_transforms[i], _sails[i].mesh.get_aabb().end.y, height_scale)


func _furled_transform(rest: Transform3D, top: float, height_scale: float) -> Transform3D:
	var lift := rest.basis.y * top * (1.0 - height_scale)
	var squashed := rest.basis * Basis.from_scale(Vector3(1.0, height_scale, 1.0))
	return Transform3D(squashed, rest.origin + lift)
