extends Control


@onready var games_container: HFlowContainer = $VBoxContainer/ScrollContainer/MarginContainer/GamesContainer

var games: Array[GameInfo]

const GAME_CARD_SCENE: PackedScene = preload("res://BoardGameMaker/Core/Game Browser/game_card.tscn")


func _ready() -> void:
	discover_games()
	reload_games()


func discover_games() -> void:
	games = [load("res://Test/games/test_game/GameInfo.tres")]


func reload_games() -> void:
	for game_card in games_container.get_children():
		game_card.queue_free()
	
	for game in games:
		create_game_card(game)


func create_game_card(game_info: GameInfo) -> void:
	var instance = GAME_CARD_SCENE.instantiate()
	instance.game_info = game_info
	games_container.add_child(instance)
