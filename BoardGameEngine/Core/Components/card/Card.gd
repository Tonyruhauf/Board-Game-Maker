class_name Card extends StackableBoardObject


@export var data: CardData
@export var is_front_up: bool = true


func _ready() -> void:
	super()
	
	shadow.object_thickness = 2.0
	
	_update_size()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	position += -size / 2
	_update_texture()


func _update_size() -> void:
	var ref_texture = data.front_texture if data.front_texture else data.back_texture
	if ref_texture:
		var tex_size = ref_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			# Scale uniformly to fit within max_size while maintaining aspect ratio
			var scale_factor = min(data.size.x / tex_size.x, data.size.y / tex_size.y)
			size = tex_size * scale_factor
		else:
			size = data.size
	else:
		size = data.size


func _update_texture() -> void:
	texture = data.front_texture if is_front_up else data.back_texture


func request_flip() -> void:
	var action: GameAction = FlipCardAction.new(
		GameService.local_player.ID,
		id,
		CardData.Side.BACK if is_front_up else CardData.Side.FRONT
	)
	game.request_action(action)


func _flip(specific_side: bool = false, side: CardData.Side = CardData.Side.FRONT) -> void:
	if specific_side:
		is_front_up = (side == CardData.Side.FRONT)
	else:
		is_front_up = !is_front_up
	_update_texture()


func is_flippable() -> bool:
	return true
