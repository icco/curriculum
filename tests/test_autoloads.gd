extends TestCase

## The autoloads exist under the names the brief asks for, but hold no rules. A test
## that needs a Run constructs one directly; nothing here resets a global — but this
## suite still cleans up any save file it creates, since GameManager.abandon() writes
## through to disk and a leftover file would leak into later suites (test_save runs
## right after this one, alphabetically).


func suite_name() -> String:
	return "autoloads"


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	check(library != null, "content library loads")
	if library == null:
		return
	check(library.cards.size() > 0, "library indexes cards")
	check(library.starting_deck.size() > 0, "library declares a starting deck")
	var spark := library.card_named("Spark")
	check(spark != null, "found spark by name")
	if spark != null:
		eq(spark.card_name, "Spark", "card_named returns the card actually named Spark")
	eq(library.card_named("Nonexistent"), null, "missing card is null")

	# The library indexes the one enemy resource that exists so far (novice.tres),
	# so enemy_named gets a real hit to pin, not just a miss that a `return null`
	# stub would also satisfy.
	var novice := library.enemy_named("Novice")
	check(novice != null, "found novice by name")
	if novice != null:
		eq(novice.enemy_name, "Novice", "enemy_named returns the enemy actually named Novice")
	eq(library.enemy_named("Nonexistent"), null, "missing enemy is null")

	# No course resources exist yet (Task 16 generates them), so course_named has no
	# hit to pin and catalog().available({}) has nothing to return either way — both
	# assertions below cannot fail against a `return null` / `return []` stub and are
	# kept only as a placeholder pinned once course content lands.
	eq(library.course_named("Nonexistent"), null, "missing course is null (unable to fail: no courses exist yet)")
	var catalog := library.catalog()
	check(catalog != null, "catalog() builds a Catalog")
	eq(
		catalog.available({}),
		[],
		"empty course list has nothing available yet (unable to fail: no courses exist yet)"
	)

	# GradeManager is stateless: pin the forward against calling Grading directly with
	# the same params, not just against the known S outcome, so a forward that mutates
	# or drops a param before calling Grading cannot pass by accident.
	var params := {
		"won": true,
		"turns_taken": 5,
		"par_turns": 5,
		"hp_end": 60,
		"hp_start": 60,
		"xp_banked": 15,
		"xp_par": 15,
		"weakness_known": true,
		"distinct_schools": 5,
	}
	var scored: Dictionary = GradeManager.score(params)
	eq(scored, Grading.score(params), "GradeManager.score forwards params unchanged to Grading")
	eq(scored["grade"], Grading.Grade.S, "forwarded to Grading")
	almost(scored["total"], 100.0, "pinned the total, not just the resulting letter grade")

	for grade in [
		Grading.Grade.S, Grading.Grade.A, Grading.Grade.B, Grading.Grade.C, Grading.Grade.F
	]:
		eq(
			GradeManager.letter(grade),
			Grading.letter(grade),
			"letter forwarded for grade %d" % grade
		)
		eq(
			GradeManager.draft_allowance(grade),
			Grading.draft_allowance(grade),
			"draft_allowance forwarded for grade %d" % grade
		)

	# GameManager holds the current Run and forwards to it, and abandon() must remove
	# any save file, not merely clear the in-memory reference.
	SaveGame.delete()
	GameManager.abandon()
	eq(GameManager.run, null, "no run after abandoning")
	eq(GameManager.strikes(), 0, "strikes with no run is zero")
	eq(GameManager.deck_cap(), Draft.BASE_CAP, "deck_cap with no run falls back to the base cap")

	GameManager.start_new_run(library)
	check(GameManager.run != null, "started a run")
	if GameManager.run != null:
		eq(GameManager.run.deck.size(), library.starting_deck.size(), "dealt the starting deck")
	eq(GameManager.strikes(), 0, "fresh run has no strikes")

	# THE CORE INVARIANT: two runs must never share a CardInstance, or xp earned in one
	# run silently carries into the next. Train the first run's opening card, start a
	# second run from the same library, and check the new run's card is a distinct,
	# untrained object rather than the same wrapper (or the library's raw CardData).
	var first_deck: Array = GameManager.run.deck
	neq(
		first_deck[0],
		library.starting_deck[0],
		"run deck holds CardInstance wrappers, not the library's raw CardData"
	)
	first_deck[0].gain_xp(3)
	eq(first_deck[0].xp, 3, "trained the first run's opening card")
	GameManager.start_new_run(library)
	var second_deck: Array = GameManager.run.deck
	neq(second_deck[0], first_deck[0], "second run dealt a different CardInstance than the first")
	eq(
		second_deck[0].xp,
		0,
		"second run's card is untrained despite the first run's card gaining xp"
	)

	eq(GameManager.save(), true, "save wrote to disk")
	check(SaveGame.has_save(), "save file exists after GameManager.save()")
	GameManager.abandon()
	eq(GameManager.run, null, "abandon cleared the run")
	eq(SaveGame.has_save(), false, "abandon deleted the save file, not just the in-memory run")

	eq(GameManager.save(), false, "save with no run returns false and writes nothing")
	eq(SaveGame.has_save(), false, "no run means no file materialises")

	# DeckManager holds the current battle piles and forwards to them.
	eq(DeckManager.deck, null, "no battle before begin_battle")
	eq(DeckManager.hand(), [], "hand with no battle is empty, not a crash")
	GameManager.start_new_run(library)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	DeckManager.begin_battle(GameManager.run.deck, rng)
	check(DeckManager.deck != null, "battle deck built")
	if DeckManager.deck != null:
		eq(DeckManager.deck.total(), GameManager.run.deck.size(), "all cards in the piles")
		eq(DeckManager.hand(), DeckManager.deck.hand, "hand() forwards to the live deck's hand")
	DeckManager.end_battle()
	eq(DeckManager.deck, null, "end_battle clears the battle")
	eq(DeckManager.hand(), [], "hand with no battle is empty again after end_battle")

	GameManager.abandon()
	eq(SaveGame.has_save(), false, "suite leaves no save file behind")
