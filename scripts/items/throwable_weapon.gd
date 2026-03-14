extends RangedWeapon
class_name ThrowableWeapon

enum ThrowableType { KNIFE, NEEDLE }

@export var throwable_type:       ThrowableType = ThrowableType.KNIFE
@export var returns_to_player:    bool          = false   # boomerang — future use

func apply_type_defaults() -> void:
	weapon_type = WeaponItem.WeaponType.THROWABLE
	match throwable_type:
		ThrowableType.KNIFE:
			damage           = 18.0
			attack_speed     = 1.5
			projectile_speed = 500.0
			projectile_range = 300.0
			ammo_type        = "knife"
		ThrowableType.NEEDLE:
			damage           = 8.0
			attack_speed     = 3.0    # very fast
			projectile_speed = 700.0
			projectile_range = 400.0
			ammo_type        = "needle"

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"]["throwable_type"]    = ThrowableType.keys()[throwable_type]
	base["weapon"]["returns_to_player"] = returns_to_player
	return base
