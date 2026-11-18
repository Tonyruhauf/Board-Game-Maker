@tool
class_name ImprovedBoxContainer
extends Control

@export var box_direction: BoxDirection:
	set(value):
		box_direction = value
		update_container()
@export var horizontal_alignment: Alignment = Alignment.BEGIN:
	set(value):
		horizontal_alignment = value
		update_container()
@export var vertical_alignment: Alignment = Alignment.BEGIN:
	set(value):
		vertical_alignment = value
		update_container()
@export var spacing: int = 4:
	set(value):
		spacing = value
		update_container()
@export var stylebox: StyleBox:
	set(value):
		if value == null:
			stylebox.changed.disconnect(queue_redraw)
			stylebox = value
		elif !value.changed.is_connected(queue_redraw):
			stylebox = value
			stylebox.changed.connect(queue_redraw)
		else:
			stylebox = value
		
		queue_redraw()

enum BoxDirection {
	HORIZONTAL,
	VERTICAL
}

enum Alignment {
	NONE,
	BEGIN,
	CENTER,
	END
}


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	child_order_changed.connect(update_container)
	resized.connect(update_container)
	
	for child in get_children():
		_connect_child_signals(child)


func update_container(_arg = null):
	if is_inside_tree():
		await get_tree().process_frame
		
		var valid_children: Array[Control] = []
		for child in get_children():
			if child is Control and child.visible:
				valid_children.append(child)
				
		if valid_children.is_empty():
			return
			
		var total_children_size: float = 0.0
		if box_direction == BoxDirection.HORIZONTAL:
			for child in valid_children:
				total_children_size += child.size.x
		else:
			for child in valid_children:
				total_children_size += child.size.y
				
		total_children_size += spacing * (valid_children.size() - 1)
		
		var main_offset: float = 0.0
		if box_direction == BoxDirection.HORIZONTAL:
			var remaining_space: float = size.x - total_children_size
			match horizontal_alignment:
				Alignment.CENTER: main_offset = remaining_space / 2.0
				Alignment.END: main_offset = remaining_space
		else:
			var remaining_space: float = size.y - total_children_size
			match vertical_alignment:
				Alignment.CENTER: main_offset = remaining_space / 2.0
				Alignment.END: main_offset = remaining_space
				
		var current_pos: float = main_offset
		for child in valid_children:
			var cross_pos: float = 0.0
			
			if box_direction == BoxDirection.HORIZONTAL:
				var remaining_cross: float = size.y - child.size.y
				match vertical_alignment:
					Alignment.CENTER: cross_pos = remaining_cross / 2.0
					Alignment.END: cross_pos = remaining_cross
				
				if horizontal_alignment != Alignment.NONE:
					child.position.x = current_pos
				if vertical_alignment != Alignment.NONE:
					child.position.y = cross_pos
					
				current_pos += (spacing + child.size.x)
				
			elif box_direction == BoxDirection.VERTICAL:
				var remaining_cross: float = size.x - child.size.x
				match horizontal_alignment:
					Alignment.CENTER: cross_pos = remaining_cross / 2.0
					Alignment.END: cross_pos = remaining_cross
				
				if vertical_alignment != Alignment.NONE:
					child.position.y = current_pos
				if horizontal_alignment != Alignment.NONE:
					child.position.x = cross_pos
					
				current_pos += (spacing + child.size.y)


func _on_child_entered_tree(child: Node):
	_connect_child_signals(child)


func _on_child_exiting_tree(child: Node):
	_disconnect_child_signals(child)


func _connect_child_signals(child: Node):
	if child is CanvasItem:
		if !child.visibility_changed.is_connected(update_container):
			child.visibility_changed.connect(update_container)
		
		if child is Control:
			if !child.resized.is_connected(update_container):
				child.resized.connect(update_container)


func _disconnect_child_signals(child: Node):
	if child is CanvasItem:
		if child.visibility_changed.is_connected(update_container):
			child.visibility_changed.disconnect(update_container)
		
		if child is Control:
			if child.resized.is_connected(update_container):
				child.resized.disconnect(update_container)


func _draw() -> void:
	if is_instance_valid(stylebox):
		draw_style_box(stylebox, Rect2(Vector2.ZERO, size))
