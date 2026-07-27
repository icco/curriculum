class_name CameraRig
extends Camera2D

## Touch camera: one finger drags the floor, two fingers pinch to zoom, and a
## short press without travel is reported as a tap. Mouse input is treated as
## touch (project setting emulate_touch_from_mouse) so the same code path is
## exercised on desktop.

signal tapped(world_pos: Vector2)

const MIN_ZOOM := 0.55
const MAX_ZOOM := 2.6

@export var pan_enabled: bool = true
@export_range(0.5, 3.0, 0.05) var start_zoom: float = 1.25
## Travel still counted as a tap, in pixels.
@export_range(2.0, 40.0) var tap_slop: float = 14.0
## How long a tap may last, in seconds.
@export_range(0.1, 1.0, 0.05) var tap_time: float = 0.4

var bounds: Rect2 = Rect2()
var _touches: Dictionary = {}        ## index -> current position
var _press_start: Dictionary = {}    ## index -> {pos, time}
var _pinch_distance: float = 0.0
var _dragging: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	zoom = Vector2(start_zoom, start_zoom)
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta

func focus_on(world_pos: Vector2, immediate: bool = false) -> void:
	var target := _clamp_to_bounds(world_pos)
	if immediate:
		position = target
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target, 0.35)

func set_bounds(rect: Rect2) -> void:
	bounds = rect.grow(220.0)
	position = _clamp_to_bounds(position)

func _clamp_to_bounds(p: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return p
	return Vector2(
		clampf(p.x, bounds.position.x, bounds.end.x),
		clampf(p.y, bounds.position.y, bounds.end.y)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMagnifyGesture:
		_apply_zoom(event.factor, event.position)
	elif event is InputEventPanGesture:
		_apply_zoom(1.0 - event.delta.y * 0.04, event.position)
	elif event is InputEventMouseButton and event.pressed:
		# Desktop convenience: wheel zoom around the pointer.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(1.0 / 1.1, event.position)
	elif event.is_action_pressed("camera_zoom_in"):
		_apply_zoom(1.15, get_viewport_rect().size * 0.5)
	elif event.is_action_pressed("camera_zoom_out"):
		_apply_zoom(1.0 / 1.15, get_viewport_rect().size * 0.5)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_press_start[event.index] = {"pos": event.position, "time": _elapsed}
		if _touches.size() == 2:
			_pinch_distance = _current_pinch_distance()
			_dragging = false
	else:
		var start: Dictionary = _press_start.get(event.index, {})
		_touches.erase(event.index)
		_press_start.erase(event.index)
		if _touches.is_empty():
			_dragging = false
		if start.is_empty():
			return
		var travel: float = (event.position - (start["pos"] as Vector2)).length()
		var held: float = _elapsed - float(start["time"])
		if travel <= tap_slop and held <= tap_time and not _dragging:
			tapped.emit(screen_to_world(event.position))

func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var d := _current_pinch_distance()
		if _pinch_distance > 1.0 and d > 1.0:
			_apply_zoom(d / _pinch_distance, _pinch_midpoint())
		_pinch_distance = d
		_dragging = true
		return
	if not pan_enabled:
		return
	if event.relative.length() > 1.0:
		_dragging = true
	position = _clamp_to_bounds(position - event.relative / zoom)

func _current_pinch_distance() -> float:
	var keys: Array = _touches.keys()
	if keys.size() < 2:
		return 0.0
	return ((_touches[keys[0]] as Vector2) - (_touches[keys[1]] as Vector2)).length()

func _pinch_midpoint() -> Vector2:
	var keys: Array = _touches.keys()
	if keys.size() < 2:
		return get_viewport_rect().size / 2.0
	return ((_touches[keys[0]] as Vector2) + (_touches[keys[1]] as Vector2)) / 2.0

## Zooms about a screen anchor so the point under the fingers stays put.
func _apply_zoom(factor: float, anchor: Vector2) -> void:
	var before := screen_to_world(anchor)
	var z: float = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	var after := screen_to_world(anchor)
	position = _clamp_to_bounds(position + (before - after))

## Computed from position/zoom, not get_canvas_transform(): that is a frame
## stale after a zoom change, which breaks pinch anchoring.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5
	return position + offset + (screen_pos - half) / zoom
