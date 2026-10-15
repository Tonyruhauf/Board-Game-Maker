extends Node

signal connected
signal disconnected
signal message_received(topic: String, event: String, payload: Dictionary)

@export var supabase_url: String = "https://your-project-id.supabase.co"
@export var supabase_key: String = "your-anon-key-here"

var socket := WebSocketPeer.new()
var _ref_counter: int = 0
var _heartbeat_timer: float = 0.0
var _is_connected: bool = false
var _joined_topics: Array[String] = []

func _process(delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			_is_connected = true
			emit_signal("connected")
			print("Realtime WebSocket Connected!")
			
		# Send heartbeat every 30 seconds to keep connection alive
		_heartbeat_timer += delta
		if _heartbeat_timer >= 30.0:
			_heartbeat_timer = 0.0
			_send_heartbeat()
			
		# Read incoming packets
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			_handle_packet(packet.get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
		if _is_connected:
			_is_connected = false
			emit_signal("disconnected")
			print("Realtime WebSocket Disconnected.")

## Connects to Supabase Realtime WebSocket server
func connect_realtime(custom_access_token: String = "") -> void:
	var ws_base = supabase_url.replace("https://", "wss://").replace("http://", "ws://")
	var url = "%s/realtime/v1/websocket?apikey=%s&v=10" % [ws_base, supabase_key]
	
	if custom_access_token != "":
		url += "&access_token=" + custom_access_token
		
	print("Connecting to Realtime: ", url)
	socket.connect_to_url(url)

## Joins a specific broadcast channel (topic)
## Example: SupabaseRealtime.join_channel("room-1")
func join_channel(topic_name: String) -> void:
	var topic = "realtime:" + topic_name
	var ref = str(_get_next_ref())
	
	# Phoenix Protocol format: [join_ref, ref, topic, event, payload]
	var payload = [
		ref, 
		ref, 
		topic, 
		"phx_join", 
		{
			"config": {
				"broadcast": { "ack": false, "self": true },
				"presence": { "key": "" },
				"private": false
			}
		}
	]
	
	_send_json(payload)
	if not topic in _joined_topics:
		_joined_topics.append(topic)
	print("Joined channel: ", topic_name)

## Broadcasts a message to all other clients listening on that channel
## Example: SupabaseRealtime.send_broadcast("room-1", "player_move", {"x": 100, "y": 200})
func send_broadcast(topic_name: String, event_name: String, data: Dictionary) -> void:
	var topic = "realtime:" + topic_name
	var ref = str(_get_next_ref())
	
	var payload = [
		null,
		ref,
		topic,
		"broadcast",
		{
			"type": "broadcast",
			"event": event_name,
			"payload": data
		}
	]
	
	_send_json(payload)

## Leaves a channel
func leave_channel(topic_name: String) -> void:
	var topic = "realtime:" + topic_name
	var ref = str(_get_next_ref())
	var payload = [ref, ref, topic, "phx_leave", {}]
	_send_json(payload)
	_joined_topics.erase(topic)

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
	# Phoenix messages arrive as arrays: [join_ref, ref, topic, event, payload]
	if data is Array and data.size() >= 5:
		var topic: String = data[2]
		var event: String = data[3]
		var payload: Variant = data[4]
		
		# Clean up topic prefix for easier reading ("realtime:room-1" -> "room-1")
		var clean_topic = topic.trim_prefix("realtime:")
		
		if event == "broadcast" and payload is Dictionary:
			var inner_event = payload.get("event", "")
			var inner_payload = payload.get("payload", {})
			emit_signal("message_received", clean_topic, inner_event, inner_payload)
