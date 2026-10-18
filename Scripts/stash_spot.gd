extends DropTarget
## The pocket stash in the kitchen. Drag a whole ingredient from the shelf here
## to keep it for tomorrow; it's saved in GameManager.stash and comes back the
## next day.
##
## Only whole ingredients from the shelf can be stashed, up to 4
## (GameManager.MAX_STASH). Chopped, ground or squeezed items can't go back in.
## What's inside the pocket isn't shown.
##
## When the stash is full, the pocket turns red while you hover an ingredient
## over it, and letting go shows a "stash is full" message above the pocket.
## The ingredient goes back to the shelf.
##
## Set this node's Texture to your pocket/bag picture.

## Sent each time something is stashed.
signal item_stashed(ingredient_name: String)

## The message shown when you try to stash something while it's full.
@export var full_text: String = "Your stash is full!"
## How long the message stays on screen, in seconds.
@export var full_message_time: float = 2.0
## Pocket tint while hovering an ingredient over it when it's full.
@export var full_color: Color = Color(1.3, 0.6, 0.6)
## Optional: plays when you try to stash something while it's full.
@export var full_sound: AudioStream
## Size of the message text.
@export var full_font_size: int = 26
## Optional font for the message.
@export var full_font: Font

var _hovering_while_full := false  # a shelf item is over the pocket, and it's full
var _message: Label
var _message_tween: Tween
var _sound_player: AudioStreamPlayer


func _ready() -> void:
	super()
	# Hide the old icon row if the scene still has one.
	var old_icons := get_node_or_null("StashedItems")
	if old_icons:
		old_icons.visible = false
	mouse_exited.connect(func(): _hovering_while_full = false)
	_build_message()


## The message box, made in code. top_level so it isn't tinted or squished
## along with the pocket.
func _build_message() -> void:
	_message = Label.new()
	_message.top_level = true
	_message.visible = false
	_message.z_index = 10
	MinigameStyle.style_hint(_message, full_font, full_font_size)
	MinigameStyle.set_banner_color(_message, Color(0.55, 0.08, 0.06, 0.85))
	add_child(_message)
	_sound_player = AudioStreamPlayer.new()
	add_child(_sound_player)


## Only whole ingredients dragged from the shelf, and only while there's room.
func can_accept(data: Dictionary) -> bool:
	return data["from"] == "shelf" and not GameManager.is_stash_full()


## Same as DropTarget, but remembers when a shelf item hovers while the stash
## is full, and tints the pocket red so the player sees it won't fit.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var ok := super(at_position, data)
	_hovering_while_full = not ok \
		and data is Dictionary \
		and data.get("type") == "ingredient" \
		and data.get("from") == "shelf" \
		and GameManager.is_stash_full()
	if _hovering_while_full:
		modulate = full_color
	return ok


## Saves it in the stash. The shelf removes it from the kitchen by itself.
func on_drop(data: Dictionary) -> void:
	GameManager.stash_item(data["name"])
	item_stashed.emit(data["name"])


## When a drag ends: if it was let go on the pocket while it was full, the
## drop didn't happen, so show the message.
func _notification(what: int) -> void:
	super(what)
	if what != NOTIFICATION_DRAG_END:
		return
	var let_go_here := get_global_rect().has_point(get_global_mouse_position())
	if _hovering_while_full and let_go_here and not get_viewport().gui_is_drag_successful():
		_show_full_message()
	_hovering_while_full = false


## Shows the "stash is full" message above the pocket, then fades it out.
func _show_full_message() -> void:
	_message.text = full_text
	_message.reset_size()
	var rect := get_global_rect()
	_message.global_position = Vector2(
		rect.position.x + (rect.size.x - _message.size.x) / 2.0,
		rect.position.y - _message.size.y - 8.0)
	if _message.global_position.y < 0.0:  # no room above: put it below instead
		_message.global_position.y = rect.end.y + 8.0
	_message.visible = true
	_message.modulate.a = 1.0
	_message.pivot_offset = _message.size / 2.0
	_message.scale = Vector2(1.15, 1.15)

	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.tween_interval(full_message_time)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
	_message_tween.tween_callback(func(): _message.visible = false)

	# A little shake on the pocket.
	pivot_offset = size / 2.0
	var shake := create_tween()
	for i in 2:
		shake.tween_property(self, "rotation", 0.06, 0.05)
		shake.tween_property(self, "rotation", -0.06, 0.05)
	shake.tween_property(self, "rotation", 0.0, 0.05)

	if full_sound:
		_sound_player.stream = full_sound
		_sound_player.play()
