# ShopUI.gd
# Buy / Sell shop panel. Opened by ShopNPC.interact().
# Uses a simple gold integer stored on the player's Node (player.gold).
#
# SCENE TREE (ShopUI.tscn):
#   ShopUI              [CanvasLayer]  layer=6        ← this script
#                                      add_to_group("shop_ui")
#   └── Root            [PanelContainer]               anchors=center, min=(540,460)
#       └── MarginContainer
#           └── VBoxContainer
#               ├── TitleRow    [HBoxContainer]
#               │   ├── TitleLabel  [Label]            text="SHOP"
#               │   └── GoldLabel   [Label]            anchors=right
#               ├── TabBar      [TabContainer]
#               │   ├── BuyTab  [ScrollContainer]      name="Buy"
#               │   │   └── BuyList  [VBoxContainer]
#               │   └── SellTab [ScrollContainer]      name="Sell"
#               │       └── SellList [VBoxContainer]
#               └── CloseButton [Button]               text="Close"
class_name ShopUI
extends CanvasLayer

@onready var root:         PanelContainer = $Root
@onready var title_label:  Label          = $Root/MarginContainer/VBoxContainer/TitleRow/TitleLabel
@onready var gold_label:   Label          = $Root/MarginContainer/VBoxContainer/TitleRow/GoldLabel
@onready var buy_list:     VBoxContainer  = $Root/MarginContainer/VBoxContainer/TabBar/Buy/BuyList
@onready var sell_list:    VBoxContainer  = $Root/MarginContainer/VBoxContainer/TabBar/Sell/SellList
@onready var close_button: Button         = $Root/MarginContainer/VBoxContainer/CloseButton

var _shop: ShopNPC = null

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("shop_ui")
	root.visible = false
	close_button.pressed.connect(close)

func _input(event: InputEvent) -> void:
	if root.visible and event.is_action_just_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
# OPEN / CLOSE
# ══════════════════════════════════════════════════════════════════════════════

func open(shop: ShopNPC) -> void:
	_shop = shop
	title_label.text = shop.shop_name
	_refresh()
	root.visible     = true
	get_tree().paused = true
	EventBus.menu_opened.emit("shop")

func close() -> void:
	root.visible      = false
	get_tree().paused = false
	_shop             = null
	EventBus.menu_closed.emit("shop")

# ══════════════════════════════════════════════════════════════════════════════
# BUILD LISTS
# ══════════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	_update_gold()
	_build_buy_list()
	_build_sell_list()

func _update_gold() -> void:
	var player := GameManager.player_ref
	var gold   := player.get("gold") if player else 0
	gold_label.text = "Gold: %d" % gold

func _build_buy_list() -> void:
	for c in buy_list.get_children(): c.queue_free()
	if _shop == null: return
	for item in _shop.get_stock():
		buy_list.add_child(_make_row(
			item,
			"%d g" % _shop.buy_price(item),
			Color(0.9, 0.85, 0.3),
			func(): _buy(item)
		))

func _build_sell_list() -> void:
	for c in sell_list.get_children(): c.queue_free()
	if _shop == null: return
	for slot in InventoryManager.slots:
		if slot == null: continue
		sell_list.add_child(_make_row(
			slot,
			"%d g" % _shop.sell_price(slot),
			Color(0.6, 0.9, 0.5),
			func(): _sell(slot)
		))

func _make_row(item: ItemData, price_text: String, price_color: Color, callback: Callable) -> HBoxContainer:
	var row   := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon  := TextureRect.new()
	icon.texture                = item.icon
	icon.custom_minimum_size    = Vector2(28, 28)
	icon.expand_mode            = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text     = price_text
	price_lbl.modulate = price_color
	price_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(price_lbl)

	var btn := Button.new()
	btn.text = "Buy" if price_color == Color(0.9, 0.85, 0.3) else "Sell"
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(callback)
	row.add_child(btn)

	return row

# ══════════════════════════════════════════════════════════════════════════════
# TRANSACTIONS
# ══════════════════════════════════════════════════════════════════════════════

func _buy(item: ItemData) -> void:
	var player := GameManager.player_ref
	if player == null or _shop == null: return
	var price := _shop.buy_price(item)
	if player.get("gold") < price:
		EventBus.hud_show_message.emit("Not enough gold.", 1.5)
		return
	if not InventoryManager.add_item(item):
		EventBus.hud_show_message.emit("Inventory full!", 1.5)
		return
	player.gold -= price
	EventBus.hud_show_message.emit("Bought %s for %d g." % [item.display_name, price], 1.5)
	_refresh()

func _sell(item: ItemData) -> void:
	var player := GameManager.player_ref
	if player == null or _shop == null: return
	var price := _shop.sell_price(item)
	# Find the slot index for this exact item reference.
	var slot_idx := -1
	for i in InventoryManager.INVENTORY_SIZE:
		if InventoryManager.slots[i] == item:
			slot_idx = i
			break
	if slot_idx < 0: return
	InventoryManager.remove_item(slot_idx)
	player.gold += price
	EventBus.hud_show_message.emit("Sold %s for %d g." % [item.display_name, price], 1.5)
	_refresh()
