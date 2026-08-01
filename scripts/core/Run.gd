class_name Run
extends RefCounted

## One attempt at the curriculum. Holds everything that dies with the run.

const STARTING_HP := 60
const MAX_STRIKES := 2

var hp := STARTING_HP
var max_hp := STARTING_HP
var strikes := 0
var courses_passed := 0
var grades := {}  ## course name -> Grading.Grade
var deck: Array = []  ## Array[CardInstance]
var bestiary: Bestiary = Bestiary.new()
var expelled := false
var won := false
## Seeds this run's examiner variants. Saved and reloaded so a continued run faces the
## same faculty it started against — rolling fresh on load would hand the player a new
## set of weaknesses and quietly invalidate everything in their Bestiary.
var content_seed := 0
var faculty: Faculty = null


## `enemies` is the content library's roster; passing none leaves the faculty empty and
## every examiner on its authored schools, which is what suites constructing a bare Run
## want. `seed_value` of 0 means "roll one", so only a load passes it explicitly.
func _init(starting_deck: Array, enemies: Array = [], seed_value: int = 0) -> void:
	deck = starting_deck.duplicate()
	content_seed = seed_value if seed_value != 0 else _fresh_seed()
	# The starting deck's schools shape the roll: the faculty has to stay learnable by
	# the deck the player actually opens with. See Faculty's constraints.
	var schools := {}
	for card in deck:
		if card != null and card.data != null:
			schools[card.data.school] = true
	faculty = Faculty.new(enemies, content_seed, schools.keys())


static func _fresh_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Never 0: that is the "roll me one" sentinel, so a run that happened to draw it
	# would re-roll its faculty on every load instead of restoring the saved one.
	return maxi(1, absi(rng.randi()))


## This run's version of a course's examiner — its schools, not the roster's.
func examiner_for(base: EnemyData) -> EnemyData:
	if faculty == null:
		return base
	return faculty.examiner(base)


func deck_cap() -> int:
	return Draft.cap_for(courses_passed)


## Records a finished battle. Returns what the report card needs to say.
##
## Dropping to zero hit points is an F, not death: hit points are restored and the
## run continues. Permadeath is the second F and nothing else. An F is also not a
## pass, so it neither increments courses_passed nor grows the deck cap.
##
## A pass restores a share of maximum hit points scaled by the grade earned
## (Grading.recovery_fraction). This is the ONLY recovery in the game — without it,
## hit points carrying between courses is a one-way ratchet and every run ends in a
## death spiral around the sixth course. Scaling it by grade rather than paying it
## flat is what keeps the pillar attached to the scarcest resource: a good grade is
## the rest site.
func record_result(course: CourseData, grade, hp_end: int) -> Dictionary:
	grades[course.course_name] = grade
	var struck: bool = grade == Grading.Grade.F
	var healed := 0

	if struck:
		strikes += 1
		hp = max_hp  # you failed the exam; you did not die
		if strikes >= MAX_STRIKES:
			expelled = true
	else:
		courses_passed += 1
		var survived := clampi(hp_end, 1, max_hp)  # a win never leaves you at zero
		hp = clampi(
			survived + int(roundf(Grading.recovery_fraction(grade) * float(max_hp))), 1, max_hp
		)
		healed = hp - survived
		if course.is_final:
			won = true

	return {
		"grade": grade,
		"strike": struck,
		"strikes": strikes,
		"expelled": expelled,
		"won": won,
		"hp": hp,
		"healed": healed,
	}


func is_over() -> bool:
	return expelled or won
