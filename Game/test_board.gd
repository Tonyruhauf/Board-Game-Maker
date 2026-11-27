@tool
extends Board


func _ready() -> void:
	super()
	
	common_ui.set_UI_element_visibility(CommonUI.UINode.SETTINGS_BUTTON, false)
