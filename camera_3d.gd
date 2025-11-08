extends Node3D

@export var hand: Node3D          # your HandRig (world object, not parented to camera)
@export var camera: Node3D        # your Camera3D (or head node)
@export var mouth_offset := Vector3(0.08, -0.06, -0.22)
# offset is in CAMERA LOCAL SPACE: +X right, +Y up, -Z forward

@export var raise_speed := 8.0    # slide speed toward mouth while held
@export var lower_speed := 6.0    # slide speed back to rest on release
@export var align_rotation := false
@export var rotation_offset_deg := Vector3(0, 0, 0)  # only used if align_rotation = true

var _rest_local: Transform3D
var _is_smoking := false

func _ready():
	if hand == null or camera == null:
		push_error("Assign 'hand' and 'camera' exports.")
		set_process(false)
		set_physics_process(false)
		return
	# Save the hand's LOCAL pose so rest follows the player's movement
	_rest_local = hand.transform

func _input(event):
	if event.is_action_pressed("smoke"):
		_is_smoking = true
	elif event.is_action_released("smoke"):
		_is_smoking = false

func _physics_process(delta):
	if hand == null or camera == null:
		return

	# Build the current REST world transform from parent + saved local
	var parent := hand.get_parent() as Node3D
	var rest_world := parent.global_transform * _rest_local

	# Build the current MOUTH world transform from camera + offset (no marker)
	var cam_xf := camera.global_transform
	var mouth_pos := cam_xf * mouth_offset  # transform local offset point to world
	var mouth_basis := cam_xf.basis
	if align_rotation:
		var rot_off := Basis.from_euler(rotation_offset_deg * deg_to_rad(1.0))
		mouth_basis = mouth_basis * rot_off

	var mouth_world := Transform3D(mouth_basis, mouth_pos)

	# Pick target and speed
	var target = mouth_world if _is_smoking else rest_world
	var speed = raise_speed if _is_smoking else lower_speed



	# Blend position (slide) and, optionally, rotation
	var from := hand.global_transform
	var to = target
	var alpha = clamp(delta * speed, 0.0, 1.0)

	# position-only slide feels “gamey”—keep rotation unless align_rotation is true
	var pos := from.origin.lerp(to.origin, alpha)

	var basis := from.basis
	if align_rotation:
		var q_from := Quaternion(from.basis)
		var q_to :=   Quaternion(to.basis)
		var q := q_from.slerp(q_to, alpha)
		basis = Basis(q)

	hand.global_transform = Transform3D(basis, pos)
