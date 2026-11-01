extends Control

## Emitted on guests when the host stops responding or closes the lobby.
## Connect this to something that returns the player to the menu.
signal host_lost
## Emitted on a guest when joining fails (e.g. "full", "started", "unreachable").
signal join_failed(reason: String)

@onready var thumbnail: TextureRect = $VBoxContainer/Thumbnail
@onready var name_label: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/Name
@onready var description: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer2/Description
@onready var tags_container: HBoxContainer = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Tags
@onready var infos_container: HBoxContainer = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos
@onready var players_count: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos/PlayersCount
@onready var average_duration: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos/AverageDuration
@onready var play_button: Button = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer2/PlayButton
@onready var players_panel: PanelContainer = $VBoxContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel
@onready var players_count_button: OptionButton = $VBoxContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/ScrollContainer/VBoxContainer/CenterContainer/PlayersCountButton
@onready var players_container: HFlowContainer = $VBoxContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/ScrollContainer/VBoxContainer/Players
@onready var options_container: VBoxContainer = $VBoxContainer/PanelContainer/GameOptions/HBoxContainer/OptionsContainer

var Main: MainNode

@export var game_info: GameInfo

var match_state: MatchState = null
var player_slots_count: int = 0

const PLAYER_CARD_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_card.tscn")
const PLAYER_SLOT_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_slot.tscn")

const JOIN_RETRY_SECONDS := 1.0
const JOIN_MAX_ATTEMPTS := 10
const HEARTBEAT_SECONDS := 5.0
const HOST_TIMEOUT_SECONDS := 16.0
const START_BROADCAST_REPEATS := 3
const START_BROADCAST_GAP := 0.3
const DEBUG_LOG := false

# --- runtime flags (never persisted) ---
var _creating := false           # create_match() in progress
var _match_started := false      # host pressed Play (lobby is closed to joins)
var _game_started := false       # this client already launched the game scene
var _confirmed := false          # guest: host has confirmed we are in the match
var _join_aborted := false       # guest: join was rejected, stop retrying
var _last_state_msec := 0        # guest: when we last heard from the host
var _refresh_id := 0             # guards against overlapping _update_players_display()
var _persisting := false
var _persist_dirty := false
var _heartbeat_timer: Timer = null


# =====================================================================
#  LIFECYCLE
# =====================================================================

func _ready() -> void:
	update_display()


func _exit_tree() -> void:
	if SupabaseRealtime.message_received.is_connected(_on_broadcast_message_received):
		SupabaseRealtime.message_received.disconnect(_on_broadcast_message_received)

	if match_state != null and not _game_started:
		# best effort: tell the others we are gone
		if is_hosting_match():
			_send("match_closed", {})
		elif _confirmed:
			_send("player_left", {"player_id": _local_id()})

	if match_state != null:
		SupabaseRealtime.leave_channel(get_match_channel())


# =====================================================================
#  HELPERS
# =====================================================================

func _log(msg: String, data: Variant = null) -> void:
	if DEBUG_LOG:
		print("[Lobby %s] %s %s" % [_local_id(), msg, "" if data == null else str(data)])
		print("\n\n")


func _local_id() -> String:
	return GameService.local_player.ID


func get_match_channel() -> String:
	if not match_state: return ""
	return "match-%s" % match_state.match_id


func is_hosting_match() -> bool:
	if match_state == null or GameService.local_player == null:
		return false
	return GameService.local_player.ID == match_state.host_id


func _send(event: String, payload: Dictionary) -> void:
	if match_state == null: return
	SupabaseRealtime.send_broadcast(get_match_channel(), event, payload)


func get_remaining_slots_count() -> int:
	if match_state == null: return 0
	var remaining: int = player_slots_count
	remaining -= match_state.invited_players.size()
	remaining -= match_state.joined_players.size()
	return maxi(remaining, 0)


# =====================================================================
#  DISPLAY
# =====================================================================

func update_display() -> void:
	if game_info:
		thumbnail.texture = game_info.thumbnail
		name_label.text = game_info.name
		description.text = game_info.description
		players_count.text = "👤%d - %d" % [game_info.min_players, game_info.max_players]
		if player_slots_count <= 0:
			player_slots_count = game_info.min_players

	if match_state:
		players_count_button.visible = is_hosting_match()

	_update_play_button()
	_update_players_display()


func _update_play_button() -> void:
	if match_state == null:
		play_button.disabled = _creating
		return
	if not is_hosting_match() or _match_started:
		play_button.disabled = true
		return
	var min_players: int = game_info.min_players if game_info else 1
	play_button.disabled = match_state.joined_players.size() < min_players


func _update_players_display() -> void:
	if match_state == null:
		players_panel.hide()
		return

	_refresh_id += 1
	var my_id: int = _refresh_id

	# 1) fetch everything BEFORE touching the UI
	var invited: Array = []
	for id in match_state.invited_players.duplicate():
		invited.append(await GameService.get_player(id))
	var joined: Array = []
	for id in match_state.joined_players.duplicate():
		joined.append(await GameService.get_player(id))

	# 2) a newer refresh started (or we left the tree) while we were waiting
	if my_id != _refresh_id or not is_inside_tree():
		return

	# 3) rebuild in one synchronous pass
	for c in players_container.get_children():
		c.queue_free()

	for p in invited:
		if p == null: continue
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = p
		card.has_joined = false
		players_container.add_child(card)

	for p in joined:
		if p == null: continue
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = p
		players_container.add_child(card)

	if is_hosting_match() and not _match_started:
		for i in get_remaining_slots_count():
			var slot = PLAYER_SLOT_SCENE.instantiate()
			slot.match_id = match_state.match_id
			players_container.add_child(slot)

	players_panel.visible = players_container.get_child_count() > 0


# =====================================================================
#  DATABASE (storage only, nothing here is required for the lobby to work)
# =====================================================================

func get_match_data(match_id: String) -> Dictionary:
	var result: Dictionary = await SupabaseManager.select(
		"matches",
		"id=eq.%s" % match_id
	)

	if result.code == 200 and not result.data.is_empty():
		return result.data[0]

	printerr("Can't get match data: ", result)
	return {}


## Host only. Writes the current state to the DB. Calls are coalesced so an
## older write can never land after a newer one.
func _persist_state() -> void:
	if match_state == null or not is_hosting_match(): return
	if _persisting:
		_persist_dirty = true
		return

	_persisting = true
	while true:
		_persist_dirty = false
		if match_state == null: break
		var r: Dictionary = await SupabaseManager.update(
			"matches",
			"id=eq.%s" % match_state.match_id,
			{
				"joined_players": match_state.joined_players,
				"invited_players": match_state.invited_players,
			}
		)
		if r.code != 200:
			printerr("persist failed (non-fatal): ", r)
		if not _persist_dirty:
			break
	_persisting = false


## Host only. The invite slots write to the DB and send "match_data_changed".
## We keep our own joined list and only take the invite list from the DB.
func _merge_invites_from_db() -> void:
	if match_state == null: return
	var data: Dictionary = await get_match_data(match_state.match_id)
	if data.is_empty() or match_state == null: return

	var merged: Array[String] = []
	for id in data.get("invited_players", []):
		var sid := str(id)
		if sid in match_state.joined_players or sid in merged:
			continue
		merged.append(sid)
	match_state.invited_players = merged

	_broadcast_state()
	update_display()


# =====================================================================
#  CREATE / JOIN
# =====================================================================

func create_match() -> bool:
	if game_info == null or GameService.local_player == null:
		printerr("create_match: missing game_info or local_player")
		return false

	var host_id: String = _local_id()
	var result: Dictionary = await SupabaseManager.insert("matches", {
		"created_by": host_id,
		"game_info": game_info.to_dict(),
		"game_state": {},
		"joined_players": [host_id],
		"invited_players": [],
	})

	if result.code != 201 or result.data.is_empty():
		printerr("create_match failed: ", result)
		return false

	await join_match(result.data[0])
	return true


func join_match(match_data: Dictionary) -> void:
	var new_state: MatchState = MatchState.from_dict(match_data)
	if new_state.match_id.is_empty():
		printerr("join_match: invalid match data ", match_data)
		join_failed.emit("invalid_match")
		return

	match_state = new_state
	if match_data.has("game_info"):
		game_info = GameInfo.from_dict(match_data.game_info)

	if not SupabaseRealtime.message_received.is_connected(_on_broadcast_message_received):
		SupabaseRealtime.message_received.connect(_on_broadcast_message_received)
	SupabaseRealtime.join_channel(get_match_channel(), false, true)

	_start_heartbeat()
	update_display()

	# ---- host: we are the source of truth ----
	if is_hosting_match():
		if _local_id() not in match_state.joined_players:
			match_state.joined_players.append(_local_id())
		player_slots_count = maxi(player_slots_count, game_info.min_players if game_info else 1)
		_persist_state()
		update_display()
		return

	# ---- guest: keep asking until the host confirms us ----
	_confirmed = false
	_join_aborted = false
	_last_state_msec = Time.get_ticks_msec()

	for i in JOIN_MAX_ATTEMPTS:
		if _confirmed or _join_aborted or not is_inside_tree():
			return
		_send("join_request", {"player_id": _local_id()})
		await get_tree().create_timer(JOIN_RETRY_SECONDS).timeout

	if not _confirmed and not _join_aborted and is_inside_tree():
		printerr("Host unreachable")
		join_failed.emit("unreachable")


# =====================================================================
#  HEARTBEAT (host sends state, guests watch for it)
# =====================================================================

func _start_heartbeat() -> void:
	if _heartbeat_timer != null: return
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_SECONDS
	_heartbeat_timer.timeout.connect(_on_heartbeat)
	add_child(_heartbeat_timer)
	_heartbeat_timer.start()


func _on_heartbeat() -> void:
	if match_state == null or _game_started: return

	if is_hosting_match():
		_broadcast_state()
		return

	if _confirmed:
		var silent_for: float = (Time.get_ticks_msec() - _last_state_msec) / 1000.0
		if silent_for > HOST_TIMEOUT_SECONDS:
			_heartbeat_timer.stop()
			printerr("Host stopped responding")
			host_lost.emit()


# =====================================================================
#  MESSAGES
# =====================================================================

func _broadcast_state() -> void:
	if match_state == null: return
	_send("state", {
		"match": match_state.to_dict(),
		"slots": player_slots_count,
		"started": _match_started,
	})


func _on_broadcast_message_received(room: String, event: String, payload: Dictionary) -> void:
	if match_state == null or room != get_match_channel():
		return

	_log("RECEIVED %s" % event, payload)

	match event:
		# ---------- host receives ----------
		"join_request":
			_on_join_request(str(payload.get("player_id", "")))
		"player_left":
			_on_player_left(str(payload.get("player_id", "")))
		"match_data_changed":
			if is_hosting_match():
				await _merge_invites_from_db()

		# ---------- guests receive ----------
		"state":
			_on_state_received(payload)
		"join_rejected":
			if str(payload.get("player_id", "")) == _local_id():
				_join_aborted = true
				printerr("Join rejected: ", payload.get("reason", ""))
				join_failed.emit(str(payload.get("reason", "rejected")))
		"match_started":
			if not is_hosting_match() and _confirmed:
				_start_game()
		"match_closed":
			if not is_hosting_match() and not _game_started:
				host_lost.emit()


## HOST. Runs synchronously, so simultaneous requests are handled one by one.
func _on_join_request(player_id: String) -> void:
	if player_id.is_empty() or not is_hosting_match():
		return

	# already in: just re-send the state (retries are harmless)
	if player_id in match_state.joined_players:
		_broadcast_state()
		return

	if _match_started:
		_send("join_rejected", {"player_id": player_id, "reason": "started"})
		return

	if match_state.joined_players.size() >= player_slots_count:
		_send("join_rejected", {"player_id": player_id, "reason": "full"})
		return

	# mutate BEFORE any await
	match_state.joined_players.append(player_id)   # array index = seat
	match_state.invited_players.erase(player_id)

	_broadcast_state()
	update_display()
	_persist_state()   # fire and forget


## HOST.
func _on_player_left(player_id: String) -> void:
	if not is_hosting_match() or _match_started:
		return
	if player_id == match_state.host_id or player_id not in match_state.joined_players:
		return

	match_state.joined_players.erase(player_id)
	_broadcast_state()
	update_display()
	_persist_state()


## GUEST.
func _on_state_received(payload: Dictionary) -> void:
	if is_hosting_match():
		return

	var incoming: MatchState = MatchState.from_dict(payload.get("match", {}))
	if incoming.match_id != match_state.match_id:
		return
	if incoming.host_id.is_empty():
		incoming.host_id = match_state.host_id

	match_state = incoming
	player_slots_count = int(payload.get("slots", player_slots_count))
	_last_state_msec = Time.get_ticks_msec()

	if _local_id() in match_state.joined_players:
		_confirmed = true

	update_display()

	# also covers a guest that missed the "match_started" event
	if _confirmed and payload.get("started", false):
		_start_game()


# =====================================================================
#  START
# =====================================================================

func _on_play_button_pressed() -> void:
	# first press: create the lobby
	if match_state == null:
		if _creating: return
		_creating = true
		_update_play_button()
		await create_match()
		_creating = false
		update_display()
		return
	
	# second press: start the game (host only)
	if not is_hosting_match() or _match_started:
		return
	var min_players: int = game_info.min_players if game_info else 1
	if match_state.joined_players.size() < min_players:
		return
	
	_match_started = true
	_update_play_button()
	
	# send a few times so a dropped packet can't strand a guest
	for i in START_BROADCAST_REPEATS:
		_broadcast_state()
		_send("match_started", {})
		await get_tree().create_timer(START_BROADCAST_GAP).timeout
	
	_start_game()


func _start_game() -> void:
	if _game_started: return
	if Main == null or game_info == null or game_info.game_scene == null:
		printerr("Can't start: Main or game scene is missing")
		return

	_game_started = true
	var game_instance: BoardGame = game_info.game_scene.instantiate()

	Main.change_scene(
		game_instance,
		{},
		{
			"setup": [match_state, GameService.local_player],
			"start": []
		}
	)


# =====================================================================
#  UI CALLBACKS
# =====================================================================

func _on_players_count_button_item_selected(index: int) -> void:
	var amount: int = int(players_count_button.get_item_text(index))
	if match_state:
		amount = maxi(amount, match_state.joined_players.size())
	player_slots_count = amount

	if match_state and is_hosting_match():
		_broadcast_state()

	_update_players_display()
