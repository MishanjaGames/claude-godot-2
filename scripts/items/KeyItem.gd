# KeyItem.gd
class_name KeyItem
extends Item

@export var quest_id: String    = ""
@export var unlocks: String     = ""   # e.g. a door node name or flag

func use(user: Node) -> void:
	EventBus.key_item_used.emit(quest_id, self, user)
	EventBus.hud_show_message.emit(display_name + " used.", 2.0)
