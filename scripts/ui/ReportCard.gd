class_name ReportCard
extends Control

## Post-battle breakdown. Shows all four terms, because the player needs to see that
## learning is what earned the grade — grading on speed alone would make never
## learning the optimal strategy, which inverts the whole premise.

signal continued

var _rows: VBoxContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_result(scored: Dictionary, result: Dictionary, course) -> void:
	for child in get_children():
		child.free()

	_rows = UIKit.transparent(VBoxContainer.new()) as VBoxContainer
	_rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rows)

	_rows.add_child(UIKit.label(course.course_name, 36))
	_rows.add_child(UIKit.label(Grading.letter(scored["grade"]), 120))

	for term in ["efficiency", "survival", "learning", "discovery"]:
		_rows.add_child(
			UIKit.label("%s  %.0f / 25" % [term.capitalize(), float(scored[term])], 28)
		)
	_rows.add_child(UIKit.label("Total  %.0f / 100" % float(scored["total"]), 32))

	var allowance: int = Grading.draft_allowance(scored["grade"])
	var allowance_text := (
		"You may copy their whole deck."
		if allowance < 0
		else "You may copy %d of their cards." % allowance
	)
	_rows.add_child(UIKit.label(allowance_text, 26))

	if bool(result.get("strike", false)):
		var strikes := int(result.get("strikes", 0))
		_rows.add_child(
			UIKit.label(
				"ACADEMIC PROBATION — strike %d of %d" % [strikes, Run.MAX_STRIKES], 28
			)
		)
		_rows.add_child(UIKit.label("Your hit points have been restored.", 24))

	var button := UIKit.button("Continue")
	button.pressed.connect(func(): continued.emit())
	_rows.add_child(button)
