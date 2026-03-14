# MeleeWeapon.gd
class_name MeleeWeapon
extends WeaponBase

# The wielder is expected to have an $AttackHitbox Area2D child.
# This script activates it for one frame during swing.
func attack(wielder: Node) -> void:
	super.attack(wielder)
	if wielder.has_node("AttackHitbox"):
		var hitbox: Area2D = wielder.get_node("AttackHitbox")
		hitbox.monitoring = true
		# Deactivate after a short window
		var timer = wielder.get_tree().create_timer(0.15)
		timer.timeout.connect(func(): hitbox.monitoring = false)
		# Damage anything in hitbox on overlap
		for body in hitbox.get_overlapping_bodies():
			if body != wielder and body.has_method("take_damage"):
				body.take_damage(damage)
				# Apply knockback
				if "velocity" in body:
					var dir = (body.global_position - wielder.global_position).normalized()
					body.velocity += dir * knockback_force
	if wielder.has_node("AnimatedSprite2D"):
		wielder.get_node("AnimatedSprite2D").play("attack")
