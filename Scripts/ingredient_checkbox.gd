extends CheckBox
## One checkbox on the selection page. The same script works for every
## ingredient: set Ingredient Name in the Inspector and it shows that
## ingredient's picture (no text).
##
##   - The player has some: the picture shows normally and can be ticked.
##   - The player has none: the picture is faded and it can't be ticked.
##   - 5 already ticked (GameManager.MAX_SELECTED): the unticked ones are
##     dimmed and can't be ticked until one is unticked.
## Hovering shows the name and how many the player has.

## Must match a name in GameManager.pocket exactly, e.g. "Bad Butterfly".
@export var ingredient_name: String = "Butterfly"
## How big the picture is.
@export var icon_size: Vector2 = Vector2(64, 64)

## All checkboxes join this group so they can update each other.
const GROUP := "ingredient_checkboxes"


func _ready() -> void:
	add_to_group(GROUP)
	text = ""
	icon = Ingredient.get_texture(ingredient_name)
	expand_icon = true
	custom_minimum_size = icon_size + Vector2(32, 0)  # room for the tick box
	update_checkbox_status()
	toggled.connect(_on_checkbox_toggled)


## Turns the checkbox on or off depending on what's in the pocket and how
## many are already ticked.
func update_checkbox_status() -> void:
	var count: int = GameManager.pocket.get(ingredient_name, 0)
	var limit_reached: bool = GameManager.selected_ingredients.size() >= GameManager.MAX_SELECTED

	if count <= 0:
		disabled = true
		set_pressed_no_signal(false)
		modulate.a = 0.35  # faded = you don't have any
		tooltip_text = "%s (none)" % ingredient_name
	elif limit_reached and not button_pressed:
		disabled = true
		modulate.a = 0.6   # dimmed = you can't carry more
		tooltip_text = "%s (%d) - you can only bring %d" % [ingredient_name, count, GameManager.MAX_SELECTED]
	else:
		disabled = false
		modulate.a = 1.0
		tooltip_text = "%s (%d)" % [ingredient_name, count]


## Adds or removes this ingredient from today's selection, then updates every
## checkbox so the limit shows right away.
func _on_checkbox_toggled(is_checked: bool) -> void:
	if is_checked:
		if GameManager.selected_ingredients.size() >= GameManager.MAX_SELECTED:
			set_pressed_no_signal(false)  # already carrying the most allowed
			return
		if not GameManager.selected_ingredients.has(ingredient_name):
			GameManager.selected_ingredients.append(ingredient_name)
	else:
		GameManager.selected_ingredients.erase(ingredient_name)
	get_tree().call_group(GROUP, "update_checkbox_status")
