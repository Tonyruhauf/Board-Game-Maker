extends TextureRect


@onready var invite_popup: PanelContainer = $CanvasLayer/InvitePopup
@onready var username_edit: LineEdit = $CanvasLayer/InvitePopup/MarginContainer/VBoxContainer/UsernameEdit
@onready var result_label: Label = $CanvasLayer/InvitePopup/MarginContainer/VBoxContainer/ResultLabel
@onready var invite_button: Button = $CanvasLayer/InvitePopup/MarginContainer/VBoxContainer/InviteButton

var match_id: String
var prev_global_pos: Vector2
var search_cooldown_remaining: float = 0.0
var searched_username: String
var found_user_profile: Dictionary

const SEARCH_COOLDOWN: float = 1.2


func _ready() -> void:
	invite_popup.hide()


func _process(delta: float) -> void:
	if global_position != prev_global_pos:
		prev_global_pos = global_position
		_update_popup_pos()
	
	if search_cooldown_remaining > 0.0:
		search_cooldown_remaining -= delta
		
		if search_cooldown_remaining <= 0.0:
			run_search()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			get_tree().call_group(TreeGroupsRegistry.PLAYER_SLOTS, "hide_invite_popup")
			show_invite_popup()


func show_invite_popup() -> void:
	invite_button.disabled = true
	
	invite_popup.show()
	_update_popup_pos()


func hide_invite_popup() -> void:
	invite_popup.hide()


func _update_popup_pos() -> void:
	invite_popup.global_position = global_position + Vector2(50, 50)
	invite_popup.global_position.x -= invite_popup.size.x


func run_search() -> void:
	var profile =\
		await GameService.get_player_profile_by_username(searched_username)
	
	if not profile.is_empty():
		result_label.text = "Player found:\n" + profile.username
		found_user_profile = profile
		invite_button.disabled = false
	else:
		result_label.text = "This player does't exist!"
		invite_button.disabled = true


func _on_username_edit_text_changed(new_text: String) -> void:
	search_cooldown_remaining = SEARCH_COOLDOWN
	searched_username = new_text


func _on_invite_button_pressed() -> void:
	invite_popup.hide()
	
	var invite_data: Dictionary = {
		"sender": GameService.local_player.ID,
		"recipient": found_user_profile.id,
		"match_id": match_id
	}
	var result = await SupabaseManager.insert("invites", invite_data)
	
	if result.code == 201:
		var channel: String = "user-%s" % found_user_profile.username
		SupabaseRealtime.send_broadcast(channel, "match_invite", result.data[0])
