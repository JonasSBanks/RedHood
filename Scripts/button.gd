extends Button

# Save the original button text so we can restore it later
var original_text: String = ""

func _ready() -> void:
	original_text = text
	pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	# 1. Check if they actually selected anything
	if GameManager.selected_ingredients.is_empty():
		text = "Select ingredients first!"
		modulate = Color.RED # Optional: Turn the button text red for visual feedback
		
		# 2. Wait for 2 seconds before changing it back
		await get_tree().create_timer(2.0).timeout
		
		text = original_text
		modulate = Color.WHITE # Reset the color back to normal
		return
		
	# 3. If they did select something, change the scene
	get_tree().change_scene_to_file("res://Scenes/Kitchen.tscn")
