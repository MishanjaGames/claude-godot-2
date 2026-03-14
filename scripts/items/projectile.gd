extends Area2D
class_name Projectile

var _direction:     Vector2 = Vector2.RIGHT
var _speed:         float   = 400.0
var _max_range:     float   = 500.0
var _damage:        float   = 10.0
var _distance_traveled: float = 0.0

func setup(dir: Vector2, spd: float, rng: float, dmg: float) -> void:
	_direction = dir.normalized()
	_speed     = spd
	_max_range = rng
	_damage    = dmg
	rotation   = _direction.angle()

func _physics_process(delta: float) -> void:
	var step: float = _speed * delta
	global_position    += _direction * step
	_distance_traveled += step

	if _distance_traveled >= _max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("get") and body.get("stats") != null:
		body.stats.take_damage(_damage)
	queue_free()
