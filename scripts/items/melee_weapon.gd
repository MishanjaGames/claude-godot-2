extends WeaponItem
class_name MeleeWeapon

# ─── Melee-specific stats ─────────────────────────────────
@export var range:        float = 60.0   # how far the hit reaches
@export var hit_angle:    float = 90.0   # arc width in degrees  (sword)
@export var pierce_count: int   = 1      # how many enemies hit   (spear: more)
@export var hit_all_around: bool = false # true = 360° spin       (axe special)

# Per-type defaults — call after setting weapon_type
func apply_type_defaults() -> void:
	match weapon_type:
		WeaponType.SWORD:
			damage        = 15.0
			attack_speed  = 1.2
			range         = 60.0
			hit_angle     = 90.0
			pierce_count  = 1
			knockback     = 80.0
		WeaponType.AXE:
			damage        = 22.0
			attack_speed  = 0.8   # slower
			range         = 55.0
			hit_angle     = 120.0
			pierce_count  = 2     # can hit two enemies
			knockback     = 150.0 # heavy knockback
		WeaponType.SPEAR:
			damage        = 12.0
			attack_speed  = 1.5   # faster
			range         = 110.0 # longest reach
			hit_angle     = 40.0  # narrow arc
			pierce_count  = 3     # pierces through enemies

func attack(user: Node, targets: Array[Node]) -> void:
	if not can_attack():
		return
	_cooldown = 1.0 / attack_speed

	var hits: Array[Node] = _filter_targets(user, targets)
	for target in hits:
		_apply_hit(user, target)

	attack_performed.emit(self, user, hits)

func _filter_targets(user: Node, targets: Array[Node]) -> Array[Node]:
	var hits:   Array[Node] = []
	var origin: Vector2     = user.global_position

	for target in targets:
		if hits.size() >= pierce_count and not hit_all_around:
			break

		var to_target: Vector2 = target.global_position - origin

		# Range check
		if to_target.length() > range:
			continue

		# Angle check (skip if 360°)
		if not hit_all_around:
			var facing: Vector2 = Vector2.RIGHT.rotated(user.rotation)
			var angle_deg: float = rad_to_deg(facing.angle_to(to_target.normalized()))
			if abs(angle_deg) > hit_angle / 2.0:
				continue

		hits.append(target)

	return hits

func _apply_hit(user: Node, target: Node) -> void:
	# Apply damage if target has Stats
	if target.has_method("get") and target.get("stats") != null:
		target.stats.take_damage(damage + user.stats.get_stat("attack"))

	# Apply knockback if target is a physics body
	if target is CharacterBody2D and knockback > 0.0:
		var direction: Vector2 = (target.global_position - user.global_position).normalized()
		target.velocity += direction * knockback

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["weapon"]["range"]          = range
	base["weapon"]["hit_angle"]      = hit_angle
	base["weapon"]["pierce_count"]   = pierce_count
	base["weapon"]["hit_all_around"] = hit_all_around
	return base
