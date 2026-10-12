class_name MainNode extends Control


var current_scene: Node
var local_player: Player = Player.new().setup("Tony")

const STARTING_SCENE: String = "res://BoardGameMaker/Core/Game Browser/game_browser.tscn"


func _ready() -> void:
	change_scene(STARTING_SCENE)


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
	
	add_child(new_scene)
	current_scene = new_scene
