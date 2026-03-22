# AchievementManager.gd
# Tracks one-time achievements. Listens to EventBus; no manual calls needed
# for standard triggers. Custom achievements call unlock() directly.
#
# ACHIEVEMENT FORMAT (register via register_achievement()):
# {
#   "id":          String,
#   "title":       String,
#   "description": String,
#   "icon":        Texture2D | null,
#   "hidden":      bool,      # if true, description is "???" until unlocked
#   "trigger":     String,    # EventBus signal name that auto-checks this
#   "condition":   Callable,  # optional — returns bool, called on trigger
# }
#
# LOAD ORDER: after EventBus, CombatManager, InventoryManager.
extends Node

var _library:   Dictionary = {}    # id → achievement dict
var _unlocked:  Array[String] = [] # permanently unlocked ids

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_register_builtin()
	_wire_triggers()

# ══════════════════════════════════════════════════════════════════════════════
# REGISTRATION
# ══════════════════════════════════════════════════════════════════════════════

func register_achievement(achievement: Dictionary) -> void:
	var id: String = achievement.get("id", "")
	if id.is_empty():
		push_warning("AchievementManager: achievement has no id.")
		return
	_library[id] = achievement

func register_achievements(list: Array) -> void:
	for a in list:
		register_achievement(a)

# ══════════════════════════════════════════════════════════════════════════════
# UNLOCK
# ══════════════════════════════════════════════════════════════════════════════

func unlock(id: String) -> void:
	if id in _unlocked or not _library.has(id):
		return
	_unlocked.append(id)
	var a: Dictionary = _library[id]
	EventBus.achievement_unlocked.emit(id)
	EventBus.hud_show_message.emit("Achievement: %s" % a.get("title", id), 4.0)

func is_unlocked(id: String) -> bool:
	return id in _unlocked

func get_all() -> Array:
	return _library.values()

func get_unlocked() -> Array:
	return _unlocked.duplicate()

func get_locked() -> Array:
	return _library.keys().filter(func(id): return not is_unlocked(id))

# ══════════════════════════════════════════════════════════════════════════════
# BUILT-IN ACHIEVEMENTS
# ══════════════════════════════════════════════════════════════════════════════

func _register_builtin() -> void:
	register_achievements([
		{
			"id": "first_blood",
			"title": "First Blood",
			"description": "Kill your first enemy.",
			"hidden": false,
			"trigger": "entity_killed_enemy",
		},
		{
			"id": "lumberjack",
			"title": "Lumberjack",
			"description": "Chop down 10 trees.",
			"hidden": false,
			"trigger": "harvestable_destroyed",
			"condition": func(): return _count("trees_chopped") >= 10,
		},
		{
			"id": "miner",
			"title": "Miner",
			"description": "Mine 20 ore veins.",
			"hidden": false,
			"trigger": "harvestable_destroyed",
			"condition": func(): return _count("ores_mined") >= 20,
		},
		{
			"id": "well_equipped",
			"title": "Well Equipped",
			"description": "Fill all 6 equipment slots.",
			"hidden": false,
			"trigger": "equipment_changed",
			"condition": func():
				for i in InventoryManager.EQUIP_SLOTS:
					if InventoryManager.equip_slots[i] == null:
						return false
				return true,
		},
		{
			"id": "level_5",
			"title": "Seasoned",
			"description": "Reach level 5.",
			"hidden": false,
			"trigger": "level_up",
			"condition": func(): return CombatManager.current_level >= 5,
		},
		{
			"id": "level_10",
			"title": "Veteran",
			"description": "Reach the maximum level.",
			"hidden": true,
			"trigger": "level_up",
			"condition": func(): return CombatManager.current_level >= CombatManager.MAX_LEVEL,
		},
		{
			"id": "crafter",
			"title": "Crafter",
			"description": "Craft 10 items.",
			"hidden": false,
			"trigger": "inventory_item_used",
			"condition": func(): return _count("items_crafted") >= 10,
		},
		{
			"id": "explorer",
			"title": "Explorer",
			"description": "Discover all 4 biomes.",
			"hidden": false,
			"trigger": "player_chunk_changed",
			"condition": func(): return _get_set("biomes_visited").size() >= 4,
		},
		{
			"id": "around_the_world",
			"title": "Around the World",
			"description": "Wrap around the planet.",
			"hidden": true,
			"trigger": "player_world_wrapped",
		},
		{
			"id": "survivor",
			"title": "Survivor",
			"description": "Survive 10 in-game days.",
			"hidden": false,
			"trigger": "day_elapsed",
			"condition": func(): return DayNightCycle.day_count >= 10,
		},
		{
			"id": "full_inventory",
			"title": "Pack Rat",
			"description": "Fill every inventory slot.",
			"hidden": false,
			"trigger": "inventory_full",
		},
		{
			"id": "quest_complete_first",
			"title": "On a Mission",
			"description": "Complete your first quest.",
			"hidden": false,
			"trigger": "quest_completed",
		},
	])

# ══════════════════════════════════════════════════════════════════════════════
# TRIGGER WIRING
# ══════════════════════════════════════════════════════════════════════════════

func _wire_triggers() -> void:
	# Generic handler: for each achievement whose trigger matches the signal,
	# check its condition (if any) then unlock.
	var triggers := {}
	for id in _library:
		var trig: String = _library[id].get("trigger", "")
		if trig.is_empty():
			continue
		if not triggers.has(trig):
			triggers[trig] = []
		triggers[trig].append(id)

	for signal_name in triggers:
		if not EventBus.has_signal(signal_name):
			continue
		var ids_to_check: Array = triggers[signal_name]
		EventBus.connect(signal_name, func(_a=null,_b=null,_c=null):
			for ach_id in ids_to_check:
				_check(ach_id)
		)

	# Specific counters wired manually.
	EventBus.harvestable_destroyed.connect(_on_harvestable_destroyed)
	EventBus.inventory_item_used.connect(func(_i,_u): _increment("items_crafted"))
	EventBus.player_chunk_changed.connect(_on_chunk_changed)

func _check(id: String) -> void:
	if is_unlocked(id):
		return
	var a: Dictionary = _library.get(id, {})
	var condition = a.get("condition", null)
	if condition == null or condition.call():
		unlock(id)

# ══════════════════════════════════════════════════════════════════════════════
# COUNTERS  (lightweight in-memory stats for condition checks)
# ══════════════════════════════════════════════════════════════════════════════

var _counters: Dictionary = {}
var _sets:     Dictionary = {}

func _increment(key: String, amount: int = 1) -> void:
	_counters[key] = _counters.get(key, 0) + amount

func _count(key: String) -> int:
	return _counters.get(key, 0)

func _set_add(key: String, value: String) -> void:
	if not _sets.has(key):
		_sets[key] = {}
	_sets[key][value] = true

func _get_set(key: String) -> Dictionary:
	return _sets.get(key, {})

func _on_harvestable_destroyed(node: Node, _pos: Vector2) -> void:
	if not "npc_data" in node:   # it's a harvestable, not an NPC
		if node.has_method("_data") or "_data" in node:
			var data = node.get("_data")
			if data and "id" in data:
				if "tree" in data.id:
					_increment("trees_chopped")
				elif "vein" in data.id or "ore" in data.id:
					_increment("ores_mined")

func _on_chunk_changed(_old: Vector2i, _new: Vector2i) -> void:
	var chunk_mgr := get_tree().get_first_node_in_group("chunk_manager")
	if not chunk_mgr or not "_generator" in chunk_mgr:
		return
	var player := GameManager.player_ref
	if player == null:
		return
	var biome = chunk_mgr._generator.get_biome_at(
		WorldManager.world_pos_to_tile(player.global_position).x)
	if biome:
		_set_add("biomes_visited", biome.id)

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	return {
		"unlocked":  _unlocked.duplicate(),
		"counters":  _counters.duplicate(),
		"sets":      _sets.duplicate(true),
	}

func deserialize(data: Dictionary) -> void:
	_unlocked = data.get("unlocked", [])
	_counters = data.get("counters", {})
	_sets     = data.get("sets",     {})
