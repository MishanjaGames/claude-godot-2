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
