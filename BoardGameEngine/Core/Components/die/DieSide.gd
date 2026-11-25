@tool
class_name DieSide extends Resource


## An optional identifier for this side.
@export var side_name: String:
	set(value):
		side_name = value

## Leave empty for no image.
@export var image: Texture2D:
	set(value):
		image = value
		emit_changed()

## Leave empty for no text.
@export var text: String:
	set(value):
		if side_name == text:
			side_name = value
		text = value
		emit_changed()

## When set to true, 0-9 are drawn as pips.
@export var use_pips: bool = true:
	set(value):
		use_pips = value
		emit_changed()
