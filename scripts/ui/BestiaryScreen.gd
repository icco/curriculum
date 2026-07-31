class_name BestiaryScreen
extends Control

## What the student has learned about examiners this run. Unknown entries show "?"
## rather than being omitted, so the player can see there is something left to
## discover -- an enemy never fought at all still gets a row, just an uninformative one.

signal closed


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_bestiary(bestiary: Bestiary, enemies: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.label("Student Bestiary", 40))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Exception to the container-ignores-mouse rule: a ScrollContainer must take the
	# mouse itself to scroll, but this does not stop its own children (the row labels
	# below) from also receiving input -- STOP only blocks ancestors further up, not
	# descendants, so this does not reintroduce the "container eats the tap" bug.
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)

	var list := UIKit.transparent(VBoxContainer.new())
	scroll.add_child(list)

	for enemy in enemies:
		var weak := (
			Schools.display_name(enemy.weak_school)
			if bestiary.knows_weakness(enemy.enemy_name)
			else "?"
		)
		var ward := (
			Schools.display_name(enemy.warded_school)
			if bestiary.knows_ward(enemy.enemy_name)
			else "?"
		)
		list.add_child(
			UIKit.label("%s — weak: %s   warded: %s" % [enemy.enemy_name, weak, ward], 26)
		)

	var button := UIKit.button("Back")
	button.pressed.connect(func(): closed.emit())
	root.add_child(button)
