class_name MainMenu
extends Control

## The front door. Offers Continue only when a save exists, so a fresh install never
## shows a dead button.

signal new_run_requested
signal continue_requested
signal bestiary_requested


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(has_save: bool) -> void:
	for child in get_children():
		child.queue_free()
	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.label("CURRICULUM", 72))
	root.add_child(UIKit.label("The only way to learn is by playing.", 26))

	if has_save:
		var resume := UIKit.button("Continue")
		resume.pressed.connect(func(): continue_requested.emit())
		root.add_child(resume)

	var fresh := UIKit.button("Enroll")
	fresh.pressed.connect(func(): new_run_requested.emit())
	root.add_child(fresh)

	var beast := UIKit.button("Bestiary")
	beast.pressed.connect(func(): bestiary_requested.emit())
	root.add_child(beast)
