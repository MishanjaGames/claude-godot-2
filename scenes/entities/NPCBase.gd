# NPCBase.gd
# Extends Entity. Base for all NPC types.
# Reads stats from an NPCData resource so subclasses only set behaviour, not numbers.
#
# SCENE TREE (NPCBase.tscn) — subclasses use this exact tree:
#   NPCBase           [CharacterBody2D]   ← attach subclass script, not this one
#   ├── CollisionShape2D                  (CapsuleShape2D)
#   ├── AnimatedSprite2D                  (SpriteFrames: idle walk hurt die attack)
#   ├── NavigationAgent2D                 (path_desired_distance=8, target_desired_distance=16)
#   ├── DetectionArea  [Area2D]           (CollisionShape2D CircleShape r=200)
#   ├── HealthBar      [ProgressBar]      (offset_y=-32, min_width=40, max=100)
#   └── NameLabel      [Label]            (offset_y=-48, h_align=center)
class_name NPCBase
extends Entity

# ── Data resource ──────────────────────────────────────────────────────────────
## Assign in the Inspector, or call setup() at runtime (e.g. from StructurePlacer).
@export var npc_data: NPCData = null

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var nav_agent:      NavigationAgent2D = $NavigationAgent2D
@onready var detection_area: Area2D            = $DetectionArea
@onready var health_bar:     ProgressBar       = $HealthBar
@onready var name_label:     Label             = $NameLabel

# ── Readable shortcuts (populated from npc_data in _on_entity_ready) ──────────
var npc_name:   String           = "NPC"
var faction:    NPCData.Faction  = NPCData.Faction.PEACEFUL

# ══════════════════════════════════════════════════════════════════════════════
# SETUP (runtime injection from StructurePlacer / ChunkManager)
# ══════════════════════════════════════════════════════════════════════════════

## Call this when instantiating NPCs procedurally instead of placing them in the editor.
func setup(data: NPCData) -> void:
	npc_data = data

# ══════════════════════════════════════════════════════════════════════════════
# ENTITY HOOK
# ══════════════════════════════════════════════════════════════════════════════

func _on_entity_ready() -> void:
	if npc_data == null:
		push_warning("NPCBase: no npc_data assigned on '%s'." % name)
		return

	# Apply data to Entity's stat_block.
	if stat_block == null:
		stat_block = StatBlock.new()
	if npc_data.stat_block != null:
		stat_block = npc_data.stat_block.duplicate()
	stat_block.base_max_health = npc_data.max_health
	stat_block.base_move_speed = npc_data.move_speed

	current_health  = stat_block.get_max_health()
	current_stamina = stat_block.get_max_stamina()

	# Appearance.
	if npc_data.sprite_frames != null:
		anim_sprite.sprite_frames = npc_data.sprite_frames
	anim_sprite.modulate = npc_data.sprite_modulate
	anim_sprite.play("idle")

	# Readable shortcuts.
	npc_name = npc_data.display_name
	faction  = npc_data.faction

	# UI.
	health_bar.max_value = stat_block.get_max_health()
	health_bar.value     = current_health
	health_bar.visible   = npc_data.faction == NPCData.Faction.HOSTILE or npc_data.is_boss
	name_label.text      = npc_data.display_name

	# Detection area radius from alert_radius.
	var shape := detection_area.get_child(0)
	if shape is CollisionShape2D and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = npc_data.alert_radius

	EventBus.npc_spawned.emit(self)
	_on_npc_ready()

## Override in subclasses instead of _on_entity_ready().
func _on_npc_ready() -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# ENTITY HOOKS
# ══════════════════════════════════════════════════════════════════════════════

func _on_damaged(_amount: int, _type: String, _source: Node) -> void:
	health_bar.value = current_health
	if not _is_dead:
		anim_sprite.play("hurt")

func _on_healed(_amount: int) -> void:
	health_bar.value = current_health

func _on_died(killer: Node) -> void:
	anim_sprite.play("die")
	velocity = Vector2.ZERO
	EventBus.npc_died.emit(self, global_position, killer)
	_drop_loot()
	_grant_exp(killer)
	# Wait for death animation then free.
	anim_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)

# ══════════════════════════════════════════════════════════════════════════════
# LOOT & EXP
# ══════════════════════════════════════════════════════════════════════════════

func _drop_loot() -> void:
	if npc_data == null or npc_data.drop_table_id.is_empty():
		return
	var table := Registry.get_drop_table(npc_data.drop_table_id)
	if table == null:
		return
	var luck := 1.0
	if GameManager.player_ref and GameManager.player_ref.stat_block:
		luck = GameManager.player_ref.stat_block.get_luck()
	var drops := table.roll_items(luck)
	for item in drops:
		EventBus.world_item_spawned.emit(item, global_position)

func _grant_exp(killer: Node) -> void:
	if npc_data == null or npc_data.exp_reward <= 0:
		return
	if killer == GameManager.player_ref:
		EventBus.experience_gained.emit(npc_data.exp_reward, npc_data.display_name)

# ══════════════════════════════════════════════════════════════════════════════
# INTERACTION
# ══════════════════════════════════════════════════════════════════════════════

## Override in subclasses (e.g. PeacefulNPC triggers dialogue here).
func interact(_interactor: Node) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# NAVIGATION HELPER
# ══════════════════════════════════════════════════════════════════════════════

## Move toward a world pixel position using NavigationAgent2D.
## Returns the direction actually moved (Vector2.ZERO if arrived).
func _move_toward(target_pos: Vector2, speed: float) -> Vector2:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return Vector2.ZERO
	var dir := (nav_agent.get_next_path_position() - global_position).normalized()
	velocity = dir * speed
	anim_sprite.play("walk")
	anim_sprite.flip_h = dir.x < 0.0
	return dir
