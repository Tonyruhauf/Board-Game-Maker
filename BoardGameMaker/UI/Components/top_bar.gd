extends PanelContainer


var Main: MainNode
var current_view: View

enum View {
	GAME_BROWSER_VIEW,
	PROFILE_VIEW
}

const PLAYER_PROFILE_VIEW: PackedScene = preload("res://BoardGameMaker/UI/Views/player_profile_view.tscn")
const GAME_BROWSER: PackedScene = preload("res://BoardGameMaker/Core/Game Browser/game_browser.tscn")


func _ready() -> void:
	current_view = View.GAME_BROWSER_VIEW


func _on_profile_button_pressed() -> void:
	current_view = View.PROFILE_VIEW
	Main.change_scene(PLAYER_PROFILE_VIEW)


func _on_games_browser_button_pressed() -> void:
	current_view = View.GAME_BROWSER_VIEW
	Main.change_scene(GAME_BROWSER)
