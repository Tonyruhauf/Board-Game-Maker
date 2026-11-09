@tool
extends Node2D

@export_category("Create New Board Game")
@export var game_name: String
@export_multiline() var game_desc: String
@export_tool_button("Create game files") var create_game_file_button = create_game_files

const GAME_INFO_PATH := "res://Game/GameInfo.tres"
const GAME_INFO_CLASS := preload("res://BoardGameMaker/Core/Game/GameInfo.gd")

const GAME_STATE_PATH := "res://Game/%sState.gd"
const GAME_STATE_TEMPLATE := """class_name %sState extends GameState"""

const MAIN_SCENE_PATH := "res://Game/main.tscn"
const MAIN_SCENE_TEMPLATE := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Game/main.gd" id="1_script"]

[node name="Main" type="Control"]
script = ExtResource("1_script")
"""

const MAIN_SCRIPT_PATH := "res://Game/main.gd"
const MAIN_SCRIPT_TEMPLATE_PATH := "res://script_templates/BoardGame/base_template.gd"


func create_game_files() -> void:
	if game_name.is_empty():
		print("Can't create game files: 'game_name' is empty.")
		return
	
	var dir: DirAccess = DirAccess.open("res://")
	dir.make_dir("Game")
	dir.make_dir("Game/actions")
	
	# CREATING FILES
	create_game_state_script()
	
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	while fs.is_scanning():
		await get_tree().process_frame
	
	create_main_scene()
	
	fs.scan()
	while fs.is_scanning():
		await get_tree().process_frame
	
	create_game_info_script()
	
	await get_tree().create_timer(0.2).timeout
	EditorInterface.get_resource_filesystem().scan()


func create_game_info_script():
	var game_info: Resource = GAME_INFO_CLASS.new()
	game_info.name = game_name
	game_info.description = game_desc
	game_info.game_scene = load(MAIN_SCENE_PATH)
	game_info.game_state_class = load(GAME_STATE_PATH % game_name.to_pascal_case())
	
	var error := ResourceSaver.save(game_info, GAME_INFO_PATH)
	
	if error != OK:
		push_error("Failed to save GameInfo: " + error_string(error))
		return


func create_game_state_script():
	var path := GAME_STATE_PATH % game_name.to_pascal_case()
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		push_error("Failed to create GameState script: " + path)
		return
	
	file.store_string(GAME_STATE_TEMPLATE % game_name.to_pascal_case())
	file.close()


func create_main_scene():
	# Script
	var script_file := FileAccess.open(MAIN_SCRIPT_PATH, FileAccess.WRITE)
	
	if script_file == null:
		push_error("Failed to create main script: " + MAIN_SCRIPT_PATH)
		return
	
	var template_file := FileAccess.open(MAIN_SCRIPT_TEMPLATE_PATH, FileAccess.READ)
	
	if template_file == null:
		push_error("Failed to open template script: " + MAIN_SCRIPT_TEMPLATE_PATH)
		return
	
	var template_string: String = template_file.get_as_text()
	template_string = template_string.replace("_CLASS_", game_name.to_pascal_case())
	
	script_file.store_string(template_string)
	script_file.close()
	
	# Scene
	var scene_file := FileAccess.open(MAIN_SCENE_PATH, FileAccess.WRITE)
	
	if scene_file == null:
		push_error("Failed to create main scene: " + MAIN_SCENE_PATH)
		return
	
	scene_file.store_string(MAIN_SCENE_TEMPLATE)
	scene_file.close()
