# HarvestableData.gd
# Data for any world object that can be hit with a tool and drops items.
# Covers trees, rock nodes, ore veins, bushes, crystal clusters, etc.
# Scene: scenes/objects/Harvestable.tscn reads from one of these resources.
class_name HarvestableData
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String              = ""
@export var display_name: String    = "Object"

# ── Health / destruction ──────────────────────────────────────────────────────
@export var max_health: int         = 3       # hits required to destroy

# ── Tool requirement ──────────────────────────────────────────────────────────
## ToolData.ToolType value. -1 means any tool (or bare hands).
@export var required_tool_type: int = -1
## Minimum tool_power to harvest. Lower-power tools deal 0 damage.
@export var min_tool_power: int     = 0
## Damage dealt per hit by the minimum-power tool. Scales with tool_power.
@export var base_hit_damage: int    = 1

# ── Drops ─────────────────────────────────────────────────────────────────────
@export var drop_table_id: String   = ""   # DropTable resource id in Registry

# ── Regrowth ──────────────────────────────────────────────────────────────────
## Seconds until this object respawns. -1 = never respawns.
@export var regrow_time: float      = -1.0

# ── Multi-stage appearance ────────────────────────────────────────────────────
## If true, the sprite changes as health decreases.
@export var is_multi_stage: bool    = false
## Health thresholds for each stage change (from full to lowest, descending).
## E.g. [6, 3] means: stage 0 above 6hp, stage 1 from 3-6hp, stage 2 below 3hp.
@export var stage_health_thresholds: Array[int]     = []
@export var stage_sprite_frames: Array[SpriteFrames] = []

# ── Audio ──────────────────────────────────────────────────────────────────────
@export var hit_sound_id: String    = ""
@export var break_sound_id: String  = ""

# ── Visual ────────────────────────────────────────────────────────────────────
@export var particle_color: Color   = Color.WHITE

# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns true if a tool of the given type and power can harvest this object.
func can_harvest(tool_type: int, tool_power: int) -> bool:
	if required_tool_type >= 0 and tool_type != required_tool_type:
		return false
	return tool_power >= min_tool_power

## Calculates hit damage scaled by tool power above the minimum.
func calculate_hit_damage(tool_power: int) -> int:
	if tool_power < min_tool_power:
		return 0
	var bonus = tool_power - min_tool_power
	return base_hit_damage + bonus

## Returns which stage index (0-based) corresponds to a given health value.
func get_stage(current_health: int) -> int:
	if not is_multi_stage or stage_health_thresholds.is_empty():
		return 0
	for i in stage_health_thresholds.size():
		if current_health > stage_health_thresholds[i]:
			return i
	return stage_health_thresholds.size()
