extends Control
## The recipe book on the kitchen counter. Opens on page 1 every day (the
## kitchen loads fresh each day). Arrows flip between page 1 and page 2.
## Seeing page 2 sets GameManager.has_read_page_2. Getting caught on page 2
## takes it away again if it was first read today; once learned on an
## earlier day, it's never taken away.
##
## Grandma snatches the book (slide-and-fade, then the day ends as SNATCHED) if:
##   - the player flips a page while she's in the room, or
##   - she walks in while the book is open on page 2.
##
## Children (names must match exactly):
##   PageImage    TextureRect       - the page picture
##   NextArrow    TextureButton     - on page 1, flips to page 2 (right arrow)
##   BackArrow    TextureButton     - on page 2, flips to page 1 (left arrow)
##   SnatchSound  AudioStreamPlayer - optional, plays when she snatches it
## The pictures load by themselves from the sprites folder. If you set a
## texture in the Inspector (handy for placing things), the script keeps yours.

## Sent after the page changes.
signal page_changed(page: int)
## Sent when Grandma snatches the book (right before the day ends).
signal snatched

## How far the book slides up while being snatched, in pixels.
@export var snatch_distance: float = 200.0
## How long the snatch animation takes, in seconds.
@export var snatch_time: float = 0.6

const PAGE_PICTURES := {
	1: "book_page_one_final_no_arrow",
	2: "book_page_two_final_no_arrow",
}
const NEXT_ARROW_PICTURE := "book_arrow_final_pointing_right"
const BACK_ARROW_PICTURE := "book_arrow_final_pointing_left"

@onready var page_image: TextureRect = $PageImage
@onready var next_arrow: TextureButton = $NextArrow
@onready var back_arrow: TextureButton = $BackArrow
@onready var snatch_sound: AudioStreamPlayer = get_node_or_null("SnatchSound")

## The page currently showing (1 or 2).
var page := 1
var _snatched := false
var _read_page_2_today := false  # page 2 was first read during this visit


func _ready() -> void:
	# The page picture shouldn't catch the mouse (so drags pass over it).
	page_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not next_arrow.texture_normal:
		next_arrow.texture_normal = Ingredient.load_sprite(NEXT_ARROW_PICTURE)
	if not back_arrow.texture_normal:
		back_arrow.texture_normal = Ingredient.load_sprite(BACK_ARROW_PICTURE)
	next_arrow.pressed.connect(flip_to.bind(2))
	back_arrow.pressed.connect(flip_to.bind(1))
	_show_page(1)


## If she walks in while the book is open on page 2, she snatches it too.
## (The footsteps warning gives the player time to flip back to page 1.)
func _process(_delta: float) -> void:
	if not _snatched and page == 2 and GameManager.grandma_in_room:
		print("Book: Grandma walked in and saw page 2!")  # for testing
		_snatch()


## Turns to a page, unless Grandma is in the room: then she snatches the book.
func flip_to(new_page: int) -> void:
	if new_page == page or _snatched:
		return

	if GameManager.grandma_in_room:
		_snatch()
		return

	page = new_page
	_show_page(page)
	print("Book: turned to page ", page)  # for testing
	if page == 2 and not GameManager.has_read_page_2:
		GameManager.has_read_page_2 = true
		_read_page_2_today = true
		print("Book: page 2 has been read!")  # for testing
	elif page == 1 and _read_page_2_today:
		# Got back to page 1 safely: page 2 is learned for good.
		_read_page_2_today = false
		print("Book: got away with it, page 2 is learned for good")  # for testing
	page_changed.emit(page)


## Shows a page's picture and only the arrow that makes sense on it.
func _show_page(number: int) -> void:
	var picture := Ingredient.load_sprite(PAGE_PICTURES[number])
	if picture:
		page_image.texture = picture
	else:
		print("Missing book page picture: ", PAGE_PICTURES[number])  # for testing
	next_arrow.visible = number == 1
	back_arrow.visible = number == 2


## Grandma takes the book: arrows stop working, the book slides up and fades
## away, then the day ends as SNATCHED.
func _snatch() -> void:
	_snatched = true
	next_arrow.disabled = true
	back_arrow.disabled = true
	print("Book: SNATCHED by Grandma!")  # for testing

	# Caught on page 2: if it was first read today, it doesn't count.
	# (Learned on an earlier day? That stays.)
	if page == 2 and _read_page_2_today:
		GameManager.has_read_page_2 = false
		print("Book: caught on page 2, so it doesn't count as read")  # for testing
	if snatch_sound and snatch_sound.stream:
		snatch_sound.play()
	snatched.emit()

	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y - snatch_distance, snatch_time)
	t.tween_property(self, "modulate:a", 0.0, snatch_time)
	await t.finished
	GameManager.end_day(GameManager.Outcome.SNATCHED)
