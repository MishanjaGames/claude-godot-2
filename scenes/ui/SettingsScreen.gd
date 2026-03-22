# SettingsScreen.gd
# Volume sliders (Master / SFX / Music) and fullscreen toggle.
# Saves to user://settings.cfg. Applied immediately on startup via _load_settings().
# Add this node to group "settings_screen" in the Inspector.
class_name SettingsScreen
extends CanvasLayer

const BUS_MASTER: int = 0
const BUS_SFX:    int = 1
const BUS_MUSIC:  int = 2
const SETTINGS_PATH: String = "user://settings.cfg"

@onready var panel:           PanelContainer = $Panel
@onready var slider_master:   HSlider        = $Panel/MarginContainer/VBoxContainer/MasterRow/SliderMaster
@onready var slider_sfx:      HSlider        = $Panel/MarginContainer/VBoxContainer/SFXRow/SliderSFX
@onready var slider_music:    HSlider        = $Panel/MarginContainer/VBoxContainer/MusicRow/SliderMusic
@onready var label_master:    Label          = $Panel/MarginContainer/VBoxContainer/MasterRow/LabelMaster
@onready var label_sfx:       Label          = $Panel/MarginContainer/VBoxContainer/SFXRow/LabelSFX
@onready var label_music:     Label          = $Panel/MarginContainer/VBoxContainer/MusicRow/LabelMusic
@onready var check_fullscreen: CheckButton   = $Panel/MarginContainer/VBoxContainer/CheckFullscreen
@onready var btn_apply:       Button         = $Panel/MarginContainer/VBoxContainer/ButtonRow/BtnApply
@onready var btn_back:        Button         = $Panel/MarginContainer/VBoxContainer/ButtonRow/BtnBack

var _pending: Dictionary = {}
var _caller:  Node = null

func _ready() -> void:
	add_to_group("settings_screen")
	panel.visible = false
	process_mode  = Node.PROCESS_MODE_ALWAYS

	slider_master.value_changed.connect(_on_slider.bind("master"))
	slider_sfx.value_changed.connect(_on_slider.bind("sfx"))
	slider_music.value_changed.connect(_on_slider.bind("music"))
	check_fullscreen.toggled.connect(func(v): _pending["fullscreen"] = v)
	btn_apply.pressed.connect(_on_apply)
	btn_back.pressed.connect(_on_back)

	_load_settings()

func open(caller: Node = null) -> void:
	_caller = caller
	_apply_to_ui()
	panel.visible = true

func close() -> void:
	panel.visible = false
	if _caller and _caller.has_method("open"):
		_caller.open()
	_caller = null

# ── Defaults ───────────────────────────────────────────────────────────────────

func _defaults() -> Dictionary:
	return { "master": 1.0, "sfx": 1.0, "music": 0.8, "fullscreen": false }

# ── Load / save ────────────────────────────────────────────────────────────────

func _load_settings() -> void:
	_pending = _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_pending["master"]     = cfg.get_value("audio",   "master",     1.0)
		_pending["sfx"]        = cfg.get_value("audio",   "sfx",        1.0)
		_pending["music"]      = cfg.get_value("audio",   "music",      0.8)
		_pending["fullscreen"] = cfg.get_value("display", "fullscreen", false)
	_apply_settings(_pending)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",   "master",     _pending.get("master",     1.0))
	cfg.set_value("audio",   "sfx",        _pending.get("sfx",        1.0))
	cfg.set_value("audio",   "music",      _pending.get("music",      0.8))
	cfg.set_value("display", "fullscreen", _pending.get("fullscreen", false))
	cfg.save(SETTINGS_PATH)

func _apply_settings(s: Dictionary) -> void:
	_set_bus(BUS_MASTER, s.get("master",     1.0))
	_set_bus(BUS_SFX,    s.get("sfx",        1.0))
	_set_bus(BUS_MUSIC,  s.get("music",      0.8))
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
		if s.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_to_ui() -> void:
	slider_master.value           = _pending.get("master",     1.0)
	slider_sfx.value              = _pending.get("sfx",        1.0)
	slider_music.value            = _pending.get("music",      0.8)
	check_fullscreen.button_pressed = _pending.get("fullscreen", false)
	_update_labels()

func _set_bus(bus: int, linear: float) -> void:
	if bus >= AudioServer.bus_count: return
	AudioServer.set_bus_volume_db(bus, linear_to_db(linear))
	AudioServer.set_bus_mute(bus, linear <= 0.0)

# ── Callbacks ──────────────────────────────────────────────────────────────────

func _on_slider(value: float, key: String) -> void:
	_pending[key] = value
	_update_labels()

func _update_labels() -> void:
	label_master.text = "%d%%" % int(_pending.get("master", 1.0) * 100)
	label_sfx.text    = "%d%%" % int(_pending.get("sfx",    1.0) * 100)
	label_music.text  = "%d%%" % int(_pending.get("music",  0.8) * 100)

func _on_apply() -> void:
	_apply_settings(_pending)
	_save_settings()
	close()

func _on_back() -> void:
	_load_settings()
	_apply_to_ui()
	close()
