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


func _init(starting_deck: Array) -> void:
	deck = starting_deck.duplicate()


func deck_cap() -> int:
	return Draft.cap_for(courses_passed)


## Records a finished battle. Returns what the report card needs to say.
##
## Dropping to zero hit points is an F, not death: hit points are restored and the
## run continues. Permadeath is the second F and nothing else. An F is also not a
## pass, so it neither increments courses_passed nor grows the deck cap.
func record_result(course: CourseData, grade, hp_end: int) -> Dictionary:
	grades[course.course_name] = grade
	var struck: bool = grade == Grading.Grade.F

	if struck:
		strikes += 1
		hp = max_hp  # you failed the exam; you did not die
		if strikes >= MAX_STRIKES:
			expelled = true
	else:
		courses_passed += 1
		hp = clampi(hp_end, 1, max_hp)  # a win never leaves you at zero
		if course.is_final:
			won = true

	return {
		"grade": grade,
		"strike": struck,
		"strikes": strikes,
		"expelled": expelled,
		"won": won,
		"hp": hp,
	}


func is_over() -> bool:
	return expelled or won
