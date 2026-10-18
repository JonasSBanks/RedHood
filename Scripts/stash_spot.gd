extends DropTarget
## The pocket stash in the kitchen. Drag a whole ingredient from the shelf here
## to keep it for tomorrow; it's saved in GameManager.stash. (Step 13 makes
## stashed items come back the next day and throws everything else away.)
##
## Only whole ingredients from the shelf can be stashed, up to 4. Chopped,
## ground or squeezed items can't go back in the pocket.
##
## Set this node's Texture to your pocket/bag picture.
## Child node, optional:
##   StashedItems  an HBoxContainer (or GridContainer) - shows a small icon
##                 for each stashed item

## Sent each time something is stashed.
signal item_stashed(ingredient_name: String)

## How big each little icon in StashedItems is.
@export var icon_size: Vector2 = Vector2(32, 32)

@onready var stashed_items: Container = get_node_or_null("StashedItems")


func _ready() -> void:
	super()
	if stashed_items:
		stashed_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_icons()


## Only whole ingredients dragged from the shelf, and only while there's room
## (GameManager.MAX_STASH, 4).
func can_accept(data: Dictionary) -> bool:
	return data["from"] == "shelf" and not GameManager.is_stash_full()


## Saves it in the stash. The shelf removes it from the kitchen by itself.
func on_drop(data: Dictionary) -> void:
	GameManager.stash_item(data["name"])
	_refresh_icons()
	item_stashed.emit(data["name"])


## Shows one small icon per stashed item.
func _refresh_icons() -> void:
	if not stashed_items:
		return
	for child in stashed_items.get_children():
		child.queue_free()
	for item_name in GameManager.stash:
		var icon := TextureRect.new()
		icon.texture = Ingredient.get_texture(item_name)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = icon_size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stashed_items.add_child(icon)
