extends Control

func _ready() -> void:
	get_tree().paused = false

func _on_new_game_pressed() -> void:
	LoadingScreen.load_scene("res://scenes/world/world.tscn")

func _on_continue_pressed() -> void:
	# placeholder — we'll add save/load later
	print("No save found yet.")

func _on_quit_pressed() -> void:
	get_tree().quit()
