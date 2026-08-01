extends TestCase

## SaveGame round-trips a Run through user://. The central risk is per-card XP: a
## save that writes the right total but attaches it to the wrong card silently
## un-trains the player's deck while looking intact, so this suite builds a deck
## whose cards all differ (in XP and in evolution state) and checks each by
## position, not by sum.


func suite_name() -> String:
	return "save"


func _course(name: String, is_final := false) -> CourseData:
	var c := CourseData.new()
	c.course_name = name
	c.is_final = is_final
	return c


func run() -> void:
	SaveGame.delete()
	eq(SaveGame.has_save(), false, "no save to begin with")
	eq(SaveGame.load_run(), null, "loading nothing returns null")

	var spark: CardData = load("res://resources/cards/spark.tres")
	var novice: EnemyData = load("res://resources/enemies/novice.tres")

	# Three cards, three different fates: untouched, evolved, lightly trained. A bug
	# that swapped which card got which XP, or that mapped every card to the same
	# resource, shows up here because the three are mutually distinguishable.
	var r := Run.new([CardInstance.new(spark), CardInstance.new(spark), CardInstance.new(spark)])
	for i in 3:
		r.deck[0].gain_xp()
	for i in 5:
		r.deck[1].gain_xp()  # xp_to_evolve is 5: this evolves into Ember Lance
	r.deck[2].gain_xp()
	r.max_hp = 75  # non-default, so a save that never wrote max_hp cannot pass by luck

	eq(r.deck[0].data.card_name, "Spark", "card 0 not evolved before saving")
	eq(r.deck[1].data.card_name, "Ember Lance", "card 1 evolved before saving")
	eq(r.deck[2].data.card_name, "Spark", "card 2 not evolved before saving")

	# A strike and a pass, in that order, so the final hp/courses_passed/strikes are
	# all distinguishable from their constructor defaults and from each other, and
	# grades ends up with two entries at two different values.
	r.record_result(_course("Remedial Wards"), Grading.Grade.F, 99)
	r.record_result(_course("Basic Arcana 101"), Grading.Grade.A, 42)

	# Both a weakness and a ward, so a key/value mix-up between the two dictionaries
	# inside Bestiary.to_dict() is visible.
	r.bestiary.record_hit(novice, novice.weak_school)
	r.bestiary.record_hit(novice, novice.warded_school)

	eq(SaveGame.save(r), true, "saved")
	eq(SaveGame.has_save(), true, "save exists")

	var back: Run = SaveGame.load_run()
	check(back != null, "loaded")
	if back == null:
		return

	# 42 survived plus the A's recovery against this run's non-default 75 max. Derived
	# rather than hardcoded: this suite is about the save round-tripping the value,
	# not about what the value should be.
	var expected_hp := 42 + int(roundf(Grading.recovery_fraction(Grading.Grade.A) * 75.0))
	eq(back.hp, expected_hp, "hp restored")
	eq(back.max_hp, 75, "max_hp restored at a non-default value")
	eq(back.strikes, 1, "strikes restored at a non-default value")
	eq(back.courses_passed, 1, "courses_passed restored at a non-default value")
	eq(back.grades["Remedial Wards"], Grading.Grade.F, "F grade restored")
	eq(back.grades["Basic Arcana 101"], Grading.Grade.A, "A grade restored")
	eq(back.deck.size(), 3, "deck size restored")
	eq(back.bestiary.knows_weakness("Novice"), true, "weakness restored")
	eq(back.bestiary.knows_ward("Novice"), true, "ward restored")

	# THE POINT OF THIS SUITE: each card's own XP and evolution state must survive,
	# attached to the right card, or a reload silently un-trains the player's deck.
	eq(back.deck[0].xp, 3, "card 0 kept its own xp")
	eq(back.deck[0].data.card_name, "Spark", "card 0 reloaded unevolved")
	eq(back.deck[1].xp, 0, "card 1 xp reset by evolution")
	eq(back.deck[1].data.card_name, "Ember Lance", "card 1 reloaded already evolved")
	eq(back.deck[2].xp, 1, "card 2 kept its own xp")
	eq(back.deck[2].data.card_name, "Spark", "card 2 reloaded unevolved")

	SaveGame.delete()

	# expelled is only reachable at MAX_STRIKES; check it round-trips true, not just
	# non-false-by-coincidence.
	var expelled_run := Run.new([CardInstance.new(spark)])
	expelled_run.record_result(_course("Intro Hexes"), Grading.Grade.F, 1)
	expelled_run.record_result(_course("Intro Hexes Retake"), Grading.Grade.F, 1)
	eq(expelled_run.expelled, true, "expelled before saving")
	eq(expelled_run.strikes, 2, "two strikes before saving")
	SaveGame.save(expelled_run)
	var expelled_back: Run = SaveGame.load_run()
	check(expelled_back != null, "expelled run loaded")
	if expelled_back != null:
		eq(expelled_back.expelled, true, "expelled restored")
		eq(expelled_back.strikes, 2, "strikes restored at max")
	SaveGame.delete()

	# won is only reachable by passing an is_final course; check it round-trips true.
	var won_run := Run.new([CardInstance.new(spark)])
	won_run.record_result(_course("Comprehensive Exam", true), Grading.Grade.S, 50)
	eq(won_run.won, true, "won before saving")
	SaveGame.save(won_run)
	var won_back: Run = SaveGame.load_run()
	check(won_back != null, "won run loaded")
	if won_back != null:
		eq(won_back.won, true, "won restored")
	SaveGame.delete()
	eq(SaveGame.has_save(), false, "delete removed it")

	# A deck entry whose resource no longer exists must be skipped, not turned into a
	# null in the deck — the deck should come back shorter, never nulled.
	var partial := {
		"version": 1,
		"hp": 10,
		"max_hp": 60,
		"strikes": 0,
		"courses_passed": 0,
		"expelled": false,
		"won": false,
		"grades": {},
		"deck": [
			{"path": "res://resources/cards/spark.tres", "xp": 2},
			{"path": "res://resources/cards/does_not_exist.tres", "xp": 9},
		],
		"bestiary": {"weaknesses": {}, "wards": {}},
	}
	var pf := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	pf.store_string(JSON.stringify(partial))
	pf.close()
	var partial_back := SaveGame.load_run()
	check(partial_back != null, "save with one bad path still loads")
	if partial_back != null:
		eq(partial_back.deck.size(), 1, "missing resource path skipped, deck shorter not nulled")
		if partial_back.deck.size() == 1:
			eq(partial_back.deck[0].xp, 2, "surviving card kept its own xp")
	SaveGame.delete()

	# A corrupt (unparseable) file does not crash the game.
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	eq(SaveGame.load_run(), null, "corrupt save loads as null")
	SaveGame.delete()

	# Valid JSON that parses to something other than a Dictionary (e.g. a bare array)
	# must also load as null, not crash trying to .get() off it.
	var nf := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	nf.store_string(JSON.stringify([1, 2, 3]))
	nf.close()
	eq(SaveGame.load_run(), null, "non-dictionary json loads as null")
	SaveGame.delete()
	eq(SaveGame.has_save(), false, "no save left behind")
