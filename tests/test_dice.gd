extends "res://tests/TestCase.gd"

func before_each() -> void:
	Dice.seed_with(1234)

func test_parse_expr_forms() -> void:
	var a := Dice.parse_expr("2d6+3")
	eq(a.count, 2, "count")
	eq(a.sides, 6, "sides")
	eq(a.flat, 3, "flat")

	var b := Dice.parse_expr("1d10")
	eq(b.count, 1, "implicit flat")
	eq(b.flat, 0, "no modifier")

	var c := Dice.parse_expr("d4-1")
	eq(c.count, 1, "bare d means one die")
	eq(c.sides, 4, "sides")
	eq(c.flat, -1, "negative modifier")

	var d := Dice.parse_expr("5")
	eq(d.sides, 0, "flat expression has no dice")
	eq(d.flat, 5, "flat value")

func test_roll_expr_within_bounds() -> void:
	for i in 300:
		var v := Dice.roll_expr("2d6+3")
		between(v, 5, 15, "2d6+3 range")
	for i in 100:
		between(Dice.roll_expr("4"), 4, 4, "flat expression")

func test_d20_covers_full_range() -> void:
	var seen: Dictionary = {}
	for i in 2000:
		seen[Dice.d20()] = true
	eq(seen.size(), 20, "d20 should produce all faces")
	truthy(seen.has(1) and seen.has(20), "extremes appear")

func test_average() -> void:
	between(Dice.average("2d6+3"), 10.0, 10.0, "2d6+3 averages 10")
	between(Dice.average("1d8"), 4.5, 4.5, "1d8 averages 4.5")

func test_seed_is_reproducible() -> void:
	Dice.seed_with(99)
	var first: Array = []
	for i in 20:
		first.append(Dice.d20())
	Dice.seed_with(99)
	for i in 20:
		eq(Dice.d20(), first[i], "same seed replays roll %d" % i)

func test_weighted_respects_zero() -> void:
	Dice.seed_with(7)
	for i in 200:
		var pick: Variant = Dice.weighted({"a": 1.0, "b": 0.0})
		eq(pick, "a", "zero-weight option never chosen")

func test_shuffled_preserves_elements() -> void:
	var src := [1, 2, 3, 4, 5, 6, 7, 8]
	var out := Dice.shuffled(src)
	eq(out.size(), src.size(), "same length")
	eq(src, [1, 2, 3, 4, 5, 6, 7, 8], "source untouched")
	var sorted_out := out.duplicate()
	sorted_out.sort()
	eq(sorted_out, src, "same multiset")
