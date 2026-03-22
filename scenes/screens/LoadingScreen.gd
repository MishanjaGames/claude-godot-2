# LoadingScreen.gd
# Asynchronous scene loader with progress bar.
# GameManager.change_scene_to() switches to this scene, which loads the target
# in a background thread, then swaps in when done.
#
# SCENE TREE (LoadingScreen.tscn):
#   LoadingScreen      [CanvasLayer]          ← this script
#   ├── Background     [ColorRect]            anchors=full, color=#0d0d0d
#   ├── VBoxContainer  (anchors=center, min=(360,80))
#   │   ├── StatusLabel  [Label]              text="Loading…", h_align=center
#   │   └── ProgressBar                       min=0, max=100
#   └── FadeOverlay    [ColorRect]            anchors=full, color=#000000
class_name LoadingScreen
extends CanvasLayer

@onready var status_label: Label       = $VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var fade_overlay: ColorRect   = $FadeOverlay

var _target:      String = ""
var _load_status: int    = ResourceLoader.THREAD_LOAD_IN_PROGRESS

func _ready() -> void:
	_target = GameManager.next_scene_path
	if _target.is_empty():
		push_error("LoadingScreen: GameManager.next_scene_path is empty.")
		return
	status_label.text   = "Loading…"
	progress_bar.value  = 0.0
	fade_overlay.modulate.a = 0.0
	ResourceLoader.load_threaded_request(_target)

func _process(_delta: float) -> void:
	if _target.is_empty():
		return
	var progress: Array = []
	_load_status = ResourceLoader.load_threaded_get_status(_target, progress)
	match _load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = (progress[0] if progress.size() > 0 else 0.0) * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			_finish()
		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Load failed: %s" % _target
			push_error("LoadingScreen: failed to load '%s'." % _target)

func _finish() -> void:
	status_label.text = "Done!"
	var packed: PackedScene = ResourceLoader.load_threaded_get(_target)
	GameManager.on_scene_loaded(_target)
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func(): get_tree().change_scene_to_packed(packed))
