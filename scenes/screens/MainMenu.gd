# MainMenu.gd
extends CanvasLayer

@onready var btn_new_game: Button      = $CenterContainer/VBoxContainer/BtnNewGame
@onready var btn_continue: Button      = $CenterContainer/VBoxContainer/BtnContinue
@onready var btn_settings: Button      = $CenterContainer/VBoxContainer/BtnSettings
@onready var btn_quit: Button          = $CenterContainer/VBoxContainer/BtnQuit
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var fade_overlay: ColorRect   = $FadeOverlay

const WORLD_SCENE: String = "res://scenes/screens/Playground.tscn"

func _ready() -> void:
	btn_continue.disabled = not GameManager.has_save()
	fade_in()

func _process(delta: float) -> void:
	# Gentle parallax scroll on the background
	parallax_bg.scroll_offset.x += delta * 20.0

func fade_in() -> void:
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func fade_out_then(callable: Callable) -> void:
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	tween.tween_callback(callable)

func _on_btn_new_game_pressed() -> void:
	GameManager.delete_save()
	fade_out_then(func(): GameManager.change_scene_to(WORLD_SCENE))

func _on_btn_continue_pressed() -> void:
	fade_out_then(func(): GameManager.change_scene_to(WORLD_SCENE))

func _on_btn_settings_pressed() -> void:
	# TODO: push a SettingsScreen
	EventBus.hud_show_message.emit("Settings not yet implemented.", 2.0)

func _on_btn_quit_pressed() -> void:
	fade_out_then(func(): get_tree().quit())
