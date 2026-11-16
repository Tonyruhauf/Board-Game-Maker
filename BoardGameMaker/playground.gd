extends Control


@onready var hotseat_manager: HotseatManager = HotseatManager.new()

@export var game_info: GameInfo


func _ready() -> void:
	if not game_info: return
	
	var match_state: MatchState = await hotseat_manager.create_hotseat_match([
		"Player A",
		"Player B"
	])
	
	var game: BoardGame = game_info.game_class.new()
	var board: Board = game_info.board_scene.instantiate()
	
	GameService.game = game
	GameService.board = board
	
	add_child(board)
	
	game.hotseat_mode = true
	game.setup(match_state)
	game.start()
