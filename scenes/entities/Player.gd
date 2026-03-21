# Player.gd
extends Entity

# ── Stats ──────────────────────────────────────────────────────────────────────
@export var sprint_multiplier: float  = 1.8
@export var stamina_drain_rate: float = 30.0   # per second while sprinting
@export var stamina_regen_rate: float = 15.0   # per second while not sprinting
@export var stamina_sprint_min: float = 10.0   # minimum stamina to start a sprint
@export var unarmed_damage: int       = 8      # damage when no weapon is equipped
@export var unarmed_attack_range: float = 48.0

# ── Runtime state ──────────────────────────────────────────────────────────────
var _is_sprinting: bool     = false
var _unarmed_cooldown: float = 0.0

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var interact_ray: RayCast2D       = $InteractRay
@onready var hurt_timer: Timer             = $HurtTimer
@onready var attack_hitbox: Area2D         = $AttackHitbox   # see scene tree below

# ── Entity hook ───────────────────────────────────────────────────────────────

func _on_entity_ready() -> void:
	GameManager.player_ref = self
	attack_hitbox.monitoring = false
	_emit_health()
	_emit_stamina()

# ── Physics loop ───────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	_handle_interaction()
	_handle_attack(delta)
	move_and_slide()

# ── Movement ───────────────────────────────────────────────────────────────────

func _handle_movement(delta: float) -> void:
	var dir = Vector2(
		Input.get_axis("move_left",  "move_right"),
		Input.get_axis("move_up",    "move_down")
	).normalized()

	_is_sprinting = Input.is_action_pressed("sprint") \
		and current_stamina > stamina_sprint_min \
		and dir != Vector2.ZERO

	var speed = move_speed * (sprint_multiplier if _is_sprinting else 1.0)
	velocity  = dir * speed

	# Stamina
	if _is_sprinting:
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	_emit_stamina()

	# Facing
	if dir.x != 0.0:
		anim_sprite.flip_h = dir.x < 0.0
		# Move attack hitbox to the correct side
		attack_hitbox.position.x = abs(attack_hitbox.position.x) * sign(dir.x)

	# Animation
	if dir == Vector2.ZERO:
		if not anim_sprite.animation in ["attack", "hurt"]:
			anim_sprite.play("idle")
	elif _is_sprinting:
		anim_sprite.play("run")
	else:
		anim_sprite.play("walk")

# ── Interaction ────────────────────────────────────────────────────────────────

func _handle_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		var obj = interact_ray.get_collider()
		if obj.has_method("interact"):
			obj.interact(self)
			EventBus.player_interacted.emit(obj)

# ── Attack ─────────────────────────────────────────────────────────────────────

func _handle_attack(delta: float) -> void:
	_unarmed_cooldown = maxf(0.0, _unarmed_cooldown - delta)

	if not Input.is_action_just_pressed("attack"):
		return

	# Use equipped weapon if available
	var active_item = InventoryManager.get_active_item()
	if active_item != null and active_item is WeaponBase:
		active_item.attack(self)
		return

	# Fallback: unarmed
	if _unarmed_cooldown > 0.0:
		return
	_unarmed_cooldown = 0.6
	anim_sprite.play("attack")
	_activate_hitbox(unarmed_damage, 0.15)

func _activate_hitbox(damage: int, duration: float) -> void:
	attack_hitbox.monitoring = true
	for body in attack_hitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			body.take_damage(damage)
	# Deactivate after swing window
	get_tree().create_timer(duration).timeout.connect(
		func(): attack_hitbox.monitoring = false
	)

# ── Entity hooks ───────────────────────────────────────────────────────────────

func _on_damaged(_amount: int) -> void:
	_emit_health()
	if not _is_dead:
		anim_sprite.play("hurt")
		hurt_timer.start()

func _on_healed(_amount: int) -> void:
	_emit_health()

func _on_died() -> void:
	anim_sprite.play("die")
	EventBus.player_died.emit()

# ── Timer callback ─────────────────────────────────────────────────────────────

func _on_hurt_timer_timeout() -> void:
	if not _is_dead and anim_sprite.animation == "hurt":
		anim_sprite.play("idle")

# ── Emit helpers ───────────────────────────────────────────────────────────────

func _emit_health() -> void:
	EventBus.player_health_changed.emit(current_health, max_health)

func _emit_stamina() -> void:
	EventBus.player_stamina_changed.emit(current_stamina, max_stamina)
