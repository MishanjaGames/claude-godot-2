# FadeOverlay.gd
# Full-screen black fade. Call fade_in() / fade_out() from any scene.
# Lives at a high canvas layer (128) so it always renders on top.
#
# SCENE TREE (FadeOverlay.tscn):
#   FadeOverlay    [CanvasLayer]  layer=128   ← this script
#   └── Rect       [ColorRect]               color=#000000, anchors=full
class_name FadeOverlay
extends CanvasLayer

@onready var rect: ColorRect = $Rect

func _ready() -> void:
	rect.modulate.a = 0.0

func fade_out(duration: float = 0.5) -> void:
	rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)

func fade_in(duration: float = 0.5) -> void:
	rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)

## Fade out, call callable, then fade in. Useful for scene transitions.
func transition(callable: Callable, out_time: float = 0.4, in_time: float = 0.4) -> void:
	fade_out(out_time)
	await get_tree().create_timer(out_time).timeout
	callable.call()
	fade_in(in_time)
