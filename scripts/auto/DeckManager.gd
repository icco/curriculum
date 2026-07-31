extends Node

## Holds the current battle's piles and forwards to them.

var deck: Deck = null


func begin_battle(cards: Array, rng: RandomNumberGenerator = null) -> Deck:
	deck = Deck.new(cards, rng)
	return deck


func end_battle() -> void:
	deck = null


func hand() -> Array:
	return [] if deck == null else deck.hand
