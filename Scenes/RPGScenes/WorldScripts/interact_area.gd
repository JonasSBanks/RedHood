extends Area2D

#customizable interact prompt
@export var prompt_message: String = "Interact"

#behavior of interaction
#will be overriden
func interact(player: CharacterBody2D) -> void :
	print("interacted with: ", owner.name)
