extends TestCase

## The multiplier applies to a card's numbers, not to damage alone: that is what
## lets Ward be a weakness at all, since Ward deals no damage.


func suite_name() -> String:
	return "multiplier"


func run() -> void:
	var novice: EnemyData = load("res://resources/enemies/novice.tres")
	var b := Bestiary.new()

	# Weak to Ink, wards Frost, neutral to everything else.
	almost(b.multiplier(novice, Schools.School.INK), 1.5, "weak school hits harder")
	almost(b.multiplier(novice, Schools.School.FROST), 0.5, "warded school is halved")
	almost(b.multiplier(novice, Schools.School.CINDER), 1.0, "neutral school is plain")

	# The bonus applies before it is known. Knowledge is the second reward.
	eq(b.knows_weakness("Novice"), false, "nothing known yet")
	almost(b.multiplier(novice, Schools.School.INK), 1.5, "bonus applies unrevealed")

	# A hit with the weak school reveals it, once.
	eq(b.record_hit(novice, Schools.School.INK), "weakness", "revealed the weakness")
	eq(b.knows_weakness("Novice"), true, "weakness now known")
	eq(b.record_hit(novice, Schools.School.INK), "", "second hit reveals nothing new")

	# A wasted hit still buys knowledge.
	eq(b.record_hit(novice, Schools.School.FROST), "ward", "revealed the ward")
	eq(b.knows_ward("Novice"), true, "ward now known")

	# A neutral hit reveals nothing.
	eq(b.record_hit(novice, Schools.School.CINDER), "", "neutral hit teaches nothing")

	# Knowledge is keyed by examiner NAME, so it carries to the next course that
	# uses the same examiner. That is the whole point of the Bestiary.
	var second: EnemyData = load("res://resources/enemies/novice.tres")
	eq(b.knows_weakness(second.enemy_name), true, "known for the type, not the instance")

	# load() may return Godot's cached instance, so the assertion above could pass
	# even under instance-keying. Build a genuinely distinct EnemyData object that
	# merely shares the examiner name, and prove the Bestiary already knows it: a
	# fresh hit with the (already-known) weak school must teach nothing new.
	var fresh_novice := EnemyData.new()
	fresh_novice.enemy_name = "Novice"
	fresh_novice.weak_school = Schools.School.INK
	fresh_novice.warded_school = Schools.School.FROST
	neq(fresh_novice, novice, "fresh_novice is a distinct object, not the cached load()")
	eq(b.knows_weakness(fresh_novice.enemy_name), true, "known by name for a brand-new instance")
	eq(
		b.record_hit(fresh_novice, Schools.School.INK),
		"",
		"a fresh instance of an already-known examiner teaches nothing new"
	)

	# Round-trips for the save file. Use two examiners that each have only ONE of
	# the two facts known, so a key swap between weaknesses/wards in
	# to_dict()/from_dict() would be caught rather than silently passing because
	# both dictionaries happen to agree on the same name.
	var golem := EnemyData.new()
	golem.enemy_name = "Golem"
	golem.weak_school = Schools.School.ROT
	golem.warded_school = Schools.School.WARD
	eq(b.record_hit(golem, Schools.School.ROT), "weakness", "golem's weakness revealed")

	var ghast := EnemyData.new()
	ghast.enemy_name = "Ghast"
	ghast.weak_school = Schools.School.CINDER
	ghast.warded_school = Schools.School.FROST
	eq(b.record_hit(ghast, Schools.School.FROST), "ward", "ghast's ward revealed")

	var round := Bestiary.from_dict(b.to_dict())
	eq(round.knows_weakness("Novice"), true, "weakness survives a round trip")
	eq(round.knows_ward("Novice"), true, "ward survives a round trip")
	eq(round.knows_weakness("Golem"), true, "golem's weakness survives a round trip")
	eq(round.knows_ward("Golem"), false, "golem's ward was never learned and must not appear")
	eq(round.knows_ward("Ghast"), true, "ghast's ward survives a round trip")
	eq(round.knows_weakness("Ghast"), false, "ghast's weakness was never learned and must not appear")
