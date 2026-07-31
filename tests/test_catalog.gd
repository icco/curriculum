extends TestCase

## Catalog availability, prerequisites, honors reveal and the structural validation
## that keeps the two-F permadeath rule fair.


func suite_name() -> String:
	return "catalog"


func _enemy(name: String, gate := false) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.is_gate = gate
	return e


func _course(
	name: String, tier: int, examiner: EnemyData, prereqs: Array, required := 0, honors := false
) -> CourseData:
	var c := CourseData.new()
	c.course_name = name
	c.tier = tier
	c.examiner = examiner
	var typed: Array[CourseData] = []
	for p in prereqs:
		typed.append(p)
	c.prerequisites = typed
	c.prerequisites_required = required
	c.is_honors = honors
	c.par_turns = 5
	c.xp_par = 15
	return c


func run() -> void:
	_test_availability_and_grading()
	_test_any_n_of()
	_test_all_required_means_all()
	_test_honors_reveal()
	_test_validate_honors_rule()
	_test_validate_examiner_repeat_rule()
	_test_validate_sound_catalog()
	_test_validate_gate_exemption()
	_test_validate_final_exemption()


func _test_availability_and_grading() -> void:
	var novice := _enemy("Novice")
	var monitor := _enemy("Hall Monitor")
	var proctor := _enemy("Proctor", true)

	var arcana := _course("Basic Arcana 101", 1, novice, [])
	var wardcraft := _course("Wardcraft 101", 1, monitor, [])
	var inspection := _course("Proctor's Inspection", 1, proctor, [arcana, wardcraft], 2)

	var catalog := Catalog.new([arcana, wardcraft, inspection])

	# With no grades, only the courses with no prerequisites are open.
	var open := catalog.available({})
	eq(open.size(), 2, "two entry courses")

	# A C is a pass; an F is not; an unattempted course is not passed either.
	eq(catalog.is_passed(arcana, {"Basic Arcana 101": Grading.Grade.C}), true, "C passes")
	eq(catalog.is_passed(arcana, {"Basic Arcana 101": Grading.Grade.F}), false, "F does not pass")
	eq(catalog.is_passed(arcana, {}), false, "unattempted is not passed")

	# "Any two of" (two prerequisites here) needs two, not one.
	var one_pass := {"Basic Arcana 101": Grading.Grade.C}
	eq(catalog.is_available(inspection, one_pass), false, "one of two passes is not enough")
	var two_pass := {"Basic Arcana 101": Grading.Grade.C, "Wardcraft 101": Grading.Grade.B}
	eq(catalog.is_available(inspection, two_pass), true, "two of two passes opens the gate")

	# A course already attempted is not offered again, pass or fail.
	eq(catalog.is_available(arcana, {"Basic Arcana 101": Grading.Grade.F}), false, "no retakes")


## The brief's own fixture used a course with exactly two prerequisites and
## prerequisites_required = 2, which cannot be told apart from "all of them" (also 2).
## A gate with THREE prerequisites and required = 2 can: passing any two -- not all
## three, not just one -- must open it.
func _test_any_n_of() -> void:
	var novice := _enemy("Novice")
	var gate := _enemy("Trio Proctor", true)

	var a := _course("A 101", 1, novice, [])
	var b := _course("B 101", 1, novice, [])
	var c := _course("C 101", 1, novice, [])
	var trio_gate := _course("Trio Gate", 1, gate, [a, b, c], 2)

	var catalog := Catalog.new([a, b, c, trio_gate])

	var one := {"A 101": Grading.Grade.C}
	eq(catalog.is_available(trio_gate, one), false, "one of three is not enough for required=2")

	var two := {"A 101": Grading.Grade.C, "B 101": Grading.Grade.C}
	eq(catalog.is_available(trio_gate, two), true, "two of three satisfies required=2")

	var all_three := {
		"A 101": Grading.Grade.C, "B 101": Grading.Grade.C, "C 101": Grading.Grade.C
	}
	eq(catalog.is_available(trio_gate, all_three), true, "three of three also satisfies required=2")


## prerequisites_required = 0 means ALL prerequisites, not just one. A fixture with a
## single prerequisite (as the brief's Thesis 301 was) cannot distinguish those two
## readings, since "all" and "any one" coincide when there is only one to satisfy.
func _test_all_required_means_all() -> void:
	var novice := _enemy("Novice")
	var gate := _enemy("All Gate", true)

	var d := _course("D 101", 1, novice, [])
	var e := _course("E 101", 1, novice, [])
	var both_gate := _course("Both Gate", 1, gate, [d, e], 0)

	var catalog := Catalog.new([d, e, both_gate])

	var one := {"D 101": Grading.Grade.C}
	eq(catalog.is_available(both_gate, one), false, "one of two is not enough when required=0")

	var both := {"D 101": Grading.Grade.C, "E 101": Grading.Grade.C}
	eq(catalog.is_available(both_gate, both), true, "all prerequisites passed opens the gate")


## An honors node needs an A or better on a prerequisite; a B is not enough, but an A
## or an S both are. revealed() must track the same threshold, not just is_available().
func _test_honors_reveal() -> void:
	var novice := _enemy("Novice")
	var monitor := _enemy("Hall Monitor")
	var arcana := _course("Basic Arcana 101", 1, novice, [])
	var tutorial := _course("Tutorial 150", 1, monitor, [arcana], 0, true)

	var catalog := Catalog.new([arcana, tutorial])

	eq(
		catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.B}),
		false,
		"B hides honors"
	)
	eq(
		catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.A}),
		true,
		"A reveals honors"
	)
	eq(
		catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.S}),
		true,
		"S reveals honors"
	)

	var revealed_s := catalog.revealed({"Basic Arcana 101": Grading.Grade.S})
	var names_s := []
	for course in revealed_s:
		names_s.append(course.course_name)
	check(names_s.has("Tutorial 150"), "honors node revealed on S")

	var revealed_b := catalog.revealed({"Basic Arcana 101": Grading.Grade.B})
	var names_b := []
	for course in revealed_b:
		names_b.append(course.course_name)
	check(not names_b.has("Tutorial 150"), "honors node stays hidden on B in revealed() too")


## validate() must flag an honors node used as a required node's prerequisite, and
## must name the specific courses involved -- not just mention the word "honors"
## somewhere. Both examiners are used twice here so the only problem in this catalog
## is the honors one, which lets us assert on the exact count and content.
func _test_validate_honors_rule() -> void:
	var novice := _enemy("Novice")
	var monitor := _enemy("Hall Monitor")
	var arcana := _course("Basic Arcana 101", 1, novice, [])
	var wardcraft := _course("Wardcraft 101", 1, monitor, [])
	var tutorial := _course("Tutorial 150", 1, monitor, [arcana], 0, true)
	var blocked := _course("Blocked 301", 3, novice, [tutorial])

	var bad := Catalog.new([arcana, wardcraft, tutorial, blocked])
	var problems := bad.validate()

	eq(problems.size(), 1, "only the honors-prerequisite problem; the examiner rule is satisfied")
	check(
		problems[0].contains("Blocked 301") and problems[0].contains("Tutorial 150"),
		"names both the requiring course and the honors course"
	)


## validate() also catches an examiner the player only ever meets once, which makes
## its Bestiary entry worthless. The problem must name the examiner and the count.
func _test_validate_examiner_repeat_rule() -> void:
	var lonely := _enemy("Lonely")
	var only := _course("Only 101", 1, lonely, [])
	var thin := Catalog.new([only])

	var problems := thin.validate()
	eq(problems.size(), 1, "exactly the single-use examiner problem")
	check(problems[0].contains("Lonely"), "names the lonely examiner")
	check(problems[0].contains("1"), "counts a single use")


## Positive case: a catalog satisfying both structural rules reports zero problems.
## Without this, a validator that flags every catalog for some unrelated reason would
## still pass every test above, since they only ever check for a problem's presence.
func _test_validate_sound_catalog() -> void:
	var novice := _enemy("Novice")
	var monitor := _enemy("Hall Monitor")
	var gate := _enemy("Proctor", true)

	var arcana := _course("Basic Arcana 101", 1, novice, [])
	var wardcraft := _course("Wardcraft 101", 1, monitor, [])
	var tutorial := _course("Tutorial 150", 1, monitor, [arcana], 0, true)
	var inspection := _course("Proctor's Inspection", 1, gate, [arcana, wardcraft], 2)
	var thesis := _course("Thesis 301", 3, novice, [inspection])

	var catalog := Catalog.new([arcana, wardcraft, tutorial, inspection, thesis])
	eq(catalog.validate(), [], "a sound catalog reports no problems")


## Gates are exempt from the repeat rule, tested both ways: a gate examiner used once
## produces no problem, and a non-gate examiner used once does.
func _test_validate_gate_exemption() -> void:
	var proctor := _enemy("Proctor", true)
	var gate_only := Catalog.new([_course("Gate", 1, proctor, [])])
	eq(gate_only.validate().size(), 0, "a gate examiner used once is not a problem")

	var lonely := _enemy("Lonely")
	var non_gate_once := Catalog.new([_course("Solo", 1, lonely, [])])
	eq(non_gate_once.validate().size(), 1, "a non-gate examiner used once is a problem")


## The final (the Comprehensive Exam) is exempt from the repeat rule on its own
## terms -- via CourseData.is_final -- not merely because content happens to also
## flag its examiner as a gate. Tested both ways, mirroring the gate exemption above:
## a non-gate examiner used once in a course flagged is_final produces no problem,
## while the same examiner used once in an otherwise-identical non-final course does.
func _test_validate_final_exemption() -> void:
	var fresh := CourseData.new()
	eq(fresh.is_final, false, "is_final defaults to false")

	var examiner := _enemy("Rector")
	var final_course := _course("Comprehensive Exam", 3, examiner, [])
	final_course.is_final = true
	var with_final := Catalog.new([final_course])
	eq(with_final.validate().size(), 0, "the final's examiner used once is not a problem")

	var same_examiner_not_final := _enemy("Rector")
	var non_final_course := _course("Ordinary 301", 3, same_examiner_not_final, [])
	var without_final := Catalog.new([non_final_course])
	eq(
		without_final.validate().size(),
		1,
		"the same examiner used once in a non-final course is still a problem"
	)
