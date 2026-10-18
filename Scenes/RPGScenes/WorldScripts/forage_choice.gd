extends Control
## The choice screen opened by forage_spot.gd. Shows the good and bad version
## of an ingredient side by side, in random order, so the player has to look
## closely. Clicking one sends `chosen` with that version's name.
##
## Needs (with Access as Unique Name on):
##   %LeftChoice   a TextureButton
##   %RightChoice  a TextureButton
##   %Hint         a Label

## Tells the forage spot which version the player picked.
signal chosen(item_name: String)

## Set by the forage spot before the screen is shown.
var good_name: String = ""
var good_texture: Texture2D
var bad_name: String = ""
var bad_texture: Texture2D

## If true, the good one is randomly on the left or the right.
@export var shuffle: bool = true

@onready var left_choice: TextureButton = %LeftChoice
@onready var right_choice: TextureButton = %RightChoice
@onready var hint: Label = %Hint

var _picked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the game
	process_mode = Node.PROCESS_MODE_ALWAYS   # works while the game is paused
	hint.text = "Which one should you take?"

	# Decide which side gets the good one.
	var good_on_left := randf() < 0.5 if shuffle else true
	if good_on_left:
		_setup(left_choice, good_name, good_texture)
		_setup(right_choice, bad_name, bad_texture)
	else:
		_setup(left_choice, bad_name, bad_texture)
		_setup(right_choice, good_name, good_texture)


## Gives a button its picture, and makes clicking it pick that version.
func _setup(button: TextureButton, item_name: String, texture: Texture2D) -> void:
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.pressed.connect(_pick.bind(item_name, button))
	# Small grow on hover so it's clear what you're about to pick.
	button.mouse_entered.connect(func(): _hover(button, true))
	button.mouse_exited.connect(func(): _hover(button, false))


func _hover(button: TextureButton, on: bool) -> void:
	if _picked:
		return
	button.pivot_offset = button.size / 2.0
	create_tween().tween_property(button, "scale", Vector2(1.1, 1.1) if on else Vector2.ONE, 0.1)


## The player clicked one: fade out the other, pause briefly, then report it.
func _pick(item_name: String, button: TextureButton) -> void:
	if _picked:
		return
	_picked = true
	var other := right_choice if button == left_choice else left_choice
	other.modulate.a = 0.3
	left_choice.disabled = true
	right_choice.disabled = true
	await get_tree().create_timer(0.4).timeout
	chosen.emit(item_name)
