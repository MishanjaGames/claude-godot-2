# Tool.gd
class_name Tool
extends Item

enum ToolType { AXE, PICKAXE, SHOVEL, GENERIC }

@export var tool_type: ToolType = ToolType.GENERIC
@export var tool_power: int     = 1   # used by world objects to determine yield

func use(user: Node) -> void:
	var pos = user.global_position if "global_position" in user else Vector2.ZERO
	EventBus.tool_used.emit(tool_type, user, pos)
