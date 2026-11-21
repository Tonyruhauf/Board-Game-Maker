@tool
class_name DieData extends Resource

@export var die_name: String
@export_enum("D4:4", "D6:6", "D8:8", "D10:10", "D12:12", "D20:20") var die_type: int = 6:
	set(value):
		die_type = value
		emit_changed()
@export var sides: Array[DieSide]:
	set(value):
		if not value.is_empty() and value[-1] == null:
			value[-1] = DieSide.new()
			value[-1].changed.connect(_on_side_changed)
		sides = value
		emit_changed()

@export_group("Colors")
@export var body_color := Color("ffffffff"):
	set(value):
		body_color = value
		emit_changed()
@export var pip_color := Color("000000ff"):
	set(value):
		pip_color = value
		emit_changed()


func _on_side_changed():
	emit_changed()
