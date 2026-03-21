# AllyNPC.gd
# Follows the player, attacks nearby HOSTILE NPCs, self-heals when low.
class_name AllyNPC
extends NPCBase

enum State { IDLE, FOLLOW, ENGAGE }

@export var follow_distance: float    = 80.0
@export var self_heal_threshold: float = 0.3   # heals below 30 % HP
@export var self_heal_amount: int      = 15
@export var self_heal_cooldown: float  = 5.0

var _state:       State = State.IDLE
var _target:      Node  = null
var _attack_timer: float = 0.0
var _heal_timer:   float = 0.0

func _on_npc_ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_heal_timer   = maxf(0.0, _heal_timer   - delta)
	_try_self_heal()
	_update_state()
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			anim_sprite.play("idle")
		State.FOLLOW:
			_move_toward(GameManager.player_ref.global_position,
				stat_block.get_move_speed())
		State.ENGAGE:
			_tick_engage()
	move_and_slide()
	apply_world_wrap()

func _update_state() -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	if _target != null:
		_state = State.ENGAGE
	elif GameManager.player_ref != null:
		var dist := global_position.distance_to(GameManager.player_ref.global_position)
		_state = State.FOLLOW if dist > follow_distance else State.IDLE
	else:
		_state = State.IDLE

func _tick_engage() -> void:
	if _target == null:
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist <= npc_data.attack_range:
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		if _attack_timer <= 0.0 and _target.has_method("take_damage"):
			_target.take_damage(npc_data.attack_damage, "physical", self)
			anim_sprite.play("attack")
			_attack_timer = npc_data.attack_cooldown
	else:
		_move_toward(_target.global_position, stat_block.get_move_speed())

func _try_self_heal() -> void:
	if _heal_timer > 0.0 or health_ratio() >= self_heal_threshold:
		return
	heal(self_heal_amount)
	_heal_timer = self_heal_cooldown

func _on_body_entered(body: Node) -> void:
	if body is NPCBase and body.faction == NPCData.Faction.HOSTILE and _target == null:
		_target = body

func _on_body_exited(body: Node) -> void:
	if body != _target:
		return
	_target = null
	for b in detection_area.get_overlapping_bodies():
		if b is NPCBase and b.faction == NPCData.Faction.HOSTILE and is_instance_valid(b):
			_target = b
			break
