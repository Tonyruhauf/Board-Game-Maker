extends Control


@onready var hotseat_manager: HotseatManager = HotseatManager.new()

@export var game: GameInfo

var game_instance: BoardGame


func _ready() -> void:
	if not game: return
	
	var match_state: MatchState = await hotseat_manager.create_hotseat_match([
		"Player A",
		"Player B"
	])
	
	game_instance = game.game_scene.instantiate()
	add_child(game_instance)
	
	game_instance.hotseat_mode = true
	game_instance.setup(match_state)
	game_instance.start()
