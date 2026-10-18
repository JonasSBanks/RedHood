extends TextureRect
## Put this on a picture (TextureRect) in a cutscene slide to flip it through
## several pictures, then make it jump. Good for a character reacting:
## e.g. Grandma tasting -> thinking -> smiling -> jumping for joy.
##
## When the slide appears:
##   1. Shows each picture in Frames, in order, Frame Time seconds apart.
##   2. Then jumps Jumps times on the last picture.
##   3. Then (if Keep Jumping is on) keeps hopping while the text shows.
## The slide's text waits until steps 1 and 2 are done.
##
## Place the picture where it stands in the editor. Don't put it in a container.

## Tells the slide this animation is done (so the text can show).
signal finished

## The pictures to switch between, in order. The first one shows right away.
@export var frames: Array[Texture2D] = []
## Seconds each picture shows before switching to the next.
@export var frame_time: float = 0.5
## Wait this long after the slide appears before starting.
@export var start_delay: float = 0.3

@export_group("Jump")
## How many times it jumps after the last picture. 0 = no jumping.
@export var jumps: int = 2
## How high each jump goes, in pixels.
@export var jump_height: float = 60.0
## How long one jump takes (up and back down), in seconds.
@export var jump_time: float = 0.4
## Keep hopping (smaller hops) after the jumps, while the text is showing.
@export var keep_jumping: bool = false

@export_group("Sounds")
## Optional: plays each time the picture switches.
@export var frame_sound: AudioStream
## Optional: plays at the start of each jump.
@export var jump_sound: AudioStream

var _start_position: Vector2
var _tween: Tween
var _sound_player: AudioStreamPlayer


func _ready() -> void:
	_start_position = position
	_sound_player = AudioStreamPlayer.new()
	add_child(_sound_player)
	if not frames.is_empty():
		texture = frames[0]


## The slide asks this to know whether to wait for it.
func finishes() -> bool:
	return true


## Called by the slide when it appears. Always starts from the beginning.
func start_move() -> void:
	if _tween:
		_tween.kill()
	position = _start_position
	scale = Vector2.ONE
	pivot_offset = Vector2(size.x / 2.0, size.y)  # squash from the feet
	if not frames.is_empty():
		texture = frames[0]

	_tween = create_tween()
	_tween.tween_interval(start_delay)
	# 1. Flip through the pictures.
	for i in range(1, frames.size()):
		_tween.tween_interval(frame_time)
		_tween.tween_callback(_show_frame.bind(i))
	if frames.size() > 1:
		_tween.tween_interval(frame_time * 0.5)  # a beat on the last picture
	# 2. Jump.
	for j in jumps:
		_add_jump(_tween, jump_height, jump_time)
	# 3. Done: let the text show, and maybe keep hopping.
	_tween.tween_callback(_done)


func _show_frame(i: int) -> void:
	texture = frames[i]
	_play(frame_sound)


## One jump: squash, spring up, fall back down, little squash on landing.
func _add_jump(t: Tween, height: float, time: float) -> void:
	var up := _start_position - Vector2(0, height)
	t.tween_callback(_play.bind(jump_sound))
	t.tween_property(self, "scale", Vector2(1.1, 0.9), time * 0.15)
	t.tween_property(self, "scale", Vector2(0.95, 1.05), time * 0.1)
	t.parallel().tween_property(self, "position", up, time * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", _start_position, time * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2.ONE, time * 0.3)
	t.tween_property(self, "scale", Vector2(1.08, 0.92), time * 0.08)
	t.tween_property(self, "scale", Vector2.ONE, time * 0.1)


func _done() -> void:
	finished.emit()
	if keep_jumping:
		_tween = create_tween().set_loops()
		_add_jump(_tween, jump_height * 0.5, jump_time * 0.8)
		_tween.tween_interval(0.3)


func _play(sound: AudioStream) -> void:
	if sound:
		_sound_player.stream = sound
		_sound_player.play()
