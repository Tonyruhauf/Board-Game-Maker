class_name CardData extends Resource


@export var front_texture: Texture2D
@export var back_texture: Texture2D

@export_group("Dimensions")
@export var size: Vector2 = Vector2(140, 200)
@export var scale: Vector2 = Vector2(1.0, 1.0)

enum Side {
	FRONT,
	BACK
}
