extends SceneTree

## Writes resources/courses/*.tres from spec section 8.1. Prerequisites are written in
## dependency order so each course can load the ones before it.

const OUT_DIR := "res://resources/courses"
const CARDS := "res://resources/cards"
const ENEMIES := "res://resources/enemies"


## [slug, name, tier, examiner slug, par_turns, xp_par, syllabus slug,
##  prerequisite slugs, required, is_honors, is_final]
func table() -> Array:
	return [
		["basic_arcana_101", "Basic Arcana 101", 1, "novice", 5, 14, "spark", [], 0, false, false],
		["cantrips_101", "Cantrips 101", 1, "glass_tutor", 5, 14, "marginalia", [], 0, false, false],
		["wardcraft_101", "Wardcraft 101", 1, "hall_monitor", 6, 16, "guard", [], 0, false, false],
		["tutorial_150", "Tutorial 150", 1, "drillmaster", 6, 17, "hoarfrost",
			["basic_arcana_101", "cantrips_101", "wardcraft_101"], 1, true, false],
		["proctors_inspection", "Proctor's Inspection", 1, "proctor", 8, 22, "rimeward",
			["basic_arcana_101", "cantrips_101", "wardcraft_101"], 2, false, false],
		["pyromancy_201", "Pyromancy 201", 2, "battle_chanter", 7, 20, "cinder_burst",
			["proctors_inspection"], 0, false, false],
		["cryomancy_201", "Cryomancy 201", 2, "drillmaster", 7, 20, "frost_lance",
			["proctors_inspection"], 0, false, false],
		["necrology_201", "Necrology 201", 2, "alchemy_master", 8, 22, "rot_seed",
			["proctors_inspection"], 0, false, false],
		["marginalia_201", "Marginalia 201", 2, "glass_tutor", 7, 20, "ink_blot",
			["proctors_inspection"], 0, false, false],
		["fieldwork_250", "Fieldwork 250", 2, "battle_chanter", 8, 22, "final_recitation",
			["pyromancy_201", "cryomancy_201", "necrology_201", "marginalia_201"], 1, true, false],
		["midterm_review", "Midterm Review", 2, "vice_chancellor", 10, 28, "cram",
			["pyromancy_201", "cryomancy_201", "necrology_201", "marginalia_201"], 2, false, false],
		["thesis_301", "Thesis 301", 3, "alchemy_master", 9, 26, "thesis_statement",
			["midterm_review"], 0, false, false],
		["applied_wardcraft_301", "Applied Wardcraft 301", 3, "hall_monitor", 9, 26, "honours_sigil",
			["midterm_review"], 0, false, false],
		["viva_voce_350", "Viva Voce 350", 3, "novice", 9, 26, "winter_term",
			["thesis_301", "applied_wardcraft_301"], 1, true, false],
		["comprehensive_exam", "Comprehensive Exam", 3, "rector", 12, 34, "",
			["thesis_301", "applied_wardcraft_301"], 0, false, true],
	]


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Two passes: write every course without prerequisites, then link them, because a
	# .tres cannot reference a file that does not exist yet.
	for row in table():
		var course := CourseData.new()
		course.course_name = row[1]
		course.tier = row[2]
		course.examiner = load("%s/%s.tres" % [ENEMIES, row[3]])
		course.par_turns = row[4]
		course.xp_par = row[5]
		if row[6] != "":
			course.guaranteed_card_drop = load("%s/%s.tres" % [CARDS, row[6]])
		course.prerequisites_required = row[8]
		course.is_honors = row[9]
		course.is_final = row[10]
		ResourceSaver.save(course, "%s/%s.tres" % [OUT_DIR, row[0]])

	var courses: Array[CourseData] = []
	for row in table():
		var path := "%s/%s.tres" % [OUT_DIR, row[0]]
		var course: CourseData = load(path)
		var prereqs: Array[CourseData] = []
		for slug in row[7]:
			prereqs.append(load("%s/%s.tres" % [OUT_DIR, slug]))
		course.prerequisites = prereqs
		ResourceSaver.save(course, path)
		courses.append(load(path))

	var library: ContentLibrary = load("res://resources/content_library.tres")
	library.courses = courses
	ResourceSaver.save(library, "res://resources/content_library.tres")

	var problems := Catalog.new(courses).validate()
	for problem in problems:
		printerr("catalog problem: %s" % problem)
	print("wrote %d courses, %d problems" % [courses.size(), problems.size()])
	quit(1 if problems.size() > 0 else 0)
	return true
