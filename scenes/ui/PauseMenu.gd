# PauseMenu.gd
# In-game pause overlay. Instanced inside World.tscn.
# Toggle via World._input() which calls pause_menu.toggle().
#
# SCENE TREE: see SCENE_SETUP.md from earlier in the project.
class_name PauseMenu
extends CanvasLayer

@onready var panel:        PanelContainer = $Panel
@onready var btn_resume:   Button         = $Panel/MarginContainer/VBoxContainer/BtnResume
@onready var btn_save:     Button         = $Panel/MarginContainer/VBoxContainer/BtnSave
@onready var btn_settings: Button         = $Panel/MarginContainer/VBoxContainer/BtnSettings
@onready var btn_menu:     Button         = $Panel/MarginContainer/VBoxContainer/BtnMenu

var _is_open: bool = false

func _ready() -> void:
	panel.visible   = false
	process_mode    = Node.PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(close)
	btn_save.pressed.connect(_on_save)
	btn_settings.pressed.connect(_on_settings)
	btn_menu.pressed.connect(_on_menu)

func open() -> void:
	if _is_open: return
	_is_open = true
	panel.visible = true
	GameManager.pause()

func close() -> void:
	if not _is_open: return
	_is_open = false
	panel.visible = false
	GameManager.unpause()

func toggle() -> void:
	open() if not _is_open else close()

func _on_save() -> void:
	SaveManager.save_game()
	EventBus.hud_show_message.emit("Game saved.", 2.0)

func _on_settings() -> void:
	var settings := get_tree().get_first_node_in_group("settings_screen")
	if settings and settings.has_method("open"):
		settings.open(self)
	close()

func _on_menu() -> void:
	SaveManager.save_game()
	close()
	GameManager.quit_to_menu()
