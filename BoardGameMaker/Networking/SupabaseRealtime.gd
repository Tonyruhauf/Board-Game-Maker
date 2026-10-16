extends Node

## Emitted when the WebSocket successfully connects to Supabase Realtime.
signal connected

## Emitted when the WebSocket connection is dropped or closed.
signal disconnected

## Emitted when a broadcast message is received from any joined channel.[br]
## [param room]: The channel name (without the "realtime:" prefix).[br]
## [param event]: The custom event name sent by the broadcaster.[br]
## [param payload]: The Dictionary payload containing the message data.
signal message_received(room: String, event: String, payload: Dictionary)

@export var supabase_url: String = "https://vescafepxaxywnqcqmpi.supabase.co"
@export var supabase_key: String = "sb_publishable_NBTPNpfnEhGqQwDZ-5_vQw_JSpmdUw1"

var socket := WebSocketPeer.new()
var _ref_counter: int = 0
var _heartbeat_timer: float = 0.0
var _is_connected: bool = false
var _joined_rooms: Array[String] = []


func _process(delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			_is_connected = true
			emit_signal("connected")
			print("Realtime WebSocket Connected!")
			
		_heartbeat_timer += delta
		if _heartbeat_timer >= 30.0:
			_heartbeat_timer = 0.0
			_send_heartbeat()
			
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			_handle_packet(packet.get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
		if _is_connected:
			_is_connected = false
			emit_signal("disconnected")
			print("Realtime WebSocket Disconnected.")


## Connects to the Supabase Realtime WebSocket server.[br]
## [param custom_access_token]: Optional JWT access token to authenticate private channels. Leave empty to use anonymous connection.
##
## Example Usage:[br]
## SupabaseRealtime.connect_realtime(SupabaseManager.current_access_token)
func connect_realtime(custom_access_token: String = "") -> void:
	var ws_base = supabase_url.replace("https://", "wss://").replace("http://", "ws://")
	var url = "%s/realtime/v1/websocket?apikey=%s&v=10" % [ws_base, supabase_key]
	
	if custom_access_token != "":
		url += "&access_token=" + custom_access_token
		
	print("Connecting to Realtime: ", url)
	socket.connect_to_url(url)


## Joins a specific broadcast channel (topic).[br]
## [param room_name]: The name of the channel room (e.g., "game-room-42").
##
## Example Usage:[br]
## SupabaseRealtime.join_channel("game-room-42")
func join_channel(room_name: String, private: bool = false) -> void:
	var room = "realtime:" + room_name
	var ref = str(_get_next_ref())
	
	var payload = [
		ref, 
		ref, 
		room, 
		"phx_join", 
		{
			"config": {
				"broadcast": { "ack": false, "self": true },
				"presence": { "key": "" },
				"private": private
			}
		}
	]
	
	_send_json(payload)
	if not room in _joined_rooms:
		_joined_rooms.append(room)
	print("Joined channel: ", room_name)


## Broadcasts a message to all other clients listening on that channel.[br]
## [param room_name]: The channel room name.[br]
## [param event_name]: A string identifier for the event (e.g., "player_move").[br]
## [param data]: A Dictionary containing the data you want to broadcast.
##
## Example Usage:[br]
## SupabaseRealtime.send_broadcast("game-room-42", "player_move", {"x": 100, "y": 200})
func send_broadcast(room_name: String, event_name: String, data: Dictionary) -> void:
	var room = "realtime:" + room_name
	var ref = str(_get_next_ref())
	
	var payload = [
		null,
		ref,
		room,
		"broadcast",
		{
			"type": "broadcast",
			"event": event_name,
			"payload": data
		}
	]
	
	_send_json(payload)


## Leaves an active channel room.[br]
## [param room_name]: The name of the channel to leave.[br]
##
## Example Usage:[br]
## SupabaseRealtime.leave_channel("game-room-42")
func leave_channel(room_name: String) -> void:
	var room = "realtime:" + room_name
	var ref = str(_get_next_ref())
	var payload = [ref, ref, room, "phx_leave", {}]
	_send_json(payload)
	_joined_rooms.erase(room)


# --- Internal Helpers ---

func _get_next_ref() -> int:
	_ref_counter += 1
	return _ref_counter

func _send_json(data: Array) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func _send_heartbeat() -> void:
	var ref = str(_get_next_ref())
	var payload = [ref, ref, "phoenix", "heartbeat", {}]
	_send_json(payload)

func _handle_packet(json_text: String) -> void:
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return
		
	var data = json.get_data()
	if data is Array and data.size() >= 5:
		var topic: String = data[2]
		var event: String = data[3]
		var payload: Variant = data[4]
		
		var clean_topic = topic.trim_prefix("realtime:")
		
		if event == "broadcast" and payload is Dictionary:
			var inner_event = payload.get("event", "")
			var inner_payload = payload.get("payload", {})
			emit_signal("message_received", clean_topic, inner_event, inner_payload)
