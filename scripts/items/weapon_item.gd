extends Item
class_name WeaponItem

# ─── Signals ──────────────────────────────────────────────
signal attack_performed(weapon: WeaponItem, user: Node, targets: Array[Node])

# ─── Weapon identity ──────────────────────────────────────
enum WeaponType { SWORD, AXE, SPEAR, BOW, SHIELD, THROWABLE, STAFF }
@export var weapon_type: WeaponType = WeaponType.SWORD

# ─── Base weapon stats ────────────────────────────────────
@export var damage:        float = 10.0
@export var attack_speed:  float = 1.0   # attacks per second
@export var knockback:     float = 0.0   # pixels pushed back on hit

# ─── Internal cooldown tracker ────────────────────────────
var _cooldown: float = 0.0

func can_attack() -> bool:
	return _cooldown <= 0.0

func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

# Override in subclasses
func attack(user: Node, targets: Array[Node]) -> void:
	if not can_attack():
		return
	_cooldown = 1.0 / attack_speed
	attack_performed.emit(self, user, targets)

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"] = {
		"type":         WeaponType.keys()[weapon_type],
		"damage":       damage,
		"attack_speed": attack_speed,
		"knockback":    knockback,
	}
	return base
