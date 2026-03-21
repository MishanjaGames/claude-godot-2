# WeaponData.gd
# Base weapon Resource. Extend with MeleeData or RangedData.
# Combat logic lives in Entity subclasses — this is data only.
class_name WeaponData
extends ItemData

enum DamageType { PHYSICAL, FIRE, ICE, POISON, LIGHTNING, MAGIC }

# ── Combat stats ───────────────────────────────────────────────────────────────
@export var damage: int               = 10
@export var attack_speed: float       = 1.0    # attacks per second
@export var attack_range: float       = 48.0   # pixels
@export var knockback_force: float    = 150.0
@export var damage_type: DamageType   = DamageType.PHYSICAL

# ── On-hit effects ─────────────────────────────────────────────────────────────
## These StatusEffects are applied to the target on a successful hit.
@export var on_hit_effects: Array[StatusEffect] = []
## Chance (0.0–1.0) to apply on_hit_effects per hit.
@export var on_hit_chance: float      = 1.0

# ── Cooldown (runtime, not exported) ──────────────────────────────────────────
var _cooldown: float = 0.0

func tick_cooldown(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func is_ready() -> bool:
	return _cooldown <= 0.0

func start_cooldown() -> void:
	_cooldown = 1.0 / maxf(0.01, attack_speed)
