class_name GameLauncher extends RefCounted


const COMMON_UI_SCENE: PackedScene = preload("res://BoardGameEngine/UI/Components/common_ui.tscn")


static func launch(
	game_info: GameInfo,
	match_state: MatchState,
	game_mode: BoardGame.GameMode,
	board_parent: Node
) -> BoardGame:
	
	if game_info == null or match_state == null:
		return null
	
	if match_state.joined_players.is_empty():
		return null
	
	var game: BoardGame = game_info.game_class.new()
	var board: Board = game_info.board_scene.instantiate()
	
	var common_ui: CanvasLayer = COMMON_UI_SCENE.instantiate()
	board.common_ui = common_ui
	
	game.game_mode = game_mode
	
	GameService.game = game
	GameService.board = board
	
	game.setup(match_state)
	
	board_parent.add_child(common_ui)
	board_parent.add_child(board)
	
	return game
