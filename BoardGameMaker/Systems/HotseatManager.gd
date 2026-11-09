class_name HotseatManager extends Node


func create_hotseat_match(player_names: Array[String]) -> MatchState:
	var match_state: MatchState = MatchState.new()
	
	for i in range(player_names.size()):
		var player: Player = Player.new().\
			set_ID(str(i)).\
			set_username(player_names[i])
		GameService.cached_players[player.ID] = player
		match_state.joined_players.append(player.ID)
	
	GameService.local_player = await GameService.get_player("0")
	match_state.host_id = GameService.local_player.ID
	
	return match_state
