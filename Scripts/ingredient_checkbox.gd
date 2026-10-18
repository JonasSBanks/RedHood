extends CheckBox
## One ingredient card on the selection page. The same script works for every
## ingredient: set Ingredient Name in the Inspector and it shows that
## ingredient's picture.
##
## Looks like the minigames: a dark rounded card with a cream frame. Hovering
## lights the frame gold; picking it gives it a thick gold frame, a gold tick
## badge in the corner, and a little pop. (The default tick box is hidden.)
##
##   - The player has some: the card shows normally and can be picked.
##   - The player has none: the card is faded and can't be picked.
##   - 5 already picked (GameManager.MAX_SELECTED): the other cards are
##     dimmed and can't be picked until one is unpicked.
## Hovering shows the name and how many the player has.

## Must match a name in GameManager.pocket exactly, e.g. "Bad Butterfly".
@export var ingredient_name: String = "Butterfly"
## How big the picture is. Every card is this plus a small frame, so all the
## cards come out the same size whatever size the pictures are.
@export var icon_size: Vector2 = Vector2(80, 80)
## Show the ingredient's name under the picture. Off by default, because names
## like "Bad Butterfly" would give away which ones are bad.
@export var show_name: bool = false
## Size of the name text (when Show Name is on).
@export var name_font_size: int = 16

## All checkboxes join this group so they can update each other.
const GROUP := "ingredient_checkboxes"

const CARD_BG := MinigameStyle.CARD_BG
const CARD_BG_PICKED := MinigameStyle.CARD_BG_PICKED
## Space between the card's frame and the picture.
const PADDING := 12.0

var _picture: TextureRect
var _badge: Control  # draws the gold tick, on top of the picture


func _ready() -> void:
	add_to_group(GROUP)
	icon = null
	text = ""
	focus_mode = Control.FOCUS_NONE
	_style_card()
	_size_card()
	update_checkbox_status()
	toggled.connect(_on_checkbox_toggled)
	mouse_entered.connect(func(): MinigameStyle.bounce(self, 1.05))
	mouse_exited.connect(func(): MinigameStyle.bounce(self, 1.0))


## Makes every card exactly the same size, and puts the picture in the middle
## at Icon Size, keeping its shape (never stretched or squished).
func _size_card() -> void:
	var name_space := name_font_size + 8.0 if show_name else 0.0
	var card_size := icon_size + Vector2(PADDING * 2.0, PADDING * 2.0 + name_space)
	scale = Vector2.ONE           # undo any scaling done in the editor
	custom_minimum_size = card_size
	size = card_size              # undo any resizing done in the editor

	_picture = TextureRect.new()
	_picture.texture = Ingredient.get_texture(ingredient_name)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.position = Vector2(PADDING, PADDING)
	_picture.size = icon_size
	add_child(_picture)

	if show_name:
		var name_label := Label.new()
		name_label.text = ingredient_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.add_theme_color_override("font_color", MinigameStyle.TEXT_COLOR)
		name_label.add_theme_color_override("font_outline_color", MinigameStyle.TEXT_OUTLINE)
		name_label.add_theme_constant_override("outline_size", 6)
		name_label.position = Vector2(0, PADDING + icon_size.y)
		name_label.size = Vector2(card_size.x, name_space)
		add_child(name_label)

	# Added last so the tick badge draws over the picture.
	_badge = Control.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = card_size
	_badge.draw.connect(_draw_badge)
	add_child(_badge)


## The card look, in the same colors as the minigames.
func _style_card() -> void:
	var frame := MinigameStyle.BAR_FRAME
	var gold := MinigameStyle.GOLD
	add_theme_stylebox_override("normal", MinigameStyle.make_panel(CARD_BG, frame, 3))
	add_theme_stylebox_override("hover", MinigameStyle.make_panel(CARD_BG, gold, 3))
	add_theme_stylebox_override("pressed", MinigameStyle.make_panel(CARD_BG_PICKED, gold, 6))
	add_theme_stylebox_override("hover_pressed", MinigameStyle.make_panel(CARD_BG_PICKED, gold, 6))
	add_theme_stylebox_override("disabled", MinigameStyle.make_panel(CARD_BG, frame, 3))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Hide the default tick box (the gold frame and badge show the pick instead).
	var none := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for tick in ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
			"radio_checked", "radio_unchecked"]:
		add_theme_icon_override(tick, none)



## Draws the gold tick badge in the top-right corner while picked.
func _draw_badge() -> void:
	if not button_pressed:
		return
	var r := 13.0
	var c := Vector2(size.x - r - 4.0, r + 4.0)
	_badge.draw_circle(c, r + 2.0, MinigameStyle.TEXT_OUTLINE)
	_badge.draw_circle(c, r, MinigameStyle.GOLD)
	_badge.draw_polyline(PackedVector2Array([
		c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(7, -5)]),
		MinigameStyle.TEXT_OUTLINE, 3.0, true)


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
	if _badge:
		_badge.queue_redraw()


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
	_pop()
	get_tree().call_group(GROUP, "update_checkbox_status")


## A quick squish-and-spring when picked or unpicked.
func _pop() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
