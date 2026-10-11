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
@onready var players: GridContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/PlayersPanel/MarginContainer/VBoxContainer/ScrollContainer/Players
@onready var options_container: VBoxContainer = $VBoxContainer/ScrollContainer/PanelContainer/GameOptions/HBoxContainer/OptionsContainer

var Main: MainNode

@export var game_info: GameInfo

var invited_player: Array[Player]
var joined_players: Array[Player]


func _ready() -> void:
	thumbnail.texture = game_info.thumbnail
	name_label.text = game_info.name
	description.text = game_info.description
	players_count.text = "👤%d - %d" % [game_info.min_players, game_info.max_players]
	
	players_panel.hide()
	
	# TODO: Replace this temporary code:
	joined_players = [Player.new().setup("Tobby"), Player.new().setup("Bob")]


func _on_play_button_pressed() -> void:
	var game_instance: BoardGame = game_info.game_scene.instantiate()
	game_instance.setup(joined_players, joined_players[0]) # TODO: Replace temporary code "joined_players[0]"
	game_instance.start()
	
	Main.change_scene(game_instance)
