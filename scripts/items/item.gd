extends Resource
class_name Item

signal used(by: Node)

@export var id:             String    = ""
@export var name:           String    = "Item"
@export var description:    String    = ""
@export var icon:           Texture2D = null
@export var stackable:      bool      = false
@export var max_stack:      int       = 1
@export var stat_modifiers: Dictionary = {}

func use(by: Node) -> void:
	used.emit(by)

func get_tooltip() -> String:
	var lines := [name, description]
	for stat in stat_modifiers:
		var val: float = stat_modifiers[stat]
		var sign_str := "+" if val >= 0 else ""
		lines.append("%s%s %s" % [sign_str, val, stat])
	return "\n".join(lines)

func to_dict() -> Dictionary:
	return {
		"id":             id,
		"name":           name,
		"description":    description,
		"stackable":      stackable,
		"max_stack":      max_stack,
		"stat_modifiers": stat_modifiers,
	}

func print_info() -> void:
	print(JSON.stringify(to_dict(), "\t"))
