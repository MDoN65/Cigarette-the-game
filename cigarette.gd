extends Node3D

@onready var smoke: GPUParticles3D = $Smoke as GPUParticles3D
var smoke_material: ParticleProcessMaterial
var current_dir: Vector3 = Vector3.UP
var lerp_speed: float = 0.1  # smoothness factor, smaller = more lag

func _ready() -> void:
	smoke_material = smoke.process_material
	if smoke_material == null:
		push_warning("Smoke node has no ProcessMaterial assigned!")

func _process(delta: float) -> void:
	if smoke_material == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Get camera forward direction (XZ plane only)
	var look_dir: Vector3 = -camera.global_transform.basis.z
	look_dir.y = 0.25  # slight upward bias
	look_dir = look_dir.normalized()

	# Smoothly interpolate from current smoke direction to camera direction
	current_dir = current_dir.lerp(look_dir, lerp_speed)
	smoke_material.direction = current_dir
