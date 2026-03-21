# HostileNPC.gd
# Five-state FSM: IDLE → PATROL → CHASE → ATTACK → RETURN.
# All tuning values come from npc_data — no hardcoded stats here.
class_name HostileNPC
extends NPCBase

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }

## Waypoints in world pixel space. Set in the editor for pre-placed NPCs.
## StructurePlacer leaves this empty — NPCs without waypoints idle at their spawn.
@export var waypoints: Array[Vector2] = []

var _state:             State  = State.IDLE
var _prev_state:        State  = State.IDLE
var _current_waypoint:  int    = 0
var _patrol_timer:      float  = 0.0
var _attack_timer:      float  = 0.0
var _home_pos:          Vector2
var _player:            Node   = null

func _on_npc_ready() -> void:
	_home_pos = global_position
	_state    = State.PATROL if not waypoints.is_empty() else State.IDLE

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Refresh player ref each frame — safe if player respawns.
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.player_ref

	_attack_timer = maxf(0.0, _attack_timer - delta)

	match _state:
		State.IDLE:    _tick_idle()
		State.PATROL:  _tick_patrol(delta)
		State.CHASE:   _tick_chase()
		State.ATTACK:  _tick_attack()
		State.RETURN:  _tick_return()

	move_and_slide()
	apply_world_wrap()

# ── State ticks ────────────────────────────────────────────────────────────────

func _tick_idle() -> void:
	velocity = Vector2.ZERO
	anim_sprite.play("idle")
	_scan_for_player()

func _tick_patrol(delta: float) -> void:
	_scan_for_player()
	if waypoints.is_empty():
		_transition(State.IDLE)
		return
	var target_wp := waypoints[_current_waypoint]
	if global_position.distance_to(target_wp) < 14.0:
		velocity        = Vector2.ZERO
		anim_sprite.play("idle")
		_patrol_timer  -= delta
		if _patrol_timer <= 0.0:
			_current_waypoint = (_current_waypoint + 1) % waypoints.size()
			_patrol_timer     = npc_data.patrol_wait_time
	else:
		_move_toward(target_wp, stat_block.get_move_speed())

func _tick_chase() -> void:
	if _player == null:
		_transition(State.RETURN)
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= npc_data.attack_range:
		_transition(State.ATTACK)
	elif dist > npc_data.leash_radius:
		_transition(State.RETURN)
	else:
		_move_toward(_player.global_position,
			stat_block.get_move_speed() * npc_data.chase_speed_mult)

func _tick_attack() -> void:
	if _player == null:
		_transition(State.RETURN)
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > npc_data.attack_range:
		_transition(State.CHASE)
		return
	velocity = Vector2.ZERO
	anim_sprite.play("attack")
	if _attack_timer <= 0.0:
		_player.take_damage(npc_data.attack_damage, "physical", self)
		_attack_timer = npc_data.attack_cooldown

func _tick_return() -> void:
	if global_position.distance_to(_home_pos) < 18.0:
		_transition(State.PATROL if not waypoints.is_empty() else State.IDLE)
		velocity = Vector2.ZERO
		return
	_move_toward(_home_pos, stat_block.get_move_speed())

# ── Helpers ────────────────────────────────────────────────────────────────────

func _scan_for_player() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= npc_data.alert_radius:
		_transition(State.CHASE)

func _transition(new_state: State) -> void:
	_prev_state = _state
	_state      = new_state
	# Emit alert only on the first entry into CHASE from a non-combat state.
	if new_state == State.CHASE \
			and _prev_state != State.CHASE \
			and _prev_state != State.ATTACK:
		EventBus.npc_alerted.emit(self, _player)
	# Emit lost-target when leaving combat.
	if _prev_state in [State.CHASE, State.ATTACK] \
			and new_state == State.RETURN:
		EventBus.npc_lost_target.emit(self)
