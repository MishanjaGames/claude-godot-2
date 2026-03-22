# EventBus.gd
# Central signal bus. Every cross-system event flows through here.
# No node ever holds a direct reference to another node for communication.
# Load order: FIRST autoload — everything else connects to it in _ready().
extends Node

# ══════════════════════════════════════════════════════════════════════════════
# PLAYER
# ══════════════════════════════════════════════════════════════════════════════
signal player_health_changed(current: int, maximum: int)
signal player_stamina_changed(current: float, maximum: float)
signal player_died()
signal player_respawned(position: Vector2)
signal player_interacted(interactable: Node)
signal player_chunk_changed(old_chunk: Vector2i, new_chunk: Vector2i)
signal player_world_wrapped(old_pos: Vector2, new_pos: Vector2)

# ══════════════════════════════════════════════════════════════════════════════
# COMBAT
# ══════════════════════════════════════════════════════════════════════════════
signal entity_damaged(entity: Node, amount: int, damage_type: String, source: Node)
signal entity_healed(entity: Node, amount: int)
signal entity_died(entity: Node, position: Vector2, killer: Node)
signal entity_killed_enemy(killer: Node, victim: Node)
signal status_effect_applied(entity: Node, effect: Resource)
signal status_effect_removed(entity: Node, effect: Resource)
signal status_effect_ticked(entity: Node, effect: Resource, damage: int)
signal knockback_applied(entity: Node, force: Vector2)

# ══════════════════════════════════════════════════════════════════════════════
# INVENTORY
# ══════════════════════════════════════════════════════════════════════════════
signal inventory_item_added(item: Resource, slot_index: int)
signal inventory_item_removed(item: Resource, slot_index: int)
signal inventory_item_used(item: Resource, user: Node)
signal inventory_item_moved(from_index: int, to_index: int)
signal inventory_full()
signal hotbar_slot_changed(slot_index: int, item: Resource)
signal active_hotbar_changed(slot_index: int)
signal equipment_changed(slot: int, item: Resource)

# ══════════════════════════════════════════════════════════════════════════════
# WORLD / CHUNKS
# ══════════════════════════════════════════════════════════════════════════════
signal chunk_load_requested(chunk_coords: Vector2i)
signal chunk_loaded(chunk_coords: Vector2i)
signal chunk_unloaded(chunk_coords: Vector2i)
signal world_generated(seed: int)
signal tile_changed(world_tile_pos: Vector2i, old_source: int, new_source: int)

# ══════════════════════════════════════════════════════════════════════════════
# WORLD OBJECTS
# ══════════════════════════════════════════════════════════════════════════════
signal world_item_spawned(item: Resource, position: Vector2)
signal world_item_picked_up(item: Resource, picker: Node)
signal harvestable_hit(harvestable: Node, damage: int, tool_power: int)
signal harvestable_destroyed(harvestable: Node, position: Vector2)
signal harvestable_regrown(harvestable: Node)
signal structure_entered(structure: Node, entity: Node)
signal structure_exited(structure: Node, entity: Node)
signal chest_opened(chest: Node, opener: Node)
signal door_toggled(door: Node, is_open: bool)

# ══════════════════════════════════════════════════════════════════════════════
# TOOLS
# ══════════════════════════════════════════════════════════════════════════════
signal tool_used(tool_type: int, user: Node, position: Vector2)
signal tool_broke(tool: Resource, user: Node)
signal key_item_used(quest_id: String, item: Resource, user: Node)

# ══════════════════════════════════════════════════════════════════════════════
# NPC
# ══════════════════════════════════════════════════════════════════════════════
signal npc_spawned(npc: Node)
signal npc_died(npc: Node, position: Vector2, killer: Node)
signal npc_dialogue_started(npc: Node, dialogue: Array)
signal npc_dialogue_ended(npc: Node)
signal npc_alerted(npc: Node, target: Node)
signal npc_lost_target(npc: Node)

# ══════════════════════════════════════════════════════════════════════════════
# SCENE / UI
# ══════════════════════════════════════════════════════════════════════════════
signal scene_change_requested(path: String)
signal scene_loaded(path: String)
signal hud_show_message(text: String, duration: float)
signal hud_show_popup(text: String, position: Vector2, color: Color)
signal dialogue_open_requested(dialogue: Array, npc: Node)
signal dialogue_closed()
signal game_paused(is_paused: bool)
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)

# ══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ══════════════════════════════════════════════════════════════════════════════
signal play_sfx_requested(sfx_id: String, position: Vector2)
signal play_music_requested(music_id: String, fade_time: float)
signal stop_music_requested(fade_time: float)

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════
signal new_game_started(seed: int)
signal game_saved()
signal game_loaded()
signal save_failed(reason: String)
signal load_failed(reason: String)

# ══════════════════════════════════════════════════════════════════════════════
# PROGRESSION
# ══════════════════════════════════════════════════════════════════════════════
signal experience_gained(amount: int, source: String)
signal level_up(new_level: int)
signal quest_updated(quest_id: String, stage: int)
signal quest_completed(quest_id: String)
signal achievement_unlocked(achievement_id: String)

# ══════════════════════════════════════════════════════════════════════════════
# DAY / NIGHT
# ══════════════════════════════════════════════════════════════════════════════
signal day_phase_changed(new_phase: int)
signal day_elapsed(day_number: int)
signal time_of_day_changed(normalised_time: float)
