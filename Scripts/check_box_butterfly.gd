extends CheckBox

const INGREDIENT_NAME = "Butterfly"

func _ready() -> void:
	update_checkbox_status()
	# Connect the built-in toggle signal to our function below
	toggled.connect(_on_checkbox_toggled)

func update_checkbox_status() -> void:
	var count = GameManager.pocket.get(INGREDIENT_NAME, 0)
	
	if count > 0:
		text = INGREDIENT_NAME.capitalize() + " (" + str(count) + ")"
		disabled = false  
	else:
		text = "You don't have enough " + INGREDIENT_NAME + "!"
		disabled = true   
		button_pressed = false 

func _on_checkbox_toggled(is_checked: bool) -> void:
	if is_checked:
		# Add to selection if it's not already there
		if not GameManager.selected_ingredients.has(INGREDIENT_NAME):
			GameManager.selected_ingredients.append(INGREDIENT_NAME)
	else:
		# Remove from selection if unchecked
		GameManager.selected_ingredients.erase(INGREDIENT_NAME)
