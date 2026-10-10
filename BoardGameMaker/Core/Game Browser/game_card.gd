extends PanelContainer


@onready var thumbnail: TextureRect = $Thumbnail
@onready var info_card: PanelContainer = $InfoCard
@onready var name_label: Label = $InfoCard/MarginContainer/VBoxContainer/NameLabel
@onready var description: Label = $InfoCard/MarginContainer/VBoxContainer/Description
@onready var players_count: Label = $InfoCard/MarginContainer/VBoxContainer/PlayersCount

@export var game_info: GameInfo

var is_hovered: bool = false


func _ready() -> void:
	name_label.text = game_info.name
	players_count.text = "👤 %d - %d" % [game_info.min_players, game_info.max_players]
	thumbnail.texture = game_info.thumbnail
	description.text = game_info.description
	
	_update_display()


func _update_display() -> void:
	info_card.visible = is_hovered


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and is_hovered:
				pass # TODO


func _on_mouse_entered() -> void:
	is_hovered = true
	_update_display()


func _on_mouse_exited() -> void:
	is_hovered = false
	_update_display()
