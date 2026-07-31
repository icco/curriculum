class_name CourseCatalog
extends Control

## The syllabus map: tier rows of medallion buttons with Line2D prerequisite edges
## behind them. Tap targets are thumb-sized per the brief. A course already attempted
## is drawn (so the run's history stays visible) but disabled -- there are no retakes.

signal course_chosen(course: CourseData)

const NODE_SIZE := Vector2(200, 200)
const ROW_HEIGHT := 380.0

var node_buttons := {}  ## course name -> Button

var _edges: Node2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func edge_count() -> int:
	return 0 if _edges == null else _edges.get_child_count()


func show_catalog(catalog: Catalog, grades: Dictionary) -> void:
	# Freed immediately rather than queue_free()'d: this screen is rebuilt in place
	# (grade earned -> map redrawn) and a headless test calls show_catalog() twice in
	# the same frame, so a deferred free would leave the first build's nodes alive
	# when the second build's node_buttons dictionary already forgot them.
	for child in get_children():
		remove_child(child)
		child.free()
	node_buttons = {}

	# Edges first so they sit behind the node buttons.
	_edges = Node2D.new()
	add_child(_edges)

	var revealed: Array = catalog.revealed(grades)
	var by_tier := {}
	for course in revealed:
		if not by_tier.has(course.tier):
			by_tier[course.tier] = []
		by_tier[course.tier].append(course)

	var width := size.x if size.x > 0.0 else 1080.0
	var centres := {}
	var tiers := by_tier.keys()
	tiers.sort()
	for row in tiers.size():
		var tier: int = tiers[row]
		var courses: Array = by_tier[tier]
		for i in courses.size():
			var course: CourseData = courses[i]
			var x := width * (float(i) + 1.0) / (float(courses.size()) + 1.0)
			var y := 220.0 + float(row) * ROW_HEIGHT
			var centre := Vector2(x, y)
			centres[course.course_name] = centre
			add_child(_node_button(course, centre, catalog.is_available(course, grades)))

	# Draw an edge for each prerequisite whose node is also on screen.
	for course in revealed:
		if not centres.has(course.course_name):
			continue
		for prerequisite in course.prerequisites:
			if not centres.has(prerequisite.course_name):
				continue
			var line := Line2D.new()
			line.width = 6.0
			line.default_color = ArtLibrary.SLATE
			line.points = [centres[prerequisite.course_name], centres[course.course_name]]
			_edges.add_child(line)


func _node_button(course: CourseData, centre: Vector2, available: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.position = centre - NODE_SIZE * 0.5
	button.text = course.course_name
	button.icon = ArtFactory.medallion(course.tier, Vector2i(96, 96))
	button.disabled = not available
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): course_chosen.emit(course))
	node_buttons[course.course_name] = button
	return button
