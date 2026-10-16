extends Control


@onready var profile_icon: TextureRect = $ProfileIcon
@onready var player_name: Label = $Name

var player: Player
var has_joined: bool = true


func _ready() -> void:
	player_name.text = player.username
	
	if not has_joined:
		modulate.a = 0.65
