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

## Emitted when a database change (INSERT, UPDATE, DELETE) is received.[br]
## [param data] is the raw "data" object from the server. The row is in
## [code]data.record[/code] (and [code]data.old_record[/code]), NOT "new"/"old".
signal postgres_changes_received(room: String, table: String, event_type: String, data: Dictionary)

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

## Automatically rejoin a channel (with backoff) after a channel error/close.
@export var auto_rejoin: bool = true
@export var max_rejoin_delay: float = 30.0

## Print every incoming packet and system message.
@export var debug_log: bool = false

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

## Rooms whose join config changed this frame. Flushed once per frame so that
## join_channel() + subscribe_to_table() calls produce ONE phx_join, not several.
var _pending_joins: Dictionary = {}

## room_name -> {
##   "private": bool, "receive_own": bool, "join_ref": String, "joined": bool,
##   "postgres_changes": Array, "retry_timer": float, "retry_attempts": int
## }
var _channels: Dictionary = {}


func _ready() -> void:
	# Default inbound buffer is 64 KB; large payloads (e.g. a big jsonb column)
	# can otherwise drop the connection.
	socket.inbound_buffer_size = 1 << 20
	socket.outbound_buffer_size = 1 << 18
	socket.max_queued_packets = 4096


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

			_flush_pending_joins()
			_tick_retries(delta)

		WebSocketPeer.STATE_CLOSED:
			if _is_connected or _connecting:
				_on_closed()


# --- Public API ---

## Connects to the Supabase Realtime WebSocket server.[br]
## [param custom_access_token]: the signed-in user's JWT. Without it you are
## the "anon" role and RLS will silently filter out most rows.
func connect_realtime(custom_access_token: String = "") -> Error:
	if supabase_url.is_empty() or supabase_key.is_empty():
		push_error("SupabaseRealtime: supabase_url and supabase_key must be set.")
		return ERR_UNCONFIGURED

	_wants_connection = true
	_reconnect_attempts = 0
	_reconnect_timer = -1.0

	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING:
			# Already open: push the new token instead of just storing it.
			if custom_access_token != "" and custom_access_token != _access_token:
				set_access_token(custom_access_token)
			return OK
		WebSocketPeer.STATE_CLOSING:
			_access_token = custom_access_token
			return ERR_BUSY

	_access_token = custom_access_token
	return _open_socket()


## Closes the connection and disables auto-reconnect.
func disconnect_realtime() -> void:
	_wants_connection = false
	_reconnect_timer = -1.0
	socket.close()


## Updates the JWT. Channels with table subscriptions are re-joined (so the
## server re-evaluates RLS with the new identity); other joined channels just
## receive an access_token push. Call this on every token refresh.
func set_access_token(token: String) -> void:
	_access_token = token
	if not _is_connected:
		return
	var auth_token := token if token != "" else supabase_key
	for room_name in _channels:
		var ch: Dictionary = _channels[room_name]
		if not ch["postgres_changes"].is_empty():
			_pending_joins[room_name] = true
		elif ch["joined"]:
			_send_json([ch["join_ref"], str(_get_next_ref()), TOPIC_PREFIX + room_name,
				"access_token", {"access_token": auth_token}])
		else:
			_pending_joins[room_name] = true


## Joins a broadcast channel (topic).[br]
## [param private] and [param receive_own] only change the existing config
## when you pass them explicitly.
func join_channel(room_name: String, private: Variant = null, receive_own: Variant = null) -> void:
	var ch := _get_or_create_channel(room_name)
	var changed := false

	if private != null and ch["private"] != bool(private):
		ch["private"] = bool(private)
		changed = true
	if receive_own != null and ch["receive_own"] != bool(receive_own):
		ch["receive_own"] = bool(receive_own)
		changed = true

	if _is_connected and (changed or ch["join_ref"] == ""):
		_pending_joins[room_name] = true


## Subscribes to database table changes (Postgres Changes) over a channel topic.[br]
## Duplicate subscriptions are ignored. Multiple calls in the same frame result
## in a single join. Best practice: register all tables before connecting.[br]
## [param room_name]: The channel/room name.[br]
## [param table]: Database table to watch (e.g., "invites").[br]
## [param filter]: Optional row filter (e.g., "recipient=eq.SOME_UUID").[br]
## [param event]: "INSERT", "UPDATE", "DELETE", or "*".[br]
## [param schema]: Database schema (default is "public").[br]
## [param private]: Whether the channel requires authorization (only applied if true).
func subscribe_to_table(
	room_name: String,
	table: String,
	filter: String = "",
	event: String = "INSERT",
	schema: String = "public",
	private: bool = false
) -> void:
	var ch := _get_or_create_channel(room_name)

	var change_config := {
		"event": event,
		"schema": schema,
		"table": table,
	}
	if not filter.is_empty():
		change_config["filter"] = filter

	var changes: Array = ch["postgres_changes"]
	if change_config in changes:
		return  # exact duplicate, nothing to do
	changes.append(change_config)

	if private and not ch["private"]:
		ch["private"] = true

	if _is_connected:
		_pending_joins[room_name] = true


## Broadcasts a message to other clients listening on that channel.[br]
func send_broadcast(room_name: String, event_name: String, data: Dictionary) -> void:
	var ch: Dictionary = _channels.get(room_name, {})
	if ch.is_empty() or not ch["joined"] or not _is_connected:
		push_warning("SupabaseRealtime: can't broadcast to '%s' (not connected or not joined)." % room_name)
		return

	_send_json([
		ch["join_ref"],
		str(_get_next_ref()),
		TOPIC_PREFIX + room_name,
		"broadcast",
		{"type": "broadcast", "event": event_name, "payload": data},
	])


## Leaves an active channel room.[br]
func leave_channel(room_name: String) -> void:
	var ch: Dictionary = _channels.get(room_name, {})
	if ch.is_empty():
		return
	if _is_connected and ch["join_ref"] != "":
		_send_json([ch["join_ref"], str(_get_next_ref()), TOPIC_PREFIX + room_name, "phx_leave", {}])
	_pending_joins.erase(room_name)
	_channels.erase(room_name)


## True if the server confirmed the join for this room.
func is_channel_joined(room_name: String) -> bool:
	var ch: Dictionary = _channels.get(room_name, {})
	return not ch.is_empty() and ch["joined"]


func _exit_tree() -> void:
	_wants_connection = false
	socket.close()


# --- Internal Helpers ---

func _get_or_create_channel(room_name: String) -> Dictionary:
	if not _channels.has(room_name):
		_channels[room_name] = {
			"private": false,
			"receive_own": false,
			"join_ref": "",
			"joined": false,
			"postgres_changes": [],
			"retry_timer": -1.0,
			"retry_attempts": 0,
		}
	return _channels[room_name]


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
		_pending_joins[room_name] = true
	_flush_pending_joins()


func _on_closed() -> void:
	var was_connected := _is_connected
	_is_connected = false
	_connecting = false
	_pending_heartbeat_ref = ""
	_pending_joins.clear()
	for room_name in _channels:
		var ch: Dictionary = _channels[room_name]
		ch["joined"] = false
		ch["join_ref"] = ""  # old joins died with the socket
		ch["retry_timer"] = -1.0
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


## Sends one phx_join per room that changed, leaving the old join first.
func _flush_pending_joins() -> void:
	if _pending_joins.is_empty() or not _is_connected:
		return
	var rooms := _pending_joins.keys()
	_pending_joins.clear()
	for room_name in rooms:
		if _channels.has(room_name):
			_rejoin(room_name)


func _rejoin(room_name: String) -> void:
	var ch: Dictionary = _channels[room_name]
	if ch["join_ref"] != "":
		_send_json([ch["join_ref"], str(_get_next_ref()), TOPIC_PREFIX + room_name, "phx_leave", {}])
	_send_join(room_name)


func _send_join(room_name: String) -> void:
	var ch: Dictionary = _channels[room_name]
	var join_ref := str(_get_next_ref())
	ch["join_ref"] = join_ref
	ch["joined"] = false
	ch["retry_timer"] = -1.0

	var payload := {
		"config": {
			"broadcast": {"ack": false, "self": ch["receive_own"]},
			"presence": {"key": ""},
			"postgres_changes": ch["postgres_changes"],
			"private": ch["private"],
		},
		"access_token": _access_token if _access_token != "" else supabase_key,
	}
	if debug_log:
		print("RT -> join ", room_name, " ref=", join_ref, " changes=", ch["postgres_changes"],
			" authenticated=", _access_token != "")

	_send_json([join_ref, join_ref, TOPIC_PREFIX + room_name, "phx_join", payload])


func _schedule_rejoin(room_name: String) -> void:
	if not auto_rejoin:
		return
	var ch: Dictionary = _channels.get(room_name, {})
	if ch.is_empty():
		return
	var delay := minf(pow(2.0, ch["retry_attempts"]), max_rejoin_delay)
	ch["retry_attempts"] += 1
	ch["retry_timer"] = delay
	if debug_log:
		print("Rejoining '%s' in %.0fs." % [room_name, delay])


func _tick_retries(delta: float) -> void:
	for room_name in _channels:
		var ch: Dictionary = _channels[room_name]
		if ch["retry_timer"] < 0.0:
			continue
		ch["retry_timer"] -= delta
		if ch["retry_timer"] < 0.0:
			ch["retry_timer"] = -1.0
			_pending_joins[room_name] = true


func _send_json(data: Array) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))


func _send_heartbeat() -> void:
	if _pending_heartbeat_ref != "":
		push_warning("SupabaseRealtime: heartbeat timeout, closing socket.")
		socket.close()
		return
	_pending_heartbeat_ref = str(_get_next_ref())
	_send_json([null, _pending_heartbeat_ref, "phoenix", "heartbeat", {}])


func _handle_packet(json_text: String) -> void:
	if debug_log:
		print("RT <- ", json_text)

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return

	var data: Variant = json.get_data()
	if not (data is Array and data.size() >= 5):
		return

	var msg_join_ref: String = str(data[0]) if data[0] != null else ""
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

		"postgres_changes":
			if payload is Dictionary and payload.has("data"):
				var change: Dictionary = payload["data"]
				var table_name: String = str(change.get("table", ""))
				var event_type: String = str(change.get("type", ""))
				postgres_changes_received.emit(room, table_name, event_type, change)

		"system":
			if payload is Dictionary:
				if debug_log or payload.get("status", "") == "error":
					print("Realtime system [%s]: %s" % [room, JSON.stringify(payload)])
				if payload.get("status", "") == "error":
					channel_error.emit(room, str(payload.get("message", "system error")))

		"phx_reply":
			if topic == "phoenix":
				if ref == _pending_heartbeat_ref:
					_pending_heartbeat_ref = ""
				return
			var ch: Dictionary = _channels.get(room, {})
			if ch.is_empty() or ch["join_ref"] != ref or not payload is Dictionary:
				return  # reply to a leave or to a stale join
			if payload.get("status", "") == "ok":
				ch["joined"] = true
				ch["retry_attempts"] = 0
				channel_joined.emit(room)
			else:
				ch["joined"] = false
				ch["join_ref"] = ""
				channel_error.emit(room, JSON.stringify(payload.get("response", {})))
				_schedule_rejoin(room)

		"phx_error", "phx_close":
			var ch: Dictionary = _channels.get(room, {})
			if ch.is_empty():
				return
			# A close for an OLD join (e.g. replaced by a re-join) must not
			# flip the healthy new channel to "not joined".
			if msg_join_ref != "" and msg_join_ref != ch["join_ref"]:
				return
			ch["joined"] = false
			ch["join_ref"] = ""
			channel_error.emit(room, event)
			_schedule_rejoin(room)
