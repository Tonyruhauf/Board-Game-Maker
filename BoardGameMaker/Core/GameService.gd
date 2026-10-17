extends Node # GameService.gd


var Main: MainNode

var cached_players: Dictionary[String, Player] = {}
var local_player: Player


func register_player_in_cache(id: String, player: Player) -> void:
	if id.is_empty() or player == null:
		return
	cached_players[id] = player


func get_player(player_id: String = "", ignore_cache: bool = false) -> Player:
	# Check Cache
	if not player_id.is_empty() and cached_players.has(player_id) and not ignore_cache:
		return cached_players[player_id]
	
	# Fetch Profile from Supabase
	var profile: Dictionary = await get_player_profile(player_id)
	if profile.is_empty(): return null
	
	# Check cache again in case it was cached while we were awaiting
	if cached_players.has(profile.id) and not ignore_cache:
		return cached_players[profile.id]
	
	# Instantiate Player Resource
	var player: Player = Player.new()
	player.ID = profile.id
	player.username = profile.username
	
	# Save to Cache
	register_player_in_cache(player.ID, player)
	
	return player


func get_local_player() -> Player:
	if local_player == null:
		local_player = await get_player("", true)
	return local_player


func get_player_profile(player_id: String) -> Dictionary:
	var result: Dictionary
	
	if player_id.is_empty():
		result = await SupabaseManager.select("player_profiles", "select=*&limit=1", true)
	else:
		var query = "select=*&id=eq.%s&limit=1" % player_id
		result = await SupabaseManager.select("player_profiles", query)
	
	if result.code == 200 and result.data is Array and not result.data.is_empty():
		return result.data[0]
	return {}


func get_player_profile_by_username(username: String) -> Dictionary:
	var encoded_username = username.uri_encode()
	var query = "select=*&username=eq.%s&limit=1" % encoded_username
	var result = await SupabaseManager.select("player_profiles", query)
	
	if result.code == 200 and result.data is Array and not result.data.is_empty():
		return result.data[0]
	return {}


func get_match(match_id: String) -> Dictionary:
	var query: String = "select=*&id=eq.%s&limit=1" % match_id
	var result = await SupabaseManager.select("matches", query)
	
	if result.code == 200 and result.data is Array and not result.data.is_empty():
		return result.data[0]
	return {}


func try_update_player_username(new_username: String) -> bool:
	var player = await get_local_player()
	if player == null:
		return false
		
	var query = "id=eq.%s" % player.ID
	var result = await SupabaseManager.update(
		"player_profiles",
		query,
		{"username": new_username}
	)
	
	if result.code == 200:
		player.username = new_username
		return true
	
	return false
