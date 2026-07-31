extends TestCase

## A full scripted run: pick an available course, fight it with a greedy policy,
## grade it, draft, repeat until the run ends. Catches integration breaks that no
## unit suite does.


func suite_name() -> String:
	return "playthrough"


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var game := Run.new(library.new_starting_deck())
	var catalog := library.catalog()

	var battles := 0
	while not game.is_over() and battles < 30:
		var open := catalog.available(game.grades)
		if open.is_empty():
			break
		var course = open[0]
		var battle := Battle.new(game.deck, course.examiner, game.bestiary, rng)
		battle.start()

		# Greedy policy: play whatever is affordable, then end the turn.
		var guard := 0
		while not battle.finished and guard < 200:
			guard += 1
			var played := false
			for card in battle.player_deck.hand.duplicate():
				if battle.can_play(card):
					battle.play_card(card)
					played = true
					if battle.finished:
						break
			if battle.finished:
				break
			if not played or battle.player.mana <= 0:
				battle.end_turn()
		check(guard < 200, "battle terminated rather than looping")
		check(battle.finished, "battle reached an end state")

		var scored: Dictionary = Grading.score(
			{
				"won": battle.player_won,
				"turns_taken": battle.turns,
				"par_turns": course.par_turns,
				"hp_end": battle.player.hp,
				"hp_start": Run.STARTING_HP,
				"xp_banked": battle.xp_banked,
				"xp_par": course.xp_par,
				"weakness_known": game.bestiary.knows_weakness(course.examiner.enemy_name),
				"distinct_schools": battle.schools_played(),
			}
		)
		var result := game.record_result(course, scored["grade"], battle.player.hp)

		if not game.is_over() and battle.player_won:
			var draft := Draft.new(game.deck, course.examiner.deck, course.guaranteed_card_drop, scored["grade"])
			draft.cap = game.deck_cap()
			# Keep the cap's worth, preferring offered cards then own.
			var selection: Array = []
			for card in draft.offered:
				if selection.size() < draft.cap:
					selection.append(card)
			for card in draft.own:
				if selection.size() < draft.cap:
					selection.append(card)
			var kept := draft.keep(selection)
			check(kept.size() == draft.cap, "draft returned a legal deck of %d" % draft.cap)
			if kept.size() == draft.cap:
				game.deck = kept
		battles += 1

	check(battles > 0, "fought at least one battle")
	check(game.is_over() or catalog.available(game.grades).is_empty(), "run reached a terminal state")
	# The deck never exceeds its cap, however the run went.
	check(game.deck.size() <= 16, "deck stayed within the cap")
	print("    playthrough: %d battles, %d strikes, won=%s" % [battles, game.strikes, game.won])
