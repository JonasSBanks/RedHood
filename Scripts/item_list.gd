extends Container
## The ingredient shelf in the kitchen. Makes one draggable button for each
## name in GameManager.selected_ingredients (an Array of names).
## Put this on an HBoxContainer (or GridContainer) and leave it with no children.

@export var button_size: Vector2 = Vector2(96, 96)


func _ready() -> void:
	refresh()


## Deletes all buttons and builds new ones from selected_ingredients.
## Call this again if selected_ingredients is changed from somewhere else.
func refresh() -> void:
	for child in get_children():
		child.queue_free()
	for item_name in GameManager.selected_ingredients:
		var button := Ingredient.new()
		button.setup(item_name, button_size)
		add_child(button)


## Called by an Ingredient button after it's dropped somewhere that took it.
## Removes one copy of that name from the array, then rebuilds the shelf.
func use_item(item_name: String) -> void:
	GameManager.selected_ingredients.erase(item_name)
	refresh()
