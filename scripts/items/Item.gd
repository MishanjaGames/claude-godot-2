# Item.gd — Base resource for all items.
class_name Item
extends Resource

@export var id: String             = "item_id"
@export var display_name: String   = "Item Name"
@export var description: String    = "An item."
@export var icon: Texture2D        = null
@export var stackable: bool        = false
@export var max_stack: int         = 1
@export var weight: float          = 0.1

# Runtime quantity (not exported; managed by InventoryManager)
var quantity: int = 1

## Override in subclasses to define use behaviour.
func use(user: Node) -> void:
	push_warning("Item.use: No use behaviour defined for " + id)
