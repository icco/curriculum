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
	for i in 4:
		eq(card.gain_xp(), false, "no evolution at %d xp" % (i + 1))
	eq(card.xp, 4, "four xp banked")
	eq(card.data.card_name, "Spark", "still a spark")

	# The fifth play evolves it, in place, immediately.
	eq(card.gain_xp(), true, "fifth play evolves")
	eq(card.data.card_name, "Ember Lance", "became ember lance")
	eq(card.xp, 0, "xp resets on evolution")

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

	# Reloading the resource must not show XP either.
	var reloaded: CardData = load("res://resources/cards/spark.tres")
	eq(reloaded.card_name, "Spark", "reloaded card is pristine")

	# Display helper.
	eq(CardInstance.new(spark, 3).progress(), "3/5", "progress reads x/y")
	var evolved := CardInstance.new(spark)
	for i in 5:
		evolved.gain_xp()
	eq(evolved.progress(), "mastered", "terminal card reads mastered")
