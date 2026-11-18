extends Node # GameService.gd


var game: BoardGame
var board: Board

var occupied_ids: Dictionary[int, Object]

var cached_players: Dictionary[String, Player] = {}
var local_player: Player

var hovered_objects: Array[BoardObject]


func get_board_game() -> BoardGame:
	return game


func get_board() -> Board:
	return board


func get_object(id: int) -> Node:
	return occupied_ids.get(id)


func create_id(object: Object) -> int:
	var new_id: int = -1
	while new_id == -1 or occupied_ids.has(new_id):
		new_id = randi()
	occupied_ids[new_id] = object
	return new_id


func release_id(id: int) -> void:
	occupied_ids.erase(id)


func get_hovered_object() -> BoardObject:
	if hovered_objects.is_empty(): return null
	if not is_instance_valid(hovered_objects[0]): return null
	return hovered_objects.front()


func add_object_to_hover_list(object: BoardObject) -> void:
	if not is_instance_valid(object): return
	if hovered_objects.has(object): return
	
	if not object.tree_exiting.is_connected(remove_object_from_hover_list):
		object.tree_exiting.connect(remove_object_from_hover_list.bind(object))
	
	hovered_objects.append(object)
	hovered_objects.sort_custom(func(a, b): return a.z_index > b.z_index)


func remove_object_from_hover_list(object: BoardObject) -> void:
	if object.tree_exiting.is_connected(remove_object_from_hover_list):
		object.tree_exiting.disconnect(remove_object_from_hover_list.bind(object))
	
	hovered_objects.erase(object)


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
