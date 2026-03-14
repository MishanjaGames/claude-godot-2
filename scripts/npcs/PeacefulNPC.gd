# PeacefulNPC.gd
class_name PeacefulNPC
extends NPCBase

@export var wander_radius: float      = 120.0
@export var wander_interval: float    = 3.0
@export var dialogue: Array[String]   = ["Hello, traveller!", "Nice day, isn't it?"]

var _wander_timer: float = 0.0
var _home_position: Vector2

func _ready() -> void:
	super._ready()
	_home_position = global_position
	faction        = Faction.PEACEFUL

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()
		_wander_timer = wander_interval

	if nav_agent.is_navigation_finished():
		anim_sprite.play("idle")
		return

	var next_pos = nav_agent.get_next_path_position()
	var dir      = (next_pos - global_position).normalized()
	velocity     = dir * move_speed
	anim_sprite.play("walk")
	anim_sprite.flip_h = dir.x < 0.0
	move_and_slide()

func _pick_new_wander_target() -> void:
	var offset = Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _home_position + offset

func interact(interactor: Node) -> void:
	EventBus.dialogue_open_requested.emit(dialogue, self)
	EventBus.npc_dialogue_started.emit(self, dialogue)
