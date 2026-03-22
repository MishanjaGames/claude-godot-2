# MainMenu.gd
# Main menu screen. Routes through GameManager for all transitions.
#
# SCENE TREE (MainMenu.tscn):
#   MainMenu           [CanvasLayer]           ← this script
#   ├── ParallaxBackground
#   │   └── ParallaxLayer  (motion_scale=0.5)
#   │       └── TextureRect (stretch=COVER)
#   ├── CenterContainer   (anchors=full)
#   │   └── VBoxContainer  (separation=10)
#   │       ├── TitleLabel  [Label]   font_size=52
#   │       ├── BtnNewGame  [Button]
#   │       ├── BtnContinue [Button]
#   │       ├── BtnSettings [Button]
#   │       └── BtnQuit     [Button]
#   ├── FadeOverlay  [ColorRect]  (anchors=full, color=#000000)
#   └── VersionLabel [Label]      (anchors=bottom-right, font_size=11)
class_name MainMenu
extends CanvasLayer

@onready var btn_new_game:    Button              = $CenterContainer/VBoxContainer/BtnNewGame
@onready var btn_continue:    Button              = $CenterContainer/VBoxContainer/BtnContinue
@onready var btn_settings:    Button              = $CenterContainer/VBoxContainer/BtnSettings
@onready var btn_quit:        Button              = $CenterContainer/VBoxContainer/BtnQuit
@onready var parallax:        ParallaxBackground  = $ParallaxBackground
@onready var fade_overlay:    ColorRect           = $FadeOverlay
@onready var version_label:   Label               = $VersionLabel

func _ready() -> void:
	btn_continue.disabled = not SaveManager.has_save()
	version_label.text    = "v0.1 — dev"

	btn_new_game.pressed.connect(_on_new_game)
	btn_continue.pressed.connect(_on_continue)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)

	# Show save metadata on Continue button if save exists.
	if SaveManager.has_save():
		var meta := SaveManager.get_save_metadata()
		if not meta.is_empty():
			var ts: int = meta.get("timestamp", 0)
			btn_continue.text = "Continue  (seed %d)" % meta.get("seed", 0)

	_fade_in()

func _process(delta: float) -> void:
	parallax.scroll_offset.x += delta * 18.0

func _fade_in() -> void:
	fade_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.7)

func _fade_out_then(callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.45)
	tween.tween_callback(callable)

func _on_new_game() -> void:
	_fade_out_then(func(): GameManager.new_game())

func _on_continue() -> void:
	_fade_out_then(func(): GameManager.continue_game())

func _on_settings() -> void:
	var settings := get_tree().get_first_node_in_group("settings_screen")
	if settings and settings.has_method("open"):
		settings.open(self)

func _on_quit() -> void:
	_fade_out_then(func(): get_tree().quit())
