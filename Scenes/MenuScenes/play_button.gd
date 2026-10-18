extends Button


## Starts day 1. GameManager sends the player to the day's first scene
## (outsideNavigable), and every later day loops back there too.
func _on_pressed() -> void:
	GameManager.start_day()
