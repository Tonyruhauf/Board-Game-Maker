extends Control


var players: Array[Player] = [
	Player.new().setup("Tony"),
	Player.new().setup("Loïc")
]
var board_game: BoardGame

const GAME_SCENE := preload("res://Test/games/test_game/test_game.tscn")


func _ready() -> void:
	board_game = GAME_SCENE.instantiate()
	add_child(board_game)
	
	board_game.setup(players, players[0])
	board_game.start()
