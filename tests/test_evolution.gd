extends TestCase

## Card XP is per-copy and per-run. The third test here is the one that matters:
## two instances sharing one CardData must not see each other's XP.


func suite_name() -> String:
	return "evolution"


func run() -> void:
	var spark: CardData = load("res://resources/cards/spark.tres")

	# Accrues one XP per play and does not evolve early.
	var card := CardInstance.new(spark)
	eq(card.xp, 0, "starts at zero")
	eq(card.level(), 1, "starts at level 1")
	for i in 4:
		eq(card.gain_xp(), false, "no evolution at %d xp" % (i + 1))
	eq(card.xp, 4, "four xp banked")
	eq(card.data.card_name, "Spark", "still a spark")

	# The fifth play evolves it, in place, immediately.
	eq(card.gain_xp(), true, "fifth play evolves")
	eq(card.data.card_name, "Ember Lance", "became ember lance")
	eq(card.xp, 0, "xp resets on evolution")
	eq(card.level(), 2, "now level 2")

	# Whole-line walk: five levels, thresholds 5/9/15/24, terminal only at the end.
	# This is the case that matters now that evolution is no longer a single step —
	# a bug that stops the chain early (or lets it run past level 5) would pass a
	# test that only checked one evolution.
	var expected_names := ["Ember Lance", "Blaze Lance", "Wildfire Lance", "Supernova Lance"]
	var thresholds := [9, 15, 24]
	for i in thresholds.size():
		var threshold: int = thresholds[i]
		eq(card.data.card_name, expected_names[i], "level %d name" % (i + 2))
		check(card.can_evolve(), "%s can still evolve" % card.data.card_name)
		for j in threshold - 1:
			eq(card.gain_xp(), false, "no evolution at %d/%d xp" % [j + 1, threshold])
		eq(card.xp, threshold - 1, "%d xp banked just under the threshold" % (threshold - 1))
		eq(card.gain_xp(), true, "the %dth play evolves" % threshold)
		eq(card.xp, 0, "xp resets on evolution")
	eq(card.data.card_name, "Supernova Lance", "walked the whole line to its terminal card")
	eq(card.level(), 5, "terminal card is level 5")

	# Evolved cards are terminal and stop accruing.
	eq(card.can_evolve(), false, "terminal card cannot evolve")
	eq(card.gain_xp(), false, "terminal card does not evolve again")
	eq(card.xp, 0, "terminal card banks no xp")

	# THE CRITICAL CASE. Two copies of one card share a CardData; XP must not leak
	# through it, or a single play would advance every copy and persist across runs.
	var a := CardInstance.new(spark)
	var b := CardInstance.new(spark)
	a.gain_xp()
	a.gain_xp()
	eq(a.xp, 2, "a banked two")
	eq(b.xp, 0, "b is untouched")
	eq(spark.card_name, "Spark", "the shared resource is unchanged")
	check(not ("xp" in spark), "CardData has no xp property at all")

	# load() is cache-keyed by path, so a second load() while `spark` is still in
	# scope just hands back the same object — it cannot catch XP having been written
	# to disk. Read the file as text instead, so this actually inspects the artifact.
	#
	# card_name is the needle, not xp_to_evolve: resources/cards/*.tres are now written
	# by tools/generate_content.gd via ResourceSaver, which omits any @export property
	# equal to its script default — xp_to_evolve's value (5) matches CardData's
	# default, so that field never reaches disk at all. card_name has no such default
	# to collide with, so it is a reliable "this file has real content" canary.
	var raw := FileAccess.get_file_as_string("res://resources/cards/spark.tres")
	check(raw.contains("card_name = "), "sanity: needle finds a real field")
	check(not raw.contains("xp = "), "on-disk resource carries no stray xp field")

	# Display helper. Format is "L<level> <xp>/<threshold>" mid-line, "L<level>
	# mastered" once terminal — the level prefix is new because a bare "3/9" no
	# longer says which of five tiers it belongs to.
	eq(CardInstance.new(spark, 3).progress(), "L1 3/5", "progress reads L<level> x/y")
	var ember_lance: CardData = spark.evolved_card
	eq(CardInstance.new(ember_lance, 2).progress(), "L2 2/9", "level 2 progress uses its own threshold")
	var evolved := CardInstance.new(spark)
	for i in 5:
		evolved.gain_xp()
	eq(evolved.data.card_name, "Ember Lance", "one evolution in, not further")
	eq(evolved.progress(), "L2 0/9", "fresh level 2 card reads L2 0/9")
	var mastered := CardInstance.new(spark)
	while mastered.can_evolve():
		mastered.gain_xp()
	eq(mastered.progress(), "L5 mastered", "terminal card reads L5 mastered")
