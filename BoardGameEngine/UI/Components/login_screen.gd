extends Control


@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/TabContainer
@onready var tab_sign_up: MarginContainer = $CenterContainer/PanelContainer/TabContainer/SignUp
@onready var tab_login: MarginContainer = $CenterContainer/PanelContainer/TabContainer/LogIn
@onready var tab_set_username: MarginContainer = $CenterContainer/PanelContainer/TabContainer/SetUsername

@onready var sign_up_email_edit: LineEdit = $CenterContainer/PanelContainer/TabContainer/SignUp/VBoxContainer/EmailEdit
@onready var sign_up_password_edit: LineEdit = $CenterContainer/PanelContainer/TabContainer/SignUp/VBoxContainer/PasswordEdit
@onready var sign_up_button: Button = $CenterContainer/PanelContainer/TabContainer/SignUp/VBoxContainer/SignUpButton

@onready var login_email_edit: LineEdit = $CenterContainer/PanelContainer/TabContainer/LogIn/VBoxContainer/EmailEdit
@onready var login_password_edit: LineEdit = $CenterContainer/PanelContainer/TabContainer/LogIn/VBoxContainer/PasswordEdit
@onready var login_button: Button = $CenterContainer/PanelContainer/TabContainer/LogIn/VBoxContainer/LogInButton

@onready var username_edit: LineEdit = $CenterContainer/PanelContainer/TabContainer/SetUsername/VBoxContainer/UsernameEdit
@onready var username_confirm_button: Button = $CenterContainer/PanelContainer/TabContainer/SetUsername/VBoxContainer/ConfirmButton

var Main: MainNode

signal log_in_success
signal sign_up_success
signal log_in_failed
signal sign_up_failed


func _ready() -> void:
	sign_up_button.pressed.connect(_try_sign_up)
	login_button.pressed.connect(_try_login)
	username_confirm_button.pressed.connect(_try_submitting_username)


func popup(open_on_login_tab: bool) -> void:
	if open_on_login_tab:
		tab_login.show()
	else:
		tab_sign_up.show()
	show()


func _try_sign_up() -> void:
	set_dirty(true)
	var result: Dictionary = await SupabaseManager.sign_up(sign_up_email_edit.text, sign_up_password_edit.text)
	set_dirty(false)
	
	if result.code == 200:
		_on_sign_up()
	else:
		_on_sign_up_failed(result.error)


func _try_login() -> void:
	set_dirty(true)
	var result: Dictionary = await SupabaseManager.sign_in(login_email_edit.text, login_password_edit.text)
	set_dirty(false)
	
	if result.code == 200:
		_on_login()
	else:
		_on_login_failed(result.error)


func _on_sign_up() -> void:
	print("Account created successfully!")
	sign_up_success.emit()
	
	tab_container.tabs_visible = false
	tab_set_username.show()


func _on_login() -> void:
	print("Log in success!")
	log_in_success.emit()
	
	hide()


func _on_sign_up_failed(error: String) -> void:
	print("Sign up failed: ", error)
	sign_up_failed.emit()


func _on_login_failed(error: String) -> void:
	print("Login failed: ", error)
	log_in_failed.emit()


func _try_submitting_username() -> void:
	set_dirty(true)
	
	var data: Dictionary = {
		"username": username_edit.text
	}
	
	var result = await SupabaseManager.insert("player_profiles", data)
	
	if result.code == 201:
		_on_username_choosen()
	else:
		_on_username_invalid(result.error)
	
	set_dirty(false)


func _on_username_choosen() -> void:
	_on_login()


func _on_username_invalid(error: String) -> void:
	print("Username failed: ", error)


func set_dirty(is_dirty: bool) -> void:
	tab_container.set_tab_disabled(0, is_dirty)
	tab_container.set_tab_disabled(1, is_dirty)
	
	sign_up_button.disabled = is_dirty
	login_button.disabled = is_dirty
	
	sign_up_email_edit.editable = !is_dirty
	sign_up_password_edit.editable = !is_dirty
	login_email_edit.editable = !is_dirty
	login_password_edit.editable = !is_dirty
	
	username_edit.editable = !is_dirty
	username_confirm_button.disabled = is_dirty
