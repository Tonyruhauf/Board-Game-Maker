extends Node


func get_player_profile() -> Dictionary:
	var result = await SupabaseManager.select("player_profiles", "select=*&limit=1", true)
	print(result)
	if result.code == 200 and result.data is Array and not result.data.is_empty():
		return result.data[0]
	return {}


func try_update_player_username(new_username: String) -> bool:
	var result = await SupabaseManager.update(
		"player_profiles",
		"",
		{"username": new_username}
	)
	
	return (result.code == 200)
