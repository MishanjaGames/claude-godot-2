extends CanvasLayer

@onready var bar:   ProgressBar = $Panel/VBox/Bar
@onready var label: Label       = $Panel/VBox/Label

var _target: String = ""

func load_scene(path: String) -> void:
	_target = path
	show()
	ResourceLoader.load_threaded_request(path)
	set_process(true)

func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)

	if progress.size() > 0:
		var pct : float = progress[0] * 100.0
		if bar != null:
			bar.value = pct
		if label != null:
			label.text = "Loading... %d%%" % int(pct)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		var scene: PackedScene = ResourceLoader.load_threaded_get(_target)
		get_tree().change_scene_to_packed(scene)
