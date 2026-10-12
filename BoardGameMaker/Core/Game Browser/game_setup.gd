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
@onready var players_container: GridContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/VBoxContainer/ScrollContainer/Players
@onready var options_container: VBoxContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/OptionsContainer

var Main: MainNode

@export var game_info: GameInfo

var invited_players: Array[Player]
var joined_players: Array[Player]

const PLAYER_CARD_SCENE: PackedScene = preload("res://BoardGameMaker/UI/Components/player_card.tscn")


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


func _on_play_button_pressed() -> void:
	var game_instance: BoardGame = game_info.game_scene.instantiate()
	game_instance.setup(joined_players, joined_players[0]) # TODO: Replace temporary code "joined_players[0]"
	game_instance.start()
	
	Main.change_scene(game_instance)
