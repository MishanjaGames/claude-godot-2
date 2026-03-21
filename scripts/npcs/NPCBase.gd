# NPCBase.gd — Base class for all NPCs. Extends Entity.
class_name NPCBase
extends Entity

enum Faction { PEACEFUL, ALLY, HOSTILE }

# ── Exports ────────────────────────────────────────────────────────────────────
@export var npc_name: String     = "NPC"
@export var faction: Faction     = Faction.PEACEFUL
@export var loot_table: Resource = null   # LootTable resource

# ── Node refs (in addition to Entity's anim_sprite + collision) ────────────────
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection_area: Area2D       = $DetectionArea
@onready var health_bar: ProgressBar      = $HealthBar

# ── Entity hook ───────────────────────────────────────────────────────────────

func _on_entity_ready() -> void:
	health_bar.max_value = max_health
	health_bar.value     = max_health

# ── Entity hooks ───────────────────────────────────────────────────────────────

func _on_damaged(_amount: int) -> void:
	health_bar.value = current_health
	anim_sprite.play("hurt")

func _on_healed(_amount: int) -> void:
	health_bar.value = current_health

func _on_died() -> void:
	anim_sprite.play("die")
	EventBus.npc_died.emit(self, global_position)
	_drop_loot()
	# Wait for death animation before freeing
	anim_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)

# ── Loot ───────────────────────────────────────────────────────────────────────

func _drop_loot() -> void:
	if loot_table == null:
		return
	var drops: Array = loot_table.roll()
	for item in drops:
		EventBus.world_item_spawned.emit(item, global_position)

# ── Interaction (override in subclasses) ──────────────────────────────────────

func interact(_interactor: Node) -> void:
	pass
