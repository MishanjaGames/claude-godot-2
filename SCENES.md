# Scene Assembly Guide
# Build every .tscn in this exact dependency order.
# Each scene is described with full node tree, property values, and signal connections.
# A scene never appears before its dependencies.

---

## ORDER OF ASSEMBLY

1.  DamagePopup.tscn
2.  FadeOverlay.tscn
3.  HotbarSlot.tscn
4.  InventorySlot.tscn
5.  DialogueBox.tscn
6.  HUD.tscn
7.  InventoryUI.tscn
8.  PauseMenu.tscn
9.  SettingsScreen.tscn
10. CraftingUI.tscn
11. ShopUI.tscn
12. DebugOverlay.tscn
13. Projectile.tscn
14. WorldItem.tscn
15. Harvestable.tscn
16. Chest.tscn
17. Door.tscn
18. CraftingStation.tscn
19. Structure.tscn
20. NPCBase.tscn
21. Player.tscn
22. LoadingScreen.tscn
23. MainMenu.tscn
24. World.tscn

---

## 1. DamagePopup.tscn
**Script:** `scenes/DamagePopup.gd`

```
DamagePopup   [Node2D]
└── Label     [Label]
	  text = ""
	  horizontal_alignment = CENTER
	  vertical_alignment   = CENTER
	  custom_minimum_size  = Vector2(60, 20)
```

No signals. Instantiated by CombatManager at runtime.

---

## 2. FadeOverlay.tscn
**Script:** `scenes/ui/FadeOverlay.gd`

```
FadeOverlay   [CanvasLayer]   layer=128
└── Rect      [ColorRect]
	  anchors_preset   = 15  (Full Rect)
	  color            = Color(0,0,0,0)
```

No signals.

---

## 3. HotbarSlot.tscn
**Script:** `scenes/ui/HotbarSlot.gd`

```
HotbarSlot        [PanelContainer]   custom_minimum_size=Vector2(48,48)
├── Icon          [TextureRect]
│     anchors_preset = 15
│     expand_mode   = FIT_WIDTH_PROPORTIONAL
├── QtyLabel      [Label]
│     anchors_preset  = 4  (bottom-right)
│     horizontal_alignment = RIGHT
│     vertical_alignment   = BOTTOM
│     add_theme_font_size_override("font_size", 11)
├── KeyLabel      [Label]
│     anchors_preset = 0  (top-left)
│     add_theme_font_size_override("font_size", 10)
│     text = "1"
└── ActiveOverlay [ColorRect]
	  anchors_preset = 15
	  color          = Color(1,1,1, 0.13)
	  visible        = false
	  mouse_filter   = PASS
```

**StyleBoxFlat on HotbarSlot (Panel theme override):**
- bg_color: `Color(0.1, 0.1, 0.18, 0.9)`
- border_color: `Color(0.3, 0.3, 0.5, 0.8)`
- border_width all: `1`
- corner_radius all: `4`

No signals. Managed entirely by HUD.gd.

---

## 4. InventorySlot.tscn
**Script:** `scenes/ui/InventorySlot.gd`

```
InventorySlot        [PanelContainer]   custom_minimum_size=Vector2(52,52)
├── Icon             [TextureRect]
│     anchors_preset = 15
│     expand_mode    = FIT_WIDTH_PROPORTIONAL
├── QtyLabel         [Label]
│     anchors_preset = 4  (bottom-right)
│     horizontal_alignment = RIGHT
│     add_theme_font_size_override("font_size", 11)
│     visible = false
└── PlaceholderLabel [Label]
	  anchors_preset = 8  (center)
	  horizontal_alignment = CENTER
	  vertical_alignment   = CENTER
	  add_theme_font_size_override("font_size", 10)
	  modulate = Color(1,1,1,0.4)
	  visible  = false
```

Same StyleBoxFlat as HotbarSlot. No signals needed — InventoryUI connects them in _build_*_grid().

---

## 5. DialogueBox.tscn
**Script:** `scenes/ui/DialogueBox.gd`

```
DialogueBox        [CanvasLayer]   layer=8
└── Panel          [PanelContainer]
	  anchors_preset         = 12  (bottom-wide)
	  offset_top             = -180
	  custom_minimum_size    = Vector2(0, 160)
	  theme/StyleBoxFlat:
		bg_color             = Color(0.08, 0.08, 0.15, 0.95)
		border_color         = Color(0.6, 0.6, 0.8, 0.6)
		border_width all     = 1
		corner_radius all    = 6
		content_margin all   = 12
	  └── MarginContainer    (margin all = 12)
		  └── VBoxContainer  (separation=6)
			  ├── SpeakerLabel    [Label]
			  │     text = ""
			  │     add_theme_font_size_override("font_size", 14)
			  │     add_theme_color_override("font_color", Color(0.9,0.85,0.4))
			  ├── RichTextLabel
			  │     bbcode_enabled = true
			  │     fit_content    = true
			  │     scroll_active  = false
			  │     add_theme_font_size_override("font_size", 13)
			  ├── ContinueHint    [Label]
			  │     text = "[Space / Enter to continue]"
			  │     horizontal_alignment = RIGHT
			  │     add_theme_font_size_override("font_size", 11)
			  │     modulate = Color(1,1,1,0.55)
			  └── ChoiceContainer [VBoxContainer]
					visible = false
					(separation = 4)
```

No manual signal connections — DialogueBox connects to EventBus in _ready().

---

## 6. HUD.tscn
**Script:** `scenes/ui/HUD.gd`  
**Dependencies:** HotbarSlot.tscn, Minimap.tscn

```
HUD                    [CanvasLayer]   layer=1
├── TopBar             [MarginContainer]
│     anchors_preset   = 10  (top-wide)
│     offset_bottom    = 34
│     theme_override margin_left=8, margin_top=6, margin_right=8
│     └── HBoxContainer  (separation=12)
│         ├── HealthBar  [ProgressBar]
│         │     custom_minimum_size = Vector2(200,18)
│         │     max_value = 100, value = 100
│         │     theme: fill color = Color(0.8, 0.2, 0.2)
│         ├── StaminaBar [ProgressBar]
│         │     custom_minimum_size = Vector2(160,14)
│         │     max_value = 100, value = 100
│         │     theme: fill color = Color(0.2, 0.7, 0.3)
│         └── XPBar      [ProgressBar]
│               custom_minimum_size = Vector2(120,10)
│               max_value = 100, value = 0
│               theme: fill color = Color(0.9, 0.8, 0.1)
├── HotbarRoot         [CenterContainer]
│     anchors_preset   = 7   (bottom-center)
│     offset_top       = -58
│     └── HotbarRow    [HBoxContainer]   (separation=4)
│         (8 HotbarSlot.tscn instances added at runtime by HUD._build_hotbar)
├── AmmoLabel          [Label]
│     anchors_preset   = 4   (bottom-right)
│     offset_top       = -58, offset_right = -8
│     horizontal_alignment = RIGHT
│     add_theme_font_size_override("font_size", 13)
│     visible = false
├── MessageContainer   [VBoxContainer]
│     anchors_preset   = 5   (top-center)
│     offset_top       = 44
│     alignment        = CENTER
│     (Labels added at runtime)
├── LevelLabel         [Label]
│     anchors_preset   = 3   (top-right)
│     offset_left = -80, offset_bottom = 28
│     horizontal_alignment = RIGHT
│     add_theme_font_size_override("font_size", 12)
│     text = "Lv. 1"
└── ClockLabel         [Label]
	  anchors_preset   = 2   (top-center)
	  offset_top = 6
	  horizontal_alignment = CENTER
	  add_theme_font_size_override("font_size", 11)
	  modulate = Color(1,1,1,0.7)
	  text = "06:00"
```

No manual signals — HUD connects to EventBus in _ready().

---

## 7. InventoryUI.tscn
**Script:** `scenes/ui/InventoryUI.gd`  
**Dependencies:** InventorySlot.tscn

```
InventoryUI         [CanvasLayer]   layer=5
├── Root            [PanelContainer]
│     anchors_preset = 8  (center)
│     offset_left=-260, offset_top=-220, offset_right=260, offset_bottom=220
│     custom_minimum_size = Vector2(520,440)
│     theme/StyleBoxFlat: bg=Color(0.1,0.1,0.18,0.97), border=1px gold-ish
│     └── MarginContainer  (margin all = 14)
│         └── VBoxContainer  (separation=8)
│             ├── TitleLabel  [Label]   text="INVENTORY"
│             │     horizontal_alignment = CENTER
│             │     add_theme_font_size_override("font_size", 18)
│             │     add_theme_color_override("font_color", Color(0.88,0.77,0.42))
│             ├── ContentRow  [HBoxContainer]  (separation=16)
│             │   ├── BagSection   [VBoxContainer]  (size_flags_h = EXPAND+FILL)
│             │   │   ├── BagLabel  [Label]  text="Bag"
│             │   │   │     add_theme_font_size_override("font_size",12)
│             │   │   └── BagGrid   [GridContainer]  columns=8, separation=3
│             │   │         (32 InventorySlot.tscn instances added at runtime)
│             │   └── EquipSection [VBoxContainer]  custom_minimum_size=Vector2(120,0)
│             │       ├── EquipLabel [Label]  text="Equipment"
│             │       │     add_theme_font_size_override("font_size",12)
│             │       └── EquipGrid  [GridContainer]  columns=2, separation=3
│             │             (6 InventorySlot.tscn instances added at runtime)
│             └── WeightLabel  [Label]
│                   text="0.0 / 50.0 kg"
│                   horizontal_alignment = RIGHT
│                   add_theme_font_size_override("font_size",11)
└── ContextMenu     [PopupMenu]
	  (no items — built at runtime)
```

**Signal connection:**
- ContextMenu → `id_pressed` → InventoryUI → `_on_context_menu_id_pressed`

---

## 8. PauseMenu.tscn
**Script:** `scenes/ui/PauseMenu.gd`

```
PauseMenu          [CanvasLayer]   layer=10
├── Backdrop       [ColorRect]
│     anchors_preset = 15
│     color = Color(0,0,0,0.6)
│     mouse_filter  = STOP
└── Panel          [PanelContainer]
	  anchors_preset = 8  (center)
	  offset_left=-140, offset_top=-180, offset_right=140, offset_bottom=180
	  custom_minimum_size = Vector2(280,360)
	  theme/StyleBoxFlat: bg=Color(0.1,0.1,0.18), border=2px gold
	  └── MarginContainer  (margin all = 24)
		  └── VBoxContainer  (separation=10)
			  ├── LabelTitle  [Label]   text="PAUSED"
			  │     horizontal_alignment = CENTER
			  │     add_theme_font_size_override("font_size",28)
			  │     add_theme_color_override("font_color", Color(0.88,0.77,0.42))
			  ├── Separator   [HSeparator]
			  │     custom_minimum_size = Vector2(0,8)
			  ├── BtnResume   [Button]  text="  Resume"
			  ├── BtnSave     [Button]  text="  Save Game"
			  ├── BtnSettings [Button]  text="  Settings"
			  └── BtnMenu     [Button]  text="  Main Menu"
				(all buttons: custom_minimum_size=Vector2(0,44), size_flags_h=EXPAND+FILL)
```

**Signal connections (all to PauseMenu root):**
- BtnResume.pressed → `close`
- BtnSave.pressed → `_on_save`
- BtnSettings.pressed → `_on_settings`
- BtnMenu.pressed → `_on_menu`

---

## 9. SettingsScreen.tscn
**Script:** `scenes/ui/SettingsScreen.gd`  
**Group:** `settings_screen`

```
SettingsScreen     [CanvasLayer]   layer=11
├── Backdrop       [ColorRect]   anchors_preset=15, color=Color(0,0,0,0.73)
└── Panel          [PanelContainer]
	  anchors_preset=8, offset=±200/±230, custom_min=Vector2(400,460)
	  theme/StyleBoxFlat: bg=Color(0.1,0.1,0.18), border=2px gold
	  └── MarginContainer  (margin all = 28)
		  └── VBoxContainer  (separation=12)
			  ├── LabelTitle        [Label]   text="SETTINGS", font_size=24, gold
			  ├── Separator         [HSeparator]
			  ├── MasterRow         [HBoxContainer]  (separation=10)
			  │   ├── LabelMasterName [Label]  text="Master"  custom_min=Vector2(72,0)
			  │   ├── SliderMaster    [HSlider] custom_min=Vector2(180,20), size_h=EXPAND+FILL
			  │   │     min=0, max=1, step=0.01, value=1.0
			  │   └── LabelMaster     [Label]  text="100%"  custom_min=Vector2(40,0), align=RIGHT
			  ├── SFXRow / MusicRow   (same structure as MasterRow)
			  ├── Separator2        [HSeparator]
			  ├── CheckFullscreen   [CheckButton]  text="Fullscreen", custom_min=Vector2(0,36)
			  ├── Separator3        [HSeparator]
			  └── ButtonRow         [HBoxContainer]  alignment=END, separation=12
				  ├── BtnBack   [Button]  text="  Back",  custom_min=Vector2(110,40)
				  └── BtnApply  [Button]  text="  Apply", custom_min=Vector2(110,40)
```

**Signal connections (all to SettingsScreen root):**
- SliderMaster.value_changed → `_on_slider`, bind `"master"`
- SliderSFX.value_changed → `_on_slider`, bind `"sfx"`
- SliderMusic.value_changed → `_on_slider`, bind `"music"`
- CheckFullscreen.toggled → inline lambda
- BtnApply.pressed → `_on_apply`
- BtnBack.pressed → `_on_back`

---

## 10. CraftingUI.tscn
**Script:** `scenes/ui/CraftingUI.gd`  
**Group:** `crafting_ui`

```
CraftingUI         [CanvasLayer]   layer=6
└── Root           [PanelContainer]
	  anchors_preset=8, offset=±260/±220, custom_min=Vector2(520,440)
	  └── MarginContainer  (margin all = 14)
		  └── VBoxContainer  (separation=8)
			  ├── TitleLabel    [Label]   text="CRAFTING",  font_size=18, gold
			  ├── StationLabel  [Label]   text="Workbench", font_size=12
			  ├── ContentRow    [HBoxContainer]  (separation=16)
			  │   ├── RecipeList   [VBoxContainer]  custom_min=Vector2(180,0), size_h=EXPAND+FILL
			  │   │     (buttons added at runtime)
			  │   └── DetailPanel  [VBoxContainer]  custom_min=Vector2(280,0)
			  │         ├── ResultLabel       [Label]    text="Select a recipe"
			  │         ├── ResultIcon        [TextureRect] custom_min=Vector2(48,48)
			  │         ├── IngredientsLabel  [Label]    text="Requires:"
			  │         ├── IngredientsList   [VBoxContainer]
			  │         └── CraftButton       [Button]   text="Craft", disabled=true
			  └── CloseButton  [Button]  text="Close"
```

**Signal connections:**
- CraftButton.pressed → `_on_craft`
- CloseButton.pressed → `close`

---

## 11. ShopUI.tscn
**Script:** `scenes/ui/ShopUI.gd`  
**Group:** `shop_ui`

```
ShopUI             [CanvasLayer]   layer=6
└── Root           [PanelContainer]
	  anchors_preset=8, offset=±270/±230, custom_min=Vector2(540,460)
	  └── MarginContainer  (margin all = 14)
		  └── VBoxContainer  (separation=8)
			  ├── TitleRow   [HBoxContainer]
			  │   ├── TitleLabel [Label]  text="SHOP", font_size=18, gold
			  │   │     size_flags_h = EXPAND+FILL
			  │   └── GoldLabel  [Label]  text="Gold: 0", font_size=13
			  ├── TabBar     [TabContainer]
			  │   ├── Buy    [ScrollContainer]  name="Buy"
			  │   │   └── BuyList  [VBoxContainer]   (rows added at runtime)
			  │   └── Sell   [ScrollContainer]  name="Sell"
			  │       └── SellList [VBoxContainer]  (rows added at runtime)
			  └── CloseButton [Button]  text="Close"
```

**Signal connections:**
- CloseButton.pressed → `close`

---

## 12. DebugOverlay.tscn
**Script:** `scenes/ui/DebugOverlay.gd`

```
DebugOverlay       [CanvasLayer]   layer=127
└── Panel          [PanelContainer]
	  anchors_preset = 0  (top-left)
	  offset_right=270, offset_bottom=8   (grows downward at runtime)
	  theme/StyleBoxFlat: bg=Color(0,0,0,0.75), no border, corner_radius=4
	  └── MarginContainer  (margin all = 8)
		  └── Lines  [VBoxContainer]   (separation=2)
				(Label nodes added at runtime by DebugOverlay._ready())
```

No signals.

---

## 13. Projectile.tscn
**Script:** `scenes/entities/Projectile.gd`

```
Projectile             [CharacterBody2D]   collision_layer=4, collision_mask=2
├── Sprite2D
│     texture = null  (set per weapon via projectile_scene)
│     z_index = 1
├── CollisionShape2D
│     shape = CapsuleShape2D(height=8, radius=3)
│     rotation_degrees = 90
└── LifetimeTimer      [Timer]
	  one_shot   = true
	  wait_time  = 3.0
```

**Signal connection:**
- LifetimeTimer.timeout → `queue_free` (connected in Projectile._ready())

---

## 14. WorldItem.tscn
**Script:** `scenes/entities/WorldItem.gd`

```
WorldItem          [Area2D]   collision_layer=8, collision_mask=1
├── Sprite2D        texture=null
├── CollisionShape2D
│     shape = CircleShape2D(radius=12)
└── Label           text=""
	  offset_y = -18
	  horizontal_alignment = CENTER
	  add_theme_font_size_override("font_size", 11)
	  modulate = Color(1,1,1,0.8)
```

**Signal connection:**  
- WorldItem.body_entered → `_on_body_entered` (connected in _ready())

---

## 15. Harvestable.tscn
**Script:** `scenes/objects/Harvestable.gd`

```
Harvestable        [StaticBody2D]   collision_layer=2
├── AnimatedSprite2D
│     sprite_frames = null  (set via setup())
├── CollisionShape2D
│     shape = RectangleShape2D(size=Vector2(32,48))
├── HitParticles   [GPUParticles2D]
│     emitting    = false
│     one_shot    = true
│     amount      = 12
│     lifetime    = 0.6
│     (ParticleProcessMaterial: direction=Vector2(0,-1), spread=60, gravity=200)
├── InteractArea   [Area2D]   collision_layer=0, collision_mask=1
│     └── CollisionShape2D  shape=CircleShape2D(radius=22)
└── RegrowTimer    [Timer]   one_shot=true, wait_time=300
```

**Signal connections:**
- RegrowTimer.timeout → `_on_regrow_timer_timeout`

---

## 16. Chest.tscn
**Script:** `scenes/objects/Chest.gd`

```
Chest              [StaticBody2D]   collision_layer=2
├── Sprite2D       texture=null
├── CollisionShape2D shape=RectangleShape2D(size=Vector2(28,24))
├── InteractLabel  [Label]   text="[E] Open"  offset_y=-28  visible=false
├── OpenSound      [AudioStreamPlayer2D]  bus="SFX"
└── InteractArea   [Area2D]   collision_mask=1
	└── CollisionShape2D  shape=RectangleShape2D(size=Vector2(40,36))
```

**Signal connections:**  
- InteractArea.body_entered → `_on_body_entered`  
- InteractArea.body_exited → `_on_body_exited`

---

## 17. Door.tscn
**Script:** `scenes/objects/Door.gd`

```
Door               [StaticBody2D]   collision_layer=2
├── Sprite2D       texture=null
├── CollisionShape2D shape=RectangleShape2D(size=Vector2(16,48))
├── InteractLabel  [Label]   text="[E] Open"  offset_y=-32  visible=false
├── OpenSound      [AudioStreamPlayer2D]   bus="SFX"
├── LockedSound    [AudioStreamPlayer2D]   bus="SFX"
└── InteractArea   [Area2D]   collision_mask=1
	└── CollisionShape2D  shape=RectangleShape2D(size=Vector2(32,56))
```

**Signal connections:**  
- InteractArea.body_entered → `_on_body_entered`  
- InteractArea.body_exited → `_on_body_exited`

---

## 18. CraftingStation.tscn
**Script:** `scenes/world/CraftingStation.gd`

```
CraftingStation    [StaticBody2D]   collision_layer=2
├── Sprite2D       texture=null  (swap per station type)
├── CollisionShape2D shape=RectangleShape2D(size=Vector2(32,32))
├── InteractLabel  [Label]   text="[E] Workbench"  offset_y=-28  visible=false
└── InteractArea   [Area2D]   collision_mask=1
	└── CollisionShape2D  shape=RectangleShape2D(size=Vector2(64,48))
```

**Signal connections:**  
- InteractArea.body_entered → `_on_body_entered`  
- InteractArea.body_exited → `_on_body_exited`

---

## 19. Structure.tscn
**Script:** `scenes/objects/Structure.gd`

```
Structure          [Node2D]
├── InteriorArea   [Area2D]   collision_layer=0, collision_mask=1
│     └── CollisionShape2D   shape=RectangleShape2D(size=Vector2(256,192))
│           (resize to match the structure's interior footprint)
└── Objects        [Node2D]
      (Chest, Door, CraftingStation instances placed here by StructurePlacer)
```

**Signal connections:**  
- InteriorArea.body_entered → `_on_body_entered`  
- InteriorArea.body_exited → `_on_body_exited`

---

## 20. NPCBase.tscn
**Script:** attach the relevant subclass script per instance:  
`PeacefulNPC.gd` / `AllyNPC.gd` / `HostileNPC.gd` / `ShopNPC.gd`

```
NPCBase            [CharacterBody2D]   collision_layer=1, collision_mask=2+4
├── CollisionShape2D   shape=CapsuleShape2D(height=28, radius=10)
├── AnimatedSprite2D
│     sprite_frames = null  (set via NPCData at runtime)
├── NavigationAgent2D
│     path_desired_distance  = 8.0
│     target_desired_distance = 16.0
│     avoidance_enabled      = true
├── DetectionArea  [Area2D]   collision_layer=0, collision_mask=1
│     └── CollisionShape2D  shape=CircleShape2D(radius=200)
│           (radius overwritten by NPCBase._on_entity_ready from NPCData.alert_radius)
├── HealthBar      [ProgressBar]
│     custom_minimum_size = Vector2(40,6)
│     position = Vector2(-20, -32)
│     max_value = 100, value = 100
│     visible   = false  (shown by NPCBase for HOSTILE/boss only)
└── NameLabel      [Label]
      position = Vector2(-30, -48)
      custom_minimum_size = Vector2(60,0)
      horizontal_alignment = CENTER
      add_theme_font_size_override("font_size", 11)
      text = ""
```

No manual signal connections — all wired in subclass _on_npc_ready().

---

## 21. Player.tscn
**Script:** `scenes/entities/Player.gd`

```
Player             [CharacterBody2D]   collision_layer=1, collision_mask=2+4+8
│     (assign a StatBlock .tres in the Inspector for stats)
├── CollisionShape2D   shape=CapsuleShape2D(height=28, radius=10)
├── AnimatedSprite2D
│     sprite_frames = null  (add your SpriteFrames: idle,walk,run,attack,hurt,die)
├── InteractRay    [RayCast2D]
│     target_position  = Vector2(36, 0)
│     enabled          = true
│     collide_with_areas = true
│     collide_with_bodies = true
├── HurtTimer      [Timer]
│     one_shot   = true
│     wait_time  = 0.4
└── AttackHitbox   [Area2D]
      position = Vector2(40, 0)
      monitoring  = false
      monitorable = false
      collision_layer = 4
      collision_mask  = 1
      └── CollisionShape2D
            shape = CapsuleShape2D(height=32, radius=16)
            rotation_degrees = 90
```

**Signal connections:**  
- HurtTimer.timeout → `_on_hurt_timer_timeout`

---

## 22. LoadingScreen.tscn
**Script:** `scenes/ui/LoadingScreen.gd`

```
LoadingScreen      [CanvasLayer]
├── Background     [ColorRect]
│     anchors_preset = 15
│     color = Color(0.05, 0.05, 0.05)
├── VBoxContainer
│     anchors_preset = 8  (center)
│     custom_minimum_size = Vector2(360,80)
│     alignment = CENTER
│     separation = 12
│     ├── StatusLabel  [Label]
│     │     text = "Loading…"
│     │     horizontal_alignment = CENTER
│     │     add_theme_font_size_override("font_size", 14)
│     └── ProgressBar
│           custom_minimum_size = Vector2(360, 20)
│           min = 0, max = 100, value = 0
└── FadeOverlay    [ColorRect]
      anchors_preset = 15
      color = Color(0,0,0,1)
      mouse_filter = STOP
```

No signals.

---

## 23. MainMenu.tscn
**Script:** `scenes/ui/MainMenu.gd` (located at `scenes/screens/MainMenu.gd`)

```
MainMenu           [CanvasLayer]
├── ParallaxBackground
│     └── ParallaxLayer   (motion_scale=Vector2(0.5,0.5))
│         └── TextureRect  (stretch_mode=COVER, expand_mode=IGNORE_SIZE)
│               (assign your background texture here)
├── CenterContainer   (anchors_preset=15)
│   └── VBoxContainer  (alignment=CENTER, separation=10)
│         custom_minimum_size = Vector2(280, 0)
│       ├── TitleLabel  [Label]   text="MY GAME"
│       │     horizontal_alignment = CENTER
│       │     add_theme_font_size_override("font_size", 52)
│       │     add_theme_color_override("font_color", Color(0.95,0.9,0.6))
│       ├── BtnNewGame   [Button]  text="New Game"
│       ├── BtnContinue  [Button]  text="Continue"
│       ├── BtnSettings  [Button]  text="Settings"
│       └── BtnQuit      [Button]  text="Quit"
│             (all buttons: custom_minimum_size=Vector2(0,44), size_h=EXPAND+FILL)
├── FadeOverlay  [ColorRect]
│     anchors_preset=15, color=Color(0,0,0,1)
├── VersionLabel [Label]
│     anchors_preset=4 (bottom-right)
│     add_theme_font_size_override("font_size",11)
│     modulate=Color(1,1,1,0.4)
└── SettingsScreen.tscn  (instanced here for main menu settings access)
```

**Signal connections (all to MainMenu root):**  
- BtnNewGame.pressed → `_on_new_game`  
- BtnContinue.pressed → `_on_continue`  
- BtnSettings.pressed → `_on_settings`  
- BtnQuit.pressed → `_on_quit`

---

## 24. World.tscn ← FINAL SCENE
**Script:** `scenes/screens/World.gd`  
**This is the main gameplay scene.**

```
World                  [Node2D]          ← root, script=World.gd
├── WorldEnvironment   [WorldEnvironment]
│     └── Environment  [Environment]
│           background_mode  = COLOR
│           background_color = Color(0.53,0.81,0.98)
│           ambient_light_source = COLOR
│           ambient_light_energy = 1.0
├── Sun                [DirectionalLight2D]
│     energy     = 1.0
│     color      = Color(1.0,0.95,0.85)
│     shadow     = false
├── TileMap            [TileMap]
│     (create a TileSet resource and assign it)
│     Layer 0: name="Terrain",    z_index=0
│     Layer 1: name="Background", z_index=-1
│     tile_size = Vector2i(16,16)
├── ObjectLayer        [Node2D]   z_index=1
├── ChunkManager       [ChunkManager]   (script: scripts/world/ChunkManager.gd)
│     (add_to_group call handled in ChunkManager.setup())
├── Camera2D           (will be reparented to Player at runtime)
│     zoom                   = Vector2(2,2)
│     limit_left             = 0
│     limit_right            = 1048576   (WorldManager.WORLD_WIDTH_TILES * TILE_SIZE)
│     limit_top              = 0
│     limit_bottom           = 65536     (WorldManager.WORLD_HEIGHT_TILES * TILE_SIZE)
│     position_smoothing_enabled = true
│     position_smoothing_speed   = 8.0
├── NavigationRegion2D
│     (bake a NavigationPolygon for NPC pathfinding — cover walkable surface)
├── SpawnPoints        [Node2D]
│   └── PlayerSpawn    [Marker2D]   position=Vector2(512,12752)
│         (adjust Y to land on surface — run once and observe surface_y in debug overlay)
├── AutoSave           [AutoSave]   (script: scenes/world/AutoSave.gd)
│     autosave_interval = 120.0
│     show_indicator    = true
└── UI                 [CanvasLayer]   layer=1
    ├── HUD.tscn            (instance)
    ├── InventoryUI.tscn    (instance)
    ├── DialogueBox.tscn    (instance)
    ├── CraftingUI.tscn     (instance)
    ├── ShopUI.tscn         (instance)
    ├── PauseMenu.tscn      (instance)
    ├── SettingsScreen.tscn (instance)
    ├── FadeOverlay.tscn    (instance)
    └── DebugOverlay.tscn   (instance)
```

**Project Settings → Application → Run → Main Scene:**  
Set to `res://scenes/screens/MainMenu.tscn`

---

## INPUTMAP ACTIONS CHECKLIST

Open **Project Settings → Input Map** and verify all of these exist:

| Action | Default |
|---|---|
| `move_up` | W, Arrow Up |
| `move_down` | S, Arrow Down |
| `move_left` | A, Arrow Left |
| `move_right` | D, Arrow Right |
| `sprint` | Shift |
| `interact` | E |
| `attack` | Left Mouse Button |
| `block` | Right Mouse Button |
| `ui_inventory` | Tab |
| `ui_accept` | Space, Enter |
| `ui_cancel` | Escape |
| `hotbar_1` … `hotbar_8` | Keys 1–8 |
| `hotbar_next` | Mouse Wheel Down |
| `hotbar_prev` | Mouse Wheel Up |

---

## AUDIO BUS SETUP

**Project → Audio** panel — create these buses in order:

| Index | Name | Send |
|---|---|---|
| 0 | Master | — |
| 1 | SFX | Master |
| 2 | Music | Master |

All `AudioStreamPlayer` / `AudioStreamPlayer2D` nodes must have their `bus` property set to the correct bus name string.

---

## COLLISION LAYER MAP

| Layer | Bit | Used by |
|---|---|---|
| 1 | 1 | Player, NPCs (body) |
| 2 | 2 | Static world (TileMap, StaticBody2D) |
| 3 | 4 | Projectiles |
| 4 | 8 | WorldItems (pickup areas) |
| 5 | 16 | Interact areas (doors, chests, harvestables) |

Assign these consistently in the Inspector on every scene's root collision nodes.

---

## TILESET SETUP

The TileMap in World.tscn needs a TileSet resource configured with:

1. **Source 0** — your main spritesheet  
   - Atlas coords used by BiomeData tile fields:  
	 `Vector2i(0,0)` = grass surface  
	 `Vector2i(1,0)` = dirt subsurface  
	 `Vector2i(2,0)` = stone underground  
	 `Vector2i(3,0)` = water  
	 `Vector2i(4,0)` = sand surface (desert)  
	 etc. — match whatever coords you set in your BiomeData .tres files  

2. **Physics layer 0** on the TileSet — enable collision on underground and surface tiles  

3. **Navigation layer 0** — enable navigation on surface tiles only so NPCs walk on ground but not through walls  

---

## FINAL CHECKLIST BEFORE FIRST RUN

- [ ] All scripts placed in the correct `res://` folders
- [ ] All autoloads registered in the correct order in Project Settings
- [ ] `res://data/` subfolders contain at least the bundled .tres files from Phase 5 + Phase 10
- [ ] `res://assets/sounds/sfx/` and `music/` folders exist (can be empty — AudioManager skips missing files)
- [ ] TileSet resource created and assigned to World.tscn TileMap
- [ ] Player.tscn has a StatBlock .tres assigned
- [ ] Main Scene set to MainMenu.tscn
- [ ] InputMap actions all defined
- [ ] Audio buses Master / SFX / Music created
- [ ] NavigationRegion2D baked in World.tscn
- [ ] CombatManager.damage_popup_scene set to DamagePopup.tscn in Inspector
