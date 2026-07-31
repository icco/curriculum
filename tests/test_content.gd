extends TestCase

## Content integrity across the whole card set. These checks are what make it safe to
## add a card by adding a .tres.


func suite_name() -> String:
	return "content"


func _library() -> ContentLibrary:
	return load("res://resources/content_library.tres")


func run() -> void:
	var library := _library()
	check(library != null, "content library loads")
	if library == null:
		return

	eq(library.cards.size(), 48, "twenty-four base cards plus twenty-four evolutions")

	var base_count := 0
	var names := {}
	for card in library.cards:
		check(card != null, "no null card in the library")
		if card == null:
			continue
		check(card.card_name != "", "every card is named")
		check(not names.has(card.card_name), "card name %s is unique" % card.card_name)
		names[card.card_name] = true
		check(card.cost >= 0 and card.cost <= 3, "%s costs 0-3" % card.card_name)
		check(card.effects.size() > 0, "%s does something" % card.card_name)
		check(card.art_id != "", "%s declares an art id" % card.card_name)
		for effect in card.effects:
			check(effect.has("kind"), "%s effect declares a kind" % card.card_name)
		if not card.is_fully_evolved():
			base_count += 1
			neq(card.evolved_card, card, "%s does not evolve into itself" % card.card_name)
			check(
				card.evolved_card.is_fully_evolved(),
				"%s evolves into a terminal card" % card.card_name
			)
			eq(card.school, card.evolved_card.school, "%s keeps its school" % card.card_name)
			eq(
				card.art_id,
				card.evolved_card.art_id,
				"%s shares art with its evolution" % card.card_name
			)
	eq(base_count, 24, "exactly twenty-four cards can evolve")

	# Every .tres under resources/ must load, including any the library does not index.
	# `--import` scans assets but does not eagerly load an unreferenced .tres, so a
	# broken orphan is invisible to check.sh's import step and only this walk finds it.
	for dir_name in ["cards", "enemies", "courses"]:
		var dir := DirAccess.open("res://resources/%s" % dir_name)
		check(dir != null, "resources/%s exists" % dir_name)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			var path := "res://resources/%s/%s" % [dir_name, file]
			check(load(path) != null, "%s loads" % path)

	# Status effects must name a real Statuses.Kind. The generator hardcodes the enum
	# values as integers, so nothing else would notice them drifting out of order and
	# silently applying Chill where Burn was meant.
	var valid_kinds := Statuses.Kind.values()
	for card in library.cards:
		for effect in card.effects:
			if effect.get("kind", "") != CardData.STATUS:
				continue
			check(effect.has("status"), "%s status effect names a kind" % card.card_name)
			check(
				effect.get("status", -1) in valid_kinds,
				"%s status %s is a real Statuses.Kind" % [card.card_name, effect.get("status", -1)]
			)

	# Every school must be a real Schools.School value. The generator hardcodes the
	# enum values as integers rather than referencing Schools.School, so a reordered
	# enum would silently reassign every card's school without this check noticing.
	var valid_schools := Schools.ALL
	for card in library.cards:
		check(
			card.school in valid_schools,
			"%s school %s is a real Schools.School" % [card.card_name, card.school]
		)

	# Every school is represented, or a deck cannot be built in it.
	var by_school := {}
	for card in library.cards:
		by_school[card.school] = int(by_school.get(card.school, 0)) + 1
	eq(by_school.size(), 5, "all five schools have cards")

	# Spot-check the table against the spec.
	var spark := library.card_named("Spark")
	check(spark != null, "spark exists")
	if spark != null:
		eq(spark.cost, 1, "spark costs one")
		eq(spark.effects[0]["amount"], 6, "spark deals six")
		eq(spark.evolved_card.card_name, "Ember Lance", "spark evolves into ember lance")
		eq(spark.evolved_card.effects[0]["amount"], 10, "ember lance deals ten")

	# The starting deck is the ten cards the spec names.
	eq(library.starting_deck.size(), 10, "ten starting cards")
	var starting := {}
	for card in library.starting_deck:
		starting[card.card_name] = int(starting.get(card.card_name, 0)) + 1
	eq(starting.get("Spark", 0), 4, "four sparks")
	eq(starting.get("Guard", 0), 4, "four guards")
	eq(starting.get("Ink Blot", 0), 2, "two ink blots")
