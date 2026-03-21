# Entity.gd
# Base class for every living thing: Player, all NPC types.
# Owns the StatBlock, status effect list, and all shared combat logic.
# Subclasses override the _on_* hooks instead of _ready() / take_damage() etc.
class_name Entity
extends CharacterBody2D

# ── Data resource (assign in Inspector or set by NPCData) ─────────────────────
@export var stat_block: StatBlock = null

# ── Runtime state ──────────────────────────────────────────────────────────────
var current_health:  int   = 0
var current_stamina: float = 0.0
var _is_dead:        bool  = false

## Active StatusEffect instances (duplicated from templates so timers are per-entity).
var _active_effects: Array[StatusEffect] = []
## Tracks remaining tick timers per effect (parallel array to _active_effects).
var _effect_tick_timers: Array[float]    = []
## Remaining durations per effect.
var _effect_durations: Array[float]      = []

# ── Shared node refs (must exist in every entity scene) ───────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision:   CollisionShape2D = $CollisionShape2D

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	if stat_block == null:
		stat_block = StatBlock.new()   # fallback with default stats
	else:
		stat_block = stat_block.duplicate()   # isolate per-instance

	current_health  = stat_block.get_max_health()
	current_stamina = stat_block.get_max_stamina()
	_on_entity_ready()

## Override this instead of _ready() to avoid super() boilerplate.
func _on_entity_ready() -> void:
	pass

func _process(delta: float) -> void:
	_tick_status_effects(delta)

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH
# ══════════════════════════════════════════════════════════════════════════════

## Deal damage. Applies defence/resistance from StatBlock.
## damage_type: "physical" | "magic" | "true"
func take_damage(raw_amount: int, damage_type: String = "physical", source: Node = null) -> void:
	if _is_dead:
		return
	var amount = stat_block.calculate_incoming_damage(raw_amount, damage_type)
	current_health = max(0, current_health - amount)
	EventBus.entity_damaged.emit(self, amount, damage_type, source)
	_on_damaged(amount, damage_type, source)
	if current_health <= 0:
		_die(source)

## Restore health.
func heal(amount: int) -> void:
	if _is_dead:
		return
	current_health = min(stat_block.get_max_health(), current_health + amount)
	EventBus.entity_healed.emit(self, amount)
	_on_healed(amount)

## Instantly kill this entity (bypasses defence).
func kill(source: Node = null) -> void:
	if _is_dead:
		return
	current_health = 0
	_die(source)

func health_ratio() -> float:
	var m = stat_block.get_max_health()
	return float(current_health) / float(m) if m > 0 else 0.0

func stamina_ratio() -> float:
	var m = stat_block.get_max_stamina()
	return current_stamina / m if m > 0.0 else 0.0

# ══════════════════════════════════════════════════════════════════════════════
# STATUS EFFECTS
# ══════════════════════════════════════════════════════════════════════════════

## Apply a StatusEffect. Refreshes duration if is_unique and already active.
func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return

	if effect.is_unique:
		var idx = _find_effect_index(effect.id)
		if idx >= 0:
			_effect_durations[idx] = effect.duration
			return   # refresh, don't re-apply modifiers

	var inst = effect.duplicate()
	_active_effects.append(inst)
	_effect_tick_timers.append(inst.tick_interval)
	_effect_durations.append(inst.duration)

	_push_effect_modifiers(inst)
	EventBus.status_effect_applied.emit(self, inst)

## Remove all effects with the given id.
func remove_status_effect(effect_id: String) -> void:
	var i = _active_effects.size() - 1
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
		var e   = _active_effects[i]
		var dur = _effect_durations[i]

		# Duration countdown (skip if permanent)
		if dur >= 0.0:
			_effect_durations[i] -= delta
			if _effect_durations[i] <= 0.0:
				_pop_effect_modifiers(e)
				EventBus.status_effect_removed.emit(self, e)
				_active_effects.remove_at(i)
				_effect_tick_timers.remove_at(i)
				_effect_durations.remove_at(i)
				continue

		# Per-tick damage / healing
		_effect_tick_timers[i] -= delta
		if _effect_tick_timers[i] <= 0.0:
			_effect_tick_timers[i] = e.tick_interval
			var tick_dmg := e.damage_per_tick + e.magic_per_tick
			var tick_heal := e.heal_per_tick
			if tick_dmg > 0:
				take_damage(e.damage_per_tick, "physical")
				if e.magic_per_tick > 0:
					take_damage(e.magic_per_tick, "magic")
				EventBus.status_effect_ticked.emit(self, e, tick_dmg)
			if tick_heal > 0:
				heal(tick_heal)
		i += 1

func _push_effect_modifiers(e: StatusEffect) -> void:
	var sid := "effect_" + e.id
	if e.move_speed_add != 0.0:
		stat_block.add_modifier(sid, "move_speed", e.move_speed_add, "add")
	if e.move_speed_mul != 1.0:
		stat_block.add_modifier(sid + "_mul", "move_speed", e.move_speed_mul, "mul")
	if e.attack_add != 0:
		stat_block.add_modifier(sid, "attack", float(e.attack_add), "add")
	if e.defence_add != 0:
		stat_block.add_modifier(sid, "defence", float(e.defence_add), "add")
	if e.stamina_regen_mul != 1.0:
		stat_block.add_modifier(sid + "_sregen", "stamina_regen", e.stamina_regen_mul, "mul")

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
# KNOCKBACK
# ══════════════════════════════════════════════════════════════════════════════

## Applies an impulse to velocity, reduced by knockback_resist.
func apply_knockback(force: Vector2) -> void:
	var resist = clampf(stat_block.knockback_resist, 0.0, 1.0)
	var actual = force * (1.0 - resist)
	velocity += actual
	EventBus.knockback_applied.emit(self, actual)

# ══════════════════════════════════════════════════════════════════════════════
# PLANET WRAP
# ══════════════════════════════════════════════════════════════════════════════

## Call this at the end of _physics_process() to keep the entity on the planet.
func apply_world_wrap() -> void:
	var prev = global_position
	global_position = WorldManager.wrap_position(global_position)
	if WorldManager.crossed_wrap_boundary(prev, global_position):
		_on_world_wrapped(prev, global_position)

## Override in Player to fire EventBus.player_world_wrapped.
func _on_world_wrapped(_old: Vector2, _new: Vector2) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# INTERNAL / DEATH
# ══════════════════════════════════════════════════════════════════════════════

func _die(killer: Node = null) -> void:
	if _is_dead:
		return
	_is_dead = true
	clear_status_effects()
	collision.set_deferred("disabled", true)
	EventBus.entity_died.emit(self, global_position, killer)
	if killer != null:
		EventBus.entity_killed_enemy.emit(killer, self)
	_on_died(killer)

# ══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HOOKS — override in subclasses
# ══════════════════════════════════════════════════════════════════════════════

## Called once after stat_block and health are initialised.
func _on_entity_ready() -> void: pass

## Called after health is reduced. amount = actual damage after reductions.
func _on_damaged(_amount: int, _damage_type: String, _source: Node) -> void: pass

## Called after health is restored.
func _on_healed(_amount: int) -> void: pass

## Called once when health reaches 0.
func _on_died(_killer: Node) -> void: pass
