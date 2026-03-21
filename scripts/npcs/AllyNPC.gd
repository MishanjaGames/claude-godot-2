# AllyNPC.gd
# Follows the player, engages nearby hostile NPCs, and heals itself when low.
class_name AllyNPC
extends NPCBase

# ── Exports ────────────────────────────────────────────────────────────────────
@export var follow_player: bool       = true
@export var follow_distance: float    = 80.0   # stops following when closer than this
@export var attack_damage: int        = 8
@export var attack_range: float       = 48.0
@export var attack_cooldown: float    = 1.0    # seconds between attacks
@export var heal_threshold: float     = 0.3    # self-heal trigger: below 30% HP
@export var self_heal_amount: int     = 15
@export var self_heal_cooldown: float = 5.0    # seconds between self-heals

# ── State ──────────────────────────────────────────────────────────────────────
enum State { IDLE, FOLLOW, ENGAGE }

var _state: State               = State.IDLE
var _target: Node               = null   # current hostile target
var _attack_timer: float        = 0.0
var _heal_timer: float          = 0.0

func _ready() -> void:
	super._ready()
	faction = Faction.ALLY
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_tick_timers(delta)
	_try_self_heal()
	_update_state()

	match _state:
		State.IDLE:
			_tick_idle()
		State.FOLLOW:
			_tick_follow()
		State.ENGAGE:
			_tick_engage()

	move_and_slide()

# ── State logic ────────────────────────────────────────────────────────────────

func _update_state() -> void:
	# Prune dead / freed targets
	if _target != null and not is_instance_valid(_target):
		_target = null

	# Always prefer engaging a hostile over following the player
	if _target != null:
		_state = State.ENGAGE
	elif follow_player and GameManager.player_ref != null:
		var dist = global_position.distance_to(GameManager.player_ref.global_position)
		_state = State.FOLLOW if dist > follow_distance else State.IDLE
	else:
		_state = State.IDLE

func _tick_idle() -> void:
	velocity = Vector2.ZERO
	anim_sprite.play("idle")

func _tick_follow() -> void:
	if GameManager.player_ref == null:
		return
	_move_toward(GameManager.player_ref.global_position)

func _tick_engage() -> void:
	if _target == null:
		return
	var dist = global_position.distance_to(_target.global_position)
	if dist <= attack_range:
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		_try_attack()
	else:
		_move_toward(_target.global_position)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _move_toward(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		return
	var dir = (nav_agent.get_next_path_position() - global_position).normalized()
	velocity = dir * move_speed
	anim_sprite.play("walk")
	anim_sprite.flip_h = dir.x < 0.0

func _try_attack() -> void:
	if _attack_timer > 0.0 or _target == null:
		return
	if _target.has_method("take_damage"):
		_target.take_damage(attack_damage)
	anim_sprite.play("attack")
	_attack_timer = attack_cooldown

func _try_self_heal() -> void:
	if _heal_timer > 0.0:
		return
	if float(current_health) / float(max_health) < heal_threshold:
		current_health = mini(max_health, current_health + self_heal_amount)
		health_bar.value = current_health
		_heal_timer = self_heal_cooldown

func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_heal_timer   = maxf(0.0, _heal_timer   - delta)

# ── Detection callbacks ────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	# Grab the nearest hostile that enters detection range
	if body is NPCBase and body.faction == NPCBase.Faction.HOSTILE:
		if _target == null or not is_instance_valid(_target):
			_target = body

func _on_body_exited(body: Node) -> void:
	if body == _target:
		# Look for another hostile still inside the area
		_target = null
		for b in detection_area.get_overlapping_bodies():
			if b is NPCBase and b.faction == NPCBase.Faction.HOSTILE and is_instance_valid(b):
				_target = b
				break
