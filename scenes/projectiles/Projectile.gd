# Projectile.gd
extends CharacterBody2D

@export var speed: float        = 400.0
@export var lifetime: float     = 3.0
@export var piercing: bool      = false   # if true, don't despawn on first hit

var _damage: int    = 5
var _direction: Vector2 = Vector2.RIGHT
var _age: float     = 0.0

@onready var sprite: Sprite2D         = $Sprite2D
@onready var hitbox: Area2D           = $Hitbox
@onready var collision: CollisionShape2D = $CollisionShape2D

func setup(direction: Vector2, damage: int) -> void:
	_direction = direction
	_damage    = damage
	rotation   = direction.angle()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	velocity = _direction * speed
	var col = move_and_collide(velocity * delta)
	if col:
		var hit = col.get_collider()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(_damage)
		if not piercing:
			queue_free()
