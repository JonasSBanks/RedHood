extends DropTarget
## The squeeze spot above the cauldron. Drop Honey or Fruit here: it squishes
## a few times, switches to its pouring/squeezed picture, drips down, and goes
## into the cauldron.
##
## Anything else dropped here is passed straight to the cauldron, as if the
## spot weren't there.
##
## This node is a TextureRect with no texture (an invisible drop zone).
## Give it a size in the Inspector so it has an area to drop on.
## Needs a child TextureRect called SqueezeItem to show the item being squeezed.

## The cauldron this spot drips into. Drag your Cauldron node into this slot.
@export var cauldron: Node
## Pictures shown after the squishes, while it drips. Drag your PNGs in here.
@export var honey_pouring_texture: Texture2D
@export var plum_squeezed_texture: Texture2D
## How many squishes before it pours.
@export var squeezes: int = 3
## How far down it drips toward the cauldron, in pixels.
@export var drip_distance: float = 80.0

@onready var squeeze_item: TextureRect = $SqueezeItem

var _busy := false  # true while an item is being squeezed
var _item_start_position: Vector2


func _ready() -> void:
	super()  # runs DropTarget's _ready too
	squeeze_item.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't block drops
	squeeze_item.texture = null
	_item_start_position = squeeze_item.position
	# If the cauldron lit up because of a hand-off from here, un-light it
	# when the mouse leaves the spot.
	mouse_exited.connect(func(): if cauldron: cauldron._clear_highlight())


## True for Honey and Fruit.
func _is_squeezable(data: Variant) -> bool:
	return data is Dictionary \
		and data.get("type") == "ingredient" \
		and cauldron != null \
		and data["name"] in cauldron.SQUEEZE_ONLY


## Honey/Fruit: the spot's own check (below). Anything else: ask the cauldron.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if cauldron != null and data is Dictionary and not _is_squeezable(data):
		modulate = Color.WHITE
		return cauldron._can_drop_data(at_position, data)
	return super(at_position, data)


## Honey/Fruit: squeeze here. Anything else: drop it into the cauldron.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _is_squeezable(data):
		cauldron._drop_data(at_position, data)
		return
	super(at_position, data)


## Only when not already squeezing, and only if the cauldron still has room.
func can_accept(_data: Dictionary) -> bool:
	return not _busy and not cauldron.is_full()


func on_drop(data: Dictionary) -> void:
	_squeeze(data["name"])


## Plays the squeeze, then adds the item to the cauldron.
func _squeeze(item_name: String) -> void:
	_busy = true

	# Show the whole item at its starting spot.
	squeeze_item.texture = Ingredient.get_texture(item_name)
	squeeze_item.position = _item_start_position
	squeeze_item.scale = Vector2.ONE
	squeeze_item.modulate.a = 1.0
	squeeze_item.pivot_offset = squeeze_item.size / 2.0

	# Squish it a few times.
	var t := create_tween()
	for i in squeezes:
		t.tween_property(squeeze_item, "scale", Vector2(1.25, 0.7), 0.12)
		t.tween_property(squeeze_item, "scale", Vector2.ONE, 0.12)
	await t.finished

	# Switch to the pouring honey / squeezed fruit picture, if one is set.
	var pour_texture := _pour_texture_for(item_name)
	if pour_texture:
		squeeze_item.texture = pour_texture
		await get_tree().create_timer(0.4).timeout  # hold it so the player sees it

	# Then it drips down toward the cauldron while fading out.
	t = create_tween().set_parallel(true)
	t.tween_property(squeeze_item, "position:y", _item_start_position.y + drip_distance, 0.4)
	t.tween_property(squeeze_item, "scale", Vector2(0.3, 0.3), 0.4)
	t.tween_property(squeeze_item, "modulate:a", 0.0, 0.4)
	await t.finished

	# Reset the picture and put the item in the cauldron.
	squeeze_item.texture = null
	squeeze_item.position = _item_start_position
	squeeze_item.scale = Vector2.ONE
	squeeze_item.modulate.a = 1.0
	cauldron.add_ingredient(item_name)
	_busy = false


## Which pouring/squeezed picture goes with which item.
func _pour_texture_for(item_name: String) -> Texture2D:
	match item_name:
		"Honey":
			return honey_pouring_texture
		"Fruit":
			return plum_squeezed_texture
	return null
