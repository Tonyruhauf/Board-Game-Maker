
extends Node # GameService.gd


var game: BoardGame
var board: Board

var occupied_ids: Dictionary[int, Object]

var cached_players: Dictionary[String, Player] = {}
var local_player: Player

var hovered_objects: Array[BoardObject]
var held_object: BoardObject


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


# Players

func get_local_player() -> Player:
	return local_player


func set_local_player(player: Player) -> void:
	local_player = player


func register_player(player: Player) -> void:
	if player == null or player.ID.is_empty():
		return
	
	cached_players[player.ID] = player


func get_player(player_id: String) -> Player:
	return cached_players.get(player_id)


func create_player(id: String, username: String) -> Player:
	if id.is_empty():
		return null
	
	var player: Player = Player.new()
	player.ID = id
	player.username = username
	
	register_player(player)
	return player


func unregister_player(player_id: String) -> void:
	cached_players.erase(player_id)


func clear_players() -> void:
	cached_players.clear()
	local_player = null


# Object interaction

func get_held_object() -> BoardObject:
	return held_object


func set_held_object(object: BoardObject) -> void:
	held_object = object


func get_hovered_object() -> BoardObject:
	if hovered_objects.is_empty():
		return null
	
	if not is_instance_valid(hovered_objects[0]):
		return null
	
	return hovered_objects.front()


func add_object_to_hover_list(object: BoardObject) -> void:
	if not is_instance_valid(object):
		return
	
	if hovered_objects.has(object):
		return
	
	if not object.tree_exiting.is_connected(remove_object_from_hover_list):
		object.tree_exiting.connect(remove_object_from_hover_list.bind(object))
	
	hovered_objects.append(object)
	hovered_objects.sort_custom(func(a, b): return a.z_index > b.z_index)


func remove_object_from_hover_list(object: BoardObject) -> void:
	if not is_instance_valid(object):
		return
	
	var callback: Callable = remove_object_from_hover_list.bind(object)
	if object.tree_exiting.is_connected(callback):
		object.tree_exiting.disconnect(callback)
	
	hovered_objects.erase(object)
