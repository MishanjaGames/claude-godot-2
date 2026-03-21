# Entity.gd
# Shared base for all living things in the game (Player, NPCs).
# Handles health, stamina, damage, healing, and death at the data layer.
# Node references (AnimatedSprite2D, CollisionShape2D) are declared here
# because every entity scene uses the same node names.
class_name Entity
extends CharacterBody2D

# ── Stats (override via @export in subclass or Inspector) ──────────────────────
@export var max_health: int          = 100
@export var max_stamina: float       = 100.0
@export var move_speed: float        = 120.0

# ── Runtime state ──────────────────────────────────────────────────────────────
var current_health: int    = 0
var current_stamina: float = 0.0
var _is_dead: bool         = false

# ── Shared node refs (every entity scene must have these named nodes) ──────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D   = $CollisionShape2D

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_health  = max_health
	current_stamina = max_stamina
	_on_entity_ready()

## Override instead of _ready() so subclasses don't need super()/_ready() boilerplate.
func _on_entity_ready() -> void:
	pass

# ── Public API ─────────────────────────────────────────────────────────────────

## Deal damage. Calls _on_damaged() hook, then _die() if health reaches 0.
func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	_on_damaged(amount)
	if current_health <= 0:
		_die()

## Restore health up to max_health. Calls _on_healed() hook.
func heal(amount: int) -> void:
	if _is_dead:
		return
	current_health = min(max_health, current_health + amount)
	_on_healed(amount)

## Returns health as a 0.0–1.0 ratio.
func health_ratio() -> float:
	return float(current_health) / float(max_health)

## Returns stamina as a 0.0–1.0 ratio.
func stamina_ratio() -> float:
	return current_stamina / max_stamina

# ── Internal ───────────────────────────────────────────────────────────────────

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	collision.set_deferred("disabled", true)
	_on_died()

# ── Virtual hooks (override in subclasses) ─────────────────────────────────────

## Called after health is reduced. `amount` is the damage dealt.
func _on_damaged(_amount: int) -> void:
	pass

## Called after health is restored. `amount` is the HP gained.
func _on_healed(_amount: int) -> void:
	pass

## Called once when current_health reaches 0.
func _on_died() -> void:
	pass
