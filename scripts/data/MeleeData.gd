# MeleeData.gd
# Melee weapon specifics. The hitbox is an Area2D on the entity scene.
class_name MeleeData
extends WeaponData

# ── Hitbox shaping ─────────────────────────────────────────────────────────────
## Width of the attack hitbox capsule in pixels.
@export var hitbox_width: float         = 48.0
## Height (reach) of the hitbox in pixels.
@export var hitbox_height: float        = 32.0
## Degrees of the swing arc (visual only — actual hit is the hitbox).
@export var swing_arc: float            = 120.0

# ── Block ──────────────────────────────────────────────────────────────────────
@export var can_block: bool             = false
## Fraction of incoming physical damage blocked while holding block input.
@export var block_reduction: float      = 0.5
## Stamina cost per blocked hit.
@export var block_stamina_cost: float   = 20.0
