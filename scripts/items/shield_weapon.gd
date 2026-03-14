extends MeleeWeapon
class_name ShieldWeapon

signal block_started
signal block_ended

# How much damage is absorbed while blocking (0.6 = 60% absorbed)
@export var block_reduction:     float = 0.6
@export var bash_stun_duration:  float = 0.5

var _blocking: bool = false

func apply_type_defaults() -> void:
	weapon_type  = WeaponItem.WeaponType.SHIELD
	damage       = 6.0
	attack_speed = 0.7
	range        = 45.0
	hit_angle    = 70.0
	pierce_count = 1
	knockback    = 250.0   # heavy bash pushback

func start_block() -> void:
	_blocking = true
	block_started.emit()

func end_block() -> void:
	_blocking = false
	block_ended.emit()

func is_blocking() -> bool:
	return _blocking

# Returns the damage that passes through (rest is blocked)
func filter_damage(amount: float) -> float:
	if _blocking:
		return amount * (1.0 - block_reduction)
	return amount

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"]["block_reduction"]    = block_reduction
	base["weapon"]["bash_stun_duration"] = bash_stun_duration
	return base
