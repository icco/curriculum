class_name Catalog
extends RefCounted

## Course availability over the syllabus map. `grades` maps course name (String) to
## Grading.Grade -- the run's grade history so far, one entry per course attempted.

var courses: Array = []


func _init(course_list: Array) -> void:
	courses = course_list.duplicate()


## A pass is C or better; an F is an attempt, not a pass.
func is_passed(course: CourseData, grades: Dictionary) -> bool:
	if course == null or not grades.has(course.course_name):
		return false
	return grades[course.course_name] != Grading.Grade.F


func is_attempted(course: CourseData, grades: Dictionary) -> bool:
	return course != null and grades.has(course.course_name)


## Honors nodes need an A or better on a met prerequisite; everything else needs a
## plain pass (C or better). A course already attempted -- pass or fail -- is never
## offered again; there are no retakes. `prerequisites_required` of 0 means all of
## `prerequisites` must be met; otherwise it is "any N of them".
func is_available(course: CourseData, grades: Dictionary) -> bool:
	if course == null or is_attempted(course, grades):
		return false
	if course.prerequisites.is_empty():
		return true

	var threshold: Array = (
		[Grading.Grade.S, Grading.Grade.A]
		if course.is_honors
		else [Grading.Grade.S, Grading.Grade.A, Grading.Grade.B, Grading.Grade.C]
	)
	var met := 0
	for prerequisite in course.prerequisites:
		if grades.has(prerequisite.course_name) and grades[prerequisite.course_name] in threshold:
			met += 1

	var required: int = course.prerequisites_required
	if required <= 0:
		required = course.prerequisites.size()
	return met >= required


func available(grades: Dictionary) -> Array:
	var out: Array = []
	for course in courses:
		if is_available(course, grades):
			out.append(course)
	return out


## Courses visible on the map: available ones plus already-attempted ones.
func revealed(grades: Dictionary) -> Array:
	var out: Array = []
	for course in courses:
		if is_available(course, grades) or is_attempted(course, grades):
			out.append(course)
	return out


## Structural rules the catalog's content must satisfy so the two-F permadeath rule
## stays fair. Returns a list of human-readable problems; an empty list means the
## catalog is sound. Never raises or prints -- callers decide how to surface problems.
func validate() -> Array:
	var problems: Array = []

	# Rule 1: no honors node may gate a required (non-honors) node. Otherwise a
	# player who never scores an A hits a dead end, and two-F permadeath makes the
	# run unwinnable through no fault of play.
	for course in courses:
		if course.is_honors:
			continue
		for prerequisite in course.prerequisites:
			if prerequisite.is_honors:
				problems.append(
					(
						"%s requires the honors course %s"
						% [course.course_name, prerequisite.course_name]
					)
				)

	# Rule 2: every non-gate examiner must appear in at least two courses, or its
	# Bestiary entry -- knowledge good against that type for the rest of the run --
	# is never cashed in. Gates and the final are one-off encounters by nature and
	# are exempt, each on its own terms (course.examiner.is_gate / course.is_final),
	# not because content happens to also flag the final's examiner as a gate.
	var uses := {}
	var gates := {}
	for course in courses:
		if course.examiner == null:
			problems.append("%s has no examiner" % course.course_name)
			continue
		var name: String = course.examiner.enemy_name
		uses[name] = int(uses.get(name, 0)) + 1
		if course.examiner.is_gate or course.is_final:
			gates[name] = true
	for name in uses:
		if gates.has(name):
			continue
		if int(uses[name]) < 2:
			problems.append("examiner %s is used by only %d course(s)" % [name, int(uses[name])])

	return problems
