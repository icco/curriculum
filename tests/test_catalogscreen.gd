extends TestCase

## CourseCatalog and BestiaryScreen, proven against the real shipped content in
## content_library.tres rather than a fixture, so the screen is tested against the
## actual 15 courses and 9 enemies.


func suite_name() -> String:
	return "catalogscreen"


func run() -> void:
	_test_entry_courses_only()
	_test_honors_reveal_and_no_retakes()
	_test_edges_behind_and_mouse_filters()
	_test_course_chosen_signal()
	_test_bestiary_known_and_unknown()
	_test_scroll_height_has_no_dead_row()


func _test_entry_courses_only() -> void:
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	var cat := lib.catalog()

	# Ground truth computed straight from the fixture's own CourseData, independent of
	# the screen under test, so this can actually fail if show_catalog's filtering
	# breaks -- not just echo back a copied literal that happens to match today.
	var entry_courses: Array = []
	for course in lib.courses:
		if course.prerequisites.is_empty():
			entry_courses.append(course)
	check(entry_courses.size() > 0, "sanity: the fixture has at least one entry course")

	var map := CourseCatalog.new()
	map.size = Vector2(1080, 1920)
	map.show_catalog(cat, {})
	eq(
		map.node_buttons.size(),
		entry_courses.size(),
		"only the prerequisite-free courses appear with no grades"
	)
	for course_name in map.node_buttons:
		eq(map.node_buttons[course_name].disabled, false, "entry courses are enterable")
	eq(map.edge_count(), 0, "no prerequisite edges among entry-only courses")
	map.free()


func _test_honors_reveal_and_no_retakes() -> void:
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	var cat := lib.catalog()

	var basic_arcana: CourseData = lib.course_named("Basic Arcana 101")
	check(basic_arcana != null, "sanity: fixture still has Basic Arcana 101")

	var honors_course: CourseData = null
	for course in lib.courses:
		if course.is_honors and course.prerequisites.has(basic_arcana):
			honors_course = course
			break
	check(honors_course != null, "sanity: an honors node lists Basic Arcana 101 as a prerequisite")

	var final_course: CourseData = null
	for course in lib.courses:
		if course.is_final:
			final_course = course
			break
	check(final_course != null, "sanity: the fixture has a final course")

	var map := CourseCatalog.new()
	map.size = Vector2(1080, 1920)
	# An S on the entry course reveals its honors branch.
	map.show_catalog(cat, {"Basic Arcana 101": Grading.Grade.S})
	check(map.node_buttons.has(honors_course.course_name), "an S revealed the honors node")
	check(not map.node_buttons.has(final_course.course_name), "the final stays hidden")

	# An attempted course is shown but cannot be retaken.
	check(map.node_buttons.has("Basic Arcana 101"), "the passed course is still drawn")
	eq(map.node_buttons["Basic Arcana 101"].disabled, true, "no retakes")
	check(map.edge_count() > 0, "drew prerequisite edges once a prerequisite is on screen")

	# A B is not enough for an honors reveal -- proves the S case above is not vacuous.
	var map_b := CourseCatalog.new()
	map_b.size = Vector2(1080, 1920)
	map_b.show_catalog(cat, {"Basic Arcana 101": Grading.Grade.B})
	check(
		not map_b.node_buttons.has(honors_course.course_name), "a B does not reveal the honors node"
	)
	map_b.free()

	map.free()


func _test_edges_behind_and_mouse_filters() -> void:
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	var cat := lib.catalog()

	var map := CourseCatalog.new()
	map.size = Vector2(1080, 1920)
	map.show_catalog(cat, {"Basic Arcana 101": Grading.Grade.S})

	check(map.get_child_count() > 0, "the map built children")
	# The edges and the node buttons now share one scrollable content control (so an
	# arbitrarily tall syllabus can scroll as a single unit) rather than being direct
	# children of the map itself -- find that shared parent via a button, and confirm
	# the edges are its first child, drawn behind every node it also parents.
	check(map.node_buttons.size() > 0, "sanity: the map has at least one node button")
	var content: Node = (map.node_buttons.values()[0] as Node).get_parent()
	check(content.get_child(0) is Node2D, "the edges container is the first child, behind the buttons")
	check(content.get_child(0) == map.find_children("*", "Node2D", true, false)[0], "that Node2D is the map's edges container")
	eq(map.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the map itself ignores the mouse")
	for course_name in map.node_buttons:
		eq(
			map.node_buttons[course_name].mouse_filter,
			Control.MOUSE_FILTER_STOP,
			"map node buttons take taps"
		)
		check(
			map.node_buttons[course_name].custom_minimum_size.x >= 96.0
			and map.node_buttons[course_name].custom_minimum_size.y >= 96.0,
			"map nodes are thumb-sized"
		)

	map.free()


func _test_course_chosen_signal() -> void:
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	var cat := lib.catalog()

	var map := CourseCatalog.new()
	map.size = Vector2(1080, 1920)
	map.show_catalog(cat, {})

	var chosen: Array = []
	map.course_chosen.connect(func(course): chosen.append(course))
	var button: Button = map.node_buttons["Basic Arcana 101"]
	button.pressed.emit()
	eq(chosen.size(), 1, "pressing a node emits course_chosen exactly once")
	eq(
		(chosen[0] as CourseData).course_name,
		"Basic Arcana 101",
		"the emitted course is the one tapped"
	)

	map.free()


func _test_bestiary_known_and_unknown() -> void:
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	check(lib.enemies.size() >= 2, "sanity: fixture has at least two examiners")

	var target: EnemyData = lib.enemies[0]
	var stranger: EnemyData = lib.enemies[1]

	var known := Bestiary.new()
	known.record_hit(target, target.weak_school)

	var beast := BestiaryScreen.new()
	beast.show_bestiary(known, lib.enemies)

	var beast_text := ""
	for child in beast.find_children("*", "Label", true, false):
		beast_text += child.text + " "

	check(beast_text.contains(target.enemy_name), "listed the known examiner")
	check(
		beast_text.contains(Schools.display_name(target.weak_school)),
		"a known weakness shows its school name"
	)
	check(beast_text.contains("?"), "unknown wards/weaknesses show ? rather than being omitted")
	check(
		beast_text.contains(stranger.enemy_name),
		"an examiner nobody has fought is still listed, not omitted"
	)
	check(
		not known.knows_weakness(stranger.enemy_name), "sanity: the stranger's weakness is unknown"
	)

	beast.free()


## The scroll content must be tall enough for the last row and no taller. Row centres
## are 0-indexed, so multiplying by the row COUNT leaves a full empty ROW_HEIGHT of
## overscroll -- 300px of dead space on the single-row catalog a fresh run shows.
func _test_scroll_height_has_no_dead_row() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var screen := CourseCatalog.new()
	screen.size = Vector2(1080, 1920)
	screen.show_catalog(library.catalog(), {})

	var content: Control = null
	for scroll in screen.find_children("*", "ScrollContainer", true, false):
		for child in scroll.get_children():
			if child is Control and child.custom_minimum_size.y > 0.0:
				content = child
				break
	check(content != null, "found the scrolling content node")
	if content == null:
		screen.free()
		return

	# A fresh run reveals only the three prerequisite-free courses: one row.
	var lowest := 0.0
	for name in screen.node_buttons:
		var button: Button = screen.node_buttons[name]
		lowest = maxf(lowest, button.position.y + button.size.y)
	check(lowest > 0.0, "at least one node was placed")
	check(
		content.custom_minimum_size.y >= lowest,
		"content reaches the lowest node (%.0f >= %.0f)" % [content.custom_minimum_size.y, lowest]
	)
	check(
		content.custom_minimum_size.y < lowest + CourseCatalog.ROW_HEIGHT,
		"no empty row below the last one (%.0f, lowest node ends %.0f)"
			% [content.custom_minimum_size.y, lowest]
	)
	screen.free()
