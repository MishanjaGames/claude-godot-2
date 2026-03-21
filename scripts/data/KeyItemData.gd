# KeyItemData.gd
# Quest / story items. Usually unique, cannot be dropped or stacked.
class_name KeyItemData
extends ItemData

@export var quest_id: String    = ""    # quest this item belongs to
@export var unlocks: String     = ""    # node group or door name it opens
@export var is_unique: bool     = true  # only one allowed in inventory

func _init() -> void:
	stackable = false
	max_stack = 1

func use(user: Node) -> void:
	EventBus.key_item_used.emit(quest_id, self, user)
	EventBus.hud_show_message.emit("%s used." % display_name, 2.0)
