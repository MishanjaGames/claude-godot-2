# ItemData.gd
# Base Resource for every item in the game.
# All item types (weapons, consumables, tools, armour, key items) extend this.
# Create .tres files in res://data/ subfolders — Registry auto-loads them.
class_name ItemData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String              = ""
@export var display_name: String    = "Item"
@export var description: String     = "An item."
@export var icon: Texture2D         = null

# ── Stack behaviour ────────────────────────────────────────────────────────────
@export var stackable: bool         = false
@export var max_stack: int          = 1

# ── Economy / weight ──────────────────────────────────────────────────────────
@export var weight: float           = 0.5    # contributes to carry weight
@export var value: int              = 1      # sell/buy price in currency

# ── Rarity (cosmetic, affects drop table colour coding) ───────────────────────
@export var rarity: Rarity          = Rarity.COMMON

# ── Runtime quantity (managed by InventoryManager, not saved in .tres) ────────
var quantity: int = 1

# ── Virtual — override in subclasses ──────────────────────────────────────────

## Called when the player activates this item from inventory or hotbar.
func use(user: Node) -> void:
	push_warning("ItemData.use: no behaviour defined for '%s'" % id)

## Returns true if this item can be used right now (stamina check, cooldown, etc.)
func can_use(user: Node) -> bool:
	return user != null

# ── Serialization helpers ──────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	return { "id": id, "quantity": quantity }
