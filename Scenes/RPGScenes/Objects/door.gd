extends Area2D

## Which scene this door goes to.
@export_file("*.tscn") var target_scene : String
@export var spawn_point_name : String = "DefaultSpawn"
## Off: walking into the door uses it right away (like the front door).
## On: the player has to stand in it and press E (the "interact" action).
@export var press_e_to_use : bool = false
## Text shown while the player is standing in it (only if press_e_to_use is on).
@export var prompt_text : String = "Press E"

var _player_inside := false
var _prompt : Label


func _ready() -> void :
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if press_e_to_use :
		_prompt = Label.new()
		_prompt.text = prompt_text
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.add_theme_font_size_override("font_size", 24)
		_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
		_prompt.add_theme_constant_override("outline_size", 6)
		_prompt.size = Vector2(240, 34)
		# Undo the door's scale so the text stays a normal size.
		_prompt.scale = Vector2.ONE / scale
		_prompt.position = Vector2(-120, -40) / scale
		_prompt.z_index = 10
		_prompt.visible = false
		add_child(_prompt)


func _on_body_entered(body: Node2D) -> void :
	if not body.is_in_group("Red") :
		return
	if press_e_to_use :
		_player_inside = true
		_prompt.visible = true
	else :
		_go()


func _on_body_exited(body: Node2D) -> void :
	if body.is_in_group("Red") and press_e_to_use :
		_player_inside = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if press_e_to_use and _player_inside and event.is_action_pressed("interact") :
		get_viewport().set_input_as_handled()
		_go()


func _go() -> void :
	if target_scene :
		# Deferred: changing scene inside a physics callback is not allowed.
		get_tree().call_deferred("change_scene_to_file", target_scene)
	else :
		push_warning("Door has no Target Scene set.")
