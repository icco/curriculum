extends TestCase


func suite_name() -> String:
	return "schools"


func run() -> void:
	eq(Schools.ALL.size(), 5, "five schools")
	eq(Schools.display_name(Schools.School.ROT), "Rot", "rot name")
	eq(Schools.colour(Schools.School.CINDER), Color("#D45C3C"), "cinder ink")

	# Every school has a distinct name and colour, or the UI cannot tell them apart.
	var names := {}
	var colours := {}
	for school in Schools.ALL:
		names[Schools.display_name(school)] = true
		colours[Schools.colour(school)] = true
	eq(names.size(), 5, "distinct names")
	eq(colours.size(), 5, "distinct colours")
