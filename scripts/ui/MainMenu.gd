class_name MainMenu
extends Control

## The front door. Offers Continue only when a save exists, so a fresh install never
## shows a dead button.

signal new_run_requested
signal continue_requested
signal bestiary_requested

const BUTTON_WIDTH := 360.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(has_save: bool) -> void:
	for child in get_children():
		child.queue_free()

	# A CenterContainer sizes its child to that child's own minimum size and centres
	# it in the screen, both axes -- the fix for a heading and a couple of buttons
	# huddled at the very top of a 1920-tall screen with nothing else on it.
	var root := UIKit.transparent(CenterContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var column := UIKit.transparent(VBoxContainer.new())
	column.add_theme_constant_override("separation", 28)
	root.add_child(column)

	var title := UIKit.label("CURRICULUM", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := UIKit.label("The only way to learn is by playing.", 26)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var gap := UIKit.transparent(Control.new())
	gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(gap)

	if has_save:
		column.add_child(_menu_button("Continue", func(): continue_requested.emit()))

	column.add_child(_menu_button("Enroll", func(): new_run_requested.emit()))
	column.add_child(_menu_button("Bestiary", func(): bestiary_requested.emit()))


## Every menu button is a fixed, generous width and centred in its column -- not
## stretched edge to edge the way a VBoxContainer fills its children by default.
func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := UIKit.button(text)
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	return button
