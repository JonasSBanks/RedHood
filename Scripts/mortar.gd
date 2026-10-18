extends DropTarget
## The mortar and pestle. Accepts Wolfs Bane, Butterfly or Bad Butterfly, opens the grinding
## minigame on top of the kitchen, and afterwards shows the powder in the mortar.
##
## Set this node's Texture to mortar_final.png in the Inspector (the empty mortar).
## Needs a child TextureRect called ItemInMortar to show the ingredient.

## Ingredient -> what it becomes after grinding. The left side must match the
## names in GameManager.selected_ingredients exactly.
const POWDERS := {
	"Wolfs Bane": "Wolfsbane Powder",
	"Butterfly": "Butterfly Powder",
	"Bad Butterfly": "Bad Butterfly Powder",
}

## Powder -> picture of the mortar with that powder in it (no folder, no .png).
const MORTAR_PICTURES := {
	"Wolfsbane Powder": "mortar_powder_wolfsbane_final",
	"Butterfly Powder": "mortar_powder_butterfly_good_final",
	"Bad Butterfly Powder": "mortar_powder_butterfly_bad_final",
}

## The minigame scene. Drag grinding_minigame.tscn into this slot.
@export var minigame_scene: PackedScene

@onready var item_in_mortar: TextureRect = $ItemInMortar

var _item_name: String = ""  # empty = mortar is empty
var _ground := false         # true once the minigame has been beaten
var _minigame_open := false
var _dragging := false  # true while the powder is being dragged out
var _empty_texture: Texture2D


func _ready() -> void:
	super()  # runs DropTarget's _ready too
	item_in_mortar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # don't block drops
	item_in_mortar.texture = null
	_empty_texture = texture  # mortar_final.png, so we can reset later


## True when something is in the mortar.
func has_item() -> bool:
	return _item_name != ""


## Only takes a grindable ingredient, and only when the mortar is empty.
func can_accept(data: Dictionary) -> bool:
	return not has_item() and POWDERS.has(data["name"])


## Puts the ingredient in the mortar, then opens the minigame.
## call_deferred waits until the drag has fully finished first.
func on_drop(data: Dictionary) -> void:
	# Dropping Wolfs Bane in while Grandma watches: caught.
	if GameManager.check_caught_with(data["name"]):
		return
	_item_name = data["name"]
	_ground = false
	item_in_mortar.texture = Ingredient.get_texture(_item_name)
	_open_minigame.call_deferred()


## Creates the minigame on its own CanvasLayer, above the kitchen UI.
func _open_minigame() -> void:
	if minigame_scene == null:
		push_error("Mortar: drag grinding_minigame.tscn into Minigame Scene in the Inspector.")
		return
	_minigame_open = true

	var layer := CanvasLayer.new()
	layer.layer = 10  # higher than the kitchen's UI layer, so it covers it

	var minigame := minigame_scene.instantiate()
	minigame.item_name = _item_name
	minigame.finished.connect(_on_minigame_finished.bind(layer))

	layer.add_child(minigame)
	get_tree().current_scene.add_child(layer)


## Runs when the grinding is complete. Closes the minigame, then the mortar
## switches to its powder picture and the item becomes e.g. "Wolfsbane Powder".
func _on_minigame_finished(layer: CanvasLayer) -> void:
	layer.queue_free()
	_minigame_open = false
	# Finishing the grinding while Grandma watches: caught.
	if GameManager.check_caught_with(_item_name):
		return
	_ground = true

	_item_name = POWDERS[_item_name]
	var powder_mortar := Ingredient.load_sprite(MORTAR_PICTURES.get(_item_name, ""))
	if powder_mortar:
		texture = powder_mortar          # the mortar picture already shows the powder
		item_in_mortar.texture = null
	else:
		# No mortar picture for this powder: show the powder on its own instead.
		item_in_mortar.texture = Ingredient.get_texture(_item_name)


## Lets the powder (not the mortar) be dragged out, e.g. to the cauldron.
## Only once it's ground, and never while the minigame is open.
## The dragged picture is the powder on its own (powder_..._final.png).
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _ground or _minigame_open:
		return null
	_dragging = true
	set_drag_preview(Ingredient.make_preview(Ingredient.get_texture(_item_name), item_in_mortar.size))
	modulate.a = 0.6  # dim the mortar while the powder is "in hand"
	return {
		"type": "ingredient",
		"name": _item_name,
		"from": "mortar",
		"chopped": false,
	}


## When the drag ends: if something took the powder, the mortar empties.
## If not, it stays and un-dims. (DropTarget's version also runs.)
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	modulate.a = 1.0
	if get_viewport().gui_is_drag_successful():
		clear()


## Empties the mortar and shows mortar_final again.
func clear() -> void:
	_item_name = ""
	_ground = false
	texture = _empty_texture
	item_in_mortar.texture = null
