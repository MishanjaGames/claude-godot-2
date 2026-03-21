# ToolData.gd
# Tools interact with Harvestable world objects (trees, rocks, ores).
# tool_type and tool_power are matched against HarvestableData requirements.
class_name ToolData
extends ItemData

enum ToolType { AXE, PICKAXE, SHOVEL, SCYTHE, WATERING_CAN, BUCKET, FISHING_ROD, GENERIC }

@export var tool_type: ToolType     = ToolType.GENERIC
## Higher power mines faster and satisfies higher-tier harvestable requirements.
@export var tool_power: int         = 1
## Harvest speed multiplier (1.0 = normal, 2.0 = twice as fast).
@export var efficiency: float       = 1.0
## How many uses before the tool breaks. -1 = unbreakable.
@export var max_durability: int     = -1

# Runtime (not exported — saved per-slot in InventoryManager)
var current_durability: int = -1

func init_durability() -> void:
	current_durability = max_durability

func use_charge() -> bool:
	if max_durability < 0:
		return true    # unbreakable
	current_durability -= 1
	return current_durability > 0

func is_broken() -> bool:
	return max_durability >= 0 and current_durability <= 0

func use(user: Node) -> void:
	var pos = user.global_position if "global_position" in user else Vector2.ZERO
	EventBus.tool_used.emit(tool_type, user, pos)
