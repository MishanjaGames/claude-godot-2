# Projectile.gd
# Moves in a direction, damages on collision, applies on-hit effects.
# setup() is called by Player._ranged_attack() immediately after instantiation.
#
# SCENE TREE (Projectile.tscn):
#   Projectile         [CharacterBody2D]   ← this script
#   ├── Sprite2D                           (texture = your bullet/arrow sprite)
#   ├── CollisionShape2D                   (CapsuleShape2D h=8 r=3, rotation=90°)
#   └── LifetimeTimer  [Timer]             (one_shot=true)
class_name Projectile
extends CharacterBody2D

@export var default_speed:    float = 400.0
@export var default_lifetime: float = 3.0

var _damage:      int    = 5
var _direction:   Vector2 = Vector2.RIGHT
var _piercing:    bool   = false
var _on_hit_effects: Array[StatusEffect] = []
var _hit_nodes:   Array  = []   # nodes already struck (piercing guard)

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	lifetime_timer.timeout.connect(queue_free)

## Called by whoever spawns this projectile.
func setup(
		direction:   Vector2,
		damage:      int,
		piercing:    bool          = false,
		speed:       float         = -1.0,
		lifetime:    float         = -1.0,
		on_hit_fx:   Array         = []
) -> void:
	_direction   = direction.normalized()
	_damage      = damage
	_piercing    = piercing
	_on_hit_effects = on_hit_fx
	rotation     = _direction.angle()
	velocity     = _direction * (speed if speed > 0.0 else default_speed)
	lifetime_timer.start(lifetime if lifetime > 0.0 else default_lifetime)

func _physics_process(_delta: float) -> void:
	var col := move_and_collide(velocity * _delta)
	if col == null:
		return
	var hit := col.get_collider()
	if hit == null or _hit_nodes.has(hit):
		return
	_hit_nodes.append(hit)

	if hit.has_method("take_damage"):
		hit.take_damage(_damage, "physical")
		for fx in _on_hit_effects:
			if hit.has_method("apply_status_effect"):
				hit.apply_status_effect(fx.duplicate())

	if not _piercing:
		queue_free()
