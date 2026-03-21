# RangedData.gd
# Ranged weapon specifics. Spawns a Projectile scene on attack.
class_name RangedData
extends WeaponData

# ── Ammunition ────────────────────────────────────────────────────────────────
## Item id of the required ammo. Empty string = unlimited/no ammo required.
@export var ammo_item_id: String        = ""
@export var ammo_count: int             = 30       # magazine capacity
@export var reload_time: float          = 1.5      # seconds

# ── Projectile ────────────────────────────────────────────────────────────────
## The PackedScene spawned per shot. Must have a setup(dir, damage) method.
@export var projectile_scene: PackedScene = null
@export var projectile_speed: float     = 400.0
@export var piercing: bool              = false    # survives first hit
## Number of projectiles per shot (1 = single, 3 = spread shot, etc.)
@export var projectiles_per_shot: int   = 1
## Spread angle in degrees between projectiles when projectiles_per_shot > 1.
@export var spread_angle: float         = 15.0

# ── Runtime (not exported) ───────────────────────────────────────────────────
var _current_ammo: int   = 0
var _is_reloading: bool  = false

func init_ammo() -> void:
	_current_ammo = ammo_count

func consume_ammo() -> bool:
	if ammo_item_id.is_empty():
		return true           # unlimited
	if _current_ammo <= 0:
		return false
	_current_ammo -= 1
	return true

func needs_reload() -> bool:
	if ammo_item_id.is_empty():
		return false
	return _current_ammo <= 0
