extends Node
## Gives the selection screen the same look as the minigames. Add a plain Node
## called SelectionStyle anywhere in the selection scene (e.g. right under the
## root) and attach this script.
## It doesn't change how selecting works, only how it looks.
##
##   - A banner at the top center: "Choose up to 5 ingredients  (2/5)",
##     updating as you pick, turning gold when you're carrying the most.
##   - The Start button gets the game's button look (gold on hover).
##   - The Start button is greyed out until at least one ingredient is picked.
##   - A dark framed panel behind the ingredient cards, matching the cards.
##   - Sounds for picking, unpicking and pressing Start.
##
## The ingredient cards style themselves (ingredient_checkbox.gd).

## Your Start Cooking button. Drag it here from the Scene panel.
@export var start_button: BaseButton
## Optional: an existing title Label to use for the banner. Best left empty:
## one is made for you, always on top and centered on the screen.
@export var title_label: Label

@export_group("Text")
@export var choose_text: String = "Choose up to %d ingredients"
@export var full_text: String = "You can't carry any more"
## How far down from the top of the screen the banner sits.
@export var title_top: float = 24.0
@export var title_font: Font
@export var title_font_size: int = 34
@export var button_font_size: int = 30

@export_group("Start button")
## Grey out Start until something is picked.
@export var need_one_to_start: bool = true

@export_group("Card panel")
## Put a dark framed panel behind the ingredient cards.
@export var card_panel: bool = true
## Space between the cards and the panel's edge.
@export var card_panel_padding: float = 24.0
## The panel's color. A warm wood brown, lighter than the cards so they stand out.
@export var card_panel_color: Color = Color(0.42, 0.28, 0.16, 0.92)
## The panel's frame color.
@export var card_panel_frame: Color = Color(0.93, 0.80, 0.55)

@export_group("Sounds")
## Plays when an ingredient is picked.
@export var pick_sound: AudioStream
## Plays when an ingredient is unpicked. Leave empty to use Pick Sound.
@export var unpick_sound: AudioStream
## Plays when Start is pressed (keeps playing into the kitchen).
@export var start_sound: AudioStream
## Pick/unpick pitch varies a little so repeats don't sound identical.
@export var pitch_variation: float = 0.08

var _was_full := false
var _sound_player: AudioStreamPlayer


func _ready() -> void:
	# Wait one frame so the rest of the scene (and its layout) is ready.
	_setup.call_deferred()


func _setup() -> void:
	if not title_label:
		# The banner gets its own CanvasLayer, so it's always on top and
		# centered on the screen, wherever this node sits in the scene.
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		title_label = Label.new()
		layer.add_child(title_label)
	MinigameStyle.style_hint(title_label, title_font, title_font_size)
	MinigameStyle.place_top_center(title_label, title_top)

	if start_button is Button:
		MinigameStyle.style_button(start_button, title_font, button_font_size)
	elif start_button:
		push_warning("SelectionStyle: Start is not a regular Button, so it can't get the card look (only the sound).")
	else:
		push_warning("SelectionStyle: drag your Start button into the Start Button slot.")

	_sound_player = AudioStreamPlayer.new()
	add_child(_sound_player)
	for box in get_tree().get_nodes_in_group("ingredient_checkboxes"):
		box.toggled.connect(_on_card_toggled)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	if card_panel:
		_add_card_panel()
	_update()


## A dark framed panel behind all the ingredient cards, sized to fit them.
func _add_card_panel() -> void:
	var cards := get_tree().get_nodes_in_group("ingredient_checkboxes")
	if cards.is_empty():
		return
	var parent: Control = cards[0].get_parent()
	var area := Rect2(cards[0].position, cards[0].size)
	for card in cards:
		if card.get_parent() == parent:
			area = area.merge(Rect2(card.position, card.size))
	area = area.grow(card_panel_padding)

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",
		MinigameStyle.make_panel(card_panel_color, card_panel_frame, 4, 22))
	panel.position = area.position
	panel.size = area.size
	parent.add_child(panel)
	parent.move_child(panel, 0)  # behind the cards


func _on_card_toggled(is_on: bool) -> void:
	var sound := pick_sound if is_on or not unpick_sound else unpick_sound
	if not sound:
		return
	_sound_player.stream = sound
	_sound_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	_sound_player.play()


## Start changes the scene right away, which would cut a normal sound off.
## So this sound's player is put on the tree's root, which survives the scene
## change, and deletes itself when the sound ends.
func _on_start_pressed() -> void:
	if not start_sound:
		return
	var player := AudioStreamPlayer.new()
	player.stream = start_sound
	player.finished.connect(player.queue_free)
	# Your Start script may have already switched scenes by now, taking this
	# node out of the tree, so reach the root through the engine instead.
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	player.play()


func _process(_delta: float) -> void:
	if title_label:
		_update()


## Keeps the banner text and the Start button in step with what's picked.
func _update() -> void:
	var picked: int = GameManager.selected_ingredients.size()
	var most: int = GameManager.MAX_SELECTED
	var full := picked >= most
	var line := full_text if full else choose_text % most
	MinigameStyle.set_hint(title_label, "%s  (%d/%d)" % [line, picked, most])

	if full != _was_full:
		_was_full = full
		MinigameStyle.set_banner_color(title_label,
			Color(0.45, 0.30, 0.05, 0.85) if full else MinigameStyle.BANNER_COLOR)

	if start_button and need_one_to_start:
		start_button.disabled = picked == 0
