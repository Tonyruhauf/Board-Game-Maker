extends Node


@export var supabase_url: String = "https://vescafepxaxywnqcqmpi.supabase.co"
@export var supabase_key: String = "sb_publishable_NBTPNpfnEhGqQwDZ-5_vQw_JSpmdUw1"

# Holds the JWT access token of the currently logged-in user
var current_access_token: String = ""


# Set this after a successful sign-in/sign-up
func set_session(access_token: String) -> void:
	current_access_token = access_token


# Clear this on logout
func clear_session() -> void:
	current_access_token = ""


# Generic request helper managing dynamic HTTPRequests with optional token support
func _make_request(url: String, method: HTTPClient.Method, body: String = "", custom_token: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	
	var bearer_token = custom_token if custom_token != "" else (current_access_token if current_access_token != "" else supabase_key)
	
	var headers = PackedStringArray([
		"apikey: " + supabase_key,
		"Authorization: Bearer " + bearer_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	])
	
	var error = http.request(url, headers, method, body)
	if error != OK:
		http.queue_free()
		return {"code": 0, "data": null, "error": "Failed to start HTTP request"}
		
	var response = await http.request_completed
	http.queue_free()
	
	var result: int = response[0]
	var response_code: int = response[1]
	var raw_data: PackedByteArray = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": response_code, "data": null, "error": "Request failed with result code: %d" % result}
		
	var json_text = raw_data.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(json_text)
	
	var parsed_output = []
	if parse_error == OK:
		parsed_output = json.get_data()
	else:
		parsed_output = json_text
		
	# Check if the server returned an error status code (400, 401, 500, etc.)
	var error_message = ""
	if response_code >= 400:
		if typeof(parsed_output) == TYPE_DICTIONARY:
			# Supabase typically returns errors with 'error_description', 'message', or 'error'
			if parsed_output.has("error_description"):
				error_message = parsed_output["error_description"]
			elif parsed_output.has("message"):
				error_message = parsed_output["message"]
			elif parsed_output.has("error"):
				error_message = str(parsed_output["error"])
			else:
				error_message = "HTTP Error %d" % response_code
		else:
			error_message = "HTTP Error %d: %s" % [response_code, json_text]
		
	return {
		"code": response_code,
		"data": parsed_output if response_code < 400 else null,
		"error": error_message
	}


# --- Database Operations ---

## SELECT (pass filter_by_user = true to automatically target current user)
func select(table: String, query_params: String = "", filter_by_user: bool = false) -> Dictionary:
	var query_string = _build_query_string(query_params, filter_by_user)
	var url = "%s/rest/v1/%s%s" % [supabase_url, table, query_string]
	return await _make_request(url, HTTPClient.METHOD_GET)


func insert(table: String, data: Dictionary) -> Dictionary:
	var url = "%s/rest/v1/%s" % [supabase_url, table]
	return await _make_request(url, HTTPClient.METHOD_POST, JSON.stringify(data))


## UPDATE (defaults to filter_by_user = true for safety)
func update(table: String, query_params: String, data: Dictionary, filter_by_user: bool = true) -> Dictionary:
	var query_string = _build_query_string(query_params, filter_by_user)
	var url = "%s/rest/v1/%s%s" % [supabase_url, table, query_string]
	return await _make_request(url, HTTPClient.METHOD_PATCH, JSON.stringify(data))


## DELETE (defaults to filter_by_user = true for safety)
func delete(table: String, query_params: String, filter_by_user: bool = true) -> Dictionary:
	var query_string = _build_query_string(query_params, filter_by_user)
	var url = "%s/rest/v1/%s%s" % [supabase_url, table, query_string]
	return await _make_request(url, HTTPClient.METHOD_DELETE)


# --- Built-in Auth Helper (Sign In) ---

func sign_in(email: String, password: String) -> Dictionary:
	var url = "%s/auth/v1/token?grant_type=password" % [supabase_url]
	var payload = {"email": email, "password": password}
	
	# Auth endpoints use the anon key explicitly for authorization
	var res = await _make_request(url, HTTPClient.METHOD_POST, JSON.stringify(payload), supabase_key)
	
	if res.code == 200 and typeof(res.data) == TYPE_DICTIONARY and res.data.has("access_token"):
		set_session(res.data["access_token"])
		
	return res


## **SIGN UP NEW USER**
## Example: var res = await SupabaseManager.sign_up("player@example.com", "securepassword123")
func sign_up(email: String, password: String) -> Dictionary:
	var url = "%s/auth/v1/signup" % [supabase_url]
	var payload = {"email": email, "password": password}
	
	# Auth endpoints use the anon key explicitly for authorization
	var res = await _make_request(url, HTTPClient.METHOD_POST, JSON.stringify(payload), supabase_key)
	
	# Note: Depending on your Supabase project settings, sign up might require email confirmation 
	# before returning an access_token, but if email confirmations are disabled, it logs them in right away.
	if res.code == 200 and typeof(res.data) == TYPE_DICTIONARY and res.data.has("access_token"):
		set_session(res.data["access_token"])
		
	return res


func _build_query_string(query_params: String, filter_by_user: bool) -> String:
	var final_params = query_params.strip_edges()
	
	if filter_by_user:
		var uid = _get_current_user_id()
		if uid != "":
			var user_filter = "user_id=eq." + uid
			if final_params != "":
				if not "user_id=eq." in final_params:
					final_params = user_filter + "&" + final_params
			else:
				final_params = user_filter
				
	if final_params == "":
		return ""
		
	return "?" + final_params if not final_params.begins_with("?") else final_params


## Extracts the user UUID ('sub' claim) directly from the current JWT access token
func _get_current_user_id() -> String:
	if current_access_token == "":
		return ""
		
	var parts = current_access_token.split(".")
	if parts.size() < 2:
		return ""
		
	# Convert Base64URL to standard Base64 format for Godot's Marshalls
	var payload_b64 = parts[1].replace("-", "+").replace("_", "/")
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
		
	var json_str = Marshalls.base64_to_utf8(payload_b64)
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("sub"):
			return data["sub"]
			
	return ""
