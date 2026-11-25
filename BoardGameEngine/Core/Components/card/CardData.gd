class_name CardData extends Resource


@export var front_texture: Texture2D
@export var back_texture: Texture2D

@export_group("Dimensions")
@export var size: Vector2 = Vector2(140, 200)
@export var scale: Vector2 = Vector2(1.0, 1.0)

@export_group("Behavior")
@export var hand_flip_preference: HandFlipPreference = HandFlipPreference.FLIP_TO_FRONT

enum Side {
	FRONT,
	BACK
}

enum HandFlipPreference {
	NEVER_FLIP,
	ALWAYS_FLIP,
	FLIP_TO_FRONT,
	FLIP_TO_BACK
}
