extends TestCase

## BattleScreen wires a Battle to the shared UI widgets and replays the event arrays
## Battle returns. It must never recompute a rule or mutate the battle. There is no
## telegraph of the examiner's next move, so the log has to say who an event affected
## rather than leaving the player to guess.
##
## Every assertion here is checked in both directions where the property can flip
## (dimmed/not-dimmed), so a check that always passes trivially cannot hide behind one
## that happens to be true right now.


func suite_name() -> String:
	return "battlescreen"


func _card(name: String, school, cost: int, effects: Array) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = school
	d.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	d.effects = typed
	d.art_id = "cards/%s" % name.to_lower()
	return d


func _enemy(hp: int, deck: Array) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = "Proctor"
	e.max_hp = hp
	e.mana_per_turn = 2
	var typed: Array[CardData] = []
	for c in deck:
		typed.append(c)
	e.deck = typed
	e.weak_school = Schools.School.ROT
	e.warded_school = Schools.School.FROST
	e.art_id = "entities/proctor"
	return e


## Only buttons and CardViews may take taps; every other Control anywhere in the
## screen's tree must ignore the mouse, or it silently eats a tap meant for the
## board beneath it.
func _assert_filters(node: Node) -> void:
	for child in node.get_children():
		if child is Button or child is CardView:
			eq(child.mouse_filter, Control.MOUSE_FILTER_STOP, "%s takes taps" % child.get_class())
		elif child is Control:
			eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % child.get_class())
		_assert_filters(child)


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var deck := library.new_starting_deck()
	var fight := Battle.new(deck, library.enemies[0], Bestiary.new(), rng)
	var screen := BattleScreen.new()
	screen.size = Vector2(1080, 1920)
	screen.begin(fight)

	# The screen itself never eats a tap meant for the board.
	eq(screen.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the screen does not eat taps")

	check(screen.hand_fan != null, "built a hand fan")
	eq(screen.hand_fan.get_child_count(), 5, "showed the five drawn cards")

	# Not just a count: the fan must show exactly the cards Battle actually drew,
	# in the same order, not merely five CardViews of arbitrary cards.
	var shown: Array = []
	for child in screen.hand_fan.get_children():
		var view: CardView = child
		shown.append(view.card)
	eq(shown, fight.player_deck.hand, "the fan shows exactly, and only, the drawn hand")

	check(screen.end_turn_button != null, "built an end-turn button")
	eq(screen.end_turn_button.mouse_filter, Control.MOUSE_FILTER_STOP, "the button takes taps")

	# No container anywhere in the tree eats a tap; only the button and the cards do.
	_assert_filters(screen)

	# There is no telegraph of the examiner's next move — the fight is a genuine
	# unknown, so the player's only information is the log and their own state.
	# The examiner's own hit points and any statuses it carries must be visible.
	check(screen.examiner_hp_label.text.length() > 0, "the examiner's hp is shown")
	check(screen.player_hp_label.text.length() > 0, "the player's hp is shown")

	# Replaying events writes them to the log rather than touching core state — proven
	# in both directions: the log actually changes, and the battle actually does not.
	var before_hp := fight.examiner.hp
	var before_log := screen.log_label.text
	screen.replay(
		[{"type": "damage", "target": "examiner", "amount": 3, "text": "3 damage, fabricated"}]
	)
	eq(fight.examiner.hp, before_hp, "replaying a fabricated event does not mutate the battle")
	neq(screen.log_label.text, before_log, "the log actually changed")
	check(screen.log_label.text.contains("3 damage, fabricated"), "logged the event text")
	check(
		screen.log_label.text.contains(fight.examiner.display_name),
		"a damage event names who it happened to"
	)

	# The same damage event aimed at the player instead must say "You", not the
	# examiner's name — proven in both directions so this cannot pass because every
	# event is always labelled the same way regardless of its target.
	screen.replay(
		[{"type": "damage", "target": "player", "amount": 4, "text": "4 damage, fabricated"}]
	)
	check(screen.log_label.text.contains("You: 4 damage, fabricated"), "damage to the player says You")

	# Some damage events (start-of-turn Burn) carry an amount but text with no
	# number in it at all -- the log must still say how much, not just who.
	screen.replay([{"type": "damage", "target": "player", "amount": 5, "text": "Burn"}])
	check(screen.log_label.text.contains("You: Burn 5"), "a numberless damage event still shows its amount")

	# Affordability dims a card — checked both ways, so this cannot pass because a
	# CardView is always dimmed (or never dimmed) regardless of mana.
	fight.player.mana = 3
	screen.refresh()
	var any_dimmed_with_mana := false
	for child in screen.hand_fan.get_children():
		if child.modulate.a < 1.0:
			any_dimmed_with_mana = true
	eq(any_dimmed_with_mana, false, "with full mana, nothing needs to be dimmed")

	fight.player.mana = 0
	screen.refresh()
	var any_dimmed_without_mana := false
	for child in screen.hand_fan.get_children():
		if child.modulate.a < 1.0:
			any_dimmed_without_mana = true
	eq(any_dimmed_without_mana, true, "unaffordable cards dim with no mana")

	screen.free()

	# Playing a lethal card through the real signal path (not by calling a private
	# method directly) ends the battle, disables the end-turn button, and emits
	# battle_finished exactly once — proving the screen only reacts to what Battle
	# already decided.
	var lethal := _card("Lethal", Schools.School.CINDER, 0, [{"kind": CardData.DAMAGE, "amount": 999}])
	var poke := _card("Poke", Schools.School.INK, 1, [{"kind": CardData.DAMAGE, "amount": 1}])
	var weak_rng := RandomNumberGenerator.new()
	weak_rng.seed = 7
	var weak_fight := Battle.new(
		[CardInstance.new(lethal)], _enemy(5, [poke]), Bestiary.new(), weak_rng
	)
	var finish_screen := BattleScreen.new()
	finish_screen.size = Vector2(1080, 1920)
	finish_screen.begin(weak_fight)

	var finished_battles: Array = []
	finish_screen.battle_finished.connect(func(b): finished_battles.append(b))

	check(finish_screen.hand_fan.get_child_count() > 0, "the lethal card was drawn")
	var lethal_view: CardView = finish_screen.hand_fan.get_children()[0]
	finish_screen.hand_fan.card_play_requested.emit(lethal_view.card)

	eq(weak_fight.finished, true, "the battle ended")
	eq(finished_battles.size(), 1, "battle_finished fired exactly once")
	eq(
		finish_screen.end_turn_button.disabled,
		true,
		"the end-turn button is disabled once the battle is over"
	)

	finish_screen.free()
