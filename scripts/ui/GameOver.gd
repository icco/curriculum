class_name GameOver
extends Control

## The end of a run, either way it ends: graduation or expulsion. Both share this
## screen because both are terminal -- the only difference is the headline.

signal restarted

const BUTTON_WIDTH := 360.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_outcome(run) -> void:
	for child in get_children():
		child.queue_free()

	# A CenterContainer sizes its child to that child's own minimum size and centres
	# it in the screen, both axes -- the fix for a heading and a lone full-width
	# button huddled at the very top of a 1920-tall screen with nothing else on it.
	var root := UIKit.transparent(CenterContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var column := UIKit.transparent(VBoxContainer.new())
	column.add_theme_constant_override("separation", 24)
	root.add_child(column)

	var headline := UIKit.label("GRADUATED" if run.won else "EXPELLED", 64)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(headline)

	var subtitle := UIKit.label(
		(
			"You broke the curriculum."
			if run.won
			else "Two failures. Your enrolment is terminated."
		),
		28
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var tally := UIKit.label("Courses passed: %d" % run.courses_passed, 26)
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tally)

	var gap := UIKit.transparent(Control.new())
	gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(gap)

	# A fixed, generous width and centred in its column -- not stretched edge to edge
	# the way a VBoxContainer fills its children by default.
	var again := UIKit.button("Enroll again")
	again.custom_minimum_size.x = BUTTON_WIDTH
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func(): restarted.emit())
	column.add_child(again)
