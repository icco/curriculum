extends TestCase

## Hit points are a RUN resource, not a per-battle buffer that refills.
##
## Run.hp was written by record_result and round-tripped by SaveGame, but Battle
## hardcoded the player at 60 and never read it, so no damage ever carried between
## courses — every fight started fresh. That deleted attrition entirely: healing
## could not matter, and there was no reason to end a fight above 1 hp.
##
## The Survival term is the other half of the same fix. It must score against the hp
## the player WALKED IN ON, not against max_hp: grading a battle against the maximum
## would let damage taken three courses ago permanently cap every later grade, which
## is a different bug wearing the same clothes.


func suite_name() -> String:
	return "battle_hp_carryover"


func _card(name: String, amount: int) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = Schools.School.CINDER
	d.cost = 1
	d.effects = [{"kind": CardData.DAMAGE, "amount": amount}]
	return d


func _enemy(hp: int) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = "Dummy"
	e.max_hp = hp
	e.mana_per_turn = 1
	# Neither weak nor warded against Cinder, so the multiplier stays 1.0 and the
	# arithmetic below is the card's face value.
	e.weak_school = Schools.School.FROST
	e.warded_school = Schools.School.INK
	e.deck = [_card("Poke", 1)]
	return e


func _deck(n: int) -> Array:
	var out := []
	for i in n:
		out.append(CardInstance.new(_card("Spark%d" % i, 5)))
	return out


func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Omitting starting_hp means "walk in at full" — what a caller with no run behind
	# it wants, and what every other suite relies on.
	var fresh := Battle.new(_deck(6), _enemy(40), Bestiary.new(), rng)
	eq(fresh.player.hp, Run.STARTING_HP, "no starting hp given: full")
	eq(fresh.player.max_hp, Run.STARTING_HP, "max is unchanged")
	eq(fresh.player_starting_hp, Run.STARTING_HP, "starting hp recorded")

	# A wounded run walks in wounded.
	var wounded := Battle.new(_deck(6), _enemy(40), Bestiary.new(), rng, 23)
	eq(wounded.player.hp, 23, "starts on what the run had left")
	eq(wounded.player.max_hp, Run.STARTING_HP, "being wounded does not lower the maximum")
	eq(wounded.player_starting_hp, 23, "records what it walked in on, not the maximum")

	# Over-max is clamped rather than trusted: a corrupt save must not hand out
	# hit points the run never had.
	var overfull := Battle.new(_deck(6), _enemy(40), Bestiary.new(), rng, 9999)
	eq(overfull.player.hp, Run.STARTING_HP, "a starting hp above max is clamped")

	# 0 is the "full" sentinel, not a dead player walking in with nothing. Run
	# guarantees this is unreachable in play (record_result clamps a win to at least
	# 1 and restores to max on an F), but the sentinel is load-bearing enough that it
	# should be intentional rather than incidental.
	var zeroed := Battle.new(_deck(6), _enemy(40), Bestiary.new(), rng, 0)
	eq(zeroed.player.hp, Run.STARTING_HP, "0 means full, not dead")
	eq(zeroed.player_starting_hp, Run.STARTING_HP, "the sentinel records full, not 0")

	# The round trip that was broken: damage taken in a battle must reach Run.hp and
	# come back out into the NEXT battle.
	var game := Run.new(_deck(6))
	var course := CourseData.new()
	course.course_name = "Attrition 101"
	# 31 survived, plus the 12 a B restores (20% of 60) — passing is the only recovery
	# between courses, so the number that carries is post-recovery.
	game.record_result(course, Grading.Grade.B, 31)
	eq(game.hp, 43, "the run banked the battle's ending hp plus the grade's recovery")
	var next_battle := Battle.new(game.deck, _enemy(40), Bestiary.new(), rng, game.hp)
	eq(next_battle.player.hp, 43, "the next battle starts on the run's hp")

	# Survival is scored against the walked-in hp. A wounded player who takes no
	# damage has survived the battle perfectly and must score full marks — scoring
	# against max_hp would give 23/60 for a flawless fight.
	var flawless := Grading.score(
		{
			"won": true,
			"turns_taken": 1,
			"par_turns": 1,
			"hp_end": wounded.player_starting_hp,
			"hp_start": wounded.player_starting_hp,
			"xp_par": 0,
			"distinct_schools": 0,
		}
	)
	almost(flawless["survival"], Grading.TERM_MAX, "untouched at 23 hp still scores full Survival")

	var halved := Grading.score(
		{
			"won": true,
			"turns_taken": 1,
			"par_turns": 1,
			"hp_end": 12,
			"hp_start": 24,
			"xp_par": 0,
			"distinct_schools": 0,
		}
	)
	almost(halved["survival"], Grading.TERM_MAX * 0.5, "losing half of what you had scores half")
