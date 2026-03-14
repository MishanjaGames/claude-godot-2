# WeaponBase.gd
class_name WeaponBase
extends Item

@export var damage: int             = 10
@export var attack_speed: float     = 1.0   # attacks per second
@export var attack_range: float     = 48.0
@export var knockback_force: float  = 150.0

var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

## Override in subclasses.
func attack(wielder: Node) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 1.0 / attack_speed
