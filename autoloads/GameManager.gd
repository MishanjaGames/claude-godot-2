# GameManager.gd
# Global game state, scene transitions, save/load.
extends Node

const SAVE_PATH: String = "user://save.json"

var current_scene_path: String = ""
var next_scene_path: String = ""
var player_ref: Node = null   # set by Player._ready()

# ── Scene Transitions ─────────────────────────────────────────────────────────

## Begin a scene change: fades out → loads via LoadingScreen → fades in.
func change_scene_to(path: String) -> void:
	next_scene_path = path
	EventBus.scene_change_requested.emit(path)

## Called by LoadingScreen when loading is complete.
func on_scene_loaded(path: String) -> void:
	current_scene_path = path
	EventBus.scene_loaded.emit(path)

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_game() -> void:
	if player_ref == null:
		push_warning("GameManager.save_game: No player reference set.")
		return

	var save_data: Dictionary = {
		"version": 1,
		"scene": current_scene_path,
		"player": {
			"position_x": player_ref.global_position.x,
			"position_y": player_ref.global_position.y,
			"health": player_ref.current_health,
			"stamina": player_ref.current_stamina,
		},
		"inventory": InventoryManager.serialize(),
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		EventBus.game_saved.emit()
	else:
		push_error("GameManager.save_game: Could not open save file for writing.")

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager.load_game: Could not open save file.")
		return {}
	var content = file.get_as_text()
	file.close()
	var result = JSON.parse_string(content)
	if result == null:
		push_error("GameManager.load_game: JSON parse failed.")
		return {}
	EventBus.game_loaded.emit()
	return result

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
