class_name CourseCatalog
extends Control

## The syllabus map: tier rows of medallion buttons with Line2D prerequisite edges
## behind them. Tap targets are thumb-sized per the brief. A course already attempted
## is drawn (so the run's history stays visible) but disabled -- there are no retakes.
##
## A tier can reveal more nodes than comfortably fit in one row (Midterm Review's
## whole tier can be six courses deep once enough prerequisites are cleared), so a
## tier's courses wrap across as many rows as they need instead of cramming onto one,
## and the whole map lives inside a ScrollContainer so an arbitrarily tall syllabus
## always stays reachable rather than running off the bottom of the screen.

signal course_chosen(course: CourseData)

const NODE_SIZE := Vector2(170, 170)
const ROW_HEIGHT := 300.0
const TOP_PADDING := 140.0
const BOTTOM_PADDING := 120.0
const MIN_GAP := 40.0  ## minimum breathing room between two node edges in a row
const MAX_COLS := 3  ## a row never gets busier than this, even on a wide screen

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

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.label("Course Catalog", 36))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A ScrollContainer must take the mouse itself to scroll -- the "containers ignore
	# the mouse" rule is for layout wrappers over a tap target, and here the scroll
	# view IS the tap target for reaching whatever is further down the syllabus.
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var width := size.x if size.x > 0.0 else 1080.0

	var revealed: Array = catalog.revealed(grades)
	var by_tier := {}
	for course in revealed:
		if not by_tier.has(course.tier):
			by_tier[course.tier] = []
		by_tier[course.tier].append(course)
	var tiers := by_tier.keys()
	tiers.sort()

	# Never squeeze more nodes into a row than the screen has room for, however many
	# a tier reveals at once -- wrap the overflow onto additional rows instead of
	# overlapping or running past the edge.
	var cols_that_fit: int = maxi(1, int(width / (NODE_SIZE.x + MIN_GAP)))
	var cols_per_row: int = mini(MAX_COLS, cols_that_fit)

	var rows: Array = []  ## Array[Array[CourseData]], each inner array one row
	for tier in tiers:
		var courses: Array = by_tier[tier]
		var i := 0
		while i < courses.size():
			rows.append(courses.slice(i, mini(i + cols_per_row, courses.size())))
			i += cols_per_row

	var total_height := TOP_PADDING + float(rows.size()) * ROW_HEIGHT + NODE_SIZE.y * 0.5 + BOTTOM_PADDING

	var content := UIKit.transparent(Control.new())
	content.custom_minimum_size = Vector2(width, total_height)
	scroll.add_child(content)

	# Edges first so they sit behind the node buttons, both added to `content` so
	# their coordinates share the same scrolling space as the nodes they connect.
	_edges = Node2D.new()
	content.add_child(_edges)

	var centres := {}
	for row in rows.size():
		var courses: Array = rows[row]
		for i in courses.size():
			var course: CourseData = courses[i]
			var x := width * (float(i) + 1.0) / (float(courses.size()) + 1.0)
			var y := TOP_PADDING + float(row) * ROW_HEIGHT
			var centre := Vector2(x, y)
			centres[course.course_name] = centre
			_add_course_node(content, course, centre, catalog.is_available(course, grades))

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


## Builds the tap target and its name label as two separate nodes rather than one
## Button with inline text. A Button's minimum size grows to fit an icon plus text at
## the theme's default font size (32), which silently overrides the fixed NODE_SIZE
## this map relies on for its column spacing -- long course names ("Applied Wardcraft
## 301") were forcing buttons wider than their allotted column, so neighbouring nodes
## grew until they touched or overlapped instead of reading as a spaced-out tier row.
## An icon-only button keeps the tap target pinned to NODE_SIZE, and the wrapped label
## underneath is free to use its own smaller font without feeding back into the
## button's layout.
func _add_course_node(content: Control, course: CourseData, centre: Vector2, available: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.position = centre - NODE_SIZE * 0.5
	button.icon = ArtFactory.medallion(course.tier, Vector2i(96, 96))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.disabled = not available
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): course_chosen.emit(course))
	node_buttons[course.course_name] = button
	content.add_child(button)

	var label := Label.new()
	label.text = course.course_name
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(NODE_SIZE.x, 0)
	label.size = Vector2(NODE_SIZE.x, 0)
	label.position = Vector2(centre.x - NODE_SIZE.x * 0.5, centre.y + NODE_SIZE.y * 0.5 + 8.0)
	content.add_child(label)
