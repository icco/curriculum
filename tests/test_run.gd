extends TestCase


func suite_name() -> String:
	return "run"


func _course(name: String, final := false) -> CourseData:
	var c := CourseData.new()
	c.course_name = name
	c.is_final = final
	return c


func _deck(n: int) -> Array:
	var out := []
	for i in n:
		var d := CardData.new()
		d.card_name = "c%d" % i
		out.append(CardInstance.new(d))
	return out


func run() -> void:
	var r := Run.new(_deck(10))
	eq(r.hp, 60, "starts at sixty")
	eq(r.strikes, 0, "no strikes")
	eq(r.deck_cap(), 10, "starting cap")
	eq(r.is_over(), false, "not over")

	# Passing banks the grade, counts the course, and grows the cap.
	r.record_result(_course("Basic Arcana 101"), Grading.Grade.B, 45)
	eq(r.grades["Basic Arcana 101"], Grading.Grade.B, "grade recorded")
	eq(r.courses_passed, 1, "one course passed")
	eq(r.deck_cap(), 11, "cap grew")
	# 45 survived, plus the 20% of max that a B restores. Passing is the only recovery
	# in the game, and it scales with the grade earned.
	eq(r.hp, 57, "hp carried over from the battle, plus the B's recovery")
	eq(r.strikes, 0, "a pass is not a strike")
	# Passing a non-final course must not win the run — only is_final does that. An
	# implementation that sets `won` on any pass would pass every other assertion here
	# identically, so this has to be checked directly.
	eq(r.won, false, "passing a non-final course does not win")

	# An F is a strike, does NOT count as a pass, and restores hit points: failing an
	# exam is not dying, so the cap does not grow and the run continues. Pre-F hp is
	# 45 (from the pass above), not max_hp (60), so restoration is distinguishable
	# from an implementation that simply leaves hp untouched.
	var first_f := r.record_result(_course("Cantrips 101"), Grading.Grade.F, 0)
	eq(r.strikes, 1, "one strike")
	eq(r.courses_passed, 1, "an F is not a pass")
	eq(r.deck_cap(), 11, "cap did not grow on a failure")
	eq(r.hp, 60, "hit points restored after a failure")
	eq(r.expelled, false, "one F is survivable")
	eq(r.is_over(), false, "run continues")
	eq(first_f["strike"], true, "reported the strike")
	eq(first_f["expelled"], false, "not expelled yet")

	# The second F is expulsion — the only death condition in the game.
	var second_f := r.record_result(_course("Wardcraft 101"), Grading.Grade.F, 0)
	eq(r.strikes, 2, "two strikes")
	eq(r.expelled, true, "expelled")
	eq(r.is_over(), true, "run over")
	eq(second_f["expelled"], true, "reported the expulsion")

	# Passing the final wins the run.
	var w := Run.new(_deck(10))
	w.record_result(_course("Comprehensive Exam", true), Grading.Grade.A, 20)
	eq(w.won, true, "passing the final wins")
	eq(w.is_over(), true, "run over on a win")

	# Failing the final is a strike like any other, not an automatic loss.
	var f := Run.new(_deck(10))
	f.record_result(_course("Comprehensive Exam", true), Grading.Grade.F, 0)
	eq(f.won, false, "failing the final does not win")
	eq(f.strikes, 1, "one strike")
	eq(f.is_over(), false, "and the run goes on")

	# The cap saturates at sixteen however many courses are passed.
	var long_run := Run.new(_deck(10))
	for i in 12:
		long_run.record_result(_course("Course %d" % i), Grading.Grade.C, 60)
	eq(long_run.courses_passed, 12, "twelve courses passed")
	eq(long_run.deck_cap(), 16, "cap saturates")

	# A win must never leave the player at 0 hit points: a photo-finish victory
	# (hp_end == 0) still floors to 1 BEFORE the grade's recovery is added, since 0 hp
	# is reserved for meaning "you failed the exam", never "you won." Plain assignment
	# (hp = hp_end) would leave hp at 0 here and pass every other assertion in this
	# file identically. A B restores 20% of 60, so 1 + 12.
	var floor_run := Run.new(_deck(10))
	floor_run.record_result(_course("Basic Arcana 101"), Grading.Grade.B, 0)
	eq(floor_run.hp, 13, "a photo-finish win floors to 1, then the grade heals on top")
	check(floor_run.hp >= 1, "a win never leaves the player at zero")

	# hp_end can exceed max_hp is not something Battle should ever report, but the
	# clamp guards both directions, so the ceiling needs its own case: maxi(hp_end, 1)
	# would satisfy the floor case above while leaving an over-max value un-clamped.
	var ceiling_run := Run.new(_deck(10))
	ceiling_run.record_result(_course("Basic Arcana 101"), Grading.Grade.B, 999)
	eq(ceiling_run.hp, ceiling_run.max_hp, "a win clamps hp to at most max_hp")

	# Recovery scales with the grade, and it is the only healing between courses.
	# Checked across every grade because a table lookup that silently defaulted to
	# zero would still pass a single-grade case.
	for row in [[Grading.Grade.S, 24], [Grading.Grade.A, 18], [Grading.Grade.B, 12],
			[Grading.Grade.C, 6]]:
		var heal_run := Run.new(_deck(10))
		var out: Dictionary = heal_run.record_result(_course("Recovery"), row[0], 20)
		eq(heal_run.hp, 20 + int(row[1]),
			"a %s restores %d of 60" % [Grading.letter(row[0]), int(row[1])])
		eq(int(out["healed"]), int(row[1]), "the result reports what it healed")

	# Recovery cannot push past the maximum, and it never exceeds it silently.
	var topped := Run.new(_deck(10))
	topped.record_result(_course("Recovery"), Grading.Grade.S, 55)
	eq(topped.hp, topped.max_hp, "recovery clamps at max_hp")

	# The bestiary belongs to the run and survives between battles: a fact learned
	# before one record_result call is still known after a later one, rather than
	# being reset. `bestiary is Bestiary` alone would pass on the field's declaration
	# alone and could never fail, so this checks it actually persists state.
	var bestiary_run := Run.new(_deck(10))
	var goblin := EnemyData.new()
	goblin.enemy_name = "Goblin"
	goblin.weak_school = Schools.School.CINDER
	bestiary_run.bestiary.record_hit(goblin, Schools.School.CINDER)
	bestiary_run.record_result(_course("Basic Arcana 101"), Grading.Grade.B, 45)
	bestiary_run.record_result(_course("Cantrips 101"), Grading.Grade.F, 0)
	eq(bestiary_run.bestiary.knows_weakness("Goblin"), true, "bestiary survives across record_result calls")
