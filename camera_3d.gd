extends Node3D

@export var hand: Node3D
@export var camera: Node3D
@export var mouth_marker: Node3D
@export var mouth_offset := Vector3(-0.2, -0.2, 0)

@export var raise_speed := 8.0
@export var lower_speed := 6.0
@export var align_rotation := false
@export var rotation_offset_deg := Vector3(0, 0, 0)

var _rest_local: Transform3D
var _is_smoking := false
var _busy := false

func _ready() -> void:
	if hand == null:
		push_error("Assign 'hand'.")
		set_process(false)
		set_physics_process(false)
		return

	_rest_local = hand.transform
	set_process_input(is_multiplayer_authority())

func is_local_player() -> bool:
	return get_multiplayer_authority() == multiplayer.get_unique_id()

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("smoke"):
		_request_smoke(true)
	elif event.is_action_released("smoke"):
		_request_smoke(false)

func _request_smoke(want: bool) -> void:
	# Optional prediction
	_is_smoking = want
	if multiplayer.is_server():
		# Host path: commit immediately and broadcast
		_commit_smoking(want)
	else:
		# Client path: ask server to commit
		rpc_id(1, "server_set_smoking", want)

@rpc("any_peer", "reliable")
func server_set_smoking(want: bool) -> void:
	# Runs on server; only accept from the owning peer
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority():
		return
	_commit_smoking(want)

func _commit_smoking(want: bool) -> void:
	_is_smoking = want
	# Broadcast to everyone, server included
	rpc("apply_smoking_state", want)

@rpc("reliable", "call_local")
func apply_smoking_state(want: bool) -> void:
	_is_smoking = want

func _physics_process(delta: float) -> void:
	if hand == null:
		return

	# Build current rest pose in world
	var parent := hand.get_parent() as Node3D
	var rest_world := parent.global_transform * _rest_local

	# Choose target
	var target_world := rest_world
	if _is_smoking:
		if is_local_player():
			# Local: use camera + offset (camera exists only for owner)
			if camera:
				var cam_xf := camera.global_transform
				var pos := cam_xf * mouth_offset
				var basis := cam_xf.basis
				if align_rotation:
					var rot_off := Basis.from_euler(rotation_offset_deg * deg_to_rad(1.0))
					basis = basis * rot_off
				target_world = Transform3D(basis, pos)
		else:
			# Remote: use a world-space marker on the head
			if mouth_marker:
				var marker_xf := mouth_marker.global_transform
				var basis := marker_xf.basis
				if align_rotation:
					var rot_off := Basis.from_euler(rotation_offset_deg * deg_to_rad(1.0))
					basis = basis * rot_off
				target_world = Transform3D(basis, marker_xf.origin)

	# Slide toward target
	var from := hand.global_transform
	var to := target_world
	var speed := raise_speed if _is_smoking else lower_speed
	var alpha = clamp(delta * speed, 0.0, 1.0)

	var pos := from.origin.lerp(to.origin, alpha)
	var basis := from.basis
	if align_rotation:
		var q_from := Quaternion(from.basis)
		var q_to := Quaternion(to.basis)
		basis = Basis(q_from.slerp(q_to, alpha))

	hand.global_transform = Transform3D(basis, pos)
