# GameManager.gd
# Owns scene transitions and the player reference.
# Save/load is delegated to SaveManager.
# LOAD ORDER: after Registry and WorldManager.
extends Node

const LOADING_SCREEN: String = "res://scenes/screens/LoadingScreen.tscn"
const MAIN_MENU:      String = "res://scenes/screens/MainMenu.tscn"
const WORLD_SCENE:    String = "res://scenes/screens/World.tscn"

# ── Runtime refs ───────────────────────────────────────────────────────────────
## Set by Player._on_entity_ready(). Always valid while in-world.
var player_ref:          Node   = null
var current_scene_path:  String = ""
var next_scene_path:     String = ""
var is_in_world:         bool   = false

# ── Game flow ──────────────────────────────────────────────────────────────────

## Start a brand-new game with a generated seed.
func new_game(seed: int = -1) -> void:
	var s = seed if seed >= 0 else randi()
	WorldManager.set_world_seed(s)
	WorldManager.clear()
	InventoryManager.clear()
	SaveManager.delete_save()
	EventBus.new_game_started.emit(s)
	change_scene_to(WORLD_SCENE)

## Resume from the most recent save.
func continue_game() -> void:
	if not SaveManager.has_save():
		push_warning("GameManager.continue_game: no save file found, starting new game.")
		new_game()
		return
	change_scene_to(WORLD_SCENE)   # World.tscn will call SaveManager.load_game() in _ready()

## Return to the main menu without saving.
func quit_to_menu() -> void:
	player_ref   = null
	is_in_world  = false
	get_tree().paused = false
	change_scene_to(MAIN_MENU)

## Full quit to OS.
func quit_game() -> void:
	SaveManager.save_game()
	get_tree().quit()

# ── Scene transitions ──────────────────────────────────────────────────────────

## Routes through LoadingScreen for async loading with a progress bar.
func change_scene_to(path: String) -> void:
	next_scene_path = path
	EventBus.scene_change_requested.emit(path)
	get_tree().change_scene_to_file(LOADING_SCREEN)

## Called by LoadingScreen when the target scene is ready to swap in.
func on_scene_loaded(path: String) -> void:
	current_scene_path = path
	is_in_world        = (path == WORLD_SCENE)
	EventBus.scene_loaded.emit(path)

# ── Pause ──────────────────────────────────────────────────────────────────────

func pause() -> void:
	get_tree().paused = true
	EventBus.game_paused.emit(true)

func unpause() -> void:
	get_tree().paused = false
	EventBus.game_paused.emit(false)

func toggle_pause() -> void:
	if get_tree().paused:
		unpause()
	else:
		pause()
