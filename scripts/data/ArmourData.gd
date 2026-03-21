# ArmourData.gd
# Equippable armour. InventoryManager tracks the active equipment per slot.
class_name ArmourData
extends ItemData

enum Slot { HEAD, CHEST, LEGS, FEET, ACCESSORY_1, ACCESSORY_2 }
enum WeightClass { LIGHT, MEDIUM, HEAVY }

@export var slot: Slot                      = Slot.CHEST
@export var weight_class: WeightClass       = WeightClass.LIGHT

# ── Stat bonuses applied to StatBlock while equipped ─────────────────────────
@export_group("Stat Bonuses")
@export var defence_bonus: int              = 0
@export var max_health_bonus: int           = 0
@export var max_stamina_bonus: float        = 0.0
@export var magic_resist_bonus: float       = 0.0
@export var move_speed_penalty: float       = 0.0   # subtracted (positive = slower)
@export var attack_bonus: int               = 0     # accessories can boost offence

# ── Passive effects active while equipped ────────────────────────────────────
@export var passive_effects: Array[StatusEffect] = []
