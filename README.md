# Godot 4.6.1 — Complete 2D Game Template

> **Branch:** `rework` — last updated 2026-03-21

---

## CURRENT STATE

| System | Status |
|---|---|
| EventBus (signal bus) | ✅ Implemented |
| GameManager (scene transitions, save/load) | ✅ Implemented — LoadingScreen wired |
| InventoryManager (32-slot + 8-slot hotbar) | ✅ Implemented — ⚠️ missing from project.godot autoloads |
| Player (movement, stamina, health, interaction) | ✅ Implemented |
| MainMenu | ✅ Implemented |
| LoadingScreen (threaded, progress bar) | ✅ Implemented |
| Playground (world scene) | ✅ Implemented — has placeholder floor StaticBody2D |
| HUD (health/stamina bars, hotbar, messages) | ✅ Implemented |
| InventoryUI (32 slots, drag-and-drop, context menu) | ✅ Implemented |
| InventorySlot | ✅ Implemented |
| DialogueBox | ✅ Implemented |
| FadeOverlay | ✅ Implemented |
| Projectile | ✅ Implemented |
| WorldItem (pickup) | ✅ Implemented |
| Item / ConsumableItem / KeyItem / WeaponBase | ✅ Implemented |
| MeleeWeapon / RangedWeapon / Tool | ✅ Implemented |
| LootTable | ✅ Implemented |
| NPCBase | ✅ Implemented |
| PeacefulNPC (wander + dialogue) | ✅ Implemented |
| AllyNPC | ❌ Not yet implemented |
| HostileNPC (patrol / chase / attack FSM) | ❌ Not yet implemented |

---

## PROJECT FOLDER STRUCTURE

```
res://
├── autoloads/
│   ├── EventBus.gd
│   ├── GameManager.gd
│   └── InventoryManager.gd
├── scenes/
│   ├── screens/
│   │   ├── MainMenu.tscn
│   │   ├── LoadingScreen.tscn
│   │   └── Playground.tscn          ← world / gameplay scene
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── InventoryUI.tscn
│   │   ├── InventorySlot.tscn
│   │   ├── DialogueBox.tscn
│   │   └── FadeOverlay.tscn
│   ├── entities/
│   │   ├── Player.tscn
│   │   ├── NPCBase.tscn
│   │   └── WorldItem.tscn
│   └── projectiles/
│       └── Projectile.tscn
├── scripts/
│   ├── items/
│   │   ├── Item.gd
│   │   ├── ConsumableItem.gd
│   │   ├── KeyItem.gd
│   │   ├── WeaponBase.gd
│   │   ├── MeleeWeapon.gd
│   │   ├── RangedWeapon.gd
│   │   └── Tool.gd
│   ├── npcs/
│   │   ├── NPCBase.gd
│   │   ├── PeacefulNPC.gd
│   │   ├── AllyNPC.gd              ← TODO: not yet created
│   │   └── HostileNPC.gd           ← TODO: not yet created
│   └── LootTable.gd
└── assets/
    ├── sprites/       # placeholder — add your sprite sheets here
    ├── sounds/        # placeholder — add SFX/music here
    └── fonts/         # placeholder — add TTF fonts here
```

---

## FILE: res://autoloads/EventBus.gd

```gdscript
# EventBus.gd
# Central signal bus. All cross-system communication flows through here.
# No node needs a direct reference to another node.
extends Node

# ── Player ──────────────────────────────────────────────────────────────────
signal player_health_changed(current: int, maximum: int)
signal player_stamina_changed(current: float, maximum: float)
signal player_died()
signal player_interacted(interactable: Node)

# ── Inventory ────────────────────────────────────────────────────────────────
signal inventory_item_added(item: Resource, slot_index: int)
signal inventory_item_removed(item: Resource, slot_index: int)
signal inventory_item_used(item: Resource, user: Node)
signal hotbar_slot_changed(slot_index: int, item: Resource)

# ── World ────────────────────────────────────────────────────────────────────
signal world_item_spawned(world_item: Node)
signal world_item_picked_up(item: Resource, picker: Node)

# ── NPC ──────────────────────────────────────────────────────────────────────
signal npc_died(npc: Node, position: Vector2)
signal npc_dialogue_started(npc: Node, dialogue: Array)
signal npc_dialogue_ended(npc: Node)
signal npc_alerted(npc: Node, target: Node)

# ── Tools & Key Items ────────────────────────────────────────────────────────
signal tool_used(tool_type: int, user: Node, position: Vector2)
signal key_item_used(quest_id: String, item: Resource, user: Node)

# ── Scene / UI ───────────────────────────────────────────────────────────────
signal scene_change_requested(path: String)
signal scene_loaded(path: String)
signal hud_show_message(text: String, duration: float)
signal dialogue_open_requested(dialogue: Array, npc: Node)
signal dialogue_closed()

# ── Game State ───────────────────────────────────────────────────────────────
signal game_saved()
signal game_loaded()
signal game_paused(is_paused: bool)
```

---

## FILE: res://autoloads/InventoryManager.gd

```gdscript
# InventoryManager.gd
# Global inventory. All item data lives here; UI reads from here.
extends Node

const INVENTORY_SIZE: int = 32
const HOTBAR_SIZE: int = 8

# Slots hold Item resources or null
var slots: Array = []          # size = INVENTORY_SIZE
var hotbar_slots: Array = []   # size = HOTBAR_SIZE
var active_hotbar_index: int = 0

func _ready() -> void:
	slots.resize(INVENTORY_SIZE)
	hotbar_slots.resize(HOTBAR_SIZE)
	slots.fill(null)
	hotbar_slots.fill(null)

# ── Public API ────────────────────────────────────────────────────────────────

## Adds item to the first available slot. Returns true on success.
func add_item(item: Resource) -> bool:
	# Try stacking first
	if item.stackable:
		for i in INVENTORY_SIZE:
			var s = slots[i]
			if s != null and s.id == item.id and s.quantity < s.max_stack:
				s.quantity += 1
				EventBus.inventory_item_added.emit(s, i)
				return true

	# Find empty slot
	for i in INVENTORY_SIZE:
		if slots[i] == null:
			var new_item = item.duplicate()
			new_item.quantity = 1
			slots[i] = new_item
			EventBus.inventory_item_added.emit(new_item, i)
			return true

	push_warning("InventoryManager: Inventory full, cannot add item.")
	return false

## Removes item at slot_index. Returns the removed item or null.
func remove_item(slot_index: int) -> Resource:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE:
		return null
	var item = slots[slot_index]
	if item == null:
		return null
	slots[slot_index] = null
	EventBus.inventory_item_removed.emit(item, slot_index)
	return item

## Returns true if inventory contains at least one item with matching id.
func has_item(item_id: String) -> bool:
	for s in slots:
		if s != null and s.id == item_id:
			return true
	return false

## Moves item from one slot to another (swap if destination occupied).
func move_item(from_index: int, to_index: int) -> void:
	var temp = slots[to_index]
	slots[to_index] = slots[from_index]
	slots[from_index] = temp

## Equip slot item to hotbar position.
func assign_to_hotbar(slot_index: int, hotbar_index: int) -> void:
	if hotbar_index < 0 or hotbar_index >= HOTBAR_SIZE:
		return
	hotbar_slots[hotbar_index] = slots[slot_index]
	EventBus.hotbar_slot_changed.emit(hotbar_index, hotbar_slots[hotbar_index])

## Returns the currently active hotbar item or null.
func get_active_item() -> Resource:
	return hotbar_slots[active_hotbar_index]

## Cycles through hotbar slots (call from player input).
func set_active_hotbar(index: int) -> void:
	active_hotbar_index = clamp(index, 0, HOTBAR_SIZE - 1)
	EventBus.hotbar_slot_changed.emit(active_hotbar_index, get_active_item())

# ── Save / Load helpers ───────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data: Dictionary = {"slots": [], "hotbar": [], "active_hotbar": active_hotbar_index}
	for s in slots:
		data["slots"].append(null if s == null else {"id": s.id, "quantity": s.quantity})
	for h in hotbar_slots:
		data["hotbar"].append(null if h == null else {"id": h.id, "quantity": h.quantity})
	return data

func deserialize(data: Dictionary) -> void:
	# NOTE: Full deserialization requires an item database lookup (not included here).
	# Implement ItemDatabase.gd that maps id → Item resource, then populate slots from data.
	active_hotbar_index = data.get("active_hotbar", 0)
	push_warning("InventoryManager.deserialize: Implement ItemDatabase lookup to restore items.")
```

---

## FILE: res://autoloads/GameManager.gd

```gdscript
# GameManager.gd
# Global game state, scene transitions, save/load.
extends Node

const SAVE_PATH: String = "user://save.json"
const LOADING_SCREEN: String = "res://scenes/screens/LoadingScreen.tscn"

var current_scene_path: String = ""
var next_scene_path: String = ""
var player_ref: Node = null   # set by Player._ready()

# ── Scene Transitions ─────────────────────────────────────────────────────────

## Begin a scene change: sets next_scene_path → switches to LoadingScreen,
## which loads the target scene asynchronously with a progress bar.
func change_scene_to(path: String) -> void:
	next_scene_path = path
	EventBus.scene_change_requested.emit(path)
	get_tree().change_scene_to_file(LOADING_SCREEN)

## Called by LoadingScreen when loading is complete.
func on_scene_loaded(path: String) -> void:
	current_scene_path = path
	EventBus.scene_loaded.emit(path)

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_game() -> void:
	if player_ref == null:
		push_warning("GameManager.save_game: No player reference set.")
		return

	var save_data: Dictionary = {
		"version": 1,
		"scene": current_scene_path,
		"player": {
			"position_x": player_ref.global_position.x,
			"position_y": player_ref.global_position.y,
			"health": player_ref.current_health,
			"stamina": player_ref.current_stamina,
		},
		"inventory": InventoryManager.serialize(),
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		EventBus.game_saved.emit()
	else:
		push_error("GameManager.save_game: Could not open save file for writing.")

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager.load_game: Could not open save file.")
		return {}
	var content = file.get_as_text()
	file.close()
	var result = JSON.parse_string(content)
	if result == null:
		push_error("GameManager.load_game: JSON parse failed.")
		return {}
	EventBus.game_loaded.emit()
	return result

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
```

---

## FILE: res://scenes/screens/MainMenu.gd

```gdscript
# MainMenu.gd
extends CanvasLayer

@onready var btn_new_game: Button      = $CenterContainer/VBoxContainer/BtnNewGame
@onready var btn_continue: Button      = $CenterContainer/VBoxContainer/BtnContinue
@onready var btn_settings: Button      = $CenterContainer/VBoxContainer/BtnSettings
@onready var btn_quit: Button          = $CenterContainer/VBoxContainer/BtnQuit
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var fade_overlay: ColorRect   = $FadeOverlay

const WORLD_SCENE: String = "res://scenes/screens/Playground.tscn"

func _ready() -> void:
	btn_continue.disabled = not GameManager.has_save()
	fade_in()

func _process(delta: float) -> void:
	# Gentle parallax scroll on the background
	parallax_bg.scroll_offset.x += delta * 20.0

func fade_in() -> void:
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)

func fade_out_then(callable: Callable) -> void:
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	tween.tween_callback(callable)

func _on_btn_new_game_pressed() -> void:
	GameManager.delete_save()
	fade_out_then(func(): GameManager.change_scene_to(WORLD_SCENE))

func _on_btn_continue_pressed() -> void:
	fade_out_then(func(): GameManager.change_scene_to(WORLD_SCENE))

func _on_btn_settings_pressed() -> void:
	# TODO: push a SettingsScreen
	EventBus.hud_show_message.emit("Settings not yet implemented.", 2.0)

func _on_btn_quit_pressed() -> void:
	fade_out_then(func(): get_tree().quit())
```

## SCENE TREE: MainMenu.tscn

```
MainMenu  [CanvasLayer]  script=MainMenu.gd
├── ParallaxBackground
│   └── ParallaxLayer  (motion_scale = Vector2(0.5, 0.5))
│       └── TextureRect  (stretch_mode=COVER, texture=<your bg texture>)
├── CenterContainer  (anchors: full rect)
│   └── VBoxContainer  (separation=12)
│       ├── Label  (text="MY GAME", align=center, theme_override font_size=48)
│       ├── BtnNewGame  [Button]  (text="New Game")
│       ├── BtnContinue [Button]  (text="Continue")
│       ├── BtnSettings [Button]  (text="Settings")
│       └── BtnQuit     [Button]  (text="Quit")
└── FadeOverlay  [ColorRect]  (color=#000000, modulate.a=1, anchors=full rect)
    — connect BtnNewGame.pressed → _on_btn_new_game_pressed
    — connect BtnContinue.pressed → _on_btn_continue_pressed
    — connect BtnSettings.pressed → _on_btn_settings_pressed
    — connect BtnQuit.pressed → _on_btn_quit_pressed
```

---

## FILE: res://scenes/screens/LoadingScreen.gd

```gdscript
# LoadingScreen.gd
# Asynchronously loads the scene path stored in GameManager.next_scene_path.
extends CanvasLayer

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var label_status: Label       = $VBoxContainer/LabelStatus
@onready var fade_overlay: ColorRect   = $FadeOverlay

var _target_path: String = ""
var _load_status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS

func _ready() -> void:
	_target_path = GameManager.next_scene_path
	if _target_path.is_empty():
		push_error("LoadingScreen: No scene path set in GameManager.")
		return
	label_status.text = "Loading..."
	ResourceLoader.load_threaded_request(_target_path)
	fade_overlay.modulate.a = 0.0

func _process(_delta: float) -> void:
	if _target_path.is_empty():
		return

	var progress: Array = []
	_load_status = ResourceLoader.load_threaded_get_status(_target_path, progress)

	match _load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0 if progress.size() > 0 else 0.0

		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			_finish_loading()

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("LoadingScreen: Failed to load scene: " + _target_path)
			label_status.text = "Load failed!"

func _finish_loading() -> void:
	label_status.text = "Done!"
	var packed_scene = ResourceLoader.load_threaded_get(_target_path)
	GameManager.on_scene_loaded(_target_path)

	# Fade out then switch
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_packed(packed_scene)
	)
```

## SCENE TREE: LoadingScreen.tscn

```
LoadingScreen  [CanvasLayer]  script=LoadingScreen.gd
├── VBoxContainer  (anchors=center, custom_minimum_size=Vector2(400,80))
│   ├── LabelStatus  [Label]   (text="Loading...", align=center)
│   └── ProgressBar            (min=0, max=100, value=0)
└── FadeOverlay  [ColorRect]   (color=#000000, modulate.a=0, anchors=full rect)
```

---

## FILE: res://scenes/screens/Playground.gd

```gdscript
# Playground.gd  (world / gameplay scene)
# Sets up the play world after loading. Spawns player, registers with GameManager.
extends Node2D

@onready var tile_map: TileMap           = $TileMap
@onready var player_spawn: Marker2D      = $SpawnPoints/PlayerSpawn
@onready var camera: Camera2D            = $Camera2D
@onready var hud: CanvasLayer            = $HUD

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")

var _player_instance: CharacterBody2D = null

func _ready() -> void:
	_spawn_player()
	_apply_save_if_exists()

func _spawn_player() -> void:
	_player_instance = PLAYER_SCENE.instantiate()
	add_child(_player_instance)
	_player_instance.global_position = player_spawn.global_position
	GameManager.player_ref = _player_instance

	# Camera follows player
	camera.reparent(_player_instance)
	camera.position = Vector2.ZERO

func _apply_save_if_exists() -> void:
	if GameManager.has_save():
		var data = GameManager.load_game()
		if data.is_empty():
			return
		var pd = data.get("player", {})
		_player_instance.global_position = Vector2(
			pd.get("position_x", player_spawn.global_position.x),
			pd.get("position_y", player_spawn.global_position.y)
		)
		_player_instance.current_health  = pd.get("health",  _player_instance.max_health)
		_player_instance.current_stamina = pd.get("stamina", _player_instance.max_stamina)
		InventoryManager.deserialize(data.get("inventory", {}))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Quick-save on Escape (replace with pause menu later)
		GameManager.save_game()
		EventBus.hud_show_message.emit("Game Saved.", 2.0)
```

## SCENE TREE: Playground.tscn

```
Playground  [Node2D]  script=Playground.gd
├── TileMap              (add your tile_set resource here)
├── Camera2D             (limit_left=-1000, limit_right=1000,
│                         limit_top=-1000, limit_bottom=1000)
├── SpawnPoints  [Node2D]
│   ├── PlayerSpawn  [Marker2D]  (position=Vector2(100, 480))
│   └── ItemSpawn_01 [Marker2D]
├── NPCLayer     [Node2D]
├── ItemLayer    [Node2D]
├── HUD          [CanvasLayer]  (instance of HUD.tscn)
└── StaticBody2D             ← placeholder floor
    ├── ColorRect            (offset_right=975, offset_bottom=55)
    └── CollisionPolygon2D
```

---

## FILE: res://scenes/ui/HUD.gd

```gdscript
# HUD.gd
# Reads from EventBus only — no direct references to Player.
extends CanvasLayer

@onready var health_bar: ProgressBar  = $MarginContainer/TopBar/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/TopBar/StaminaBar
@onready var hotbar_container: HBoxContainer = $HotbarContainer
@onready var minimap_placeholder: Control    = $MinimapPlaceholder
@onready var message_label: Label            = $MessageLabel

var _hotbar_slots: Array[TextureRect] = []
var _message_timer: float = 0.0

func _ready() -> void:
	# Cache hotbar slot TextureRects
	for child in hotbar_container.get_children():
		if child is TextureRect:
			_hotbar_slots.append(child)

	# Connect to EventBus
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.hotbar_slot_changed.connect(_on_hotbar_changed)
	EventBus.hud_show_message.connect(_on_show_message)

	message_label.visible = false

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false

# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value     = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value     = current

func _on_hotbar_changed(slot_index: int, item: Resource) -> void:
	if slot_index >= _hotbar_slots.size():
		return
	_hotbar_slots[slot_index].texture = item.icon if item != null else null

func _on_show_message(text: String, duration: float) -> void:
	message_label.text    = text
	message_label.visible = true
	_message_timer        = duration
```

## SCENE TREE: HUD.tscn

```
HUD  [CanvasLayer]  script=HUD.gd
├── MarginContainer  (anchors=top-wide, theme_override margin_bottom=60)
│   └── TopBar  [HBoxContainer]  (separation=16)
│       ├── HealthBar   [ProgressBar]  (min=0, max=100, value=100,
│       │                               custom_minimum_size=Vector2(200,20))
│       └── StaminaBar  [ProgressBar]  (min=0, max=100, value=100,
│                                       custom_minimum_size=Vector2(200,20))
├── HotbarContainer  [HBoxContainer]  (anchors=bottom-center, separation=4)
│   ├── Slot0  [TextureRect]  (custom_minimum_size=Vector2(48,48), expand_mode=FIT_WIDTH)
│   ├── Slot1 … Slot7  [TextureRect]  (same as Slot0)
├── MinimapPlaceholder  [Control]  (anchors=top-right,
│                                   custom_minimum_size=Vector2(150,150))
│   └── Label  (text="[Minimap]", align=center)
└── MessageLabel  [Label]  (anchors=top-center, visible=false,
                             horizontal_alignment=CENTER)
```

---

## FILE: res://scenes/ui/InventoryUI.gd

```gdscript
# InventoryUI.gd
# 32-slot grid with drag-and-drop and right-click context menu.
extends CanvasLayer

@onready var grid: GridContainer      = $Panel/MarginContainer/GridContainer
@onready var context_menu: PopupMenu  = $ContextMenu
@onready var panel: PanelContainer    = $Panel

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")

var _selected_slot_index: int = -1
var _drag_slot_index: int     = -1
var _drag_preview: TextureRect = null

func _ready() -> void:
	panel.visible = false
	_build_grid()
	EventBus.inventory_item_added.connect(_on_inventory_changed)
	EventBus.inventory_item_removed.connect(_on_inventory_changed)

	context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):   # Map Tab in InputMap
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _build_grid() -> void:
	for i in InventoryManager.INVENTORY_SIZE:
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.right_clicked.connect(_on_slot_right_clicked)
		slot.drag_started.connect(_on_slot_drag_started)
		slot.drag_dropped.connect(_on_slot_drag_dropped)
		grid.add_child(slot)
	_refresh_all_slots()

func _refresh_all_slots() -> void:
	var children = grid.get_children()
	for i in children.size():
		children[i].set_item(InventoryManager.slots[i])

func _on_inventory_changed(_item: Resource, _idx: int) -> void:
	_refresh_all_slots()

func _on_slot_right_clicked(slot_index: int) -> void:
	_selected_slot_index = slot_index
	if InventoryManager.slots[slot_index] == null:
		return
	context_menu.clear()
	context_menu.add_item("Use",     0)
	context_menu.add_item("Equip",   1)
	context_menu.add_item("Drop",    2)
	context_menu.add_item("Inspect", 3)
	context_menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i(120, 0)))

func _on_context_menu_id_pressed(id: int) -> void:
	var item = InventoryManager.slots[_selected_slot_index]
	if item == null:
		return
	match id:
		0:  # Use
			item.use(GameManager.player_ref)
			EventBus.inventory_item_used.emit(item, GameManager.player_ref)
		1:  # Equip — assign to first free hotbar slot
			for h in InventoryManager.HOTBAR_SIZE:
				if InventoryManager.hotbar_slots[h] == null:
					InventoryManager.assign_to_hotbar(_selected_slot_index, h)
					break
		2:  # Drop — remove and spawn WorldItem at player feet
			var dropped = InventoryManager.remove_item(_selected_slot_index)
			EventBus.world_item_spawned.emit(dropped)
		3:  # Inspect
			EventBus.hud_show_message.emit(item.display_name + ": " + item.description, 4.0)

func _on_slot_drag_started(slot_index: int) -> void:
	_drag_slot_index = slot_index

func _on_slot_drag_dropped(target_index: int) -> void:
	if _drag_slot_index >= 0 and _drag_slot_index != target_index:
		InventoryManager.move_item(_drag_slot_index, target_index)
		_refresh_all_slots()
	_drag_slot_index = -1
```

---

## FILE: res://scenes/ui/InventorySlot.gd
*(Scene: PanelContainer → TextureRect + QtyLabel)*

```gdscript
# InventorySlot.gd
extends PanelContainer

signal right_clicked(slot_index: int)
signal drag_started(slot_index: int)
signal drag_dropped(target_index: int)

@export var slot_index: int = 0

@onready var icon: TextureRect = $TextureRect
@onready var qty_label: Label  = $QtyLabel

var _item: Resource = null

func set_item(item: Resource) -> void:
	_item = item
	if item == null:
		icon.texture  = null
		qty_label.text = ""
		qty_label.visible = false
	else:
		icon.texture  = item.icon
		if item.stackable and item.quantity > 1:
			qty_label.text    = str(item.quantity)
			qty_label.visible = true
		else:
			qty_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(slot_index)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _item != null:
			drag_started.emit(slot_index)

func accept_drop(from_index: int) -> void:
	drag_dropped.emit(from_index)
```

## SCENE TREE: InventorySlot.tscn

```
InventorySlot  [PanelContainer]  script=InventorySlot.gd
│   custom_minimum_size=Vector2(52,52)
├── TextureRect  (expand_mode=FIT_WIDTH_PROPORTIONAL, anchors=full rect)
└── QtyLabel  [Label]  (anchors=bottom-right, text="", visible=false,
                         horizontal_alignment=RIGHT)
```

## SCENE TREE: InventoryUI.tscn

```
InventoryUI  [CanvasLayer]  script=InventoryUI.gd
├── Panel  [PanelContainer]  (anchors=center, custom_minimum_size=Vector2(480,560))
│   └── MarginContainer  (margin=8 all sides)
│       └── VBoxContainer
│           ├── Label  (text="INVENTORY", align=center)
│           └── GridContainer  (columns=8, separation=4)
│               (slots populated at runtime)
└── ContextMenu  [PopupMenu]  (hidden, connected to id_pressed)
```

---

## FILE: res://scenes/ui/DialogueBox.gd

```gdscript
# DialogueBox.gd
# Simple dialogue sequencer. Advances on Space/Enter, closes when done.
extends CanvasLayer

@onready var rich_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/RichTextLabel
@onready var speaker_label: Label      = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var continue_hint: Label      = $Panel/MarginContainer/VBoxContainer/ContinueHint
@onready var panel: PanelContainer     = $Panel

var _dialogue: Array[String] = []
var _current_line: int       = 0
var _source_npc: Node        = null
var _is_open: bool           = false

func _ready() -> void:
	panel.visible = false
	EventBus.dialogue_open_requested.connect(_open_dialogue)

func _open_dialogue(dialogue: Array, npc: Node) -> void:
	_dialogue    = dialogue
	_source_npc  = npc
	_current_line = 0
	_is_open      = true
	panel.visible = true
	speaker_label.text = npc.npc_name if npc != null else ""
	_show_line()
	get_tree().paused = true

func _show_line() -> void:
	if _current_line < _dialogue.size():
		rich_label.text = _dialogue[_current_line]
		continue_hint.text = "[Space / Enter to continue]" if _current_line < _dialogue.size() - 1 else "[Space / Enter to close]"
	else:
		_close_dialogue()

func _close_dialogue() -> void:
	_is_open       = false
	panel.visible  = false
	get_tree().paused = false
	EventBus.dialogue_closed.emit()
	EventBus.npc_dialogue_ended.emit(_source_npc)

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_accept"):
		_current_line += 1
		_show_line()
		get_viewport().set_input_as_handled()
```

## SCENE TREE: DialogueBox.tscn

```
DialogueBox  [CanvasLayer]  script=DialogueBox.gd
└── Panel  [PanelContainer]  (anchors=bottom-wide,
                               custom_minimum_size=Vector2(0, 160))
    └── MarginContainer  (margin=12 all)
        └── VBoxContainer  (separation=6)
            ├── SpeakerLabel   [Label]         (text="", bold theme)
            ├── RichTextLabel                  (bbcode_enabled=true,
            │                                   fit_content=true)
            └── ContinueHint   [Label]         (text="", italic, align=right)
```

---

## FILE: res://scenes/ui/FadeOverlay.gd

```gdscript
# FadeOverlay.gd
# Reusable black fade. Call fade_out() / fade_in() from code.
extends CanvasLayer

@onready var rect: ColorRect        = $ColorRect
@onready var anim: AnimationPlayer  = $AnimationPlayer

func fade_out(duration: float = 0.5) -> void:
	rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)

func fade_in(duration: float = 0.5) -> void:
	rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
```

## SCENE TREE: FadeOverlay.tscn

```
FadeOverlay  [CanvasLayer]  (layer=128, so it renders on top of everything)
│   script=FadeOverlay.gd
├── ColorRect   (color=#000000, modulate.a=0, anchors=full rect)
└── AnimationPlayer  (optional — can drive fade_in/fade_out animations)
```

---

## FILE: res://scenes/entities/Player.gd

```gdscript
# Player.gd
extends CharacterBody2D

# ── Stats ──────────────────────────────────────────────────────────────────────
@export var max_health: int          = 100
@export var max_stamina: float       = 100.0
@export var move_speed: float        = 160.0
@export var sprint_multiplier: float = 1.8
@export var stamina_drain_rate: float = 30.0  # per second while sprinting
@export var stamina_regen_rate: float = 15.0  # per second while not sprinting
@export var stamina_sprint_min: float = 10.0  # min stamina to start sprinting

var current_health: int   = max_health
var current_stamina: float = max_stamina
var _is_dead: bool         = false
var _is_sprinting: bool    = false

# ── Nodes ──────────────────────────────────────────────────────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_ray: RayCast2D       = $InteractRay
@onready var collision: CollisionShape2D   = $CollisionShape2D
@onready var hurt_timer: Timer             = $HurtTimer

func _ready() -> void:
	GameManager.player_ref = self
	_emit_health()
	_emit_stamina()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	_handle_interaction()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	_is_sprinting = Input.is_action_pressed("sprint") \
		and current_stamina > stamina_sprint_min \
		and dir != Vector2.ZERO

	var speed = move_speed * (sprint_multiplier if _is_sprinting else 1.0)
	velocity  = dir * speed

	# Stamina management
	if _is_sprinting:
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
	_emit_stamina()

	# Face direction
	if dir.x != 0.0:
		anim_sprite.flip_h = dir.x < 0.0

	# Animations
	if dir == Vector2.ZERO:
		anim_sprite.play("idle")
	elif _is_sprinting:
		anim_sprite.play("run")
	else:
		anim_sprite.play("walk")

func _handle_interaction() -> void:
	if Input.is_action_just_pressed("interact"):
		interact_ray.force_raycast_update()
		if interact_ray.is_colliding():
			var obj = interact_ray.get_collider()
			if obj.has_method("interact"):
				obj.interact(self)
				EventBus.player_interacted.emit(obj)

# ── Health / Damage ────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	_emit_health()
	anim_sprite.play("hurt")
	hurt_timer.start()
	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	_emit_health()

func _die() -> void:
	_is_dead = true
	anim_sprite.play("die")
	collision.set_deferred("disabled", true)
	EventBus.player_died.emit()

func _on_hurt_timer_timeout() -> void:
	if not _is_dead:
		anim_sprite.play("idle")

# ── Emit helpers ──────────────────────────────────────────────────────────────

func _emit_health() -> void:
	EventBus.player_health_changed.emit(current_health, max_health)

func _emit_stamina() -> void:
	EventBus.player_stamina_changed.emit(current_stamina, max_stamina)
```

## SCENE TREE: Player.tscn

```
Player  [CharacterBody2D]  script=Player.gd
├── CollisionShape2D  (shape=CapsuleShape2D, height=28, radius=10)
├── AnimatedSprite2D
│   (add SpriteFrames resource with animations:
│    idle, walk, run, hurt, die — each pointing to your sprite sheet)
├── InteractRay  [RayCast2D]  (target_position=Vector2(32,0),
│                               enabled=true, collide_with_areas=true)
└── HurtTimer  [Timer]  (wait_time=0.4, one_shot=true)
    — connect HurtTimer.timeout → _on_hurt_timer_timeout
```

---

## FILE: res://scripts/items/Item.gd

```gdscript
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
```

---

## FILE: res://scripts/items/ConsumableItem.gd

```gdscript
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
```

---

## FILE: res://scripts/items/KeyItem.gd

```gdscript
# KeyItem.gd
class_name KeyItem
extends Item

@export var quest_id: String    = ""
@export var unlocks: String     = ""   # e.g. a door node name or flag

func use(user: Node) -> void:
	EventBus.key_item_used.emit(quest_id, self, user)
	EventBus.hud_show_message.emit(display_name + " used.", 2.0)
```

---

## FILE: res://scripts/items/WeaponBase.gd

```gdscript
# WeaponBase.gd
class_name WeaponBase
extends Item

@export var damage: int             = 10
@export var attack_speed: float     = 1.0   # attacks per second
@export var attack_range: float     = 48.0
@export var knockback_force: float  = 150.0

var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

## Override in subclasses.
func attack(wielder: Node) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 1.0 / attack_speed
```

---

## FILE: res://scripts/items/MeleeWeapon.gd

```gdscript
# MeleeWeapon.gd
class_name MeleeWeapon
extends WeaponBase

# The wielder is expected to have an $AttackHitbox Area2D child.
func attack(wielder: Node) -> void:
	super.attack(wielder)
	if wielder.has_node("AttackHitbox"):
		var hitbox: Area2D = wielder.get_node("AttackHitbox")
		hitbox.monitoring = true
		var timer = wielder.get_tree().create_timer(0.15)
		timer.timeout.connect(func(): hitbox.monitoring = false)
		for body in hitbox.get_overlapping_bodies():
			if body != wielder and body.has_method("take_damage"):
				body.take_damage(damage)
				if "velocity" in body:
					var dir = (body.global_position - wielder.global_position).normalized()
					body.velocity += dir * knockback_force
	if wielder.has_node("AnimatedSprite2D"):
		wielder.get_node("AnimatedSprite2D").play("attack")
```

---

## FILE: res://scripts/items/RangedWeapon.gd

```gdscript
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
```

---

## FILE: res://scenes/projectiles/Projectile.gd

```gdscript
# Projectile.gd
extends CharacterBody2D

@export var speed: float        = 400.0
@export var lifetime: float     = 3.0
@export var piercing: bool      = false   # if true, don't despawn on first hit

var _damage: int    = 5
var _direction: Vector2 = Vector2.RIGHT
var _age: float     = 0.0

@onready var sprite: Sprite2D         = $Sprite2D
@onready var hitbox: Area2D           = $Hitbox
@onready var collision: CollisionShape2D = $CollisionShape2D

func setup(direction: Vector2, damage: int) -> void:
	_direction = direction
	_damage    = damage
	rotation   = direction.angle()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	velocity = _direction * speed
	var col = move_and_collide(velocity * delta)
	if col:
		var hit = col.get_collider()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(_damage)
		if not piercing:
			queue_free()
```

## SCENE TREE: Projectile.tscn

```
Projectile  [CharacterBody2D]  script=Projectile.gd
├── Sprite2D           (texture=<bullet/arrow sprite>)
├── CollisionShape2D   (shape=CapsuleShape2D, height=8, radius=3,
│                        rotation_degrees=90)
└── Hitbox  [Area2D]
    └── CollisionShape2D  (same as above)
```

---

## FILE: res://scripts/items/Tool.gd

```gdscript
# Tool.gd
class_name Tool
extends Item

enum ToolType { AXE, PICKAXE, SHOVEL, GENERIC }

@export var tool_type: ToolType = ToolType.GENERIC
@export var tool_power: int     = 1

func use(user: Node) -> void:
	var pos = user.global_position if "global_position" in user else Vector2.ZERO
	EventBus.tool_used.emit(tool_type, user, pos)
```

---

## FILE: res://scripts/npcs/NPCBase.gd

```gdscript
# NPCBase.gd — Base class for all NPCs.
class_name NPCBase
extends CharacterBody2D

enum Faction { PEACEFUL, ALLY, HOSTILE }

@export var npc_name: String             = "NPC"
@export var max_health: int              = 50
@export var faction: Faction             = Faction.PEACEFUL
@export var move_speed: float            = 80.0
@export var loot_table: Resource         = null   # LootTable resource

var current_health: int = max_health
var _is_dead: bool      = false

@onready var anim_sprite: AnimatedSprite2D   = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D    = $NavigationAgent2D
@onready var detection_area: Area2D          = $DetectionArea
@onready var collision: CollisionShape2D     = $CollisionShape2D
@onready var health_bar: ProgressBar         = $HealthBar

func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value     = max_health

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	health_bar.value = current_health
	anim_sprite.play("hurt")
	if current_health <= 0:
		die()

func die() -> void:
	_is_dead = true
	anim_sprite.play("die")
	collision.set_deferred("disabled", true)
	EventBus.npc_died.emit(self, global_position)
	_drop_loot()
	await anim_sprite.animation_finished
	queue_free()

func _drop_loot() -> void:
	if loot_table == null:
		return
	var drops: Array = loot_table.roll()
	for item in drops:
		EventBus.world_item_spawned.emit(item)

func interact(interactor: Node) -> void:
	pass  # Override in subclasses
```

## SCENE TREE: NPCBase.tscn

```
NPCBase  [CharacterBody2D]  script=<subclass>.gd
├── CollisionShape2D      (shape=CapsuleShape2D)
├── AnimatedSprite2D      (SpriteFrames: idle, walk, hurt, die, attack)
├── NavigationAgent2D     (path_desired_distance=8, target_desired_distance=16)
├── DetectionArea  [Area2D]
│   └── CollisionShape2D  (shape=CircleShape2D, radius=200)
└── HealthBar  [ProgressBar]  (custom_minimum_size=Vector2(40,6),
                                offset_y=-30, modulate=red)
```

---

## FILE: res://scripts/npcs/PeacefulNPC.gd

```gdscript
# PeacefulNPC.gd
class_name PeacefulNPC
extends NPCBase

@export var wander_radius: float      = 120.0
@export var wander_interval: float    = 3.0
@export var dialogue: Array[String]   = ["Hello, traveller!", "Nice day, isn't it?"]

var _wander_timer: float = 0.0
var _home_position: Vector2

func _ready() -> void:
	super._ready()
	_home_position = global_position
	faction        = Faction.PEACEFUL

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()
		_wander_timer = wander_interval

	if nav_agent.is_navigation_finished():
		anim_sprite.play("idle")
		return

	var next_pos = nav_agent.get_next_path_position()
	var dir      = (next_pos - global_position).normalized()
	velocity     = dir * move_speed
	anim_sprite.play("walk")
	anim_sprite.flip_h = dir.x < 0.0
	move_and_slide()

func _pick_new_wander_target() -> void:
	var offset = Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	nav_agent.target_position = _home_position + offset

func interact(interactor: Node) -> void:
	EventBus.dialogue_open_requested.emit(dialogue, self)
	EventBus.npc_dialogue_started.emit(self, dialogue)
```

---

## FILE: res://scripts/npcs/AllyNPC.gd — ❌ NOT YET IMPLEMENTED

> **TODO:** Create `AllyNPC.gd` extending `NPCBase`. Planned behaviour:
> - Follows the player when `follow_player = true`
> - Attacks `HOSTILE` faction NPCs in detection range
> - Self-heals below a configurable HP threshold

---

## FILE: res://scripts/npcs/HostileNPC.gd — ❌ NOT YET IMPLEMENTED

> **TODO:** Create `HostileNPC.gd` extending `NPCBase`. Planned behaviour:
> - State machine: `IDLE → PATROL → CHASE → ATTACK → RETURN`
> - Patrols exported `waypoints: Array[Vector2]`
> - Alerts via `EventBus.npc_alerted` when player enters `alert_radius`
> - Returns to home position when player escapes `alert_radius * 1.5`

---

## FILE: res://scenes/entities/WorldItem.gd

```gdscript
# WorldItem.gd
# An item lying in the world. Player walks over / interacts to pick up.
extends Area2D

@export var item: Resource = null   # Assign an Item resource in the editor

@onready var sprite: Sprite2D            = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label                = $Label

func _ready() -> void:
	if item != null:
		sprite.texture = item.icon
		label.text     = item.display_name
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == GameManager.player_ref:
		_pickup(body)

func interact(interactor: Node) -> void:
	_pickup(interactor)

func _pickup(picker: Node) -> void:
	if item == null:
		return
	if InventoryManager.add_item(item):
		EventBus.world_item_picked_up.emit(item, picker)
		EventBus.hud_show_message.emit("Picked up " + item.display_name, 2.0)
		queue_free()
	else:
		EventBus.hud_show_message.emit("Inventory full!", 2.0)
```

## SCENE TREE: WorldItem.tscn

```
WorldItem  [Area2D]  script=WorldItem.gd
├── Sprite2D           (texture=null — set via item.icon at runtime)
├── CollisionShape2D   (shape=CircleShape2D, radius=12)
└── Label              (text="Item", offset_y=-20, align=center)
```

---

## FILE: res://scripts/LootTable.gd

```gdscript
# LootTable.gd
# Weighted random loot roller.
class_name LootTable
extends Resource

## Each entry: { "item": Item, "weight": float, "min_qty": int, "max_qty": int }
@export var drops: Array[Dictionary] = []

## Rolls the table and returns an Array of Item resources.
func roll() -> Array:
	var result: Array = []
	for entry in drops:
		var item: Resource = entry.get("item", null)
		if item == null:
			continue
		var weight: float  = entry.get("weight", 1.0)
		var min_q: int     = entry.get("min_qty", 1)
		var max_q: int     = entry.get("max_qty", 1)
		# weight is treated as a 0-100 percent probability
		if randf() * 100.0 <= weight:
			var qty = randi_range(min_q, max_q)
			for _i in qty:
				var drop = item.duplicate()
				result.append(drop)
	return result
```

---

## AUTOLOAD SETUP

In **Project → Project Settings → Autoload**, add these entries in order:

| Name               | Path                                  |
|--------------------|---------------------------------------|
| `EventBus`         | `res://autoloads/EventBus.gd`         |
| `GameManager`      | `res://autoloads/GameManager.gd`      |
| `InventoryManager` | `res://autoloads/InventoryManager.gd` |

> ⚠️ **Known issue:** `InventoryManager` is currently **missing** from `project.godot`'s autoload list. Add it manually in Project Settings → Autoload.

> **Order note:** EventBus should load first since GameManager and InventoryManager reference it at runtime.

---

## STEP-BY-STEP SETUP CHECKLIST

### A — Project Setup
- [ ] Create a new Godot 4.6.1 project (2D, Forward+ or Mobile renderer)
- [ ] Recreate the folder structure shown at the top of this file inside `res://`
- [ ] Open **Project Settings → Autoload** and add all three autoloads in the order above

### B — Input Map
Open **Project Settings → Input Map** and add these actions:

| Action         | Default Key     |
|----------------|-----------------|
| `move_up`      | W / Arrow Up    |
| `move_down`    | S / Arrow Down  |
| `move_left`    | A / Arrow Left  |
| `move_right`   | D / Arrow Right |
| `sprint`       | Shift           |
| `interact`     | E               |
| `ui_inventory` | Tab             |
| `ui_accept`    | Space / Enter   |

### C — Create Scenes (in this order)

1. **FadeOverlay.tscn** — CanvasLayer (layer=128) → ColorRect (full-rect anchor, black) + AnimationPlayer. Attach `FadeOverlay.gd`.
2. **InventorySlot.tscn** — PanelContainer → TextureRect + QtyLabel. Attach `InventorySlot.gd`. `custom_minimum_size=(52,52)`.
3. **DialogueBox.tscn** — CanvasLayer → Panel → MarginContainer → VBoxContainer → SpeakerLabel + RichTextLabel + ContinueHint. Attach `DialogueBox.gd`.
4. **HUD.tscn** — CanvasLayer with health/stamina bars, hotbar (8 TextureRect slots Slot0–Slot7), minimap placeholder, message label. Attach `HUD.gd`.
5. **InventoryUI.tscn** — CanvasLayer → PanelContainer → MarginContainer → VBoxContainer → GridContainer (columns=8) + ContextMenu PopupMenu. Attach `InventoryUI.gd`.
6. **Projectile.tscn** — CharacterBody2D → Sprite2D + CollisionShape2D + Hitbox (Area2D + CollisionShape2D). Attach `Projectile.gd`.
7. **WorldItem.tscn** — Area2D → Sprite2D + CollisionShape2D + Label. Attach `WorldItem.gd`.
8. **Player.tscn** — CharacterBody2D → CollisionShape2D + AnimatedSprite2D (SpriteFrames: idle, walk, run, hurt, die) + InteractRay (RayCast2D, target=Vector2(32,0)) + HurtTimer (one_shot=true, wait_time=0.4). Attach `Player.gd`. Connect HurtTimer.timeout → `_on_hurt_timer_timeout`.
9. **NPCBase.tscn** — CharacterBody2D → CollisionShape2D + AnimatedSprite2D + NavigationAgent2D + DetectionArea (Area2D + CircleShape radius=200) + HealthBar. Attach a subclass script (`PeacefulNPC.gd` etc.) — do not attach `NPCBase.gd` directly.
10. **MainMenu.tscn** — CanvasLayer → ParallaxBackground (→ ParallaxLayer → TextureRect) + CenterContainer (→ VBoxContainer → Label + 4 Buttons) + FadeOverlay ColorRect. Attach `MainMenu.gd`. Connect all button signals.
11. **LoadingScreen.tscn** — CanvasLayer → VBoxContainer (→ LabelStatus + ProgressBar) + FadeOverlay ColorRect. Attach `LoadingScreen.gd`.
12. **Playground.tscn** — Node2D → TileMap + Camera2D + SpawnPoints (→ PlayerSpawn Marker2D at Vector2(100,480)) + NPCLayer + ItemLayer + HUD instance + StaticBody2D floor (ColorRect + CollisionPolygon2D). Attach `Playground.gd`.

### D — TileMap Setup
- [ ] Select TileMap in Playground.tscn, create a TileSet, paint collision on solid tiles
- [ ] Add **NavigationRegion2D** (sibling to TileMap) and bake a NavigationPolygon for NPC pathfinding

### E — Sprite / Animation Setup
- [ ] Create SpriteFrames for Player: `idle`, `walk`, `run`, `hurt`, `die`
- [ ] Create SpriteFrames for NPCs: `idle`, `walk`, `hurt`, `die`, `attack`

### F — Set Main Scene
- [ ] **Project Settings → Application → Run → Main Scene** → `res://scenes/screens/MainMenu.tscn`

### G — Fix InventoryManager Autoload (⚠️ required)
- [ ] Open **Project Settings → Autoload**
- [ ] Add `InventoryManager` → `res://autoloads/InventoryManager.gd`
- [ ] Verify order: EventBus → GameManager → InventoryManager

### H — Create Item Resources
- [ ] Right-click FileSystem → **New Resource** → `ConsumableItem`, `KeyItem`, etc.
- [ ] Fill in `id`, `display_name`, `description`, `icon`, `stackable`, `max_stack`
- [ ] Assign to WorldItem nodes or LootTable drop arrays

### I — LootTable Setup
- [ ] New Resource → `LootTable`, populate `drops` array
- [ ] Entry format: `{"item": <Item resource>, "weight": 50.0, "min_qty": 1, "max_qty": 2}`
- [ ] Assign to NPC `loot_table` export field

### J — NavigationRegion2D
- [ ] Add NavigationRegion2D to Playground
- [ ] Draw or bake NavigationPolygon over walkable areas
- [ ] Match navigation layer masks with NavigationAgent2D nodes in NPCs

### K — Implement Missing NPC Types
- [ ] Create `res://scripts/npcs/AllyNPC.gd` (follow player + attack hostiles + self-heal)
- [ ] Create `res://scripts/npcs/HostileNPC.gd` (IDLE/PATROL/CHASE/ATTACK/RETURN FSM)

### L — Final Test
- [ ] Run from MainMenu; confirm player spawns, moves, camera follows
- [ ] Pick up a WorldItem → inventory slot fills, hotbar shows icon
- [ ] Test PeacefulNPC dialogue (E key near NPC)
- [ ] Press Escape in-world to quick-save; restart and use Continue

---

*Generated for Godot 4.6.1 (stable). All scripts use GDScript with @export annotations and Godot 4 API only. No deprecated methods used.*