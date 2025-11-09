extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var accel: float = 20.0
@export var air_control: float = 2.0
@export var mouse_sens: float = 0.12
@export var jump_velocity: float = 4.5

@export var drop_forward := 1.2
@export var drop_height := 0.3
var world_cig: Node = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var yaw := 0.0   # left/right (Player)
var pitch := 0.0 # up/down (Head)

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D

@onready var stress := $Stress
@onready var stress_bar := $CanvasLayer/MarginContainer/StressBar

func _ready() -> void:
	cam.current = is_multiplayer_authority()
	
	# Only show UI for local player
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.visible = is_multiplayer_authority()
	
	if stress_bar:
		stress_bar.visible = is_multiplayer_authority()
		
	world_cig = get_tree().get_first_node_in_group("SharedCigarette")
	print("[Player] world_cig =", world_cig)

	if world_cig == null:
		push_error("[Player] No node in group 'SharedCigarette'")
		return

	print("[Player] has_signal(state_changed)?", world_cig.has_signal("state_changed"))

	var cb := Callable(self, "_on_cig_state_changed")
	var err = world_cig.state_changed.connect(cb)
	print("[Player] connect err =", err)  # 0 == OK

	print("[Player] is_connected?",
		world_cig.state_changed.is_connected(cb))

	# tell Stress where the UI bar is - only for local player
	if stress and stress_bar and is_multiplayer_authority():
		stress.bar_path = stress_bar.get_path()

func _on_cig_state_changed(is_held: bool, holder_peer_id: int) -> void:
	print("[Player] _on_cig_state_changed fired! is_held=", is_held, " holder=", holder_peer_id)
	var am_holder := holder_peer_id == multiplayer.get_unique_id()
	toggle_holding_cig(is_held and am_holder)

	# 🔗 allow smoking relief only if we actually hold the cig
	if stress:
		stress.set_can_smoke(is_held and am_holder)

func toggle_holding_cig(is_holding: bool):
	var HandRig = get_node("HandRig")
	print(HandRig)
	HandRig.set_show_cigarette(is_holding)

func try_pickup_cig_from_world() -> void:
	if world_cig == null: return
	if world_cig.global_position.distance_to(global_position) > 2.0:
		return

	var my_id := multiplayer.get_unique_id()

	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		# Host or single-player: run locally
		world_cig.req_pickup(my_id)
	else:
		# Client -> server (peer 1)
		world_cig.rpc_id(1, "req_pickup", my_id)


func try_drop_cig_to_world() -> void:
	if world_cig == null: return
	var f := -global_transform.basis.z.normalized()
	var drop_pos := global_transform.origin + f * drop_forward + Vector3(0, drop_height, 0)
	var drop_xform := Transform3D(Basis(), drop_pos)  # lay flat; adjust if needed
    
	var my_id := multiplayer.get_unique_id()
    
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		# Host or single-player: run locally
		world_cig.req_drop(my_id, drop_xform)
	else:
		# Client -> server (peer 1)
		world_cig.rpc_id(1, "req_drop", my_id, drop_xform)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sens * 0.01
		pitch -= event.relative.y * mouse_sens * 0.01
		pitch = clamp(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation.y = yaw
		head.rotation.x = pitch

	# Press Esc to free the mouse, click to recapture
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if event.is_action("interact"):
		try_pickup_cig_from_world()
	elif event.is_action("drop"):
		try_drop_cig_to_world()

	# Hold to smoke (you can map "smoke" in Input Map)
	if event.is_action_pressed("smoke"):
		if stress:
			stress.set_smoking(true)
	elif event.is_action_released("smoke"):
		if stress:
			stress.set_smoking(false)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var wish_dir = get_input_direction()
		var speed_target = sprint_speed if Input.is_action_pressed("sprint") else move_speed
		var movement_basis = Basis(Vector3.UP, yaw) # rotate inputs by yaw

		var horizontal_vel: Vector3 = velocity
		horizontal_vel.y = 0.0

		var desired_vel: Vector3 = (movement_basis * wish_dir).normalized() * speed_target
		var control := accel if is_on_floor() else air_control
		horizontal_vel = horizontal_vel.lerp(desired_vel, clamp(control * delta, 0.0, 1.0))

		velocity.x = horizontal_vel.x
		velocity.z = horizontal_vel.z

		# Gravity & jump
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

		move_and_slide()

func get_input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		dir.x += 1.0
	return dir
	
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
