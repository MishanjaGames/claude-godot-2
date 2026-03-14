extends Item
class_name EquippableItem

enum EquipSlot {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	HANDS,
	RING_L,
	RING_R,
	AMULET,
	ARTIFACT,
}

@export var slot: EquipSlot = EquipSlot.CHEST

func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["equip"] = {
		"slot": EquipSlot.keys()[slot],
	}
	return base
