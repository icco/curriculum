extends TestCase

## Content integrity across the whole card set. These checks are what make it safe to
## add a card by adding a .tres.


## A maxed deck's whole turn (3 mana) should land around 45-50 direct damage,
## not one-shot a properly-statted boss. This is the per-card half of that
## budget, checked independently of tools/generate_content.gd's own
## enforcement — Bitter Recall's level5 form once reached 3 casts x 29 damage
## = 87 from a single 1-cost card before that generator-side fix landed.
const TURN_DAMAGE_CAP := 50


func suite_name() -> String:
	return "content"


func _library() -> ContentLibrary:
	return load("res://resources/content_library.tres")


## Same-turn direct damage only (Burn/Decay pay out over several turns, a
## different balance question from one turn's burst) x however many times one
## copy can be cast on 3 mana (1, if exhaust or free).
func _turn_ceiling(card: CardData) -> int:
	var per_cast := 0
	for effect in card.effects:
		var kind: String = effect.get("kind", "")
		if kind == CardData.DAMAGE or kind == CardData.BONUS_IF_CHILLED:
			per_cast += int(effect.get("amount", 0))
	if per_cast == 0:
		return 0
	var casts := 1 if (card.exhaust or card.cost <= 0) else maxi(1, int(floor(3.0 / card.cost)))
	return per_cast * casts


func run() -> void:
	var library := _library()
	check(library != null, "content library loads")
	if library == null:
		return

	eq(library.cards.size(), 120, "twenty-four lines of five levels each")

	var terminal_count := 0
	var evolvable_count := 0
	var names := {}
	var art_ids := {}
	# Tracks every card that is *someone's* evolved_card, so the roots (level1
	# cards, the ones nobody points to) can be found afterward.
	var is_evolved_card := {}
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
		# Every level now gets its own illustration (the art pipeline generates one
		# per card, not one per line), so art_id must be unique per card rather
		# than shared within a line — the inverse of what this used to assert.
		check(not art_ids.has(card.art_id), "art id %s is unique" % card.art_id)
		art_ids[card.art_id] = true
		for effect in card.effects:
			check(effect.has("kind"), "%s effect declares a kind" % card.card_name)
		if card.is_fully_evolved():
			terminal_count += 1
		else:
			evolvable_count += 1
			neq(card.evolved_card, card, "%s does not evolve into itself" % card.card_name)
			eq(
				card.school,
				card.evolved_card.school,
				"%s keeps its school through evolution" % card.card_name
			)
			is_evolved_card[card.evolved_card.card_name] = true
	eq(evolvable_count, 96, "96 of 120 cards can still evolve (levels 1-4 of every line)")
	eq(terminal_count, 24, "24 terminal, mastered cards, one per line")
	eq(art_ids.size(), 120, "every one of the 120 cards has a distinct art id")

	# Walk each line root (a card nobody's evolved_card points at) from level 1 to
	# level 5: exactly five distinct levels, one shared school throughout, the
	# 5/9/15/24 thresholds on levels 1-4, and termination at level 5. Pinning
	# roots.size() before the walk means an empty or truncated library cannot pass
	# every assertion below vacuously.
	var roots: Array[CardData] = []
	for card in library.cards:
		if not is_evolved_card.has(card.card_name):
			roots.append(card)
	eq(roots.size(), 24, "exactly twenty-four line roots (level 1 cards)")

	var expected_thresholds := [5, 9, 15, 24]
	for root in roots:
		var seen := {}
		var node: CardData = root
		var school: int = root.school
		var depth := 0
		while depth < 4:
			check(not seen.has(node.card_name), "%s line has no repeated card" % root.card_name)
			seen[node.card_name] = true
			eq(node.school, school, "%s stays in one school across its whole line" % root.card_name)
			check(
				not node.is_fully_evolved(),
				"%s level %d is not terminal early" % [root.card_name, depth + 1]
			)
			eq(
				node.xp_to_evolve,
				expected_thresholds[depth],
				"%s level %d needs %d xp to evolve" % [root.card_name, depth + 1, expected_thresholds[depth]]
			)
			node = node.evolved_card
			depth += 1
		check(not seen.has(node.card_name), "%s line has no repeated card" % root.card_name)
		seen[node.card_name] = true
		eq(node.school, school, "%s's level 5 stays in the line's school" % root.card_name)
		check(node.is_fully_evolved(), "%s line terminates at level 5" % root.card_name)
		eq(seen.size(), 5, "%s line is exactly five levels long" % root.card_name)

	# Per-card turn-damage ceiling: pinned separately from generate_content.gd's own
	# enforcement so a future change to the growth rule or a hand-edited .tres can't
	# silently reintroduce a one-card alpha strike. library.cards.size() == 120 is
	# already pinned above, so this can't pass vacuously on an empty list.
	for card in library.cards:
		var ceiling := _turn_ceiling(card)
		check(
			ceiling <= TURN_DAMAGE_CAP,
			"%s could deal %d damage in one 3-mana turn, over the %d cap" % [card.card_name, ceiling, TURN_DAMAGE_CAP]
		)

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

	# Every school must be a real Schools.School value. This is a membership check
	# only: it catches an out-of-range value (e.g. a typo'd constant), but a
	# reordered Schools.School enum produces integers that are all still in
	# range, so this alone would not notice every card's school silently
	# reassigning. tools/generate_content.gd closes that gap at the source by
	# reading Schools.School directly instead of mirroring it as hardcoded ints;
	# the identity checks below (Spark is Cinder, etc.) are what actually pin a
	# specific card to a specific school.
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

	# Identity checks: one named card per school, and one named status. A
	# membership check (school in Schools.ALL) cannot tell CINDER from FROST if
	# the enum reorders — these can, because they compare against a specific
	# named enum member rather than "any valid value."
	eq(library.card_named("Spark").school, Schools.School.CINDER, "spark is cinder")
	eq(library.card_named("Frost Lance").school, Schools.School.FROST, "frost lance is frost")
	eq(library.card_named("Ink Blot").school, Schools.School.INK, "ink blot is ink")
	eq(library.card_named("Rot Seed").school, Schools.School.ROT, "rot seed is rot")
	eq(library.card_named("Guard").school, Schools.School.WARD, "guard is ward")

	var kindle := library.card_named("Kindle")
	check(kindle != null, "kindle exists")
	if kindle != null:
		eq(kindle.effects[0]["status"], Statuses.Kind.BURN, "kindle burns, specifically")

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

	# Examiners: six regular plus two gates plus the final.
	eq(library.enemies.size(), 9, "nine examiners")
	var gates := 0
	for enemy in library.enemies:
		check(enemy.enemy_name != "", "every examiner is named")
		check(enemy.max_hp > 0, "%s has hit points" % enemy.enemy_name)
		check(enemy.mana_per_turn > 0, "%s has mana" % enemy.enemy_name)
		check(enemy.deck.size() >= 3, "%s has a deck of at least three" % enemy.enemy_name)
		check(enemy.art_id != "", "%s declares art" % enemy.enemy_name)
		neq(enemy.weak_school, enemy.warded_school, "%s weak != warded" % enemy.enemy_name)
		for card in enemy.deck:
			check(card != null, "%s deck has no holes" % enemy.enemy_name)
			# An examiner must be able to afford at least one card, or it hesitates
			# forever and the battle cannot end.
		var affordable := false
		for card in enemy.deck:
			if card != null and card.cost <= enemy.mana_per_turn:
				affordable = true
		check(affordable, "%s can afford something in its own deck" % enemy.enemy_name)
		if enemy.is_gate:
			gates += 1
	eq(gates, 2, "two gate examiners")

	# Every school is somebody's weakness and somebody's ward, so no school is dead
	# weight and none is a universal answer.
	var weak_schools := {}
	var warded_schools := {}
	for enemy in library.enemies:
		weak_schools[enemy.weak_school] = true
		warded_schools[enemy.warded_school] = true
	eq(weak_schools.size(), 5, "all five schools are somebody's weakness")
	eq(warded_schools.size(), 5, "all five schools are somebody's ward")
