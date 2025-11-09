extends Node3D

@export var show_cigarette = false
@onready var cigarette = $Cigarette

func _ready() -> void:
	cigarette.visible = show_cigarette

@rpc("authority")
func set_show_cigarette(value: bool) -> void:
	# Runs on the authority (server). Authority updates state and broadcasts to peers.
	show_cigarette = value
	if is_instance_valid(cigarette):
		cigarette.visible = value
	# Broadcast the new value to all remote peers
	rpc("_rpc_update_show_cigarette", value)

@rpc("call_remote")
func _rpc_update_show_cigarette(value: bool) -> void:
	# Runs on clients to apply the authoritative state
	show_cigarette = value
	if is_instance_valid(cigarette):
		cigarette.visible = value
