# Player.gd
# Extends Entity. Handles all player-controlled behaviour:
#   movement, sprinting, stamina, attacking, interaction, hotbar input, world wrap.
#
# SCENE TREE (Player.tscn):
#   Player          [CharacterBody2D]   ← this script
#   ├── CollisionShape2D                (CapsuleShape2D h=28 r=10)
#   ├── AnimatedSprite2D                (SpriteFrames: idle walk run attack hurt die)
#   ├── InteractRay    [RayCast2D]      (target=Vector2(36,0), enabled, collide_areas)
#   ├── HurtTimer      [Timer]          (one_shot, wait_time=0.4)
#   ├── AttackHitbox   [Area2D]         (position=Vector2(40,0), monitoring=false)
#   │   └── CollisionShape2D            (CapsuleShape2D h=32 r=16, rotation=90°)
#   └── StaminaRegenTimer [Timer]       (one_shot=false, wait_time=0.1)
extends Entity

# ── Animation names ────────────────────────────────────────────────────────────
const ANIM_IDLE:   String = "idle"
const ANIM_WALK:   String = "walk"
const ANIM_RUN:    String = "run"
const ANIM_ATTACK: String = "attack"
const ANIM_HURT:   String = "hurt"
const ANIM_DIE:    String = "die"

# ── Runtime state ──────────────────────────────────────────────────────────────
var _is_sprinting:       bool  = false
var _unarmed_cooldown:   float = 0.0
var _is_attacking:       bool  = false
var _attack_queued:      bool  = false   # buffer one attack input during animation
var _last_move_dir:      Vector2 = Vector2.RIGHT   # remembered for hitbox facing

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var interact_ray:   RayCast2D  = $InteractRay
@onready var hurt_timer:     Timer      = $HurtTimer
@onready var attack_hitbox:  Area2D     = $AttackHitbox

# ══════════════════════════════════════════════════════════════════════════════
# ENTITY HOOK
# ══════════════════════════════════════════════════════════════════════════════

func _on_entity_ready() -> void:
	GameManager.player_ref       = self
	attack_hitbox.monitoring     = false
	attack_hitbox.monitorable    = false
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	_emit_health()
	_emit_stamina()

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	_handle_attack(delta)
	_handle_interaction()
	_handle_hotbar_input()
	move_and_slide()
	apply_world_wrap()

# ══════════════════════════════════════════════════════════════════════════════
# MOVEMENT & STAMINA
# ══════════════════════════════════════════════════════════════════════════════

func _handle_movement(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("move_left",  "move_right"),
		Input.get_axis("move_up",    "move_down")
	).normalized()

	var can_sprint := current_stamina > stat_block.sprint_stamina_min and dir != Vector2.ZERO
	_is_sprinting  = Input.is_action_pressed("sprint") and can_sprint

	var speed := stat_block.get_move_speed() * (stat_block.sprint_multiplier if _is_sprinting else 1.0)
	velocity   = dir * speed

	# Stamina tick.
	if _is_sprinting:
		current_stamina = maxf(0.0, current_stamina - stat_block.stamina_drain * delta)
	else:
		var regen_mul := 1.0
		# Status effects can set stamina_regen_mul via modifier.
		current_stamina = minf(
			stat_block.get_max_stamina(),
			current_stamina + stat_block.stamina_regen * regen_mul * delta
		)
	_emit_stamina()

	# Facing.
	if dir.x != 0.0:
		anim_sprite.flip_h  = dir.x < 0.0
		_last_move_dir      = dir
		# Shift hitbox to the facing side.
		attack_hitbox.position.x = abs(attack_hitbox.position.x) * sign(dir.x)

	# Animation (don't interrupt attack or hurt).
	if not _is_attacking and anim_sprite.animation != ANIM_HURT:
		if dir == Vector2.ZERO:
			anim_sprite.play(ANIM_IDLE)
		elif _is_sprinting:
			anim_sprite.play(ANIM_RUN)
		else:
			anim_sprite.play(ANIM_WALK)

# ══════════════════════════════════════════════════════════════════════════════
# ATTACK
# ══════════════════════════════════════════════════════════════════════════════

func _handle_attack(delta: float) -> void:
	_unarmed_cooldown = maxf(0.0, _unarmed_cooldown - delta)

	# Tick active weapon cooldown.
	var active = InventoryManager.get_active_item()
	if active is WeaponData:
		active.tick_cooldown(delta)

	if Input.is_action_just_pressed("attack"):
		if _is_attacking:
			_attack_queued = true   # buffer for after current swing
		else:
			_do_attack()

func _do_attack() -> void:
	var active = InventoryManager.get_active_item()

	if active is MeleeData:
		_melee_attack(active as MeleeData)
	elif active is RangedData:
		_ranged_attack(active as RangedData)
	else:
		_unarmed_attack()

# ── Melee ─────────────────────────────────────────────────────────────────────

func _melee_attack(weapon: MeleeData) -> void:
	if not weapon.is_ready():
		return
	weapon.start_cooldown()
	_start_attack_anim(0.3)

	# Size the hitbox to the weapon.
	var col := attack_hitbox.get_child(0) as CollisionShape2D
	if col and col.shape is CapsuleShape2D:
		var cap := col.shape as CapsuleShape2D
		cap.height = weapon.hitbox_height
		cap.radius = weapon.hitbox_width * 0.5

	attack_hitbox.monitoring = true
	await get_tree().create_timer(0.12).timeout
	for body in attack_hitbox.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var damage := weapon.damage + stat_block.get_attack()
		if stat_block.roll_crit():
			damage = stat_block.apply_crit(damage)
			EventBus.hud_show_popup.emit("CRIT!", body.global_position, Color.YELLOW)
		body.take_damage(damage, WeaponData.DamageType.keys()[weapon.damage_type].to_lower(), self)
		_apply_on_hit_effects(weapon, body)
		var kb_dir := (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(kb_dir * weapon.knockback_force)
		EventBus.hud_show_popup.emit(str(damage), body.global_position, Color.WHITE)

	attack_hitbox.monitoring = false

# ── Ranged ────────────────────────────────────────────────────────────────────

func _ranged_attack(weapon: RangedData) -> void:
	if weapon._is_reloading:
		EventBus.hud_show_message.emit("Reloading…", 1.0)
		return
	if weapon.needs_reload():
		_start_reload(weapon)
		return
	if not weapon.is_ready():
		return

	weapon.start_cooldown()
	if not weapon.consume_ammo():
		_start_reload(weapon)
		return

	_start_attack_anim(0.2)

	if weapon.projectile_scene == null:
		push_warning("Player: RangedData '%s' has no projectile_scene." % weapon.id)
		return

	var base_dir := (get_global_mouse_position() - global_position).normalized()
	var count    := weapon.projectiles_per_shot

	for i in count:
		var angle_offset := 0.0
		if count > 1:
			var spread := deg_to_rad(weapon.spread_angle)
			angle_offset = lerp(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))

		var dir := base_dir.rotated(angle_offset)
		var proj: Node2D = weapon.projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		if proj.has_method("setup"):
			proj.setup(dir, weapon.damage + stat_block.get_attack(), weapon.piercing)

func _start_reload(weapon: RangedData) -> void:
	weapon._is_reloading = true
	EventBus.hud_show_message.emit("Reloading…", weapon.reload_time)
	await get_tree().create_timer(weapon.reload_time).timeout
	weapon.init_ammo()
	weapon._is_reloading = false
	EventBus.hud_show_message.emit("Reloaded.", 1.5)

# ── Unarmed ───────────────────────────────────────────────────────────────────

func _unarmed_attack() -> void:
	if _unarmed_cooldown > 0.0:
		return
	_unarmed_cooldown = 0.55
	_start_attack_anim(0.25)

	attack_hitbox.monitoring = true
	await get_tree().create_timer(0.1).timeout
	for body in attack_hitbox.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var damage := stat_block.get_attack()
		body.take_damage(damage, "physical", self)
		EventBus.hud_show_popup.emit(str(damage), body.global_position, Color.WHITE)
	attack_hitbox.monitoring = false

# ── Attack anim helper ────────────────────────────────────────────────────────

func _start_attack_anim(duration: float) -> void:
	_is_attacking = true
	anim_sprite.play(ANIM_ATTACK)
	await get_tree().create_timer(duration).timeout
	_is_attacking = false
	if _attack_queued:
		_attack_queued = false
		_do_attack()

# ── On-hit effects ────────────────────────────────────────────────────────────

func _apply_on_hit_effects(weapon: WeaponData, target: Node) -> void:
	if weapon.on_hit_effects.is_empty():
		return
	if randf() > weapon.on_hit_chance:
		return
	for effect in weapon.on_hit_effects:
		if target.has_method("apply_status_effect"):
			target.apply_status_effect(effect.duplicate())

# ══════════════════════════════════════════════════════════════════════════════
# INTERACTION
# ══════════════════════════════════════════════════════════════════════════════

func _handle_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var obj := interact_ray.get_collider()
	if obj and obj.has_method("interact"):
		obj.interact(self)
		EventBus.player_interacted.emit(obj)

# ══════════════════════════════════════════════════════════════════════════════
# HOTBAR INPUT
# ══════════════════════════════════════════════════════════════════════════════

func _handle_hotbar_input() -> void:
	# Number keys 1–8.
	for i in 8:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			InventoryManager.set_active_hotbar(i)
			return
	# Scroll wheel.
	if Input.is_action_just_pressed("hotbar_next"):
		InventoryManager.scroll_hotbar(1)
	elif Input.is_action_just_pressed("hotbar_prev"):
		InventoryManager.scroll_hotbar(-1)

# ══════════════════════════════════════════════════════════════════════════════
# ENTITY HOOKS
# ══════════════════════════════════════════════════════════════════════════════

func _on_damaged(_amount: int, _type: String, _source: Node) -> void:
	_emit_health()
	if _is_dead:
		return
	anim_sprite.play(ANIM_HURT)
	hurt_timer.start()

func _on_healed(_amount: int) -> void:
	_emit_health()

func _on_died(_killer: Node) -> void:
	anim_sprite.play(ANIM_DIE)
	velocity = Vector2.ZERO
	EventBus.player_died.emit()

func _on_world_wrapped(old_pos: Vector2, new_pos: Vector2) -> void:
	EventBus.player_world_wrapped.emit(old_pos, new_pos)

# ══════════════════════════════════════════════════════════════════════════════
# TIMER CALLBACKS
# ══════════════════════════════════════════════════════════════════════════════

func _on_hurt_timer_timeout() -> void:
	if not _is_dead and not _is_attacking:
		anim_sprite.play(ANIM_IDLE)

# ══════════════════════════════════════════════════════════════════════════════
# EMIT HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _emit_health() -> void:
	EventBus.player_health_changed.emit(current_health, stat_block.get_max_health())

func _emit_stamina() -> void:
	EventBus.player_stamina_changed.emit(current_stamina, stat_block.get_max_stamina())
