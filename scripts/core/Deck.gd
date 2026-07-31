class_name Deck
extends RefCounted

## The four battle piles. Holds the same CardInstance objects as the run deck, so
## XP earned mid-battle is already banked on the run's cards when the battle ends.

const HAND_SIZE := 5

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhausted: Array[CardInstance] = []

var _rng: RandomNumberGenerator


func _init(cards: Array, rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	for card in cards:
		draw_pile.append(card)
	shuffle_draw_pile()


## Fisher-Yates against our own RNG, so a seeded test shuffles reproducibly.
func shuffle_draw_pile() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = swap


func draw(count: int) -> Array:
	var drawn := []
	for _i in count:
		if draw_pile.is_empty():
			reshuffle()
		if draw_pile.is_empty():
			break  # nothing left anywhere; do not spin
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
	return drawn


func reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw_pile()


## End of turn: unplayed cards go to the discard, retained cards stay in hand.
func discard_hand() -> Array:
	var discarded := []
	var kept: Array[CardInstance] = []
	for card in hand:
		if card.data.retain:
			kept.append(card)
		else:
			discard_pile.append(card)
			discarded.append(card)
	hand = kept
	return discarded


func play(card: CardInstance) -> void:
	hand.erase(card)
	if card.data.exhaust:
		exhausted.append(card)
	else:
		discard_pile.append(card)


func total() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhausted.size()
