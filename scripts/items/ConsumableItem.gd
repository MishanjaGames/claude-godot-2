# ConsumableItem.gd
class_name ConsumableItem
extends Item

@export var heal_amount: int        = 0
@export var stamina_restore: float  = 0.0

func use(user: Node) -> void:
	if user.has_method("heal") and heal_amount > 0:
		user.heal(heal_amount)
	if "current_stamina" in user and stamina_restore > 0.0:
		user.current_stamina = minf(user.max_stamina,
			user.current_stamina + stamina_restore)
		EventBus.player_stamina_changed.emit(user.current_stamina, user.max_stamina)
	EventBus.hud_show_message.emit("Used " + display_name + ".", 2.0)
