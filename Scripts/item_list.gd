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

var _current_size := Vector2.ZERO


func _ready() -> void:
	# Wait one frame so the container has its real size before fitting.
	refresh.call_deferred()
	# If the box changes size, only resize the buttons (never rebuild here).
	resized.connect(_resize_buttons)


## Deletes all buttons and builds new ones from selected_ingredients.
## Call this again if selected_ingredients is changed from somewhere else.
func refresh() -> void:
	# Remove old buttons right away (queue_free alone would leave them in
	# the container until the end of the frame).
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_current_size = _button_size()
	for item_name in GameManager.selected_ingredients:
		var button := Ingredient.new()
		button.setup(item_name, _current_size)
		add_child(button)


## Called when the container changes size: resizes the existing buttons.
## Only acts on a real change, so it can't trigger itself in a loop.
func _resize_buttons() -> void:
	var new_size := _button_size()
	if new_size.is_equal_approx(_current_size):
		return
	_current_size = new_size
	for child in get_children():
		if child is Control:
			child.custom_minimum_size = new_size


## The button size: Button Size, or (with Fit To Box) the biggest square that
## lets MAX_SELECTED buttons sit side by side inside the container.
func _button_size() -> Vector2:
	if not fit_to_box:
		return button_size
	var slots: int = GameManager.MAX_SELECTED
	var gap: float = get_theme_constant("separation")
	var by_width: float = (size.x - gap * (slots - 1)) / slots
	var side: float = floor(clamp(min(by_width, size.y), 8.0, 512.0))
	return Vector2(side, side)


## Called by an Ingredient button after it's dropped somewhere that took it.
## Removes one copy of that name from the array, then rebuilds the shelf
## (deferred, so the button isn't removed while it's still handling the drag).
func use_item(item_name: String) -> void:
	GameManager.selected_ingredients.erase(item_name)
	refresh.call_deferred()
