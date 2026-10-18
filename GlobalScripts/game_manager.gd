# game_manager.gd
extends Node

# This dictionary stores your state in RAM while the game runs
var pocket = {
	"Wolfs Bane": 1,
	"Butterfly": 1,
	"Honey": 1,
	"Mushroom": 1,
	"Fruit": 1
}

# Tracks the keys of the ingredients the player has selected
var selected_ingredients: Array[String] = []

var current_recipe = {
	"Wolfs Bane": 0,
	"Butterfly": 0,
	"Honey": 0,
	"Mushroom": 1,
	"Fruit": 0
}
