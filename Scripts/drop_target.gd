extends TextureRect
class_name DropTarget
## Shared base for kitchen stations (pot, cutting board, pocket).
## Handles the highlight, the bounce, and the drop checks, so each station
## only has to answer two questions:
##   can_accept(data) -> will I take this item?
##   on_drop(data)    -> what do I do with it?
## Stations never move: none of them let the station itself be dragged.

@export var highlight_color: Color = Color(1.2, 1.2, 0.8)

@export_group("Drop sound")
## Plays when something is dropped on this station (optional).
## Cutting board / mortar: placing an item. Cauldron: an item going in.
@export var drop_sound: AudioStream
## Each drop's pitch varies a little so repeats don't sound identical.
@export var drop_pitch_variation: float = 0.1

var _drop_sound_player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_clear_highlight)


## Override in the station's script.
func can_accept(_data: Dictionary) -> bool:
	return false


## Override in the station's script.
func on_drop(_data: Dictionary) -> void:
	pass


## Godot calls this while something is dragged over the station.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary \
		and data.get("type") == "ingredient" \
		and can_accept(data)
	modulate = highlight_color if ok else Color.WHITE
	return ok


## Godot calls this when the player lets go over the station.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_clear_highlight()
	play_drop_sound()
	on_drop(data)
	bounce()


## Plays Drop Sound, if one is set.
func play_drop_sound() -> void:
	if not drop_sound:
		return
	if not _drop_sound_player:
		_drop_sound_player = AudioStreamPlayer.new()
		add_child(_drop_sound_player)
	_drop_sound_player.stream = drop_sound
	_drop_sound_player.pitch_scale = randf_range(1.0 - drop_pitch_variation, 1.0 + drop_pitch_variation)
	_drop_sound_player.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_highlight()


func _clear_highlight() -> void:
	modulate = Color.WHITE


## Quick squish for feedback. Changes scale only, never position.
func bounce() -> void:
	pivot_offset = size / 2.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.1, 0.9), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
