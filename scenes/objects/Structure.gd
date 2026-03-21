# Structure.gd
# Optional root script for complex structures (buildings, dungeons, caves).
# Attach to a Node2D that is the logical root of a multi-object structure.
# Provides enter/exit detection and a unified interface for saving child states.
#
# SCENE TREE (Structure.tscn — base template):
#   Structure              [Node2D]     ← this script
#   ├── InteriorArea       [Area2D]     (covers the interior footprint)
#   │   └── CollisionShape2D           (RectangleShape2D — set to interior size)
#   └── Objects            [Node2D]    (children: Chest, Door, NPC, etc.)
class_name Structure
extends Node2D

@export var structure_id: String = ""   # matches StructureData.id
@export var structure_name: String = "Structure"

# ── Runtime ────────────────────────────────────────────────────────────────────
var _entities_inside: Array[Node] = []

@onready var interior_area: Area2D = $InteriorArea
@onready var objects:       Node2D = $Objects

func _ready() -> void:
	interior_area.body_entered.connect(_on_body_entered)
	interior_area.body_exited.connect(_on_body_exited)

# ── Enter / exit ───────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if not _entities_inside.has(body):
		_entities_inside.append(body)
	EventBus.structure_entered.emit(self, body)

func _on_body_exited(body: Node) -> void:
	_entities_inside.erase(body)
	EventBus.structure_exited.emit(self, body)

func is_player_inside() -> bool:
	return GameManager.player_ref != null and _entities_inside.has(GameManager.player_ref)

# ── Child object queries ───────────────────────────────────────────────────────

## Returns all Chest nodes that are children of this structure.
func get_chests() -> Array:
	return objects.get_children().filter(func(c): return c is Chest)

## Returns all Door nodes that are children of this structure.
func get_doors() -> Array:
	return objects.get_children().filter(func(c): return c is Door)

# ══════════════════════════════════════════════════════════════════════════════
# SERIALIZATION
# Each child object that has get_state() / apply_state() is saved by index.
# SaveManager calls these via the Structure node's path in the scene tree.
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	var child_states: Dictionary = {}
	for i in objects.get_child_count():
		var child := objects.get_child(i)
		if child.has_method("get_state"):
			child_states[str(i)] = child.get_state()
	return {
		"structure_id": structure_id,
		"child_states": child_states,
	}

func deserialize(data: Dictionary) -> void:
	var child_states: Dictionary = data.get("child_states", {})
	for key in child_states:
		var idx := int(key)
		if idx < objects.get_child_count():
			var child := objects.get_child(idx)
			if child.has_method("apply_state"):
				child.apply_state(child_states[key])
