# SaveManager.gd
# Complete save / load for all game systems.
# Format version 3 adds: combat XP/level, structure states, placed NPC states.
#
# SAVE FILE LAYOUT (user://save.json):
# {
#   "version":    3,
#   "timestamp":  unix_time,
#   "world":      WorldManager.serialize(),
#   "player":     { position, health, stamina, stat_block },
#   "inventory":  InventoryManager.serialize(),
#   "combat":     CombatManager.serialize(),
#   "structures": { "x_y": Structure.serialize(), ... },
#   "loose_chests": { "x_y": Chest.get_state(), ... },
#   "loose_doors":  { "x_y": Door.get_state(), ... },
# }
#
# LOAD ORDER: after WorldManager.
extends Node

const SAVE_PATH:    String = "user://save.json"
const SAVE_VERSION: int    = 3

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.game_saved.connect(func(): print("SaveManager: saved at %s." % _timestamp_str()))

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

## Full game save. Automatically scans the scene tree for Structure / Chest / Door nodes.
func save_game() -> void:
	var player := GameManager.player_ref
	if player == null:
		push_warning("SaveManager.save_game: no player_ref — aborting.")
		EventBus.save_failed.emit("Player not found.")
		return

	var data: Dictionary = {
		"version":    SAVE_VERSION,
		"timestamp":  Time.get_unix_time_from_system(),
		"world":      WorldManager.serialize(),
		"player":     _serialize_player(player),
		"inventory":  InventoryManager.serialize(),
		"combat":     CombatManager.serialize(),
		"structures":   _serialize_structures(),
		"loose_chests": _serialize_group("chest"),
		"loose_doors":  _serialize_group("door"),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager.save_game: cannot write '%s'." % SAVE_PATH)
		EventBus.save_failed.emit("Could not write save file.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.game_saved.emit()

## Applies a save to all systems. Call from World._ready() after player is spawned.
func apply_save(player: Node) -> void:
	var data := load_raw()
	if data.is_empty():
		return

	data = _migrate(data, data.get("version", 1))

	# World (seed + tile deltas — must come first so chunks generate correctly).
	WorldManager.deserialize(data.get("world", {}))

	# Player.
	_apply_player(player, data.get("player", {}))

	# Inventory (needs Registry — must come after WorldManager.deserialize sets seed).
	InventoryManager.deserialize(data.get("inventory", {}))

	# Combat XP / level.
	CombatManager.deserialize(data.get("combat", {}))

	# Structure and object states are applied later, after the world has loaded
	# its chunks and instantiated those nodes.
	# World.gd calls apply_object_states() once chunks are ready.

	EventBus.game_loaded.emit()

## Second-pass restore for objects that only exist after chunks load.
## Call from World.gd after load_initial() finishes.
func apply_object_states() -> void:
	var data := load_raw()
	if data.is_empty():
		return
	data = _migrate(data, data.get("version", 1))
	_apply_structures(data.get("structures",   {}))
	_apply_group("chest", data.get("loose_chests", {}))
	_apply_group("door",  data.get("loose_doors",  {}))

## Lightweight summary for save-slot display (does not deserialize anything).
func get_save_metadata() -> Dictionary:
	var data := load_raw()
	if data.is_empty():
		return {}
	var ts: int = data.get("timestamp", 0)
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	return {
		"version":       data.get("version", 0),
		"timestamp":     ts,
		"timestamp_str": "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute],
		"seed":          data.get("world", {}).get("world_seed", 0),
		"level":         data.get("combat", {}).get("level", 1),
		"play_time_sec": 0,   # TODO: add playtime tracking in Phase 8
	}

## Raw JSON dict — use only for migration / metadata inspection.
func load_raw() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager.load_raw: cannot read '%s'." % SAVE_PATH)
		EventBus.load_failed.emit("Could not read save file.")
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null:
		push_error("SaveManager.load_raw: JSON parse failed.")
		EventBus.load_failed.emit("Save file is corrupted.")
		return {}
	return parsed

# ══════════════════════════════════════════════════════════════════════════════
# PLAYER SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════

func _serialize_player(player: Node) -> Dictionary:
	var d: Dictionary = {
		"position_x":      player.global_position.x,
		"position_y":      player.global_position.y,
		"current_health":  player.current_health,
		"current_stamina": player.current_stamina,
	}
	if player.stat_block:
		d["stat_block"] = player.stat_block.serialize()
	return d

func _apply_player(player: Node, pd: Dictionary) -> void:
	if pd.is_empty():
		return
	player.global_position = Vector2(
		pd.get("position_x", player.global_position.x),
		pd.get("position_y", player.global_position.y)
	)
	player.current_health  = pd.get("current_health",  player.stat_block.get_max_health())
	player.current_stamina = pd.get("current_stamina", player.stat_block.get_max_stamina())
	if player.stat_block and pd.has("stat_block"):
		player.stat_block.deserialize(pd["stat_block"])

# ══════════════════════════════════════════════════════════════════════════════
# STRUCTURE SERIALIZATION
# Structures register themselves to the "structure" group in Structure._ready().
# ══════════════════════════════════════════════════════════════════════════════

func _serialize_structures() -> Dictionary:
	var result: Dictionary = {}
	var nodes := get_tree().get_nodes_in_group("structure")
	for node in nodes:
		if node.has_method("serialize"):
			var key := _pos_key(node.global_position)
			result[key] = node.serialize()
	return result

func _apply_structures(data: Dictionary) -> void:
	var nodes := get_tree().get_nodes_in_group("structure")
	for node in nodes:
		if node.has_method("deserialize"):
			var key := _pos_key(node.global_position)
			if data.has(key):
				node.deserialize(data[key])

# ══════════════════════════════════════════════════════════════════════════════
# LOOSE OBJECT GROUPS (Chest, Door not inside a Structure)
# Register with add_to_group("chest") and add_to_group("door") in _ready().
# ══════════════════════════════════════════════════════════════════════════════

func _serialize_group(group_name: String) -> Dictionary:
	var result: Dictionary = {}
	for node in get_tree().get_nodes_in_group(group_name):
		if node.has_method("get_state"):
			result[_pos_key(node.global_position)] = node.get_state()
	return result

func _apply_group(group_name: String, data: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if node.has_method("apply_state"):
			var key := _pos_key(node.global_position)
			if data.has(key):
				node.apply_state(data[key])

# ══════════════════════════════════════════════════════════════════════════════
# MIGRATION
# ══════════════════════════════════════════════════════════════════════════════

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# v1 → v2: world data moved under "world" key.
	if from_version < 2:
		if not data.has("world"):
			data["world"] = {
				"world_seed":       data.get("seed", 0),
				"generated_chunks": {},
				"modified_chunks":  {},
			}

	# v2 → v3: add combat, structures, loose_chests, loose_doors keys.
	if from_version < 3:
		if not data.has("combat"):
			data["combat"] = {}
		if not data.has("structures"):
			data["structures"] = {}
		if not data.has("loose_chests"):
			data["loose_chests"] = {}
		if not data.has("loose_doors"):
			data["loose_doors"] = {}

	return data

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Position-based key — unique per world object as long as nothing overlaps exactly.
func _pos_key(world_pos: Vector2) -> String:
	return "%.0f_%.0f" % [world_pos.x, world_pos.y]

func _timestamp_str() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
