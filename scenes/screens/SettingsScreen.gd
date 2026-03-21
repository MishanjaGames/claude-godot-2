# SettingsScreen.gd
# Volume controls (master / SFX / music) and display settings.
# Can be instanced in Playground or MainMenu.
# Add this node to the "settings_screen" group in the Inspector.
extends CanvasLayer

# AudioServer bus indices — adjust if your project uses different names.
const BUS_MASTER: int = 0
const BUS_SFX: int    = 1   # create a bus named "SFX" in the Audio panel
const BUS_MUSIC: int  = 2   # create a bus named "Music" in the Audio panel

@onready var panel: PanelContainer        = $Panel
@onready var slider_master: HSlider       = $Panel/MarginContainer/VBoxContainer/MasterRow/SliderMaster
@onready var slider_sfx: HSlider          = $Panel/MarginContainer/VBoxContainer/SFXRow/SliderSFX
@onready var slider_music: HSlider        = $Panel/MarginContainer/VBoxContainer/MusicRow/SliderMusic
@onready var label_master: Label          = $Panel/MarginContainer/VBoxContainer/MasterRow/LabelMaster
@onready var label_sfx: Label             = $Panel/MarginContainer/VBoxContainer/SFXRow/LabelSFX
@onready var label_music: Label           = $Panel/MarginContainer/VBoxContainer/MusicRow/LabelMusic
@onready var check_fullscreen: CheckButton = $Panel/MarginContainer/VBoxContainer/CheckFullscreen
@onready var btn_apply: Button            = $Panel/MarginContainer/VBoxContainer/ButtonRow/BtnApply
@onready var btn_back: Button             = $Panel/MarginContainer/VBoxContainer/ButtonRow/BtnBack

const SETTINGS_PATH: String = "user://settings.cfg"

var _pending: Dictionary = {}
var _caller_scene: Node  = null   # node to return to on Back

func _ready() -> void:
	add_to_group("settings_screen")
	panel.visible = false
	process_mode  = Node.PROCESS_MODE_ALWAYS

	_setup_sliders()
	_load_settings()
	_apply_to_ui()

	slider_master.value_changed.connect(_on_slider_changed.bind("master"))
	slider_sfx.value_changed.connect(_on_slider_changed.bind("sfx"))
	slider_music.value_changed.connect(_on_slider_changed.bind("music"))
	check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_back.pressed.connect(_on_back_pressed)

# ── Public ─────────────────────────────────────────────────────────────────────

func open(from: Node = null) -> void:
	_caller_scene = from
	_apply_to_ui()
	panel.visible = true

func close() -> void:
	panel.visible = false

# ── Slider setup ───────────────────────────────────────────────────────────────

func _setup_sliders() -> void:
	for s in [slider_master, slider_sfx, slider_music]:
		s.min_value = 0.0
		s.max_value = 1.0
		s.step      = 0.01

# ── Settings persistence ───────────────────────────────────────────────────────

func _default_settings() -> Dictionary:
	return {
		"master": 1.0,
		"sfx":    1.0,
		"music":  0.8,
		"fullscreen": false,
	}

func _load_settings() -> void:
	_pending = _default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_pending["master"]     = cfg.get_value("audio",   "master",     1.0)
	_pending["sfx"]        = cfg.get_value("audio",   "sfx",        1.0)
	_pending["music"]      = cfg.get_value("audio",   "music",      0.8)
	_pending["fullscreen"] = cfg.get_value("display", "fullscreen", false)
	_apply_settings(_pending)

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio",   "master",     _pending["master"])
	cfg.set_value("audio",   "sfx",        _pending["sfx"])
	cfg.set_value("audio",   "music",      _pending["music"])
	cfg.set_value("display", "fullscreen", _pending["fullscreen"])
	cfg.save(SETTINGS_PATH)

func _apply_settings(s: Dictionary) -> void:
	_set_bus_volume(BUS_MASTER, s["master"])
	_set_bus_volume(BUS_SFX,    s["sfx"])
	_set_bus_volume(BUS_MUSIC,  s["music"])
	var mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if s["fullscreen"] \
		else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_to_ui() -> void:
	slider_master.value     = _pending.get("master", 1.0)
	slider_sfx.value        = _pending.get("sfx",    1.0)
	slider_music.value      = _pending.get("music",  0.8)
	check_fullscreen.button_pressed = _pending.get("fullscreen", false)
	_update_labels()

func _set_bus_volume(bus_index: int, linear: float) -> void:
	if bus_index >= AudioServer.bus_count:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))
	AudioServer.set_bus_mute(bus_index, linear <= 0.0)

# ── Callbacks ──────────────────────────────────────────────────────────────────

func _on_slider_changed(value: float, key: String) -> void:
	_pending[key] = value
	_update_labels()

func _on_fullscreen_toggled(pressed: bool) -> void:
	_pending["fullscreen"] = pressed

func _on_apply_pressed() -> void:
	_apply_settings(_pending)
	_save_settings()
	close()
	if _caller_scene != null and _caller_scene.has_method("open"):
		_caller_scene.open()

func _on_back_pressed() -> void:
	_load_settings()   # discard pending changes
	_apply_to_ui()
	close()
	if _caller_scene != null and _caller_scene.has_method("open"):
		_caller_scene.open()

func _update_labels() -> void:
	label_master.text = "%d%%" % int(_pending.get("master", 1.0) * 100)
	label_sfx.text    = "%d%%" % int(_pending.get("sfx",    1.0) * 100)
	label_music.text  = "%d%%" % int(_pending.get("music",  0.8) * 100)
