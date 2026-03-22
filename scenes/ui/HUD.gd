# HUD.gd
# In-world heads-up display. Reads exclusively from EventBus — zero direct refs.
# Manages: health/stamina/XP bars, hotbar, timed message queue, ammo counter.
#
# SCENE TREE (HUD.tscn):
#   HUD                    [CanvasLayer]  layer=1  ← this script
#   ├── TopBar             [MarginContainer]        anchors=top-wide
#   │   └── HBoxContainer
#   │       ├── HealthBar      [ProgressBar]        custom_min=(200,18)
#   │       ├── StaminaBar     [ProgressBar]        custom_min=(160,14)
#   │       └── XPBar          [ProgressBar]        custom_min=(120,10)
#   ├── HotbarRoot         [CenterContainer]        anchors=bottom-center
#   │   └── HotbarRow      [HBoxContainer]
#   │       └── (8× HotbarSlot scenes instanced here at runtime)
#   ├── AmmoLabel          [Label]                  anchors=bottom-right
#   ├── MessageContainer   [VBoxContainer]          anchors=top-center, offset_y=40
#   │   └── (MessageLabel scenes added at runtime)
#   └── LevelLabel         [Label]                  anchors=top-right
class_name HUD
extends CanvasLayer

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var health_bar:        ProgressBar    = $TopBar/HBoxContainer/HealthBar
@onready var stamina_bar:       ProgressBar    = $TopBar/HBoxContainer/StaminaBar
@onready var xp_bar:            ProgressBar    = $TopBar/HBoxContainer/XPBar
@onready var hotbar_row:        HBoxContainer  = $HotbarRoot/HotbarRow
@onready var ammo_label:        Label          = $AmmoLabel
@onready var message_container: VBoxContainer  = $MessageContainer
@onready var level_label:       Label          = $LevelLabel

const HOTBAR_SLOT_SCENE: PackedScene = preload("res://scenes/ui/HotbarSlot.tscn")

# ── Message queue ──────────────────────────────────────────────────────────────
## Each entry: { "label": Label, "timer": float }
var _messages: Array[Dictionary] = []
const MESSAGE_FADE_TIME: float = 0.4

# ── Hotbar slot refs ───────────────────────────────────────────────────────────
var _hotbar_slots: Array[Node] = []

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_hotbar()
	_connect_signals()
	ammo_label.visible   = false
	level_label.text     = "Lv. 1"
	xp_bar.max_value     = 100.0
	xp_bar.value         = 0.0

func _process(delta: float) -> void:
	_tick_messages(delta)
	_update_xp_bar()
	_update_ammo_label()

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL WIRING
# ══════════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.hotbar_slot_changed.connect(_on_hotbar_slot_changed)
	EventBus.active_hotbar_changed.connect(_on_active_hotbar_changed)
	EventBus.hud_show_message.connect(_on_show_message)
	EventBus.level_up.connect(_on_level_up)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH / STAMINA / XP
# ══════════════════════════════════════════════════════════════════════════════

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	_tween_bar(health_bar, float(current))

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	_tween_bar(stamina_bar, current)

func _update_xp_bar() -> void:
	xp_bar.max_value = float(CombatManager.xp_for_next_level())
	xp_bar.value     = float(CombatManager.current_xp)

func _on_level_up(new_level: int) -> void:
	level_label.text = "Lv. %d" % new_level
	# Flash the XP bar gold briefly.
	var tween := create_tween()
	tween.tween_property(xp_bar, "modulate", Color(1.0, 0.85, 0.1), 0.1)
	tween.tween_property(xp_bar, "modulate", Color.WHITE, 0.5)

func _tween_bar(bar: ProgressBar, target: float) -> void:
	var tween := bar.create_tween()
	tween.tween_property(bar, "value", target, 0.12).set_ease(Tween.EASE_OUT)

# ══════════════════════════════════════════════════════════════════════════════
# HOTBAR
# ══════════════════════════════════════════════════════════════════════════════

func _build_hotbar() -> void:
	for i in InventoryManager.HOTBAR_SIZE:
		var slot: Node = HOTBAR_SLOT_SCENE.instantiate()
		hotbar_row.add_child(slot)
		_hotbar_slots.append(slot)
		if slot.has_method("setup"):
			slot.setup(i)

func _on_hotbar_slot_changed(slot_index: int, item: Resource) -> void:
	if slot_index >= _hotbar_slots.size():
		return
	var slot := _hotbar_slots[slot_index]
	if slot.has_method("set_item"):
		slot.set_item(item)

func _on_active_hotbar_changed(slot_index: int) -> void:
	for i in _hotbar_slots.size():
		var slot := _hotbar_slots[i]
		if slot.has_method("set_active"):
			slot.set_active(i == slot_index)

# ══════════════════════════════════════════════════════════════════════════════
# AMMO
# ══════════════════════════════════════════════════════════════════════════════

func _update_ammo_label() -> void:
	var item := InventoryManager.get_active_item()
	if item is RangedData:
		var weapon := item as RangedData
		ammo_label.visible = true
		ammo_label.text    = "%d / %d" % [weapon._current_ammo, weapon.ammo_count]
		ammo_label.modulate = Color(1.0, 0.4, 0.4) if weapon._current_ammo == 0 \
			else Color.WHITE
	else:
		ammo_label.visible = false

# ══════════════════════════════════════════════════════════════════════════════
# MESSAGE QUEUE
# ══════════════════════════════════════════════════════════════════════════════

func _on_show_message(text: String, duration: float) -> void:
	# Re-use an existing label with the same text rather than stacking duplicates.
	for entry in _messages:
		if entry["label"].text == text:
			entry["timer"] = duration
			entry["label"].modulate.a = 1.0
			return

	var lbl := Label.new()
	lbl.text                   = text
	lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	message_container.add_child(lbl)
	_messages.append({ "label": lbl, "timer": duration })

func _tick_messages(delta: float) -> void:
	var i := 0
	while i < _messages.size():
		var entry: Dictionary = _messages[i]
		entry["timer"] -= delta
		var t := entry["timer"]
		# Fade out during the last MESSAGE_FADE_TIME seconds.
		if t < MESSAGE_FADE_TIME:
			entry["label"].modulate.a = maxf(0.0, t / MESSAGE_FADE_TIME)
		if t <= 0.0:
			entry["label"].queue_free()
			_messages.remove_at(i)
		else:
			i += 1

# ══════════════════════════════════════════════════════════════════════════════
# DEATH / RESPAWN
# ══════════════════════════════════════════════════════════════════════════════

func _on_player_died() -> void:
	_on_show_message("You died…", 3.0)

func _on_player_respawned(_pos: Vector2) -> void:
	_on_show_message("Respawned", 2.0)
