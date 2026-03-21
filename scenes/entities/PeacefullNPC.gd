# PeacefulNPC.gd
# Wanders within a radius of its home, triggers dialogue on interact.
class_name PeacefulNPC
extends NPCBase

var _home_pos:     Vector2 = Vector2.ZERO
var _wander_timer: float   = 0.0

func _on_npc_ready() -> void:
	_home_pos     = global_position
	_wander_timer = randf_range(0.5, npc_data.wander_interval)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_target()
		_wander_timer = npc_data.wander_interval
	_move_toward(nav_agent.target_position, stat_block.get_move_speed())
	move_and_slide()
	apply_world_wrap()

func _pick_wander_target() -> void:
	var r       := npc_data.wander_radius
	var offset  := Vector2(randf_range(-r, r), randf_range(-r, r))
	nav_agent.target_position = _home_pos + offset

func interact(interactor: Node) -> void:
	if npc_data == null or npc_data.dialogue.is_empty():
		return
	EventBus.dialogue_open_requested.emit(npc_data.dialogue, self)
	EventBus.npc_dialogue_started.emit(self, npc_data.dialogue)
