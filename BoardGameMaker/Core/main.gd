class_name MainNode extends Control


@onready var background: ColorRect = $BG
@onready var top_bar: PanelContainer = $ScrollContainer/VBoxContainer/TopBar
@onready var scene_container: Control = $ScrollContainer/VBoxContainer/SceneContainer
@onready var login_screen: Control = $LoginScreen
@onready var match_invite: PanelContainer = $MatchInvite

var current_scene: Node

const STARTING_SCENE: String = "res://BoardGameMaker/Core/Game Browser/game_browser.tscn"
const GAME_SETUP_SCENE: String = "res://BoardGameMaker/Core/Game Browser/game_setup.tscn"


func _ready() -> void:
	GameService.Main = self
	top_bar.Main = self
	login_screen.Main = self
	match_invite.Main = self
	
	login_screen.log_in_success.connect(_on_login_success)
	
	top_bar.hide()
	
	# Realtime connection
	SupabaseRealtime.message_received.connect(_on_broadcast_message_received)
	SupabaseRealtime.channel_error.connect(func(room, reason): push_error("%s: %s" % [room, reason]))
	SupabaseRealtime.connect_realtime(SupabaseManager.current_access_token)
	
	if await SupabaseManager.try_restore_session():
		_on_login_success()
	else:
		login_screen.popup(true)


func _on_login_success() -> void:
	if not await _try_load_local_player():
		printerr("CANNOT LOAD LOCAL PLAYER")
		login_screen.popup(true)
	else:
		_setup_local_player()
		
		top_bar.show()
		change_scene(STARTING_SCENE)


func _try_load_local_player() -> bool:
	GameService.local_player = await GameService.get_local_player()
	
	if GameService.local_player == null:
		return false
	
	return true


func _setup_local_player():
	var user_channel: String = "user-%s" % GameService.local_player.username
	SupabaseRealtime.join_channel(user_channel)


func _on_broadcast_message_received(
	room: String,
	event: String,
	payload: Dictionary
):
	
	print("Received")
	print(room)
	print(event)
	print(payload)
	
	match event:
		"match_invite":
			_on_match_invite_received(payload)


func _on_match_invite_received(data: Dictionary) -> void:
	match_invite.popup(data)


func join_match(match_data: Dictionary) -> void:
	change_scene(GAME_SETUP_SCENE).join_match(match_data)


func change_scene(
	scene: Variant,
	properties_override: Dictionary[String, Variant] = {},
) -> Node:
	
	if current_scene:
		current_scene.queue_free()
	
	var new_scene: Node
	if scene is String:
		new_scene = load(scene).instantiate()
	elif scene is PackedScene:
		new_scene = scene.instantiate()
	elif scene is Node:
		new_scene = scene
	
	new_scene.set("Main", self)
	
	for property_name in properties_override.keys():
		new_scene.set(property_name, properties_override[property_name])
	
	var is_game: bool = (new_scene is BoardGame)
	top_bar.visible = not is_game
	background.visible = not is_game
	
	scene_container.add_child(new_scene)
	current_scene = new_scene
	
	return current_scene
