extends RigidBody3D

signal state_changed(is_held: bool, holder_peer_id: int)

enum State { ON_TABLE, HELD }

@export var interact_range := 2.0    # optional helper if you do distance checks from player
var state: int = State.ON_TABLE
var holder_peer_id: int = 0

func _ready() -> void:
	# Keep server as authority, clients only request changes.
	if multiplayer.is_server():
		set_multiplayer_authority(multiplayer.get_unique_id())
	_set_world_active(true)

# ---- Client requests (server decides) ----
@rpc("any_peer")
func req_pickup(requestor_peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if state == State.ON_TABLE:
		state = State.HELD
		holder_peer_id = requestor_peer_id
		# Tell everyone who now holds the cig and to hide it in world
		rpc("do_set_held", holder_peer_id)

@rpc("any_peer")
func req_drop(requestor_peer_id: int, drop_transform: Transform3D) -> void:
	if not multiplayer.is_server(): return
	if state == State.HELD and requestor_peer_id == holder_peer_id:
		state = State.ON_TABLE
		holder_peer_id = 0
		# Tell everyone to show the world cig back at this transform
		rpc("do_set_on_table", drop_transform)

# ---- Replicated state changes (run on all) ----
@rpc("authority", "call_local")
func do_set_held(new_holder_peer_id: int) -> void:
	holder_peer_id = new_holder_peer_id
	_set_world_active(false)                 # hide/disconnect physics in the world
	emit_signal("state_changed", true, holder_peer_id)

@rpc("authority", "call_local")
func do_set_on_table(world_xform: Transform3D) -> void:
	holder_peer_id = 0
	global_transform = world_xform
	_set_world_active(true)                  # show/enable physics in the world
	emit_signal("state_changed", false, 0)

# ---- Helpers ----
func _set_world_active(active: bool) -> void:
	visible = active
	if self is RigidBody3D:
		freeze = not active
		if active:
			sleeping = false
			gravity_scale = 1.0
			# Reset collision layers to default when active
			collision_layer = 1
			collision_mask = 1
		else:
			gravity_scale = 0.0
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
