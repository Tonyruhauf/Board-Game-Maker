class_name GameLauncher extends RefCounted


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
	
	game.game_mode = game_mode
	
	GameService.game = game
	GameService.board = board
	
	# Add the board to the appropriate scene.
	# This assumes the launcher is called from a scene
	# with a suitable parent.
	
	game.setup(match_state)
	board_parent.add_child(board)
	
	return game
