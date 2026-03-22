# Godot 4.6.1 — Complete 2D Game Template

> **Branch:** `remaster` — last updated 2026-03-21

Here's the full plan broken into phases, ordered strictly by dependency so nothing blocks the next step.

# Phase 1 — Foundation (do this first, everything depends on it)
New folder structure, all autoloads rewritten, and every data Resource class defined. No scenes yet — just the skeleton the whole game runs on. Specifically: EventBus, Registry (replaces ItemDatabase — one place for items, NPCs, biomes, structures, objects), WorldManager, GameManager, SaveManager, InventoryManager. Also: StatBlock.gd as a pure Resource that holds every stat (health, stamina, speed, attack, defence, etc.) — entities just carry one and it handles all the math. This is the most critical phase because every other phase reads from these.

# Phase 2 — World Generation
WorldGenerator.gd (noise layers: height, temperature, moisture → biome), ChunkManager.gd (32×32 tile chunks loaded around the player, unloaded when far away), BiomeData.tres format (defines which tiles spawn, which objects, which NPCs), and the planet-wrap logic (one function in WorldManager that checks if a character hits the world edge and teleports them to the opposite side — works for any entity automatically). StructurePlacer.gd runs during generation to stamp buildings/dungeons/caves from pre-authored StructureData resources using Godot's stamp API.

# Phase 3 — Entity System
Entity.gd (base, extends CharacterBody2D, carries a StatBlock), Player.gd, NPCBase.gd + PeacefulNPC, AllyNPC, HostileNPC. Key difference from current code: entities don't hardcode stats — they just ask their StatBlock. StatusEffect system (poison, burn, slow, etc.) as a list of StatusEffect resources on the entity that tick each frame.

# Phase 4 — Object System
Harvestable.gd base (trees, rocks, ore veins, bushes) — all share: health, DropTable, harvest tool requirement, regrowth timer. Each specific type (TreeObject, RockNode, OreVein) extends it with only the things that differ. Structure.gd for placed buildings with door/chest/NPC spawn points baked in.

# Phase 5 — Item & Combat System
Full item hierarchy under ItemData (base Resource): ConsumableData, WeaponData (→ MeleeData, RangedData), ToolData, ArmourData, KeyItemData. Weapons and tools are data-only resources; the combat logic lives in Player.gd and NPCBase.gd, not in the items themselves. DropTable replaces LootTable — weighted, supports quantity ranges, condition filters.

# Phase 6 — UI Layer
HUD, InventoryUI, DialogueBox, PauseMenu, SettingsScreen — all rebuilt to read from the new autoloads. Minimap (simple: render chunk grid as tiny coloured pixels into a SubViewport).

#Phase 7 — Save System
SaveManager serialises: player position + stats, inventory, world seed + which chunks have been modified and how (delta saves — only changed chunks, not the whole world), placed structures state (open doors, looted chests), NPC states.

*Generated for Godot 4.6.1 (stable). All scripts use GDScript with @export annotations and Godot 4 API only. No deprecated methods used.*
