class_name HotseatManager extends RefCounted


static func create_match(player_names: Array[String]) -> MatchState:
	GameService.clear_players()
	
	var match_state: MatchState = MatchState.new()
	
	for i in range(player_names.size()):
		var player: Player = GameService.create_player(
			"local_%d" % i,
			player_names[i]
		)
		
		match_state.joined_players.append(player.ID)
	
	return match_state
