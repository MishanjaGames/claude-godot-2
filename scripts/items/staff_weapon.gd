extends RangedWeapon
class_name StaffWeapon

enum StaffType { FIRE, ICE, LIGHTNING }

@export var staff_type:       StaffType = StaffType.FIRE
@export var mana_cost:        float     = 10.0
@export var spell_effect:     String    = ""     # "burn", "slow", "stun"
@export var effect_duration:  float     = 2.0

func apply_type_defaults() -> void:
	weapon_type = WeaponItem.WeaponType.STAFF
	ammo_type   = ""   # uses mana, not inventory items
	match staff_type:
		StaffType.FIRE:
			damage = 20.0;  attack_speed = 0.8
			projectile_speed = 350.0;  projectile_range = 450.0
			mana_cost = 10.0;  spell_effect = "burn";   effect_duration = 3.0
		StaffType.ICE:
			damage = 15.0;  attack_speed = 0.6
			projectile_speed = 300.0;  projectile_range = 400.0
			mana_cost = 12.0;  spell_effect = "slow";   effect_duration = 2.0
		StaffType.LIGHTNING:
			damage = 30.0;  attack_speed = 0.5
			projectile_speed = 800.0;  projectile_range = 500.0
			mana_cost = 20.0;  spell_effect = "stun";   effect_duration = 1.0

# Override to spend mana instead of inventory ammo
func attack(user: Node, targets: Array[Node]) -> void:
	if not can_attack():
		return
	if user.get("stats") != null:
		if not user.stats.spend_mana(mana_cost):   # ← clean, returns false if not enough
			print("[Staff] Not enough mana!")
			return
	_cooldown = 1.0 / attack_speed
	_spawn_projectile(user)
	attack_performed.emit(self, user, [])

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"]["staff_type"]      = StaffType.keys()[staff_type]
	base["weapon"]["mana_cost"]       = mana_cost
	base["weapon"]["spell_effect"]    = spell_effect
	base["weapon"]["effect_duration"] = effect_duration
	return base
