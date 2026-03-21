# HostileNPC.gd
# Full patrol → chase → attack → return state machine.
class_name HostileNPC
extends NPCBase

# ── Exports ────────────────────────────────────────────────────────────────────
@export var waypoints: Array[Vector2]  = []         # patrol route (world positions)
@export var alert_radius: float        = 180.0      # player detection range
@export var leash_radius: float        = 360.0      # gives up chase beyond this
@export var attack_range: float        = 40.0       # melee reach
@export var attack_damage: int         = 12
@export var attack_cooldown: float     = 1.2        # seconds between swings
@export var patrol_wait_time: float    = 1.5        # pause at each waypoint
@export var chase_speed_mult: float    = 1.25       # speed boost while chasing

# ── State machine ──────────────────────────────────────────────────────────────
enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }

var _state: State           = State.IDLE
var _prev_state: State      = State.IDLE   # for alert-emit de-duplication
var _current_waypoint: int  = 0
var _patrol_timer: float    = 0.0
var _attack_timer: float    = 0.0
var _home_position: Vector2
var _player: Node           = null

func _ready() -> void:
	super._ready()
	faction        = Faction.HOSTILE
	_home_position = global_position
	_player        = GameManager.player_ref
	_state         = State.PATROL if not waypoints.is_empty() else State.IDLE

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Keep player ref fresh (player might respawn / change)
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.player_ref

	_attack_timer = maxf(0.0, _attack_timer - delta)

	match _state:
		State.IDLE:
			_tick_idle()
		State.PATROL:
			_tick_patrol(delta)
		State.CHASE:
			_tick_chase()
		State.ATTACK:
			_tick_attack()
		State.RETURN:
			_tick_return()

	move_and_slide()

# ── State ticks ────────────────────────────────────────────────────────────────

func _tick_idle() -> void:
	velocity = Vector2.ZERO
	anim_sprite.play("idle")
	_scan_for_player()

func _tick_patrol(delta: float) -> void:
	_scan_for_player()

	if waypoints.is_empty():
		_state = State.IDLE
		return

	var target_wp = waypoints[_current_waypoint]
	if global_position.distance_to(target_wp) < 12.0:
		# Arrived — wait, then advance
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		_patrol_timer -= delta
		if _patrol_timer <= 0.0:
			_current_waypoint = (_current_waypoint + 1) % waypoints.size()
			_patrol_timer = patrol_wait_time
		return

	_move_to(target_wp, move_speed)

func _tick_chase() -> void:
	if _player == null:
		_transition(State.RETURN)
		return

	var dist = global_position.distance_to(_player.global_position)

	if dist <= attack_range:
		_transition(State.ATTACK)
		return

	if dist > leash_radius:
		_transition(State.RETURN)
		return

	_move_to(_player.global_position, move_speed * chase_speed_mult)

func _tick_attack() -> void:
	if _player == null:
		_transition(State.RETURN)
		return

	var dist = global_position.distance_to(_player.global_position)

	if dist > attack_range:
		_transition(State.CHASE)
		return

	velocity = Vector2.ZERO
	anim_sprite.play("attack")

	if _attack_timer <= 0.0:
		_player.take_damage(attack_damage)
		_attack_timer = attack_cooldown

func _tick_return() -> void:
	if global_position.distance_to(_home_position) < 16.0:
		_state = State.PATROL if not waypoints.is_empty() else State.IDLE
		velocity = Vector2.ZERO
		return
	_move_to(_home_position, move_speed)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _move_to(target_pos: Vector2, speed: float) -> void:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		return
	var dir = (nav_agent.get_next_path_position() - global_position).normalized()
	velocity = dir * speed
	anim_sprite.play("walk")
	anim_sprite.flip_h = dir.x < 0.0

func _scan_for_player() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= alert_radius:
		_transition(State.CHASE)

func _transition(new_state: State) -> void:
	_prev_state = _state
	_state      = new_state

	# Emit alert only on the first transition into CHASE
	if new_state == State.CHASE and _prev_state != State.CHASE and _prev_state != State.ATTACK:
		EventBus.npc_alerted.emit(self, _player)
