# Player.gd
extends CharacterBody2D

# ── Stats ──────────────────────────────────────────────────────────────────────
@export var max_health: int          = 100
@export var max_stamina: float       = 100.0
@export var move_speed: float        = 160.0
@export var sprint_multiplier: float = 1.8
@export var stamina_drain_rate: float = 30.0  # per second while sprinting
@export var stamina_regen_rate: float = 15.0  # per second while not sprinting
@export var stamina_sprint_min: float = 10.0  # min stamina to start sprinting

var current_health: int   = max_health
var current_stamina: float = max_stamina
var _is_dead: bool         = false
var _is_sprinting: bool    = false

# ── Nodes ──────────────────────────────────────────────────────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_ray: RayCast2D       = $InteractRay
@onready var collision: CollisionShape2D   = $CollisionShape2D
@onready var hurt_timer: Timer             = $HurtTimer

func _ready() -> void:
	GameManager.player_ref = self
	_emit_health()
	_emit_stamina()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	_handle_interaction()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	_is_sprinting = Input.is_action_pressed("sprint") \
		and current_stamina > stamina_sprint_min \
		and dir != Vector2.ZERO

	var speed = move_speed * (sprint_multiplier if _is_sprinting else 1.0)
	velocity  = dir * speed

	# Stamina management
	if _is_sprinting:
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	_emit_stamina()

	# Face direction
	if dir.x != 0.0:
		anim_sprite.flip_h = dir.x < 0.0

	# Animations
	if dir == Vector2.ZERO:
		anim_sprite.play("idle")
	elif _is_sprinting:
		anim_sprite.play("run")
	else:
		anim_sprite.play("walk")

func _handle_interaction() -> void:
	if Input.is_action_just_pressed("interact"):
		interact_ray.force_raycast_update()
		if interact_ray.is_colliding():
			var obj = interact_ray.get_collider()
			if obj.has_method("interact"):
				obj.interact(self)
				EventBus.player_interacted.emit(obj)

# ── Health / Damage ────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	_emit_health()
	anim_sprite.play("hurt")
	hurt_timer.start()
	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	_emit_health()

func _die() -> void:
	_is_dead = true
	anim_sprite.play("die")
	collision.set_deferred("disabled", true)
	EventBus.player_died.emit()

func _on_hurt_timer_timeout() -> void:
	if not _is_dead:
		anim_sprite.play("idle")

# ── Emit helpers ──────────────────────────────────────────────────────────────

func _emit_health() -> void:
	EventBus.player_health_changed.emit(current_health, max_health)

func _emit_stamina() -> void:
	EventBus.player_stamina_changed.emit(current_stamina, max_stamina)
