extends TestCase

## Each term in isolation, then the thresholds. Note that a passing suite here does
## NOT prove S is reachable in real play — that is what tools/simulate.gd is for.


func suite_name() -> String:
	return "grading"


func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"won": true,
		"turns_taken": 10,
		"par_turns": 5,
		"hp_end": 0,
		"hp_start": 60,
		"xp_banked": 0,
		"xp_par": 15,
		"weakness_known": false,
		"distinct_schools": 0,
	}
	for key in overrides:
		p[key] = overrides[key]
	return p


func run() -> void:
	# Efficiency: par is the TARGET, not the floor. Finishing exactly at par earns
	# 25 / PAR_TARGET; the last points are bought by finishing inside par. Clamped at
	# full marks so beating it by a mile is not worth more than beating it.
	almost(Grading.score(_params({"turns_taken": 5, "par_turns": 5}))["efficiency"], 20.0, "at par")
	almost(
		Grading.score(_params({"turns_taken": 4, "par_turns": 5}))["efficiency"],
		25.0,
		"four fifths of par is exactly full marks"
	)
	almost(Grading.score(_params({"turns_taken": 3, "par_turns": 5}))["efficiency"], 25.0, "well under par caps")
	almost(Grading.score(_params({"turns_taken": 10, "par_turns": 5}))["efficiency"], 10.0, "double par")
	# The gradient has to be strictly increasing between par and the cap, or "beat
	# par" is just a second clamp with extra steps.
	var slower: float = Grading.score(_params({"turns_taken": 6, "par_turns": 5}))["efficiency"]
	var at_par: float = Grading.score(_params({"turns_taken": 5, "par_turns": 5}))["efficiency"]
	var faster: float = Grading.score(_params({"turns_taken": 4, "par_turns": 5}))["efficiency"]
	check(slower < at_par and at_par < faster, "efficiency strictly improves as turns drop")

	# Survival: proportional to hit points kept.
	almost(Grading.score(_params({"hp_end": 60}))["survival"], 25.0, "untouched")
	almost(Grading.score(_params({"hp_end": 30}))["survival"], 12.5, "half hp")
	almost(Grading.score(_params({"hp_end": 0}))["survival"], 0.0, "no hp")

	# Learning: scored against an authored par, NOT against deck size.
	almost(Grading.score(_params({"xp_banked": 15, "xp_par": 15}))["learning"], 25.0, "at xp par")
	almost(Grading.score(_params({"xp_banked": 30, "xp_par": 15}))["learning"], 25.0, "over par caps")
	almost(Grading.score(_params({"xp_banked": 3, "xp_par": 15}))["learning"], 5.0, "a fifth of par")

	# Discovery: 15 for knowing the weakness, 10 spread over the five schools.
	almost(Grading.score(_params({"weakness_known": true}))["discovery"], 15.0, "weakness alone")
	almost(Grading.score(_params({"distinct_schools": 5}))["discovery"], 10.0, "all schools alone")
	almost(
		Grading.score(_params({"weakness_known": true, "distinct_schools": 5}))["discovery"],
		25.0,
		"both is full marks"
	)

	# A perfect battle totals 100 and earns an S.
	var perfect_params := {
		"turns_taken": 4,
		"par_turns": 5,
		"hp_end": 60,
		"xp_banked": 15,
		"xp_par": 15,
		"weakness_known": true,
		"distinct_schools": 5,
	}
	var perfect := Grading.score(_params(perfect_params))
	almost(perfect["total"], 100.0, "perfect total")
	eq(perfect["grade"], Grading.Grade.S, "perfect is an S")

	# score() must grade its OWN total through grade_for(), not just special-case
	# S/F around `won` — a won battle at a middle tier proves the wiring, since every
	# other score()-level grade assertion in this suite lands on S or F.
	# 20 efficiency (at par) + 25 survival + 0 learning + 19 discovery. Deliberately
	# not landing on a tier cutoff, so this case proves the routing rather than the
	# boundary handling that the grade_for assertions below already pin.
	var mid := Grading.score(
		_params({
			"turns_taken": 5, "par_turns": 5, "hp_end": 60,
			"weakness_known": true, "distinct_schools": 2,
		})
	)
	almost(mid["total"], 64.0, "mid-tier total")
	eq(mid["grade"], Grading.Grade.B, "a 64 total grades B through score()")

	# Thresholds — pin each of the four cutoffs exactly at its value AND just below,
	# so a `>=` weakened to `>` (which would kick the exact-cutoff value down a tier)
	# and a cutoff placed too low (which would let the just-below value pass) both fail.
	eq(Grading.grade_for(90.0), Grading.Grade.S, "90 is S")
	eq(Grading.grade_for(89.9), Grading.Grade.A, "just under 90 is A")
	eq(Grading.grade_for(75.0), Grading.Grade.A, "75 is A")
	eq(Grading.grade_for(74.9), Grading.Grade.B, "just under 75 is B")
	eq(Grading.grade_for(60.0), Grading.Grade.B, "60 is B")
	eq(Grading.grade_for(59.9), Grading.Grade.C, "just under 60 is C")
	eq(Grading.grade_for(40.0), Grading.Grade.C, "40 is C")
	eq(Grading.grade_for(39.9), Grading.Grade.F, "under 40 is F")
	eq(Grading.grade_for(0.0), Grading.Grade.F, "zero is F")

	# Losing is an F however well it otherwise went — use the SAME params as the
	# perfect-100 battle above so the override is proven against the maximum
	# achievable total, not merely a total that happens to still clear a lower tier.
	var lost_params := perfect_params.duplicate()
	lost_params["won"] = false
	var lost := Grading.score(_params(lost_params))
	almost(lost["total"], 100.0, "the loss does not zero the underlying total")
	eq(lost["grade"], Grading.Grade.F, "a loss is an F even at a perfect 100 total")

	# Letters — every grade, not just S, so a transposed dictionary entry is caught.
	eq(Grading.letter(Grading.Grade.S), "S", "S letter")
	eq(Grading.letter(Grading.Grade.A), "A", "A letter")
	eq(Grading.letter(Grading.Grade.B), "B", "B letter")
	eq(Grading.letter(Grading.Grade.C), "C", "C letter")
	eq(Grading.letter(Grading.Grade.F), "F", "F letter")

	# The draft allowance the grade buys.
	eq(Grading.draft_allowance(Grading.Grade.S), -1, "S takes the whole deck")
	eq(Grading.draft_allowance(Grading.Grade.A), 5, "A takes five")
	eq(Grading.draft_allowance(Grading.Grade.B), 3, "B takes three")
	eq(Grading.draft_allowance(Grading.Grade.C), 1, "C takes one")
	eq(Grading.draft_allowance(Grading.Grade.F), 0, "F takes nothing")

	# Guards against division by zero in authored content.
	almost(
		Grading.score(_params({"par_turns": 0}))["efficiency"],
		25.0,
		"zero par_turns does not divide, awards full marks"
	)

	# xp_banked stays at its default of 0 here deliberately: with xp_par also 0, an
	# unguarded division is 0.0 / 0.0, which produces NaN rather than a crash. NaN
	# would otherwise slip past almost()'s tolerance check — NaN compares false
	# against every threshold, including "> 0.001", so `almost(NaN, 25.0, ...)` would
	# NOT register as a failure on its own — so this is checked for finiteness
	# explicitly first.
	var zero_xp_par: float = Grading.score(_params({"xp_par": 0}))["learning"]
	check(not is_nan(zero_xp_par), "zero xp_par must not produce NaN")
	almost(zero_xp_par, 25.0, "zero xp_par does not divide, awards full marks")
