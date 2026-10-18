extends Container
## The ingredient shelf in the kitchen. Makes one draggable button for each
## name in GameManager.selected_ingredients (an Array of names).
## Put this on an HBoxContainer (or GridContainer) and leave it with no children.
##
## With Fit To Box on, the buttons size themselves so that the most the player
## can bring (GameManager.MAX_SELECTED, 5) fits inside this container. Make the
## container the inside area of the wood box and the items will always fit.

## Size the buttons to fit the container (true), or use Button Size (false).
@export var fit_to_box: bool = true
## Button size used when Fit To Box is off.
@export var button_size: Vector2 = Vector2(96, 96)


func _ready() -> void:
	resized.connect(refresh)  # re-fit if the window or box changes size
	refresh()


## Deletes all buttons and builds new ones from selected_ingredients.
## Call this again if selected_ingredients is changed from somewhere else.
func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var each := _fitted_size() if fit_to_box else button_size
	for item_name in GameManager.selected_ingredients:
		var button := Ingredient.new()
		button.setup(item_name, each)
		add_child(button)


## The biggest square that lets MAX_SELECTED buttons sit side by side,
## with the container's spacing between them, without going past its height.
func _fitted_size() -> Vector2:
	var slots: int = GameManager.MAX_SELECTED
	var gap: float = get_theme_constant("separation")
	var by_width: float = (size.x - gap * (slots - 1)) / slots
	var side: float = max(min(by_width, size.y), 8.0)
	return Vector2(side, side)


## Called by an Ingredient button after it's dropped somewhere that took it.
## Removes one copy of that name from the array, then rebuilds the shelf.
func use_item(item_name: String) -> void:
	GameManager.selected_ingredients.erase(item_name)
	refresh()
