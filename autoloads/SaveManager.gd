# SaveManager.gd
# Handles all disk I/O for game saves.
# Separated from GameManager so save logic is isolated and testable.
# LOAD ORDER: after WorldManager.
extends Node

const SAVE_PATH:    String = "user://save.json"
const SAVE_VERSION: int    = 2   # bump when save format changes

func _ready() -> void:
	EventBus.game_saved.connect(func(): print("SaveManager: game saved."))

# ── Public API ─────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

## Serialises and writes all game state to disk.
func save_game() -> void:
	var player = GameManager.player_ref
	if player == null:
		push_warning("SaveManager.save_game: no player_ref — aborting.")
		EventBus.save_failed.emit("Player not found.")
		return

	var data: Dictionary = {
		"version":   SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),

		"world":     WorldManager.serialize(),

		"player": {
			"position_x":      player.global_position.x,
			"position_y":      player.global_position.y,
			"current_health":  player.current_health,
			"current_stamina": player.current_stamina,
			"stat_block":      player.stat_block.serialize() if player.stat_block else {},
		},

		"inventory": InventoryManager.serialize(),
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager.save_game: could not open '%s' for writing." % SAVE_PATH)
		EventBus.save_failed.emit("Could not write save file.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.game_saved.emit()

## Reads the save file and returns the raw Dictionary. Empty dict on failure.
func load_raw() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager.load_raw: could not open '%s'." % SAVE_PATH)
		EventBus.load_failed.emit("Could not read save file.")
		return {}
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null:
		push_error("SaveManager.load_raw: JSON parse failed.")
		EventBus.load_failed.emit("Save file is corrupted.")
		return {}
	return parsed

## Applies a loaded save Dictionary to all autoloads and the player.
## Call this from World.tscn's _ready() after the player has been spawned.
func apply_save(player: Node) -> void:
	var data = load_raw()
	if data.is_empty():
		return

	var version: int = data.get("version", 1)
	data = _migrate(data, version)

	# World state (seed, chunk deltas)
	WorldManager.deserialize(data.get("world", {}))

	# Player
	var pd: Dictionary = data.get("player", {})
	if not pd.is_empty():
		player.global_position = Vector2(
			pd.get("position_x", player.global_position.x),
			pd.get("position_y", player.global_position.y)
		)
		player.current_health  = pd.get("current_health",  player.stat_block.get_max_health())
		player.current_stamina = pd.get("current_stamina", player.stat_block.get_max_stamina())
		if player.stat_block and pd.has("stat_block"):
			player.stat_block.deserialize(pd["stat_block"])

	# Inventory
	InventoryManager.deserialize(data.get("inventory", {}))

	EventBus.game_loaded.emit()

# ── Save metadata (for save-slot UI) ──────────────────────────────────────────

## Returns a lightweight summary without applying anything.
func get_save_metadata() -> Dictionary:
	var data = load_raw()
	if data.is_empty():
		return {}
	return {
		"version":   data.get("version",   0),
		"timestamp": data.get("timestamp", 0),
		"seed":      data.get("world",     {}).get("world_seed", 0),
	}

# ── Migration ──────────────────────────────────────────────────────────────────

## Upgrades old save formats to the current version.
## Add a new branch here whenever SAVE_VERSION is bumped.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 2:
		# v1 → v2: GameManager used to own save/world data; move under "world" key
		if not data.has("world"):
			data["world"] = {
				"world_seed": data.get("seed", 0),
				"generated_chunks": {},
				"modified_chunks":  {},
			}
	return data
