extends Node3D

var peer := ENetMultiplayerPeer.new()
@export var player_scene: PackedScene

func _ready() -> void:
	# Wire signals once
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ======================
# UI buttons
# ======================
func _on_host_pressed() -> void:
	var err := peer.create_server(1027)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		return
	multiplayer.multiplayer_peer = peer

	# Spawn the host's own player on the server
	_spawn_player(multiplayer.get_unique_id())

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$CanvasLayer.hide()

func _on_join_pressed() -> void:
	var err := peer.create_client("127.0.0.1", 1027)
	if err != OK:
		push_error("Failed to create client: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	# UI will hide after we’re connected in _on_connected_to_server()

# ======================
# Multiplayer events
# ======================
func _on_connected_to_server() -> void:
	# The server will spawn us; the node will replicate down automatically.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$CanvasLayer.hide()

func _on_connection_failed() -> void:
	push_error("Connection failed")

func _on_server_disconnected() -> void:
	push_warning("Disconnected from server")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$CanvasLayer.show()
	# Optional: cleanup all players locally
	for child in get_children():
		if child is Node3D and child.name.is_valid_int():
			child.queue_free()

func _on_peer_connected(id: int) -> void:
	# This signal fires on everyone, but only the server should spawn players.
	if multiplayer.is_server():
		_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	# Only the server should despawn; it will replicate to clients.
	if multiplayer.is_server():
		_despawn_player(id)

# ======================
# Spawn / Despawn
# ======================
func _spawn_player(id: int) -> void:
	var player := player_scene.instantiate()
	player.name = str(id)
	# Give control of this node to that peer. Critical for per-player input & RPC auth.
	player.set_multiplayer_authority(id)
	add_child(player, true)  # 'true' keeps name readable; replication works either way

func _despawn_player(id: int) -> void:
	# Call an RPC so every peer (including server) removes the same node
	rpc("_rpc_despawn_player", id)
	# Also execute locally on server immediately (call_local could do this too)
	_rpc_despawn_player(id)

@rpc("reliable", "call_local")
func _rpc_despawn_player(id: int) -> void:
	var node := get_node_or_null(str(id))
	if node:
		node.queue_free()
