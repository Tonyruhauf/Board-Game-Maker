extends Control


@onready var thumbnail: TextureRect = $VBoxContainer/Thumbnail
@onready var name_label: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/Name
@onready var description: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer2/Description
@onready var tags_container: HBoxContainer = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Tags
@onready var infos_container: HBoxContainer = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos
@onready var players_count: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos/PlayersCount
@onready var average_duration: Label = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Infos/AverageDuration
@onready var play_button: Button = $VBoxContainer/Thumbnail/GameInfos/MarginContainer/VBoxContainer/HBoxContainer2/PlayButton
@onready var players_panel: PanelContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel
@onready var players_count_button: OptionButton = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/ScrollContainer/VBoxContainer/CenterContainer/PlayersCountButton
@onready var players_container: HFlowContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/ScrollContainer/VBoxContainer/Players
@onready var options_container: VBoxContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/OptionsContainer

var Main: MainNode

@export var game_info: GameInfo

var match_state: MatchState = null

var player_slots_count: int

const PLAYER_CARD_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_card.tscn")
const PLAYER_SLOT_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_slot.tscn")


func _ready() -> void:
	update_display()


func update_display():
	if game_info:
		thumbnail.texture = game_info.thumbnail
		name_label.text = game_info.name
		description.text = game_info.description
		players_count.text = "👤%d - %d" % [game_info.min_players, game_info.max_players]
	
	players_panel.hide()
	_update_players_display()


func create_match() -> void:
	match_state = MatchState.new()
	
	match_state.joined_players = [GameService.local_player.ID]
	update_display()
	
	var result: Dictionary = await SupabaseManager.insert("matches", {
		"created_by": GameService.local_player.ID,
		"game_info": game_info.to_dict(),
		"joined_players": match_state.joined_players,
		"invited_players": match_state.invited_players,
	})
	
	if result.code == 201:
		match_state.match_id = result.data[0].id
		
		result = await SupabaseManager.insert("match_players", {
			"match_id": result.data[0].id,
			"user_id": GameService.local_player.ID,
			"seat": 0
		})


func join_match(match_data: Dictionary) -> void:
	match_state = MatchState.from_dict(match_data)
	game_info = GameInfo.from_dict(match_data.game_info)
	
	update_display()


func _update_players_display() -> void:
	if match_state == null:
		return
	
	var invited_players: Array[String] = match_state.invited_players
	var joined_players: Array[String] = match_state.joined_players
	
	players_panel.visible =\
		(invited_players.size() > 0 or joined_players.size() > 0)
	
	for player_card in players_container.get_children():
		player_card.queue_free()
	
	for player_id in invited_players:
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = await GameService.get_player(player_id)
		card.has_joined = false
		players_container.add_child(card)
	
	for player_id in joined_players:
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = await GameService.get_player(player_id)
		players_container.add_child(card)
	
	for i in get_remaining_slots_count():
		var slot = PLAYER_SLOT_SCENE.instantiate()
		slot.match_id = match_state.match_id
		players_container.add_child(slot)


func get_remaining_slots_count() -> int:
	var remaining_slots: int = player_slots_count
	remaining_slots -= match_state.invited_players.size()
	remaining_slots -= match_state.joined_players.size()
	return remaining_slots


func _on_play_button_pressed() -> void:
	if match_state == null:
		play_button.disabled = true
		await create_match()
		play_button.disabled = false
		return
	
	var game_instance: BoardGame = game_info.game_scene.instantiate()
	game_instance.setup(match_state.joined_players, GameService.local_player)
	game_instance.start()
	
	Main.change_scene(game_instance)


func _on_players_count_button_item_selected(index: int) -> void:
	var amount: int = int(players_count_button.get_item_text(index))
	player_slots_count = amount
	_update_players_display()
