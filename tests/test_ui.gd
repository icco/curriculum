extends "res://tests/TestCase.gd"

## Guards two things that have broken before and are invisible when they do:
## a Control that swallows board taps, and a theme variation that does not exist.

var _nodes: Array = []

func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			_root().remove_child(n)
			n.free()
	_nodes.clear()

func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

func _mount(node: Node) -> Node:
	_root().add_child(node)
	_nodes.append(node)
	return node

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)

## A full-rect Control with the default filter makes the board silently
## unresponsive, so every non-interactive Control must ignore the mouse.
func test_hud_controls_do_not_swallow_board_taps() -> void:
	var hud: HUD = _mount(HUD.new())
	var all: Array = []
	_walk(hud, all)
	var checked := 0
	for node: Node in all:
		if not (node is Control):
			continue
		var control := node as Control
		if control is Button:
			eq(control.mouse_filter, Control.MOUSE_FILTER_STOP,
				"%s is a button and should capture taps" % control.name)
			continue
		checked += 1
		eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must let taps through to the board" % _path_of(control, hud))
	truthy(checked > 5, "walked a real HUD tree (%d controls)" % checked)

func test_loop_screen_blocks_input_while_open() -> void:
	var screen: LoopScreen = _mount(LoopScreen.new())
	falsy(screen.is_open(), "starts closed")
	var state := GameState.new()
	screen.show_loop_failed(state, {"depth": 2, "kills": 3, "insight": 4})
	truthy(screen.is_open(), "opens on a failed loop")
	# The scrim is deliberately STOP: the board must not be tappable behind it.
	var all: Array = []
	_walk(screen, all)
	var found_scrim := false
	for node: Node in all:
		if node is ColorRect and (node as ColorRect).mouse_filter == Control.MOUSE_FILTER_STOP:
			found_scrim = true
	truthy(found_scrim, "a blocking scrim covers the board")

func test_theme_defines_every_variation_the_ui_asks_for() -> void:
	var theme := UIKit.theme()
	truthy(theme != null, "theme resource loads")
	for variation: String in ["PrimaryButton", "DangerButton", "DimButton", "ListButton"]:
		truthy(theme.has_stylebox("normal", variation), "%s has a normal stylebox" % variation)
		eq(theme.get_type_variation_base(variation), &"Button", "%s varies Button" % variation)
	for variation: String in ["TitleLabel", "HeadingLabel", "StatusLabel", "DimLabel",
			"BannerLabel", "HintLabel", "GoodLabel", "InsightLabel"]:
		truthy(theme.has_font_size("font_size", variation), "%s sets a font size" % variation)
		eq(theme.get_type_variation_base(variation), &"Label", "%s varies Label" % variation)
	for variation: String in ["LogPanel", "ScreenPanel"]:
		truthy(theme.has_stylebox("panel", variation), "%s has a panel stylebox" % variation)
	truthy(theme.has_stylebox("fill", "ProgressBar"), "progress bars are styled")

func test_hud_action_buttons_cover_every_action_main_sends() -> void:
	var hud: HUD = _mount(HUD.new())
	# Toggling an unknown action would silently do nothing, so assert the set.
	for action: String in ["spells", "items", "dash", "loot", "door", "descend", "end_turn"]:
		hud.set_action_enabled(action, false)
		var button: Button = hud._buttons.get(action, null)
		truthy(button != null, "%s has a button" % action)
		truthy(button.disabled, "%s can be disabled" % action)
		hud.set_action_enabled(action, true)
		falsy(button.disabled, "%s can be enabled" % action)

func test_hud_touch_targets_meet_the_minimum() -> void:
	var hud: HUD = _mount(HUD.new())
	for action: String in hud._buttons:
		var button: Button = hud._buttons[action]
		truthy(button.custom_minimum_size.y >= 48.0,
			"%s is at least 48dp tall (%d)" % [action, int(button.custom_minimum_size.y)])
		truthy(button.custom_minimum_size.x >= 48.0,
			"%s is at least 48dp wide (%d)" % [action, int(button.custom_minimum_size.x)])

func _path_of(control: Control, root: Node) -> String:
	var names: Array = [control.get_class() if control.name == "" else str(control.name)]
	var cursor: Node = control.get_parent()
	while cursor != null and cursor != root:
		names.push_front(str(cursor.name))
		cursor = cursor.get_parent()
	return "/".join(names)
