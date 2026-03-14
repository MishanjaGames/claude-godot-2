# RangedWeapon.gd
class_name RangedWeapon
extends WeaponBase

@export var ammo_count: int     = 30
@export var reload_time: float  = 1.5

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")

var _is_reloading: bool = false

func attack(wielder: Node) -> void:
	if _is_reloading or ammo_count <= 0:
		EventBus.hud_show_message.emit("No ammo! Reloading…", 1.5)
		_start_reload(wielder)
		return
	super.attack(wielder)
	ammo_count -= 1

	var proj = PROJECTILE_SCENE.instantiate()
	wielder.get_tree().current_scene.add_child(proj)
	proj.global_position = wielder.global_position
	# Fire toward mouse
	var direction = (wielder.get_global_mouse_position() - wielder.global_position).normalized()
	proj.setup(direction, damage)

func _start_reload(wielder: Node) -> void:
	_is_reloading = true
	var timer = wielder.get_tree().create_timer(reload_time)
	timer.timeout.connect(func():
		ammo_count   = 30
		_is_reloading = false
		EventBus.hud_show_message.emit("Reloaded.", 1.0)
	)
