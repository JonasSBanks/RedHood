extends CheckBox
## One checkbox on the selection page. The same script works for every
## ingredient: set Ingredient Name in the Inspector and it shows that
## ingredient's picture (no text).
##
## Replaces the separate scripts like check_box_wolfsbane.gd.
##   - The player has some: the picture shows normally and can be ticked.
##   - The player has none: the picture is faded and it can't be ticked.
## Hovering shows the name and how many the player has.

## Must match a name in GameManager.pocket exactly, e.g. "Bad Butterfly".
@export var ingredient_name: String = "Wolfs Bane"
## How big the picture is.
@export var icon_size: Vector2 = Vector2(64, 64)


func _ready() -> void:
	text = ""
	icon = Ingredient.get_texture(ingredient_name)
	expand_icon = true
	custom_minimum_size = icon_size + Vector2(32, 0)  # room for the tick box
	update_checkbox_status()
	toggled.connect(_on_checkbox_toggled)


## Turns the checkbox on or off depending on what's in the pocket.
func update_checkbox_status() -> void:
	var count: int = GameManager.pocket.get(ingredient_name, 0)
	tooltip_text = "%s (%d)" % [ingredient_name, count]
	if count > 0:
		disabled = false
		modulate.a = 1.0
	else:
		disabled = true
		button_pressed = false
		modulate.a = 0.35  # faded = you don't have any


## Adds or removes this ingredient from today's selection.
func _on_checkbox_toggled(is_checked: bool) -> void:
	if is_checked:
		if not GameManager.selected_ingredients.has(ingredient_name):
			GameManager.selected_ingredients.append(ingredient_name)
	else:
		GameManager.selected_ingredients.erase(ingredient_name)
