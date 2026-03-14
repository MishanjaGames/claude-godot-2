extends WeaponItem
class_name RangedWeapon

# ─── Ranged-specific stats ────────────────────────────────
@export var projectile_speed:  float  = 400.0
@export var projectile_range:  float  = 500.0  # max travel distance
@export var ammo_type:         String = "arrow"
@export var projectile_scene:  PackedScene = null  # assign in Inspector

func apply_type_defaults() -> void:
	damage           = 12.0
	attack_speed     = 0.9
	projectile_speed = 400.0
	projectile_range = 500.0

func attack(user: Node, targets: Array[Node]) -> void:
	if not can_attack():
		return

	# Check ammo
	if user.has_method("get") and user.get("inventory") != null:
		if not user.inventory.has_item(ammo_type):
			print("[Bow] No ammo!")
			return
		user.inventory.remove_item(ammo_type, 1)

	_cooldown = 1.0 / attack_speed
	_spawn_projectile(user)
	attack_performed.emit(self, user, [])

func _spawn_projectile(user: Node) -> void:
	if projectile_scene == null:
		print("[Bow] No projectile scene assigned!")
		return

	var projectile = projectile_scene.instantiate()
	user.get_tree().current_scene.add_child(projectile)
	projectile.global_position = user.global_position
	projectile.setup(
		Vector2.RIGHT.rotated(user.rotation),
		projectile_speed,
		projectile_range,
		damage + user.stats.get_stat("attack")
	)

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"]["projectile_speed"] = projectile_speed
	base["weapon"]["projectile_range"] = projectile_range
	base["weapon"]["ammo_type"]        = ammo_type
	return base
