# DamagePopup.gd
# A short-lived floating label that rises and fades out.
# Spawned by CombatManager._spawn_popup().
#
# SCENE TREE (DamagePopup.tscn):
#   DamagePopup    [Node2D]    ← this script
#   └── Label      [Label]     (h_align=center, v_align=center, no wrap)
class_name DamagePopup
extends Node2D

const RISE_SPEED:  float = 55.0   # pixels per second upward
const FADE_TIME:   float = 0.65   # seconds before fully transparent
const SCALE_PUNCH: float = 1.35   # initial scale overshoot

@onready var label: Label = $Label

var _age:   float = 0.0
var _color: Color = Color.WHITE

## Called by CombatManager immediately after instantiation.
func setup(text: String, color: Color) -> void:
	_color       = color
	label.text   = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", _font_size_for(text))
	# Punch scale then settle.
	scale = Vector2(SCALE_PUNCH, SCALE_PUNCH)

func _process(delta: float) -> void:
	_age += delta
	# Rise.
	position.y -= RISE_SPEED * delta
	# Slight horizontal drift for visual variety.
	position.x += sin(_age * 6.0) * 0.4

	# Fade out in the last 40 % of lifetime.
	var fade_start := FADE_TIME * 0.6
	if _age > fade_start:
		var t := (_age - fade_start) / (FADE_TIME - fade_start)
		modulate.a = 1.0 - t

	# Scale settle toward 1.0.
	var target_scale := 1.0 + max(0.0, (SCALE_PUNCH - 1.0) * (1.0 - _age / 0.12))
	scale = Vector2(target_scale, target_scale)

	if _age >= FADE_TIME:
		queue_free()

func _font_size_for(text: String) -> int:
	# Larger numbers get bigger text.
	if text.begins_with("+"):   return 14   # heal / XP
	if text == "CRIT!":         return 18
	if text == "BLOCK":         return 16
	var n := int(text)
	if n >= 40:                 return 20
	if n >= 20:                 return 17
	return 14
