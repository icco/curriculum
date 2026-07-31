extends TestCase

## Content integrity. Grows in Tasks 16-18 to cover the whole card, examiner and
## course set; starts by pinning the CardData contract.


func suite_name() -> String:
	return "content"


func run() -> void:
	var spark: CardData = load("res://resources/cards/spark.tres")
	check(spark != null, "spark loads")
	if spark == null:
		return
	eq(spark.card_name, "Spark", "spark name")
	eq(spark.school, Schools.School.CINDER, "spark is cinder")
	eq(spark.cost, 1, "spark costs 1")
	eq(spark.xp_to_evolve, 5, "spark evolves at 5")
	eq(spark.effects.size(), 1, "spark has one effect")
	eq(spark.effects[0]["kind"], CardData.DAMAGE, "spark deals damage")
	eq(spark.effects[0]["amount"], 6, "spark deals 6")
	check(not spark.is_fully_evolved(), "spark can evolve")

	var lance: CardData = spark.evolved_card
	check(lance != null, "spark points at ember lance")
	if lance == null:
		return
	eq(lance.card_name, "Ember Lance", "evolved name")
	eq(lance.effects[0]["amount"], 10, "ember lance deals 10")
	check(lance.is_fully_evolved(), "ember lance is terminal")
	# A card that evolves into itself is an infinite loop at play time.
	neq(lance, lance.evolved_card, "no self-evolution")
