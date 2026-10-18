extends Area2D
## A place in the world where the player forages one ingredient.
## Walk into it, press the interact key, and a choice screen opens on top of
## the game showing the good and bad version. Whichever the player clicks is
## added to the pocket, the screen closes, and the player is back where they were.
##
## Set everything for the ingredient in the Inspector, e.g. for a mushroom:
##   Good Name: Mushroom        Good Texture: mushroom_good.png
##   Bad Name:  Bad Mushroom    Bad Texture:  mushroom_bad.png
##
## Needs:
##   a CollisionShape2D child (the area the player must stand in)
##   the player node added to the group named in Player Group ("player")
## Optional children:
##   Sprite2D called Sprite  - the plant in the world (hidden once picked)
##   Label called Prompt     - e.g. "Press E", shown while the player is close

## The choice screen. Drag forage_choice.tscn into this slot.
@export var choice_scene: PackedScene

@export_group("Ingredient")
@export var good_name: String = "Mushroom"
@export var good_texture: Texture2D
@export var bad_name: String = "Bad Mushroom"
@export var bad_texture: Texture2D

@export_group("Settings")
## The input action that opens the choice. "ui_accept" is Enter/Space by default.
## Change it to your own action (e.g. "interact") if you have one.
@export var interact_action: StringName = &"ui_accept"
## The group the player node is in, so only the player triggers it.
@export var player_group: StringName = &"player"
## If true, the spot can only be foraged once.
@export var one_time: bool = true

@onready var sprite: Node2D = get_node_or_null("Sprite")
@onready var prompt: CanvasItem = get_node_or_null("Prompt")

var _player_inside := false
var _open := false
var _used := false


func _ready() -> void:
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
		_open_choice()


## Opens the choice screen on its own CanvasLayer above everything,
## and pauses the game so the player can't walk off.
func _open_choice() -> void:
	if choice_scene == null:
		push_error("ForageSpot: drag forage_choice.tscn into Choice Scene in the Inspector.")
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


## The player picked one: add it to the pocket, close the screen, unpause.
func _on_chosen(item_name: String, layer: CanvasLayer) -> void:
	_add_to_pocket(item_name)
	layer.queue_free()
	get_tree().paused = false
	_open = false
	if one_time:
		_used = true
		if sprite:
			sprite.visible = false  # the plant has been picked
	_update_prompt()


## THE ONE LINE TO MATCH YOUR GAME: where foraged items are stored.
## Change "pocket" to the name of your global pocket array in GameManager.
func _add_to_pocket(item_name: String) -> void:
	GameManager.pocket.append(item_name)
	print("Pocket now has: ", GameManager.pocket)  # for testing, remove later


func _update_prompt() -> void:
	if prompt:
		prompt.visible = _player_inside and not _open and not _used
