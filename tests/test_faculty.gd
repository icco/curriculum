extends TestCase

## Per-run examiner variants: deterministic from the seed, never written back to the
## shared roster resources.


func suite_name() -> String:
	return "faculty"


func _card(school: int, kind: String, amount: int) -> CardData:
	var d := CardData.new()
	d.card_name = "c%d%s" % [school, kind]
	d.school = school
	d.cost = 1
	d.effects = [{"kind": kind, "amount": amount}] as Array[Dictionary]
	return d


func _enemy(name: String, weak: int, warded: int, deck: Array) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.max_hp = 40
	e.mana_per_turn = 2
	e.weak_school = weak
	e.warded_school = warded
	var typed: Array[CardData] = []
	typed.assign(deck)
	e.deck = typed
	return e


func _roster() -> Array:
	var hit := _card(Schools.School.CINDER, CardData.DAMAGE, 6)
	var block := _card(Schools.School.WARD, CardData.BLOCK, 6)
	return [
		_enemy("Aggressive", Schools.School.INK, Schools.School.FROST, [hit, hit, hit, hit, hit]),
		_enemy("Turtle", Schools.School.ROT, Schools.School.WARD, [block, block, block, hit, hit]),
		_enemy("Mixed", Schools.School.FROST, Schools.School.CINDER, [hit, hit, hit, block, hit]),
	]


func run() -> void:
	# Deterministic in the seed: the whole save format rests on this, since a save
	# stores one integer and rebuilds the faculty from it rather than serialising
	# nine examiners.
	var a := Faculty.new(_roster(), 4242)
	var b := Faculty.new(_roster(), 4242)
	for name in ["Aggressive", "Turtle", "Mixed"]:
		var one: EnemyData = a.examiner(_enemy(name, 0, 0, []))
		var two: EnemyData = b.examiner(_enemy(name, 0, 0, []))
		eq(one.warded_school, two.warded_school, "%s rolls the same ward for the same seed" % name)

	# Different seeds must actually produce different worlds, or "generative" is a
	# label rather than a behaviour. Checked across many seeds rather than two,
	# since any single pair can legitimately collide.
	var seen := {}
	for seed_value in range(1, 40):
		var faculty := Faculty.new(_roster(), seed_value)
		var signature := ""
		for enemy in faculty.all():
			signature += "%d," % enemy.warded_school
		seen[signature] = true
	check(seen.size() > 1, "different seeds produce different faculties")

	# The shared roster resources must come back untouched. Writing the roll onto the
	# library's own EnemyData would leak it into every later run in the session --
	# the Resource-is-a-shared-singleton trap spec section 4 calls out.
	var roster := _roster()
	var before: Array = []
	for enemy in roster:
		before.append([enemy.weak_school, enemy.warded_school, enemy.deck.size()])
	var faculty := Faculty.new(roster, 99)
	for i in roster.size():
		eq(
			[roster[i].weak_school, roster[i].warded_school, roster[i].deck.size()],
			before[i],
			"%s's roster resource is unmodified" % roster[i].enemy_name
		)
		var variant: EnemyData = faculty.examiner(roster[i])
		neq(variant, roster[i], "the variant is a distinct object")
		eq(variant.enemy_name, roster[i].enemy_name, "the name survives -- it is the Bestiary's key")
		eq(variant.weak_school, roster[i].weak_school, "the weak school is left as authored")

	# Spec section 5: never weak and warded to the same school, at any seed.
	# Also: a defensive examiner is never warded against a school the player opens
	# with, or halving their damage against a mostly-Block deck makes it unbreakable
	# rather than merely hard.
	var starting := [Schools.School.CINDER, Schools.School.WARD]
	for seed_value in range(1, 60):
		var f := Faculty.new(_roster(), seed_value, starting)
		for enemy in f.all():
			neq(
				enemy.warded_school,
				enemy.weak_school,
				"seed %d: %s is not both weak and warded to one school" % [seed_value, enemy.enemy_name]
			)
			if enemy.enemy_name == "Turtle":
				check(
					not starting.has(enemy.warded_school),
					"seed %d: the block-heavy examiner is not warded against a starting school"
					% seed_value
				)

	# An empty roster is legal -- it is what a suite building a bare Run gets -- and
	# must leave examiners on their authored schools rather than crashing.
	var bare := Faculty.new([], 7)
	check(bare.is_empty(), "no roster means an empty faculty")
	var untouched := _enemy("Solo", Schools.School.ROT, Schools.School.INK, [])
	eq(bare.examiner(untouched), untouched, "an unknown examiner falls back to its own resource")
	eq(bare.examiner(null), null, "a null examiner does not crash the lookup")
