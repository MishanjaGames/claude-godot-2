# Entity.gd
# Base class for every living thing: Player, all NPC types.
# Owns the StatBlock, status effect list, and all shared combat logic.
class_name Entity
extends CharacterBody2D

@export var stat_block: StatBlock = null

var current_health:  int   = 0
var current_stamina: float = 0.0
var _is_dead:        bool  = false

var _active_effects:      Array[StatusEffect] = []
var _effect_tick_timers:  Array[float]        = []
var _effect_durations:    Array[float]        = []

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision:   CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if stat_block == null:
		stat_block = StatBlock.new()
	else:
		stat_block = stat_block.duplicate()
	current_health  = stat_block.get_max_health()
	current_stamina = stat_block.get_max_stamina()
	add_to_group("entity")   # used by DebugOverlay entity counter
	_on_entity_ready()

func _on_entity_ready() -> void:
	pass

func _process(delta: float) -> void:
	_tick_status_effects(delta)

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH
# ══════════════════════════════════════════════════════════════════════════════

func take_damage(raw_amount: int, damage_type: String = "physical", source: Node = null) -> void:
	if _is_dead:
		return
	var amount := stat_block.calculate_incoming_damage(raw_amount, damage_type)
	current_health = max(0, current_health - amount)
	EventBus.entity_damaged.emit(self, amount, damage_type, source)
	_on_damaged(amount, damage_type, source)
	if current_health <= 0:
		_die(source)

func heal(amount: int) -> void:
	if _is_dead:
		return
	current_health = min(stat_block.get_max_health(), current_health + amount)
	EventBus.entity_healed.emit(self, amount)
	_on_healed(amount)

func kill(source: Node = null) -> void:
	if _is_dead:
		return
	current_health = 0
	_die(source)

func health_ratio() -> float:
	var m := stat_block.get_max_health()
	return float(current_health) / float(m) if m > 0 else 0.0

func stamina_ratio() -> float:
	var m := stat_block.get_max_stamina()
	return current_stamina / m if m > 0.0 else 0.0

# ══════════════════════════════════════════════════════════════════════════════
# STATUS EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return
	if effect.is_unique:
		var idx := _find_effect_index(effect.id)
		if idx >= 0:
			_effect_durations[idx] = effect.duration
			return
	var inst := effect.duplicate()
	_active_effects.append(inst)
	_effect_tick_timers.append(inst.tick_interval)
	_effect_durations.append(inst.duration)
	_push_effect_modifiers(inst)
	EventBus.status_effect_applied.emit(self, inst)

func remove_status_effect(effect_id: String) -> void:
	var i := _active_effects.size() - 1
	while i >= 0:
		if _active_effects[i].id == effect_id:
			_pop_effect_modifiers(_active_effects[i])
			EventBus.status_effect_removed.emit(self, _active_effects[i])
			_active_effects.remove_at(i)
			_effect_tick_timers.remove_at(i)
			_effect_durations.remove_at(i)
		i -= 1

func has_status_effect(effect_id: String) -> bool:
	return _find_effect_index(effect_id) >= 0

func clear_status_effects() -> void:
	for e in _active_effects:
		_pop_effect_modifiers(e)
	_active_effects.clear()
	_effect_tick_timers.clear()
	_effect_durations.clear()

func _tick_status_effects(delta: float) -> void:
	var i := 0
	while i < _active_effects.size():
		var e   := _active_effects[i]
		if _effect_durations[i] >= 0.0:
			_effect_durations[i] -= delta
			if _effect_durations[i] <= 0.0:
				_pop_effect_modifiers(e)
				EventBus.status_effect_removed.emit(self, e)
				_active_effects.remove_at(i)
				_effect_tick_timers.remove_at(i)
				_effect_durations.remove_at(i)
				continue
		_effect_tick_timers[i] -= delta
		if _effect_tick_timers[i] <= 0.0:
			_effect_tick_timers[i] = e.tick_interval
			if e.damage_per_tick > 0:
				take_damage(e.damage_per_tick, "physical")
			if e.magic_per_tick > 0:
				take_damage(e.magic_per_tick, "magic")
			if e.heal_per_tick > 0:
				heal(e.heal_per_tick)
			EventBus.status_effect_ticked.emit(self, e, e.damage_per_tick + e.magic_per_tick)
		i += 1

func _push_effect_modifiers(e: StatusEffect) -> void:
	var sid := "effect_" + e.id
	if e.move_speed_add != 0.0:   stat_block.add_modifier(sid, "move_speed", e.move_speed_add, "add")
	if e.move_speed_mul != 1.0:   stat_block.add_modifier(sid + "_mul", "move_speed", e.move_speed_mul, "mul")
	if e.attack_add != 0:         stat_block.add_modifier(sid, "attack", float(e.attack_add), "add")
	if e.defence_add != 0:        stat_block.add_modifier(sid, "defence", float(e.defence_add), "add")
	if e.stamina_regen_mul != 1.0: stat_block.add_modifier(sid + "_sregen", "stamina_regen", e.stamina_regen_mul, "mul")

func _pop_effect_modifiers(e: StatusEffect) -> void:
	var sid := "effect_" + e.id
	stat_block.remove_all_modifiers_from(sid)
	stat_block.remove_all_modifiers_from(sid + "_mul")
	stat_block.remove_all_modifiers_from(sid + "_sregen")

func _find_effect_index(effect_id: String) -> int:
	for i in _active_effects.size():
		if _active_effects[i].id == effect_id:
			return i
	return -1

# ══════════════════════════════════════════════════════════════════════════════
# KNOCKBACK & WRAP
# ══════════════════════════════════════════════════════════════════════════════

func apply_knockback(force: Vector2) -> void:
	var resist := clampf(stat_block.knockback_resist, 0.0, 1.0)
	velocity  += force * (1.0 - resist)
	EventBus.knockback_applied.emit(self, force * (1.0 - resist))

func apply_world_wrap() -> void:
	var prev           := global_position
	global_position     = WorldManager.wrap_position(global_position)
	if WorldManager.crossed_wrap_boundary(prev, global_position):
		_on_world_wrapped(prev, global_position)

func _on_world_wrapped(_old: Vector2, _new: Vector2) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# DEATH
# ══════════════════════════════════════════════════════════════════════════════

func _die(killer: Node = null) -> void:
	if _is_dead:
		return
	_is_dead = true
	clear_status_effects()
	collision.set_deferred("disabled", true)
	remove_from_group("entity")   # remove from entity counter on death
	EventBus.entity_died.emit(self, global_position, killer)
	if killer != null:
		EventBus.entity_killed_enemy.emit(killer, self)
	_on_died(killer)

# ══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HOOKS
# ══════════════════════════════════════════════════════════════════════════════

func _on_entity_ready() -> void:                                          pass
func _on_damaged(_amount: int, _type: String, _source: Node) -> void:    pass
func _on_healed(_amount: int) -> void:                                    pass
func _on_died(_killer: Node) -> void:                                     pass
