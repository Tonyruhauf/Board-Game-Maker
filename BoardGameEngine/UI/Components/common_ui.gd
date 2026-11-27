class_name CommonUI extends CanvasLayer


@onready var top_bar: HBoxContainer = $TopBar
@onready var bottom_bar: HBoxContainer = $BottomBar
@onready var left_bar: VBoxContainer = $LeftBar
@onready var right_bar: VBoxContainer = $RightBar

@onready var top_left_slot: HBoxContainer = $TopBar/LeftSlot
@onready var top_center_slot: HBoxContainer = $TopBar/CenterSlot
@onready var top_right_slot: HBoxContainer = $TopBar/RightSlot

@onready var bottom_left_slot: HBoxContainer = $BottomBar/LeftSlot
@onready var bottom_center_slot: HBoxContainer = $BottomBar/CenterSlot
@onready var bottom_right_slot: HBoxContainer = $BottomBar/RightSlot

@onready var left_top_slot: VBoxContainer = $LeftBar/TopSlot
@onready var left_center_slot: VBoxContainer = $LeftBar/CenterSlot
@onready var left_bottom_slot: VBoxContainer = $LeftBar/BottomSlot

@onready var right_top_slot: VBoxContainer = $RightBar/TopSlot
@onready var right_center_slot: VBoxContainer = $RightBar/CenterSlot
@onready var right_bottom_slot: VBoxContainer = $RightBar/BottomSlot

@onready var settings_button: Button = $LeftBar/BottomSlot/SettingsButton
@onready var end_turn_button: Button = $BottomBar/RightSlot/EndTurnButton

var tab_override: bool = false
var hidden_nodes: Array[Node]

enum Slot {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
	LEFT_TOP,
	LEFT_CENTER,
	LEFT_BOTTOM,
	RIGHT_TOP,
	RIGHT_CENTER,
	RIGHT_BOTTOM
}

enum UINode {
	SETTINGS_BUTTON,
	END_TURN_BUTTON
	#RULES_BUTTON
}


func _input(event: InputEvent) -> void:
	if event.is_action("show_hidden_ui"):
		_set_tab_override(event.is_pressed())


func _set_tab_override(enabled: bool) -> void:
	tab_override = enabled
	_update_visibility()


func move_UI_element(element: UINode, slot: Slot):
	_get_ui_node(element).reparent(_get_slot(slot))


func set_UI_element_visibility(element: UINode, visibility: bool):
	var node: Node = _get_ui_node(element)
	
	match visibility:
		true:
			if hidden_nodes.has(node):
				hidden_nodes.erase(node)
		false:
			if not hidden_nodes.has(node):
				hidden_nodes.append(node)
	
	_update_visibility()


func _get_ui_node(node: UINode) -> Node:
	match node:
		UINode.SETTINGS_BUTTON: return settings_button
		UINode.END_TURN_BUTTON: return end_turn_button
		_: return null


func _get_slot(slot: Slot) -> Node:
	match slot:
		Slot.TOP_LEFT: return top_left_slot
		Slot.TOP_CENTER: return top_center_slot
		Slot.TOP_RIGHT: return top_right_slot
		Slot.BOTTOM_LEFT: return bottom_left_slot
		Slot.BOTTOM_CENTER: return bottom_center_slot
		Slot.BOTTOM_RIGHT: return bottom_right_slot
		Slot.LEFT_TOP: return left_top_slot
		Slot.LEFT_CENTER: return left_center_slot
		Slot.LEFT_BOTTOM: return left_bottom_slot
		Slot.RIGHT_TOP: return right_top_slot
		Slot.RIGHT_CENTER: return right_center_slot
		Slot.RIGHT_BOTTOM: return right_bottom_slot
		_: return null


func _update_visibility() -> void:
	for i in UINode.keys().size():
		var node = _get_ui_node(i)
		node.visible = not hidden_nodes.has(node) or tab_override


func _on_end_turn_button_pressed() -> void:
	var action: GameAction = EndTurnAction.new(
		GameService.get_local_player().ID
	)
	GameService.game.request_action(action)
