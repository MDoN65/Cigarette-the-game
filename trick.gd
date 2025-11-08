#extends Node3D
#
#@onready var hand: Node3D = $HandMesh
#@onready var cigarette: Node3D = $Cigarette
#@onready var smoke: GPUParticles3D = $Cigarette/Smoke
#@onready var anim: AnimationPlayer = $AnimationPlayer
#@onready var ember_light: OmniLight3D = $EmberLight
#
#var is_flipping := false
#var ember_intensity := 1.5
#var ember_pulse_speed := 6.0
#
#func _ready() -> void:
	## Slightly tone down smoke at start
	#smoke.amount = 250
	#var mat := smoke.process_material as ParticleProcessMaterial
	#if mat:
		#mat.initial_velocity = 0.3
		#mat.gravity = Vector3(0, -0.05, 0)
		#mat.lifetime = 6.0
		#mat.lifetime_randomness = 0.3
		#mat.direction = Vector3.UP
		#mat.spread = 10.0
		#mat.damping = 0.15
#
##func _process(delta: float) -> void:
	### Flickering ember glow for realism
	##ember_light.light_energy = ember_intensity + sin(Time.get_ticks_msec() / 100.0) * 0.3
	##if is_flipping and not anim.is_
