# StatusEffect.gd
# Base Resource for a single buff or debuff applied to an Entity.
# Create .tres files for each effect (poison, burn, slow, regen, etc.)
# Entity._process() ticks active effects and removes expired ones.
#
# ADDING A NEW EFFECT:
#   1. Right-click FileSystem → New Resource → StatusEffect
#   2. Fill in the fields below
#   3. Pass the resource to entity.apply_status_effect(effect)
class_name StatusEffect
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String              = ""
@export var display_name: String    = "Effect"
@export var description: String     = ""
@export var icon: Texture2D         = null
@export var is_debuff: bool         = true    # false = buff (shown differently in UI)
@export var is_unique: bool         = true    # if true, applying again refreshes duration

# ── Timing ─────────────────────────────────────────────────────────────────────
@export var duration: float         = 5.0     # seconds; -1 = permanent until removed
@export var tick_interval: float    = 1.0     # seconds between damage/heal ticks

# ── Per-tick effects ───────────────────────────────────────────────────────────
@export_group("Tick Effects")
@export var damage_per_tick: int    = 0       # physical damage each tick
@export var magic_per_tick: int     = 0       # magic damage each tick
@export var heal_per_tick: int      = 0       # healing each tick

# ── Stat modifiers (applied for the full duration, not per tick) ───────────────
@export_group("Stat Modifiers")
@export var move_speed_add: float   = 0.0     # flat addition (negative = slow)
@export var move_speed_mul: float   = 1.0     # multiplier (0.5 = 50% speed)
@export var attack_add: int         = 0
@export var defence_add: int        = 0
@export var stamina_regen_mul: float = 1.0   # 0.0 = blocks stamina regen

# ── Visual feedback ────────────────────────────────────────────────────────────
@export_group("Visual")
@export var tint_color: Color       = Color.WHITE    # entity tint while active
@export var particle_scene: PackedScene = null       # optional VFX scene
