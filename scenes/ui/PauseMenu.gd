# PauseMenu.gd
# In-game pause overlay. Instance inside Playground.tscn.
# Toggle via GameManager or direct call from Playground._input().
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var btn_resume: Button    = $Panel/MarginContainer/VBoxContainer/BtnResume
@onready var btn_save: Button      = $Panel/MarginContainer/VBoxContainer/BtnSave
@onready var btn_settings: Button  = $Panel/MarginContainer/VBoxContainer/BtnSettings
@onready var btn_menu: Button      = $Panel/MarginContainer/VBoxContainer/BtnMenu

const MAIN_MENU: String = "res://scenes/screens/MainMenu.tscn"

var _is_open: bool = false

func _ready() -> void:
	panel.visible = false
	process_mode  = Node.PROCESS_MODE_ALWAYS   # runs even when tree is paused

	btn_resume.pressed.connect(close)
	btn_save.pressed.connect(_on_save_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)

	EventBus.game_paused.connect(_on_game_paused)

# ── Public ─────────────────────────────────────────────────────────────────────

func open() -> void:
	if _is_open:
		return
	_is_open      = true
	panel.visible = true
	get_tree().paused = true
	EventBus.game_paused.emit(true)

func close() -> void:
	if not _is_open:
		return
	_is_open      = false
	panel.visible = false
	get_tree().paused = false
	EventBus.game_paused.emit(false)

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_game_paused(is_paused: bool) -> void:
	# Sync if paused externally (e.g. dialogue box)
	if not is_paused and _is_open:
		close()

func _on_save_pressed() -> void:
	GameManager.save_game()
	EventBus.hud_show_message.emit("Game Saved.", 2.0)
	# Keep menu open so player sees the confirmation in HUD

func _on_settings_pressed() -> void:
	# Forward to SettingsScreen if present in the scene tree
	var settings = get_tree().get_first_node_in_group("settings_screen")
	if settings != null:
		settings.open()
		close()

func _on_menu_pressed() -> void:
	GameManager.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
