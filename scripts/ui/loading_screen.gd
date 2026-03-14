extends CanvasLayer

var _bar:    ProgressBar = null
var _label:  Label       = null
var _target: String      = ""


func _ready() -> void:
	_build()
	hide()
	set_process(false)


func _build() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_label = Label.new()
	_label.text = "Loading..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 20)
	_bar.min_value   = 0.0
	_bar.max_value   = 100.0
	_bar.value       = 0.0
	_bar.show_percentage = false
	vbox.add_child(_bar)


func load_scene(path: String) -> void:
	_target = path
	_bar.value  = 0.0
	_label.text = "Loading..."
	show()
	ResourceLoader.load_threaded_request(path)
	set_process(true)


func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)

	if progress.size() > 0:
		var pct : float= progress[0] * 100.0
		_bar.value  = pct
		_label.text = "Loading... %d%%" % int(pct)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		hide()
		var scene: PackedScene = ResourceLoader.load_threaded_get(_target)
		get_tree().change_scene_to_packed(scene)
