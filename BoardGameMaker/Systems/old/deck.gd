class_name Deck
extends Resource
## A deck is just data: one back image, and one front image per card.
## Create it in the FileSystem dock: right click > New Resource > Deck.

@export var back_texture: Texture2D
@export var front_textures: Array[Texture2D]
