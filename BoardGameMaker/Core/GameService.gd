extends Node


func get_player_profile() -> Dictionary:
	var result = await SupabaseManager.select("player_profiles", "select=*&limit=1", true)
	
	if result.code == 200 and result.data is Array and not result.data.is_empty():
		return result.data[0]
	return {}


func get_player_by_username(username: String) -> Dictionary:
	var encoded_username = username.uri_encode()
	var query = "select=*&username=eq.%s&limit=1" % encoded_username
	var result = await SupabaseManager.select("player_profiles", query)
	return result


func try_update_player_username(new_username: String) -> bool:
	var result = await SupabaseManager.update(
		"player_profiles",
		"",
		{"username": new_username}
	)
	
	return (result.code == 200)
