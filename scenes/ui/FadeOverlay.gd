# FadeOverlay.gd
# Reusable black fade. Call fade_out() / fade_in() from code.
extends CanvasLayer

@onready var rect: ColorRect        = $ColorRect
@onready var anim: AnimationPlayer  = $AnimationPlayer

func fade_out(duration: float = 0.5) -> void:
	rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)

func fade_in(duration: float = 0.5) -> void:
	rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
