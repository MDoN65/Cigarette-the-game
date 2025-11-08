extends StaticBody3D

var is_open: bool = false
var busy: bool = false
@export var animation_player: AnimationPlayer

func interact() -> void:
	# throttle spam on the clicking peer
	if busy:
		return
	busy = true

	if multiplayer.is_server():
		# Host toggles directly and announces to all
		_server_apply_toggle()
	else:
		# Non-host asks the server (peer_id 1) to toggle
		rpc_id(1, "request_toggle")

	# optional tiny delay to prevent double taps; re-enabled when animation finishes too
	await get_tree().create_timer(0.1).timeout
	busy = false


# === Client -> Server ===
@rpc("any_peer", "reliable")
func request_toggle() -> void:
	# This runs on the server because the client called rpc_id(1, ...)
	if not multiplayer.is_server():
		return
	_server_apply_toggle()


# === Server logic ===
func _server_apply_toggle() -> void:
	is_open = !is_open
	# Broadcast new state to everyone (host + all clients)
	rpc("apply_state", is_open)


# === Runs on everyone (because server called rpc with call_local) ===
@rpc("reliable", "call_local")
func apply_state(new_state: bool) -> void:
	is_open = new_state
	if is_open:
		print("Opening door")
		animation_player.play("open")
	else:
		print("Closing door")
		animation_player.play("close")

	# Re-enable interaction when the animation is done (adjust if your anims differ)
	await get_tree().create_timer(1.0).timeout
	busy = false
