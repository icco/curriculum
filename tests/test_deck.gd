extends TestCase

## Draw, reshuffle, retain and exhaust. Every test seeds its own RNG so shuffles
## are reproducible.


func suite_name() -> String:
	return "deck"


func _card(name: String, retain := false, exhaust := false) -> CardInstance:
	var data := CardData.new()
	data.card_name = name
	data.retain = retain
	data.exhaust = exhaust
	return CardInstance.new(data)


func _cards(n: int) -> Array:
	var out := []
	for i in n:
		out.append(_card("c%d" % i))
	return out


func _deck(cards: Array) -> Deck:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	return Deck.new(cards, rng)


func run() -> void:
	eq(Deck.HAND_SIZE, 5, "hand size is five")

	# Drawing moves cards from the draw pile to the hand and conserves the total.
	var deck := _deck(_cards(10))
	eq(deck.total(), 10, "ten cards in")
	eq(deck.draw(5).size(), 5, "drew five")
	eq(deck.hand.size(), 5, "five in hand")
	eq(deck.draw_pile.size(), 5, "five left to draw")
	eq(deck.total(), 10, "total conserved")

	# An empty draw pile reshuffles the discard rather than starving.
	var small := _deck(_cards(3))
	small.draw(3)
	small.discard_hand()
	eq(small.draw_pile.size(), 0, "draw pile empty before reshuffle")
	eq(small.discard_pile.size(), 3, "three discarded")
	var drawn := small.draw(2)
	eq(drawn.size(), 2, "reshuffled and drew two")
	eq(small.discard_pile.size(), 0, "discard consumed by reshuffle")
	eq(small.total(), 3, "reshuffle conserves cards")

	# Drawing more than exists stops rather than looping forever.
	var tiny := _deck(_cards(2))
	eq(tiny.draw(5).size(), 2, "draws only what exists")

	# Unplayed cards discard at end of turn; retained cards stay in hand.
	var mixed := _deck([_card("keep", true), _card("drop"), _card("drop2")])
	mixed.draw(3)
	var discarded := mixed.discard_hand()
	eq(discarded.size(), 2, "two discarded")
	eq(mixed.hand.size(), 1, "retained card stayed")
	eq(mixed.hand[0].data.card_name, "keep", "the retained one")

	# Playing a card discards it; an exhaust card leaves play for the battle.
	var play_deck := _deck([_card("normal"), _card("burner", false, true)])
	play_deck.draw(2)
	var normal: CardInstance = null
	var burner: CardInstance = null
	for card in play_deck.hand:
		if card.data.card_name == "normal":
			normal = card
		else:
			burner = card
	play_deck.play(normal)
	eq(play_deck.discard_pile.size(), 1, "played card discarded")
	play_deck.play(burner)
	eq(play_deck.exhausted.size(), 1, "exhaust card set aside")
	eq(play_deck.discard_pile.size(), 1, "exhaust did not reach the discard")
	play_deck.reshuffle()
	eq(play_deck.draw_pile.size(), 1, "exhausted card is not reshuffled")
	eq(play_deck.total(), 2, "exhausted cards still count toward the total")

	# The piles hold the SAME CardInstance objects passed in, not duplicates. XP
	# earned mid-battle must land on the run's own card object.
	var source_cards := _cards(2)
	var identity_deck := _deck(source_cards)
	identity_deck.draw(2)
	identity_deck.hand[0].xp = 3
	var found_xp := false
	for c in source_cards:
		if c.xp == 3:
			found_xp = true
	check(found_xp, "xp gained on a drawn card is visible on the original instance")

	# The shuffle must run off the injected RNG, or a seeded run is not reproducible.
	var order_a := []
	for c in _deck(_cards(10)).draw(10):
		order_a.append(c.data.card_name)
	var order_b := []
	for c in _deck(_cards(10)).draw(10):
		order_b.append(c.data.card_name)
	eq(order_a, order_b, "same seed draws the same order")

	var rng_c := RandomNumberGenerator.new()
	rng_c.seed = 999
	var order_c := []
	for c in Deck.new(_cards(10), rng_c).draw(10):
		order_c.append(c.data.card_name)
	neq(order_c, order_a, "a different seed draws a different order")
