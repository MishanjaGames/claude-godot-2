# LoadingScreen.gd
# Asynchronously loads the scene path stored in GameManager.next_scene_path.
extends CanvasLayer

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var label_status: Label       = $VBoxContainer/LabelStatus
@onready var fade_overlay: ColorRect   = $FadeOverlay

var _target_path: String = ""
var _load_status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS

func _ready() -> void:
	_target_path = GameManager.next_scene_path
	if _target_path.is_empty():
		push_error("LoadingScreen: No scene path set in GameManager.")
		return
	label_status.text = "Loading..."
	ResourceLoader.load_threaded_request(_target_path)
	fade_overlay.modulate.a = 0.0

func _process(_delta: float) -> void:
	if _target_path.is_empty():
		return

	var progress: Array = []
	_load_status = ResourceLoader.load_threaded_get_status(_target_path, progress)

	match _load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0 if progress.size() > 0 else 0.0

		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			_finish_loading()

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("LoadingScreen: Failed to load scene: " + _target_path)
			label_status.text = "Load failed!"

func _finish_loading() -> void:
	label_status.text = "Done!"
	var packed_scene = ResourceLoader.load_threaded_get(_target_path)
	GameManager.on_scene_loaded(_target_path)

	# Fade out then switch
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_packed(packed_scene)
	)
