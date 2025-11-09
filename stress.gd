extends Node

signal stress_changed(value: float)
signal stress_maxed()   # if you want to react when it fills

@export var max_stress := 100.0
@export var start_stress := 10.0
@export var rise_per_sec := 5.0         # stress grows per second
@export var smoke_relief_per_sec := 25.0# stress decreases while smoking

@export_range(0.0, 1.0) var yellow_threshold := 0.50   # >= 50% turns yellow
@export_range(0.0, 1.0) var red_threshold    := 0.80   # >= 80% turns red

@export var color_green := Color(0.20, 0.80, 0.30)     # tweak to taste
@export var color_yellow := Color(0.95, 0.80, 0.20)
@export var color_red := Color(0.90, 0.20, 0.20)
@export var color_bg := Color(0.10, 0.10, 0.10, 0.8)   # bar background


@export var bar_path: NodePath          # set this to the ProgressBar in the inspector

var _stress := 0.0
var _can_smoke := false                  # you only get relief if actually holding the cig
var _is_smoking := false

var _sb_bg: StyleBoxFlat
var _sb_fill_green: StyleBoxFlat
var _sb_fill_yellow: StyleBoxFlat
var _sb_fill_red: StyleBoxFlat


@onready var _bar: ProgressBar = get_node_or_null(bar_path)

func _ready() -> void:
	_stress = clampf(start_stress, 0.0, max_stress)
	_build_styles()
	_update_bar()

func set_can_smoke(v: bool) -> void:
	print("[Stress] set_can_smoke(", v, ")")
	_can_smoke = v
	if not _can_smoke:
		_is_smoking = false

func set_smoking(v: bool) -> void:
	_is_smoking = v and _can_smoke

func get_stress() -> float:
	return _stress

func _process(delta: float) -> void:
	var prev := _stress

	if _is_smoking:
		_stress -= smoke_relief_per_sec * delta
	else:
		_stress += rise_per_sec * delta

	_stress = clampf(_stress, 0.0, max_stress)

	# print("[Stress] _process: stress =", _stress)

	if _stress != prev:
		emit_signal("stress_changed", _stress)
		_update_bar()
		if _stress >= max_stress:
			emit_signal("stress_maxed")

func _update_bar() -> void:
	print("[Stress] _update_bar: updating bar...")
	if _bar:
		print("[Stress] _update_bar: setting bar max to", max_stress, " value to", _stress)
		_bar.max_value = max_stress
		_bar.value = _stress
		_update_bar_style()

func _build_styles() -> void:
	if not _bar: return
	_sb_bg = StyleBoxFlat.new()
	_sb_bg.bg_color = color_bg
	_set_round(_sb_bg)

	_sb_fill_green = StyleBoxFlat.new()
	_sb_fill_green.bg_color = color_green
	_set_round(_sb_fill_green)

	_sb_fill_yellow = StyleBoxFlat.new()
	_sb_fill_yellow.bg_color = color_yellow
	_set_round(_sb_fill_yellow)

	_sb_fill_red = StyleBoxFlat.new()
	_sb_fill_red.bg_color = color_red
	_set_round(_sb_fill_red)

	# apply background once
	_bar.add_theme_stylebox_override("background", _sb_bg)

func _set_round(sb: StyleBoxFlat) -> void:
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6

func _update_bar_style() -> void:
	if not _bar: return
	var ratio := (_stress / max_stress)
	var fill := _sb_fill_green
	if ratio >= red_threshold:
		fill = _sb_fill_red
	elif ratio >= yellow_threshold:
		fill = _sb_fill_yellow
	_bar.add_theme_stylebox_override("fill", fill)
