# QuestManager.gd
# Tracks active quests, their stages, and objective completion.
# Quests are defined as Dictionaries (no separate Resource class needed —
# they are simple enough to define inline or load from JSON).
#
# QUEST FORMAT:
# {
#   "id":          String,
#   "title":       String,
#   "description": String,
#   "stages": [
#     {                                  # stage 0 = first stage
#       "description": String,           # shown in journal
#       "objectives":  [                 # all must complete to auto-advance
#         { "type": "kill",    "target_id": String, "required": int },
#         { "type": "collect", "item_id":   String, "required": int },
#         { "type": "reach",   "location":  String              },
#         { "type": "talk",    "npc_id":    String              },
#         { "type": "use",     "item_id":   String              },
#       ],
#       "on_complete": Callable,         # optional — called when stage finishes
#     },
#   ],
# }
#
# LOAD ORDER: after EventBus, Registry, InventoryManager.
extends Node

# ── Runtime state ──────────────────────────────────────────────────────────────
## quest_id → { "stage": int, "progress": Dictionary }
var _active:    Dictionary = {}
## quest_ids that have been fully completed.
var _completed: Array[String] = []

# ── Quest library (id → quest dict) ───────────────────────────────────────────
var _library: Dictionary = {}

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	EventBus.entity_killed_enemy.connect(_on_entity_killed)
	EventBus.inventory_item_added.connect(_on_item_added)
	EventBus.npc_dialogue_ended.connect(_on_npc_dialogue_ended)
	EventBus.key_item_used.connect(_on_key_item_used)

# ══════════════════════════════════════════════════════════════════════════════
# QUEST REGISTRATION
# ══════════════════════════════════════════════════════════════════════════════

## Register a quest definition. Call from a game-specific script or data loader.
func register_quest(quest: Dictionary) -> void:
	var id: String = quest.get("id", "")
	if id.is_empty():
		push_warning("QuestManager.register_quest: quest has no id.")
		return
	_library[id] = quest

## Register multiple quests at once.
func register_quests(quests: Array) -> void:
	for q in quests:
		register_quest(q)

# ══════════════════════════════════════════════════════════════════════════════
# QUEST FLOW
# ══════════════════════════════════════════════════════════════════════════════

## Start a quest. Ignored if already active or completed.
func start_quest(quest_id: String) -> void:
	if is_completed(quest_id) or is_active(quest_id):
		return
	if not _library.has(quest_id):
		push_warning("QuestManager.start_quest: unknown id '%s'." % quest_id)
		return
	_active[quest_id] = { "stage": 0, "progress": {} }
	EventBus.quest_updated.emit(quest_id, 0)
	EventBus.hud_show_message.emit("Quest started: %s" % _get_title(quest_id), 3.0)
	_init_progress(quest_id)

## Manually advance a quest to the next stage (use for cutscene / trigger-based advancement).
func advance_quest(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	_next_stage(quest_id)

## Force-complete a quest regardless of objectives.
func complete_quest(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	_active.erase(quest_id)
	_completed.append(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.hud_show_message.emit("Quest complete: %s" % _get_title(quest_id), 3.5)

## Abandon a quest (removes from active, does not mark as completed).
func abandon_quest(quest_id: String) -> void:
	_active.erase(quest_id)

# ══════════════════════════════════════════════════════════════════════════════
# QUERIES
# ══════════════════════════════════════════════════════════════════════════════

func is_active(quest_id: String) -> bool:
	return _active.has(quest_id)

func is_completed(quest_id: String) -> bool:
	return quest_id in _completed

func get_stage(quest_id: String) -> int:
	return _active.get(quest_id, {}).get("stage", -1)

func get_active_quests() -> Array:
	return _active.keys()

func get_completed_quests() -> Array:
	return _completed.duplicate()

## Returns progress dict for a specific quest + stage objective.
## e.g. get_progress("kill_slimes", 0, "slime") → 3  (killed 3 slimes so far)
func get_progress(quest_id: String, stage: int, objective_key: String) -> int:
	var q := _active.get(quest_id, {})
	return q.get("progress", {}).get("%d_%s" % [stage, objective_key], 0)

# ══════════════════════════════════════════════════════════════════════════════
# OBJECTIVE TRACKING (signal handlers)
# ══════════════════════════════════════════════════════════════════════════════

func _on_entity_killed(_killer: Node, victim: Node) -> void:
	if not "npc_data" in victim or victim.npc_data == null:
		return
	var target_id: String = victim.npc_data.id
	_tick_objective("kill", target_id)

func _on_item_added(item: Resource, _slot: int) -> void:
	if not "id" in item:
		return
	_tick_objective("collect", item.id)

func _on_npc_dialogue_ended(npc: Node) -> void:
	if not "npc_data" in npc or npc.npc_data == null:
		return
	_tick_objective("talk", npc.npc_data.id)

func _on_key_item_used(quest_id: String, item: Resource, _user: Node) -> void:
	if not quest_id.is_empty():
		_tick_objective("use", item.get("id", ""))
	# Also check if using this item completes a "use" objective.
	if "id" in item:
		_tick_objective("use", item.id)

## Increment progress for a given objective type + target across all active quests.
func _tick_objective(obj_type: String, target: String) -> void:
	for quest_id in _active.keys():
		var q     := _active[quest_id]
		var stage := q["stage"]
		var quest := _library.get(quest_id, {})
		var stages: Array = quest.get("stages", [])
		if stage >= stages.size():
			continue
		var objectives: Array = stages[stage].get("objectives", [])
		for obj in objectives:
			if obj.get("type", "") != obj_type:
				continue
			var key_field := "target_id" if obj_type == "kill" else "item_id" if obj_type in ["collect", "use"] else "npc_id"
			if obj.get(key_field, "") != target:
				continue
			var prog_key := "%d_%s" % [stage, target]
			q["progress"][prog_key] = q["progress"].get(prog_key, 0) + 1
			_check_stage_complete(quest_id)
			return

# ══════════════════════════════════════════════════════════════════════════════
# STAGE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

func _check_stage_complete(quest_id: String) -> void:
	var q     := _active.get(quest_id, {})
	var stage := q.get("stage", 0)
	var quest := _library.get(quest_id, {})
	var stages: Array = quest.get("stages", [])
	if stage >= stages.size():
		return
	var objectives: Array = stages[stage].get("objectives", [])

	for obj in objectives:
		var required: int = obj.get("required", 1)
		var type: String  = obj.get("type", "")
		var key_field := "target_id" if type == "kill" \
			else "item_id" if type in ["collect","use"] \
			else "npc_id"
		var target: String = obj.get(key_field, "")
		var prog_key := "%d_%s" % [stage, target]
		if q["progress"].get(prog_key, 0) < required:
			return   # at least one objective not met

	_next_stage(quest_id)

func _next_stage(quest_id: String) -> void:
	var q     := _active[quest_id]
	var quest := _library.get(quest_id, {})
	var stages: Array = quest.get("stages", [])
	var current_stage := q["stage"]

	# Fire on_complete callback for the finishing stage.
	var stage_data := stages[current_stage] if current_stage < stages.size() else {}
	if stage_data.has("on_complete"):
		(stage_data["on_complete"] as Callable).call()

	var next_stage := current_stage + 1
	if next_stage >= stages.size():
		complete_quest(quest_id)
		return

	q["stage"] = next_stage
	EventBus.quest_updated.emit(quest_id, next_stage)
	var desc: String = stages[next_stage].get("description", "")
	if not desc.is_empty():
		EventBus.hud_show_message.emit(desc, 3.5)
	_init_progress(quest_id)

func _init_progress(quest_id: String) -> void:
	# Pre-seed collect objectives with current inventory counts.
	var q     := _active[quest_id]
	var quest := _library.get(quest_id, {})
	var stage := q["stage"]
	var stages: Array = quest.get("stages", [])
	if stage >= stages.size():
		return
	for obj in stages[stage].get("objectives", []):
		if obj.get("type", "") == "collect":
			var item_id: String = obj.get("item_id", "")
			var already := InventoryManager.count_item(item_id)
			if already > 0:
				var prog_key := "%d_%s" % [stage, item_id]
				q["progress"][prog_key] = already
	_check_stage_complete(quest_id)

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	return {
		"active":    _active.duplicate(true),
		"completed": _completed.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	_active    = data.get("active",    {})
	_completed = data.get("completed", [])

# ── Helper ─────────────────────────────────────────────────────────────────────

func _get_title(quest_id: String) -> String:
	return _library.get(quest_id, {}).get("title", quest_id)
