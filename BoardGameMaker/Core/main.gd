class_name MainNode extends Control


@onready var background: ColorRect = $BG
@onready var top_bar: PanelContainer = $ScrollContainer/VBoxContainer/TopBar
@onready var scene_container: Control = $ScrollContainer/VBoxContainer/SceneContainer
@onready var login_screen: Control = $LoginScreen
@onready var match_invite: PanelContainer = $MatchInvite

var current_scene: Node
var local_player: Player = Player.new()

const STARTING_SCENE: String = "res://BoardGameMaker/Core/Game Browser/game_browser.tscn"


func _ready() -> void:
	top_bar.Main = self
	login_screen.Main = self
	GameService.Main = self
	
	login_screen.log_in_success.connect(_on_login_success)
	
	top_bar.hide()
	
	#if await SupabaseManager.try_restore_session():
		#_on_login_success()
	#else:
	login_screen.popup(true)


func _on_login_success() -> void:
	if not await _try_load_local_player():
		printerr("CANNOT LOAD LOCAL PLAYER")
		login_screen.popup(true)
	else:
		top_bar.show()
		change_scene(STARTING_SCENE)
		
		_finish_loading_local_player()


func _try_load_local_player() -> bool:
	var profile: Dictionary = await GameService.get_player_profile()
	
	if profile.is_empty():
		return false
	
	local_player.ID = profile.id
	local_player.username = profile.username
	
	return true


func _finish_loading_local_player():
	# Realtime Connections
	SupabaseRealtime.connect_realtime(SupabaseManager.current_access_token)
	SupabaseRealtime.message_received.connect(_on_broadcast_message_received)
	
	var user_channel: String = "user-%s" % local_player.username
	SupabaseRealtime.join_channel(user_channel)


func _on_broadcast_message_received(
	room: String,
	event: String,
	payload: Dictionary
):
	
	match event:
		"match_invite":
			_on_match_invite_received(payload)


func _on_match_invite_received(data: Dictionary) -> void:
	match_invite.popup(data)


func change_scene(
	scene: Variant,
	properties_override: Dictionary[String, Variant] = {},
):
	
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
