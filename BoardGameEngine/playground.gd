
extends Control


@export var game_info: GameInfo


func _ready() -> void:
	if not game_info:
		return
	
	var match_state: MatchState = HotseatManager.create_match([
		"Player A",
		"Player B"
	])
	
	var game: BoardGame = GameLauncher.launch(
		game_info,
		match_state,
		BoardGame.GameMode.HOTSEAT,
		self
	)
	
	if game:
		game.start()
