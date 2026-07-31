class_name GameOver
extends Control

## The end of a run, either way it ends: graduation or expulsion. Both share this
## screen because both are terminal -- the only difference is the headline.

signal restarted


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_outcome(run) -> void:
	for child in get_children():
		child.queue_free()
	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	if run.won:
		root.add_child(UIKit.label("GRADUATED", 64))
		root.add_child(UIKit.label("You broke the curriculum.", 28))
	else:
		root.add_child(UIKit.label("EXPELLED", 64))
		root.add_child(UIKit.label("Two failures. Your enrolment is terminated.", 28))

	root.add_child(UIKit.label("Courses passed: %d" % run.courses_passed, 26))
	var again := UIKit.button("Enroll again")
	again.pressed.connect(func(): restarted.emit())
	root.add_child(again)
