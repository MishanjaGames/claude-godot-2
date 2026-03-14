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
		EventBus.world_item_spawned.emit(item)  # WorldScreen spawns actual node

func interact(interactor: Node) -> void:
	pass  # Override in subclasses
