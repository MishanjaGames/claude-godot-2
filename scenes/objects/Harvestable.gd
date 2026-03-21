# Harvestable.gd
# World object that can be struck with tools to yield items.
# Covers trees, rocks, ore veins, bushes, crystals, etc.
# ChunkManager spawns this via setup(HarvestableData).
#
# SCENE TREE (Harvestable.tscn):
#   Harvestable            [StaticBody2D]    ← this script
#   ├── AnimatedSprite2D                     (SpriteFrames per-data at runtime)
#   ├── CollisionShape2D                     (RectangleShape2D — resized at runtime)
#   ├── HitParticles       [GPUParticles2D]  (one-shot, emit_color driven by data)
#   ├── InteractArea       [Area2D]          (slightly larger than collision, for E-key)
#   │   └── CollisionShape2D
#   └── RegrowTimer        [Timer]           (one_shot=true — starts after destruction)
class_name Harvestable
extends StaticBody2D

# ── Data ───────────────────────────────────────────────────────────────────────
var _data: HarvestableData = null

# ── Runtime state ──────────────────────────────────────────────────────────────
var _current_health: int  = 0
var _is_destroyed:   bool = false
var _current_stage:  int  = 0

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var anim_sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var collision:      CollisionShape2D = $CollisionShape2D
@onready var hit_particles:  GPUParticles2D   = $HitParticles
@onready var interact_area:  Area2D           = $InteractArea
@onready var regrow_timer:   Timer            = $RegrowTimer

# ══════════════════════════════════════════════════════════════════════════════
# SETUP (called by ChunkManager after instantiation)
# ══════════════════════════════════════════════════════════════════════════════

func setup(data: HarvestableData) -> void:
	_data           = data
	_current_health = data.max_health
	_current_stage  = 0

	# Apply initial sprite stage.
	_apply_stage(0)

	# Particle colour from data.
	if hit_particles:
		var mat := hit_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.color = data.particle_color

	# Regrow timer.
	regrow_timer.one_shot = true
	regrow_timer.timeout.connect(_on_regrow_timer_timeout)

	# Interact area for E-key harvesting (player without right tool type).
	interact_area.body_entered.connect(_on_interact_area_body_entered)

func _ready() -> void:
	# If placed in the editor with data already set, apply it.
	if _data != null and _current_health == 0:
		_current_health = _data.max_health

# ══════════════════════════════════════════════════════════════════════════════
# HIT — called by Player attack or tool use via EventBus.tool_used
# ══════════════════════════════════════════════════════════════════════════════

## Primary entry point. Called when a tool or weapon strikes this object.
## tool_type:  ToolData.ToolType value (-1 for bare hands / weapon)
## tool_power: ToolData.tool_power (0 for bare hands / weapon)
func hit(tool_type: int, tool_power: int, _attacker: Node = null) -> void:
	if _is_destroyed or _data == null:
		return

	if not _data.can_harvest(tool_type, tool_power):
		# Wrong tool — play a thud sound and show no progress.
		EventBus.play_sfx_requested.emit("hit_wrong_tool", global_position)
		_shake()
		return

	var damage := _data.calculate_hit_damage(tool_power)
	_current_health -= damage
	EventBus.harvestable_hit.emit(self, damage, tool_power)

	# Sound.
	if not _data.hit_sound_id.is_empty():
		EventBus.play_sfx_requested.emit(_data.hit_sound_id, global_position)

	# Particles.
	if hit_particles:
		hit_particles.restart()

	_shake()

	# Stage update.
	if _data.is_multi_stage:
		var new_stage := _data.get_stage(_current_health)
		if new_stage != _current_stage:
			_apply_stage(new_stage)

	if _current_health <= 0:
		_destroy()

# ══════════════════════════════════════════════════════════════════════════════
# INTERACT (E-key proximity — always attempts bare-hand harvest)
# ══════════════════════════════════════════════════════════════════════════════

func interact(interactor: Node) -> void:
	var active_item = InventoryManager.get_active_item()
	var tool_type   := -1
	var tool_power  := 0

	if active_item is ToolData:
		tool_type  = active_item.tool_type
		tool_power = active_item.tool_power
		# Consume durability.
		if not active_item.use_charge():
			EventBus.tool_broke.emit(active_item, interactor)
			InventoryManager.remove_item(InventoryManager.active_hotbar_index)

	hit(tool_type, tool_power, interactor)

# ══════════════════════════════════════════════════════════════════════════════
# DESTRUCTION & DROPS
# ══════════════════════════════════════════════════════════════════════════════

func _destroy() -> void:
	_is_destroyed = true

	# Sound.
	if _data and not _data.break_sound_id.is_empty():
		EventBus.play_sfx_requested.emit(_data.break_sound_id, global_position)

	# Drop loot.
	_drop_loot()

	EventBus.harvestable_destroyed.emit(self, global_position)

	# Hide visuals and disable collision — keep node alive for regrowth.
	anim_sprite.visible = false
	collision.set_deferred("disabled", true)
	interact_area.set_deferred("monitoring", false)

	# Schedule regrowth or remove permanently.
	if _data and _data.regrow_time > 0.0:
		regrow_timer.start(_data.regrow_time)
	else:
		queue_free()

func _drop_loot() -> void:
	if _data == null or _data.drop_table_id.is_empty():
		return
	var table := Registry.get_drop_table(_data.drop_table_id)
	if table == null:
		return
	var luck := 1.0
	if GameManager.player_ref and GameManager.player_ref.stat_block:
		luck = GameManager.player_ref.stat_block.get_luck()
	var items := table.roll_items(luck)
	for item in items:
		# Scatter drops slightly so they don't stack exactly.
		var scatter := Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 0.0))
		EventBus.world_item_spawned.emit(item, global_position + scatter)

# ══════════════════════════════════════════════════════════════════════════════
# REGROWTH
# ══════════════════════════════════════════════════════════════════════════════

func _on_regrow_timer_timeout() -> void:
	_current_health = _data.max_health
	_is_destroyed   = false
	_apply_stage(0)
	anim_sprite.visible = true
	collision.set_deferred("disabled", false)
	interact_area.set_deferred("monitoring", true)
	EventBus.harvestable_regrown.emit(self)

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _apply_stage(stage: int) -> void:
	_current_stage = stage
	if not _data.is_multi_stage or _data.stage_sprite_frames.is_empty():
		return
	var idx := clampi(stage, 0, _data.stage_sprite_frames.size() - 1)
	if _data.stage_sprite_frames[idx] != null:
		anim_sprite.sprite_frames = _data.stage_sprite_frames[idx]
		anim_sprite.play("default")

func _shake() -> void:
	# Simple 3-frame position shake — no Tween dependency.
	var origin := position
	for i in 3:
		await get_tree().process_frame
		position = origin + Vector2(randf_range(-2.0, 2.0), 0.0)
	position = origin

func _on_interact_area_body_entered(_body: Node) -> void:
	pass   # Proximity detection only — actual interact() called by Player's InteractRay.
