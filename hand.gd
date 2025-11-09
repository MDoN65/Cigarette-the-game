extends Node3D

@export var show_cigarette = false
@onready var cigarette = $Cigarette

func _ready() -> void:
	cigarette.visible = show_cigarette
	# Set multiplayer authority to match the parent player
	var player = get_parent()
	if player and player.has_method("get_multiplayer_authority"):
		set_multiplayer_authority(player.get_multiplayer_authority())

@rpc("authority")
func set_show_cigarette(value: bool) -> void:
	# Runs on the authority (server). Authority updates state and broadcasts to peers.
	show_cigarette = value
	if is_instance_valid(cigarette):
		cigarette.visible = value
	# Only broadcast if we are the authority
	if is_multiplayer_authority():
		rpc("_rpc_update_show_cigarette", value)

@rpc("call_remote")
func _rpc_update_show_cigarette(value: bool) -> void:
	# Runs on clients to apply the authoritative state
	show_cigarette = value
	if is_instance_valid(cigarette):
		cigarette.visible = value
