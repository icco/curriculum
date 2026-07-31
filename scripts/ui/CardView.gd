class_name CardView
extends Control

## One card. Dragged upward to play, tapped to inspect. Portrait 2:3, so it stays
## legible in a five-card fan on a 1080-wide screen.

signal play_requested(card)
signal inspect_requested(card)

const CARD_SIZE := Vector2(200, 300)
## How far up the card must be dragged before it counts as played.
const PLAY_THRESHOLD := 120.0

var card: CardInstance = null

var _dragging := false
var _drag_start := Vector2.ZERO
var _home := Vector2.ZERO
var _playable := true


func setup(instance: CardInstance) -> void:
	card = instance
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	if card == null:
		return

	var frame := TextureRect.new()
	frame.texture = ArtLibrary.texture(card.data.art_id, Vector2i(CARD_SIZE))
	frame.size = CARD_SIZE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# Fully evolved cards get a gold rim: same illustration, now mastered.
	if not card.can_evolve():
		var rim := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color("#E0A51F")
		box.set_border_width_all(6)
		rim.add_theme_stylebox_override("panel", box)
		rim.size = CARD_SIZE
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rim)

	var name_box := UIKit.label(card.data.card_name, 24)
	name_box.position = Vector2(16, CARD_SIZE.y - 96)
	name_box.size = Vector2(CARD_SIZE.x - 32, 40)
	add_child(name_box)

	var cost := UIKit.label(str(card.data.cost), 30)
	cost.position = Vector2(12, 8)
	add_child(cost)

	var sigil := TextureRect.new()
	sigil.texture = ArtFactory.sigil(card.data.school, Vector2i(32, 32))
	sigil.position = Vector2(CARD_SIZE.x - 44, 8)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sigil)

	# XP ticks along the bottom edge.
	if card.can_evolve():
		for i in card.data.xp_to_evolve:
			var tick := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = ArtLibrary.INK if i < card.xp else ArtLibrary.SLATE
			tick.add_theme_stylebox_override("panel", style)
			tick.size = Vector2(24, 8)
			tick.position = Vector2(16 + i * 30, CARD_SIZE.y - 24)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tick)


func set_playable(value: bool) -> void:
	_playable = value
	modulate.a = 1.0 if value else 0.45


func remember_home() -> void:
	_home = position


func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			_dragging = true
			_drag_start = mouse_event.global_position
			_home = position
		else:
			var lifted: float = _drag_start.y - mouse_event.global_position.y
			_dragging = false
			if _playable and lifted >= PLAY_THRESHOLD:
				play_requested.emit(card)
			else:
				position = _home
				inspect_requested.emit(card)
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
