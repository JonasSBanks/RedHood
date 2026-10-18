extends DropTarget
## The cutting board. Accepts a dragged Mushroom or Bad Mushroom, shows it on the board,
## and opens the chopping minigame on top of the kitchen.
## After the minigame, the board holds the chopped version.
##
## Needs a child TextureRect called ItemOnBoard to show the ingredient.

## The ingredients that can be chopped. "Chopped " is added to the front
## after the minigame: "Bad Mushroom" -> "Chopped Bad Mushroom".
const CHOPPABLE := ["Mushroom", "Bad Mushroom"]

## The minigame scene. Drag chopping_minigame.tscn into this slot in the Inspector.
@export var minigame_scene: PackedScene

@onready var item_on_board: TextureRect = $ItemOnBoard

var _item_name: String = ""  # empty = board is empty
var _chopped := false  # true once the minigame has been beaten
var _minigame_open := false
var _dragging := false  # true while the chopped item is being dragged off


func _ready() -> void:
	super()  # runs DropTarget's _ready too
	item_on_board.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't block drops
	item_on_board.texture = null


## True when something is sitting on the board.
func has_item() -> bool:
	return _item_name != ""


## Only takes a choppable ingredient, and only when the board is empty.
func can_accept(data: Dictionary) -> bool:
	return not has_item() and data["name"] in CHOPPABLE


## Puts the ingredient on the board, then opens the minigame.
## call_deferred waits until the drag has fully finished (so the shelf has
## already removed the Mushroom) before covering the screen.
func on_drop(data: Dictionary) -> void:
	_item_name = data["name"]
	_chopped = false
	item_on_board.texture = Ingredient.get_texture(_item_name)
	_open_minigame.call_deferred()


## Creates the minigame on its own CanvasLayer, above the kitchen UI.
## The kitchen stays underneath untouched, so nothing in it resets.
func _open_minigame() -> void:
	if minigame_scene == null:
		push_error("CuttingBoard: drag chopping_minigame.tscn into Minigame Scene in the Inspector.")
		return
	_minigame_open = true

	var layer := CanvasLayer.new()
	layer.layer = 10  # higher than the kitchen's UI layer, so it covers it

	var minigame := minigame_scene.instantiate()
	minigame.item_name = _item_name
	# bind(layer) passes the layer along, so we know what to delete afterwards
	minigame.finished.connect(_on_minigame_finished.bind(layer))

	layer.add_child(minigame)
	get_tree().current_scene.add_child(layer)


## Runs when the chop is complete. Deleting the layer deletes the
## minigame with it, revealing the kitchen again. Then the item on the
## board becomes the chopped version, e.g. "Mushroom" -> "Chopped Mushroom".
func _on_minigame_finished(layer: CanvasLayer) -> void:
	layer.queue_free()
	_minigame_open = false
	_chopped = true
	_item_name = "Chopped " + _item_name
	item_on_board.texture = Ingredient.get_texture(_item_name)


## Lets the chopped item (not the board) be dragged off, e.g. to the cauldron.
## Only once it's chopped, and never while the minigame is open.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _chopped or _minigame_open:
		return null
	_dragging = true
	set_drag_preview(Ingredient.make_preview(item_on_board.texture, item_on_board.size))
	item_on_board.modulate.a = 0.4  # dim while "in hand"
	return {
		"type": "ingredient",
		"name": _item_name,
		"from": "board",
		"chopped": true,
	}


## When the drag ends: if something took the item, the board empties.
## If not, the item stays and un-dims. (DropTarget's version also runs.)
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	item_on_board.modulate.a = 1.0
	if get_viewport().gui_is_drag_successful():
		clear()


## Empties the board so it can take another Mushroom.
func clear() -> void:
	_item_name = ""
	_chopped = false
	item_on_board.texture = null
