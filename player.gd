extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var accel: float = 20.0
@export var air_control: float = 2.0
@export var mouse_sens: float = 0.12
@export var jump_velocity: float = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var yaw := 0.0   # left/right (Player)
var pitch := 0.0 # up/down (Head)

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.current = is_multiplayer_authority()

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

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var wish_dir = get_input_direction()
		var speed_target = sprint_speed if Input.is_action_pressed("sprint") else move_speed
		var basis = Basis(Vector3.UP, yaw) # rotate inputs by yaw

		var horizontal_vel: Vector3 = velocity
		horizontal_vel.y = 0.0

		var desired_vel: Vector3 = (basis * wish_dir).normalized() * speed_target
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
