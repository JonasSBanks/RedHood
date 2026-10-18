# game_manager.gd
extends Node

# This dictionary stores your state in RAM while the game runs
var player_data = {
	"Wolfs Bane": 0,
	"Butterfly": 0,
	"Honey": 0,
	"Mushroom": 0,
	"Fruit": 0
}

var current_recipe = {
	"Wolfs Bane": 0,
	"Butterfly": 1,
	"Honey": 1,
	"Mushroom": 1,
	"Fruit": 0
}
