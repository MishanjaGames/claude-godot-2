# NPCData.gd
# Data resource defining a type of NPC.
# NPCBase reads one of these to initialise its stats instead of using @export vars.
# Create .tres files in res://data/npcs/
class_name NPCData
extends Resource

enum Faction { PEACEFUL, ALLY, HOSTILE }

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String                      = ""
@export var display_name: String            = "NPC"
@export var faction: Faction                = Faction.PEACEFUL
@export var is_boss: bool                   = false

# ── Appearance ────────────────────────────────────────────────────────────────
## Assign a SpriteFrames resource with: idle, walk, hurt, die, attack
@export var sprite_frames: SpriteFrames     = null
## Tint applied to the sprite (useful for colour variants without new sprites)
@export var sprite_modulate: Color          = Color.WHITE

# ── Stats ──────────────────────────────────────────────────────────────────────
@export_group("Stats")
@export var max_health: int                 = 50
@export var move_speed: float               = 80.0
## Applies a StatBlock for advanced stat modifiers. Optional.
@export var stat_block: StatBlock           = null

# ── Combat (for HOSTILE / ALLY factions) ─────────────────────────────────────
@export_group("Combat")
@export var attack_damage: int              = 8
@export var attack_range: float             = 40.0
@export var attack_cooldown: float          = 1.2
@export var alert_radius: float             = 180.0
@export var leash_radius: float             = 360.0   # gives up chase beyond this
@export var chase_speed_mult: float         = 1.25
@export var patrol_wait_time: float         = 1.5

# ── Dialogue (for PEACEFUL faction) ──────────────────────────────────────────
@export_group("Dialogue")
@export var dialogue: Array[String]         = []
@export var wander_radius: float            = 120.0
@export var wander_interval: float          = 3.0

# ── Drops ─────────────────────────────────────────────────────────────────────
@export_group("Loot")
@export var drop_table_id: String           = ""
@export var exp_reward: int                 = 0
