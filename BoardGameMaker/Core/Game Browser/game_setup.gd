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

var player_slots_count: int
var invited_players: Array[Player]
var joined_players: Array[Player]

const PLAYER_CARD_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_card.tscn")
const PLAYER_SLOT_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_slot.tscn")


func _ready() -> void:
	thumbnail.texture = game_info.thumbnail
	name_label.text = game_info.name
	description.text = game_info.description
	players_count.text = "👤%d - %d" % [game_info.min_players, game_info.max_players]
	
	players_panel.hide()
	
	joined_players = [Main.local_player]
	_update_players_display()


func _update_players_display() -> void:
	players_panel.visible =\
		(invited_players.size() > 0 or joined_players.size() > 0)
	
	for player_card in players_container.get_children():
		player_card.queue_free()
	
	for player in invited_players:
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = player
		card.has_joined = false
		players_container.add_child(card)
	
	for player in joined_players:
		var card = PLAYER_CARD_SCENE.instantiate()
		card.player = player
		players_container.add_child(card)
	
	for i in get_remaining_slots_count():
		var slot = PLAYER_SLOT_SCENE.instantiate()
		players_container.add_child(slot)


func get_remaining_slots_count() -> int:
	var remaining_slots: int = player_slots_count
	remaining_slots -= invited_players.size()
	remaining_slots -= joined_players.size()
	return remaining_slots


func _on_play_button_pressed() -> void:
	var game_instance: BoardGame = game_info.game_scene.instantiate()
	game_instance.setup(joined_players, joined_players[0]) # TODO: Replace temporary code "joined_players[0]"
	game_instance.start()
	
	Main.change_scene(game_instance)


func _on_players_count_button_item_selected(index: int) -> void:
	var amount: int = int(players_count_button.get_item_text(index))
	player_slots_count = amount
	_update_players_display()
