extends Area2D
## A place in the world where the player forages one ingredient.
## Walk into it, press the interact key, and a choice screen opens on top of
## the game showing the good and bad version. Whichever the player clicks is
## added to the pocket, the screen closes, and the player is back where they were.
##
## Set everything for the ingredient in the Inspector, e.g. for a mushroom:
##   Good Name: Mushroom        Good Texture: mushroom_good.png
##   Bad Name:  Bad Mushroom    Bad Texture:  mushroom_bad.png
## Leave Bad Name empty for an item with only one version (e.g. Wolfs Bane):
## pressing E then just picks it up, no choice screen.
##
## Needs:
##   a CollisionShape2D child (the area the player must stand in)
##   the player node added to the group named in Player Group
## Optional children:
##   Sprite2D called Sprite  - the plant in the world (hidden once picked)
##   Label called Prompt     - shown while the player is close (made for you if missing)

## The choice screen. Drag forage_minigame.tscn into this slot.
@export var choice_scene: PackedScene

@export_group("Ingredient")
@export var good_name: String = "Mushroom"
@export var good_texture: Texture2D
@export var bad_name: String = "Bad Mushroom"
@export var bad_texture: Texture2D

@export_group("Settings")
## The input action that opens the choice ("interact" is E).
@export var interact_action: StringName = &"interact"
## The group the player node is in, so only the player triggers it.
@export var player_group: StringName = &"Red"
## If true, the spot can only be foraged once per day.
@export var one_time: bool = true
## If true, the spot only shows up once the player has read page 2 of the
## recipe book (GameManager.has_read_page_2). Use it for Wolfs Bane.
@export var needs_page_2: bool = false
## Text of the prompt shown while standing here.
@export var prompt_text: String = "Press E"

@onready var sprite: Node2D = _find_sprite()
@onready var prompt: CanvasItem = get_node_or_null("Prompt")

var _player_inside := false
var _open := false
var _used := false


func _ready() -> void:
	# Locked away until page 2 is read: hide and switch off completely.
	if needs_page_2 and not GameManager.has_read_page_2:
		visible = false
		monitoring = false
		set_process_unhandled_input(false)
		return
	# Already picked earlier today (e.g. the player went inside and came back out).
	if one_time and _key() in GameManager.foraged_today:
		_used = true
		if sprite:
			sprite.visible = false
	if prompt == null:
		prompt = _make_prompt()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		_player_inside = true
		_update_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group(player_group):
		_player_inside = false
		_update_prompt()


## Pressing the interact key while standing here opens the choice.
func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and not _open and not _used \
			and event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		if bad_name == "":
			_picked(good_name)  # only one version: just take it
		else:
			_open_choice()


## Opens the choice screen on its own CanvasLayer above everything,
## and pauses the game so the player can't walk off.
func _open_choice() -> void:
	if choice_scene == null:
		push_error("ForageSpot: drag forage_minigame.tscn into Choice Scene in the Inspector.")
		return
	_open = true

	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while paused

	var choice := choice_scene.instantiate()
	choice.good_name = good_name
	choice.good_texture = good_texture
	choice.bad_name = bad_name
	choice.bad_texture = bad_texture
	choice.chosen.connect(_on_chosen.bind(layer))

	layer.add_child(choice)
	get_tree().current_scene.add_child(layer)
	get_tree().paused = true
	_update_prompt()


## The player picked one: close the screen, unpause, add it to the pocket.
func _on_chosen(item_name: String, layer: CanvasLayer) -> void:
	layer.queue_free()
	get_tree().paused = false
	_open = false
	_picked(item_name)


func _picked(item_name: String) -> void:
	GameManager.add_to_pocket(item_name)
	if one_time:
		_used = true
		GameManager.foraged_today.append(_key())
		if sprite:
			sprite.visible = false  # the plant has been picked
	_update_prompt()


## Name used to remember this spot was picked today.
func _key() -> String:
	return str(get_tree().current_scene.scene_file_path, ":", name)


func _find_sprite() -> Node2D:
	var s := get_node_or_null("Sprite")
	if s == null:
		s = get_node_or_null("Sprite2D")
	return s


func _make_prompt() -> Label:
	var label := Label.new()
	label.text = prompt_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.size = Vector2(80, 20)
	label.position = Vector2(-40, -72)
	label.z_index = 10
	add_child(label)
	return label


func _update_prompt() -> void:
	if prompt:
		prompt.visible = _player_inside and not _open and not _used
