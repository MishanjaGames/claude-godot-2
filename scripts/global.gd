extends Node

# ── Rendering ─────────────────────────────────────────────
# true  = draw hardcoded shapes (what we have now)
# false = use sprite textures from resources
var use_raw: bool = true

# ── Game state ────────────────────────────────────────────
var current_scene: String = ""

# ── Helpers ───────────────────────────────────────────────

# Call from anywhere to toggle raw mode at runtime
func toggle_raw() -> void:
	use_raw = not use_raw
	print("Raw: ", use_raw)
	raw_mode_changed.emit(use_raw)

signal raw_mode_changed(enabled: bool)
