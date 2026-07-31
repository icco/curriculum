class_name Grading
extends RefCounted

## Four terms of 25 points each. Efficiency and Survival reward winning cleanly;
## Learning and Discovery reward the two mechanics the game is named for. Grading on
## efficiency alone would make never learning the optimal strategy. Takes plain
## numbers in a Dictionary and returns a Dictionary — no dependency on Battle, Run,
## CardData, or anything else, so this is trivially testable in isolation.

enum Grade { S, A, B, C, F }

const TERM_MAX := 25.0
const DISCOVERY_WEAKNESS := 15.0
const DISCOVERY_SCHOOLS := 10.0
const SCHOOL_COUNT := 5.0

const _LETTERS := {Grade.S: "S", Grade.A: "A", Grade.B: "B", Grade.C: "C", Grade.F: "F"}

## -1 means "the whole deck".
const _ALLOWANCE := {Grade.S: -1, Grade.A: 5, Grade.B: 3, Grade.C: 1, Grade.F: 0}


static func letter(grade: Grade) -> String:
	return _LETTERS.get(grade, "?")


static func draft_allowance(grade: Grade) -> int:
	return _ALLOWANCE.get(grade, 0)


static func grade_for(total: float) -> Grade:
	if total >= 90.0:
		return Grade.S
	if total >= 75.0:
		return Grade.A
	if total >= 60.0:
		return Grade.B
	if total >= 40.0:
		return Grade.C
	return Grade.F


static func score(params: Dictionary) -> Dictionary:
	var turns_taken := maxi(1, int(params.get("turns_taken", 1)))
	var par_turns := int(params.get("par_turns", 0))
	var efficiency := TERM_MAX
	if par_turns > 0:
		efficiency = TERM_MAX * clampf(float(par_turns) / float(turns_taken), 0.0, 1.0)

	var hp_start := maxi(1, int(params.get("hp_start", 1)))
	var hp_end := clampi(int(params.get("hp_end", 0)), 0, hp_start)
	var survival := TERM_MAX * (float(hp_end) / float(hp_start))

	var xp_par := int(params.get("xp_par", 0))
	var learning := TERM_MAX
	if xp_par > 0:
		learning = TERM_MAX * clampf(
			float(int(params.get("xp_banked", 0))) / float(xp_par), 0.0, 1.0
		)

	var discovery := 0.0
	if bool(params.get("weakness_known", false)):
		discovery += DISCOVERY_WEAKNESS
	var distinct := clampi(int(params.get("distinct_schools", 0)), 0, int(SCHOOL_COUNT))
	discovery += DISCOVERY_SCHOOLS * (float(distinct) / SCHOOL_COUNT)

	var total := efficiency + survival + learning + discovery
	var grade := Grade.F if not bool(params.get("won", false)) else grade_for(total)

	return {
		"efficiency": efficiency,
		"survival": survival,
		"learning": learning,
		"discovery": discovery,
		"total": total,
		"grade": grade,
	}
