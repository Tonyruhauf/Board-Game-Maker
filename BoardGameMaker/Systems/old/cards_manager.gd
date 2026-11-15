extends Node
## Autoload (Project Settings > Globals) with the name "CardsManager".
## Do NOT add a class_name here, it would clash with the autoload name.

signal card_dropped(card: Card)

var dragged_card: Card = null  # the card currently held by the mouse, if any


# Creates a pile with the cards of the deck in random order.
# cards_count <= 0 means "use all the cards of the deck".
func create_card_pile(deck: Deck, cards_count := -1, front_side := false) -> CardPile:
	var fronts := deck.front_textures.duplicate()
	fronts.shuffle()
	if cards_count > 0:
		fronts.resize(mini(cards_count, fronts.size()))

	var pile := CardPile.new()
	get_tree().current_scene.add_child(pile)

	for front in fronts:
		var card := Card.new()
		card.setup(front, deck.back_texture, front_side)
		pile.add_card(card)

	return pile
