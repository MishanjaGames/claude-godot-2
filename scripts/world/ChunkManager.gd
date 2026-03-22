# Structure.gd  (patched — adds add_to_group)
class_name Structure
extends Node2D

@export var structure_id:   String = ""
@export var structure_name: String = "Structure"

var _entities_inside: Array[Node] = []

@onready var interior_area: Area2D = $InteriorArea
@onready var objects:       Node2D = $Objects

func _ready() -> void:
	add_to_group("structure")   # SaveManager scans this group
	interior_area.body_entered.connect(_on_body_entered)
	interior_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not _entities_inside.has(body):
		_entities_inside.append(body)
	EventBus.structure_entered.emit(self, body)

func _on_body_exited(body: Node) -> void:
	_entities_inside.erase(body)
	EventBus.structure_exited.emit(self, body)

func is_player_inside() -> bool:
	return GameManager.player_ref != null and _entities_inside.has(GameManager.player_ref)

func get_chests() -> Array:
	return objects.get_children().filter(func(c): return c is Chest)

func get_doors() -> Array:
	return objects.get_children().filter(func(c): return c is Door)

func serialize() -> Dictionary:
	var child_states: Dictionary = {}
	for i in objects.get_child_count():
		var child := objects.get_child(i)
		if child.has_method("get_state"):
			child_states[str(i)] = child.get_state()
	return { "structure_id": structure_id, "child_states": child_states }

func deserialize(data: Dictionary) -> void:
	var child_states: Dictionary = data.get("child_states", {})
	for key in child_states:
		var idx := int(key)
		if idx < objects.get_child_count():
			var child := objects.get_child(idx)
			if child.has_method("apply_state"):
				child.apply_state(child_states[key])
