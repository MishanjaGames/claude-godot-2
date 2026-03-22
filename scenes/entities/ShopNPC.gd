# ShopNPC.gd
# An NPC that opens a shop on interact.
# Attach in place of PeacefulNPC.gd on an NPCBase.tscn instance.
# Stock is defined as an Array of item_ids in the Inspector or via setup().
#
# STOCK FORMAT (set on the node or in NPCData via a custom field):
#   stock_item_ids: Array[String]  — Registry item ids available to buy
#   buy_multiplier: float          — fraction of item.value paid when player sells
#   sell_multiplier: float         — multiplier on item.value when player buys
class_name ShopNPC
extends NPCBase

@export var stock_item_ids:   Array[String] = []
@export var buy_multiplier:   float         = 0.5    # player sells at 50% value
@export var sell_multiplier:  float         = 1.5    # player buys at 150% value
@export var shop_name:        String        = "Shop"

func _on_npc_ready() -> void:
	pass   # no wandering — stays put

func interact(_interactor: Node) -> void:
	var ui := get_tree().get_first_node_in_group("shop_ui")
	if ui and ui.has_method("open"):
		ui.open(self)
	else:
		push_warning("ShopNPC: no node in group 'shop_ui' found in scene.")

## Build the buy stock list (duplicated items ready to sell).
func get_stock() -> Array:
	var result: Array = []
	for id in stock_item_ids:
		var item := Registry.get_item(id)
		if item:
			result.append(item)
	return result

## Price the player pays to buy an item.
func buy_price(item: ItemData) -> int:
	return max(1, int(float(item.value) * sell_multiplier))

## Price the shop pays to buy from the player.
func sell_price(item: ItemData) -> int:
	return max(1, int(float(item.value) * buy_multiplier))
