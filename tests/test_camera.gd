extends "res://tests/TestCase.gd"

## Drives CameraRig with synthesised touch events so pan, pinch-zoom and tap
## detection are actually exercised rather than shipped on faith.

var _cam: CameraRig
var _taps: Array = []

func before_each() -> void:
	_cam = CameraRig.new()
	_root().add_child(_cam)
	_cam.set_bounds(Rect2(Vector2(-2000, -2000), Vector2(4000, 4000)))
	_cam.position = Vector2.ZERO
	_taps = []
	_cam.tapped.connect(func(p: Vector2) -> void: _taps.append(p))

## Freed, not queued: the suite finishes before deferred deletions run.
func after_each() -> void:
	if _cam != null and is_instance_valid(_cam):
		_root().remove_child(_cam)
		_cam.free()
	_cam = null

func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_cam._unhandled_input(e)

func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relative
	_cam._unhandled_input(e)

func test_starts_at_a_sensible_zoom() -> void:
	between(_cam.zoom.x, CameraRig.MIN_ZOOM, CameraRig.MAX_ZOOM, "default zoom is in range")

func test_single_finger_drag_pans_the_camera() -> void:
	var before := _cam.position
	_touch(0, Vector2(400, 300), true)
	_drag(0, Vector2(340, 300), Vector2(-60, 0))
	_touch(0, Vector2(340, 300), false)
	truthy(_cam.position.x > before.x, "dragging left moves the camera right across the floor")

func test_pan_is_scaled_by_zoom() -> void:
	_cam.zoom = Vector2(2.0, 2.0)
	_cam.position = Vector2.ZERO
	_touch(0, Vector2(400, 300), true)
	_drag(0, Vector2(300, 300), Vector2(-100, 0))
	_touch(0, Vector2(300, 300), false)
	var zoomed_in := _cam.position.x

	_cam.zoom = Vector2(1.0, 1.0)
	_cam.position = Vector2.ZERO
	_touch(1, Vector2(400, 300), true)
	_drag(1, Vector2(300, 300), Vector2(-100, 0))
	_touch(1, Vector2(300, 300), false)
	truthy(_cam.position.x > zoomed_in, "the same swipe covers more ground when zoomed out")

func test_pinch_apart_zooms_in_and_together_zooms_out() -> void:
	_cam.zoom = Vector2(1.0, 1.0)
	# Two fingers 100px apart.
	_touch(0, Vector2(500, 300), true)
	_touch(1, Vector2(600, 300), true)
	# Spread them to 200px.
	_drag(0, Vector2(450, 300), Vector2(-50, 0))
	_drag(1, Vector2(650, 300), Vector2(50, 0))
	var spread := _cam.zoom.x
	truthy(spread > 1.0, "spreading fingers zooms in (%f)" % spread)

	# Bring them back together.
	_drag(0, Vector2(540, 300), Vector2(90, 0))
	_drag(1, Vector2(560, 300), Vector2(-90, 0))
	truthy(_cam.zoom.x < spread, "pinching together zooms back out")
	_touch(0, Vector2(540, 300), false)
	_touch(1, Vector2(560, 300), false)

func test_zoom_is_clamped() -> void:
	for i in 40:
		_cam._apply_zoom(2.0, Vector2(576, 324))
	# Zoom is a float32 property, so compare with a tolerance.
	between(_cam.zoom.x, CameraRig.MAX_ZOOM - 0.001, CameraRig.MAX_ZOOM + 0.001,
		"clamps at the maximum")
	for i in 40:
		_cam._apply_zoom(0.5, Vector2(576, 324))
	between(_cam.zoom.x, CameraRig.MIN_ZOOM - 0.001, CameraRig.MIN_ZOOM + 0.001,
		"clamps at the minimum")

func test_zoom_keeps_the_anchor_point_steady() -> void:
	_cam.zoom = Vector2(1.0, 1.0)
	_cam.position = Vector2.ZERO
	var anchor := Vector2(700, 400)
	var world_before := _cam.screen_to_world(anchor)
	_cam._apply_zoom(1.6, anchor)
	var world_after := _cam.screen_to_world(anchor)
	truthy(world_before.distance_to(world_after) < 1.0,
		"the point under the fingers stays put (moved %f px)" % world_before.distance_to(world_after))

func test_short_press_reports_a_tap() -> void:
	_touch(0, Vector2(500, 320), true)
	_touch(0, Vector2(502, 321), false)
	eq(_taps.size(), 1, "a short press with no travel is a tap")

func test_drag_does_not_report_a_tap() -> void:
	_touch(0, Vector2(500, 320), true)
	_drag(0, Vector2(400, 320), Vector2(-100, 0))
	_touch(0, Vector2(400, 320), false)
	eq(_taps.size(), 0, "panning the camera is not a tap")

func test_pinch_does_not_report_a_tap() -> void:
	_touch(0, Vector2(500, 300), true)
	_touch(1, Vector2(600, 300), true)
	_drag(0, Vector2(450, 300), Vector2(-50, 0))
	_drag(1, Vector2(650, 300), Vector2(50, 0))
	_touch(0, Vector2(450, 300), false)
	_touch(1, Vector2(650, 300), false)
	eq(_taps.size(), 0, "a pinch never counts as a tap")

func test_tap_reports_world_coordinates() -> void:
	_cam.zoom = Vector2(1.0, 1.0)
	_cam.position = Vector2(500, 500)
	_touch(0, Vector2(300, 200), true)
	_touch(0, Vector2(300, 200), false)
	eq(_taps.size(), 1, "tap registered")
	var reported: Vector2 = _taps[0]
	var expected := _cam.screen_to_world(Vector2(300, 200))
	truthy(reported.distance_to(expected) < 0.5, "tap is converted to world space")

func test_position_is_clamped_to_bounds() -> void:
	_cam.set_bounds(Rect2(Vector2(0, 0), Vector2(100, 100)))
	_cam.focus_on(Vector2(99999, 99999), true)
	truthy(_cam.position.x <= _cam.bounds.end.x, "cannot pan past the right edge")
	_cam.focus_on(Vector2(-99999, -99999), true)
	truthy(_cam.position.x >= _cam.bounds.position.x, "cannot pan past the left edge")
