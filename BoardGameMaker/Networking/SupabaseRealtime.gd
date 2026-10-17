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

## Emitted when the server confirms a channel join.
signal channel_joined(room: String)

## Emitted when a channel join fails or the channel errors/closes.
signal channel_error(room: String, reason: String)

const TOPIC_PREFIX := "realtime:"
const HEARTBEAT_INTERVAL := 25.0

@export var supabase_url: String = "https://vescafepxaxywnqcqmpi.supabase.co"
@export var supabase_key: String = "sb_publishable_NBTPNpfnEhGqQwDZ-5_vQw_JSpmdUw1"

## Automatically reconnect (with exponential backoff) and rejoin channels.
@export var auto_reconnect: bool = true
@export var max_reconnect_delay: float = 30.0

var socket := WebSocketPeer.new()

var _ref_counter: int = 0
var _heartbeat_timer: float = 0.0
var _pending_heartbeat_ref: String = ""
var _is_connected: bool = false
var _connecting: bool = false
var _wants_connection: bool = false
var _access_token: String = ""
var _reconnect_attempts: int = 0
var _reconnect_timer: float = -1.0

## room_name -> { "private": bool, "receive_own": bool, "join_ref": String, "joined": bool }
var _channels: Dictionary = {}


func _process(delta: float) -> void:
	if _reconnect_timer >= 0.0:
		_reconnect_timer -= delta
		if _reconnect_timer < 0.0:
			_reconnect_timer = -1.0
			_open_socket()
		return

	socket.poll()

	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_on_opened()

			_heartbeat_timer += delta
			if _heartbeat_timer >= HEARTBEAT_INTERVAL:
				_heartbeat_timer = 0.0
				_send_heartbeat()

			while socket.get_available_packet_count() > 0:
				var packet := socket.get_packet()
				if socket.was_string_packet():
					_handle_packet(packet.get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			# Also covers a failed initial connection (never reached OPEN).
			if _is_connected or _connecting:
				_on_closed()


## Connects to the Supabase Realtime WebSocket server.[br]
## [param custom_access_token]: Optional JWT access token to authenticate private channels. Leave empty to use anonymous connection.
##
## Example Usage:[br]
## SupabaseRealtime.connect_realtime(SupabaseManager.current_access_token)
func connect_realtime(custom_access_token: String = "") -> Error:
	if supabase_url.is_empty() or supabase_key.is_empty():
		push_error("SupabaseRealtime: supabase_url and supabase_key must be set.")
		return ERR_UNCONFIGURED

	_access_token = custom_access_token
	_wants_connection = true
	_reconnect_attempts = 0
	_reconnect_timer = -1.0

	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING:
			return OK
		WebSocketPeer.STATE_CLOSING:
			return ERR_BUSY
	return _open_socket()


## Closes the connection and disables auto-reconnect. Joined channels are kept
## and will be rejoined on the next connect_realtime() call.
func disconnect_realtime() -> void:
	_wants_connection = false
	_reconnect_timer = -1.0
	socket.close()


## Updates the JWT (e.g. after a token refresh) on the live connection and all channels.
func set_access_token(token: String) -> void:
	_access_token = token
	if not _is_connected:
		return
	var auth_token := token if token != "" else supabase_key
	for room_name in _channels:
		var ch: Dictionary = _channels[room_name]
		if ch.joined:
			_send_json([ch.join_ref, str(_get_next_ref()), TOPIC_PREFIX + room_name,
				"access_token", {"access_token": auth_token}])


## Joins a specific broadcast channel (topic).[br]
## Can be called before the socket is open; the join is sent once connected.[br]
## [param room_name]: The name of the channel room (e.g., "game-room-42").[br]
## [param private]: Require authorization (RLS) for this channel.[br]
## [param receive_own]: If true, you also receive your own broadcasts.
##
## Example Usage:[br]
## SupabaseRealtime.join_channel("game-room-42")
func join_channel(room_name: String, private: bool = false, receive_own: bool = false) -> void:
	if _channels.has(room_name):
		return
	_channels[room_name] = {
		"private": private,
		"receive_own": receive_own,
		"join_ref": "",
		"joined": false,
	}
	if _is_connected:
		_send_join(room_name)


## Broadcasts a message to the other clients listening on that channel.[br]
## The channel must be joined (wait for [signal channel_joined]).[br]
## [param room_name]: The channel room name.[br]
## [param event_name]: A string identifier for the event (e.g., "player_move").[br]
## [param data]: A Dictionary containing the data you want to broadcast.
##
## Example Usage:[br]
## SupabaseRealtime.send_broadcast("game-room-42", "player_move", {"x": 100, "y": 200})
func send_broadcast(room_name: String, event_name: String, data: Dictionary) -> void:
	var ch: Dictionary = _channels.get(room_name, {})
	if ch.is_empty() or not ch.joined or not _is_connected:
		push_warning("SupabaseRealtime: can't broadcast to '%s' (not connected or not joined)." % room_name)
		return

	_send_json([
		ch.join_ref,
		str(_get_next_ref()),
		TOPIC_PREFIX + room_name,
		"broadcast",
		{"type": "broadcast", "event": event_name, "payload": data},
	])


## Leaves an active channel room.[br]
## [param room_name]: The name of the channel to leave.[br]
##
## Example Usage:[br]
## SupabaseRealtime.leave_channel("game-room-42")
func leave_channel(room_name: String) -> void:
	var ch: Dictionary = _channels.get(room_name, {})
	if ch.is_empty():
		return
	if _is_connected and ch.join_ref != "":
		_send_json([ch.join_ref, str(_get_next_ref()), TOPIC_PREFIX + room_name, "phx_leave", {}])
	_channels.erase(room_name)


func _exit_tree() -> void:
	_wants_connection = false
	socket.close()


# --- Internal Helpers ---

func _open_socket() -> Error:
	var ws_base := supabase_url.trim_suffix("/").replace("https://", "wss://").replace("http://", "ws://")
	var url := "%s/realtime/v1/websocket?apikey=%s&vsn=2.0.0" % [ws_base, supabase_key.uri_encode()]

	print("Connecting to Realtime.")
	var err := socket.connect_to_url(url)
	if err != OK:
		push_error("SupabaseRealtime: connect_to_url failed (%s)." % error_string(err))
		_connecting = false
		_schedule_reconnect()
		return err
	_connecting = true
	return OK


func _on_opened() -> void:
	_is_connected = true
	_connecting = false
	_reconnect_attempts = 0
	_heartbeat_timer = 0.0
	_pending_heartbeat_ref = ""
	connected.emit()
	print("Realtime WebSocket Connected!")
	for room_name in _channels:
		_send_join(room_name)


func _on_closed() -> void:
	var was_connected := _is_connected
	_is_connected = false
	_connecting = false
	_pending_heartbeat_ref = ""
	for room_name in _channels:
		_channels[room_name].joined = false
	if was_connected:
		disconnected.emit()
		print("Realtime WebSocket Disconnected (code %d)." % socket.get_close_code())
	_schedule_reconnect()


func _schedule_reconnect() -> void:
	if not (_wants_connection and auto_reconnect):
		return
	var delay := minf(pow(2.0, _reconnect_attempts), max_reconnect_delay)
	_reconnect_attempts += 1
	_reconnect_timer = delay
	print("Reconnecting to Realtime in %.0fs." % delay)


func _get_next_ref() -> int:
	_ref_counter += 1
	return _ref_counter


func _send_join(room_name: String) -> void:
	var ch: Dictionary = _channels[room_name]
	var join_ref := str(_get_next_ref())
	ch.join_ref = join_ref
	ch.joined = false
	_send_json([
		join_ref,
		join_ref,
		TOPIC_PREFIX + room_name,
		"phx_join",
		{
			"config": {
				"broadcast": {"ack": false, "self": ch.receive_own},
				"presence": {"key": ""},
				"postgres_changes": [],
				"private": ch.private,
			},
			"access_token": _access_token if _access_token != "" else supabase_key,
		},
	])


func _send_json(data: Array) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))


func _send_heartbeat() -> void:
	if _pending_heartbeat_ref != "":
		# Previous heartbeat was never answered: connection is dead.
		push_warning("SupabaseRealtime: heartbeat timeout, closing socket.")
		socket.close()
		return
	_pending_heartbeat_ref = str(_get_next_ref())
	_send_json([null, _pending_heartbeat_ref, "phoenix", "heartbeat", {}])


func _handle_packet(json_text: String) -> void:
	print("RT <- ", json_text)
	
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return

	var data: Variant = json.get_data()
	if not (data is Array and data.size() >= 5):
		return

	var ref: String = str(data[1]) if data[1] != null else ""
	var topic: String = str(data[2]) if data[2] != null else ""
	var event: String = str(data[3]) if data[3] != null else ""
	var payload: Variant = data[4]
	var room := topic.trim_prefix(TOPIC_PREFIX)

	match event:
		"broadcast":
			if payload is Dictionary:
				var inner_event: String = str(payload.get("event", ""))
				var inner_payload: Variant = payload.get("payload", {})
				if inner_payload is Dictionary:
					message_received.emit(room, inner_event, inner_payload)

		"phx_reply":
			if topic == "phoenix":
				if ref == _pending_heartbeat_ref:
					_pending_heartbeat_ref = ""
				return
			var ch: Dictionary = _channels.get(room, {})
			if ch.is_empty() or ch.join_ref != ref or not payload is Dictionary:
				return
			if payload.get("status", "") == "ok":
				ch.joined = true
				channel_joined.emit(room)
			else:
				channel_error.emit(room, JSON.stringify(payload.get("response", {})))

		"phx_error", "phx_close":
			if _channels.has(room):
				_channels[room].joined = false
				channel_error.emit(room, event)
