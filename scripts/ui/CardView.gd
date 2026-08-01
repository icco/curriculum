class_name CardView
extends Control

## One card. Dragged upward to play, tapped to inspect. Portrait 2:3, so it stays
## legible in a five-card fan on a 1080-wide screen.

signal play_requested(card)
signal inspect_requested(card)

## Smaller than the original 200x300: at that size, five fanned and tilted cards
## overlapped enough to clip each other's names. 170x255 keeps the 2:3 portrait and
## leaves every card in a five-hand fully clear of its neighbours (see HandFan).
const CARD_SIZE := Vector2(170, 255)
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
	# The card's own school, not one hashed from the key: the ink IS the school cue.
	frame.texture = ArtLibrary.texture(card.data.art_id, Vector2i(CARD_SIZE), card.data.school)
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

	# Text must contrast with the school's ink, not with the theme. Ink is #000000, so a
	# black-on-black card name is invisible — a fifth of the pool unreadable.
	var ink: Color = Schools.colour(card.data.school)
	var text_colour: Color = ArtLibrary.PAPER if ink.get_luminance() < 0.4 else ArtLibrary.INK

	# What the card actually DOES. Without this, a player can only tell cards apart by
	# name and has to have memorised all 48 — the single biggest readability gap
	# reported from the playtest.
	var effects_box := UIKit.label(effect_summary(card.data.effects), 19)
	effects_box.position = Vector2(10, CARD_SIZE.y - 112)
	effects_box.size = Vector2(CARD_SIZE.x - 20, 54)
	effects_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effects_box.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	effects_box.clip_text = true
	_paint_card_text(effects_box, text_colour)
	add_child(effects_box)

	var name_box := UIKit.label(card.data.card_name, 22)
	name_box.position = Vector2(10, CARD_SIZE.y - 50)
	name_box.size = Vector2(CARD_SIZE.x - 20, 30)
	name_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint_card_text(name_box, text_colour)
	add_child(name_box)

	var cost := UIKit.label(str(card.data.cost), 26)
	cost.position = Vector2(10, 6)
	_paint_card_text(cost, text_colour)
	add_child(cost)

	var sigil := TextureRect.new()
	sigil.texture = ArtFactory.sigil(card.data.school, Vector2i(28, 28))
	sigil.position = Vector2(CARD_SIZE.x - 38, 6)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sigil)

	# XP ticks along the bottom edge.
	if card.can_evolve():
		for i in card.data.xp_to_evolve:
			var tick := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = ArtLibrary.INK if i < card.xp else ArtLibrary.SLATE
			tick.add_theme_stylebox_override("panel", style)
			tick.size = Vector2(16, 6)
			tick.position = Vector2(10 + i * 20, CARD_SIZE.y - 14)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tick)


## Turns a card's effects into short, plain-English text — "6 damage", "+6 block",
## "3 Burn", "12 damage, lose 3 hp" — so a card can be judged without memorising it.
## Static and pure so it is trivially testable on its own.
static func effect_summary(effects: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var kind: String = str(effect.get("kind", ""))
		var amount: int = int(effect.get("amount", 0))
		match kind:
			CardData.DAMAGE:
				parts.append("%d damage" % amount)
			CardData.BLOCK:
				parts.append("+%d block" % amount)
			CardData.HEAL:
				parts.append("+%d heal" % amount)
			CardData.STATUS:
				parts.append("%d %s" % [amount, _status_name(effect.get("status", Statuses.Kind.BURN))])
			CardData.DRAW:
				parts.append("Draw %d" % amount)
			CardData.MANA_NEXT:
				parts.append("+%d mana next turn" % amount)
			CardData.SELF_DAMAGE:
				parts.append("lose %d hp" % amount)
			CardData.DOUBLE_DECAY:
				parts.append("doubles Decay")
			CardData.BONUS_IF_CHILLED:
				parts.append("+%d if chilled" % amount)
			CardData.BONUS_IF_WARD_PLAYED:
				parts.append("+%d if warded" % amount)
	return ", ".join(parts)


static func _status_name(kind) -> String:
	match int(kind):
		Statuses.Kind.BURN:
			return "Burn"
		Statuses.Kind.CHILL:
			return "Chill"
		Statuses.Kind.BLOT:
			return "Blot"
		Statuses.Kind.DECAY:
			return "Decay"
	return "?"


## Colours a card label AND gives it a matching thin outline. Rotated text on a
## grainy card background can turn a single-stroke glyph (a capital I is nothing but
## one thin vertical bar) into a scattering of sub-pixel fragments once the whole
## card is tilted and the frame is downsampled — the outline thickens every glyph
## just enough that this can't happen, without changing the colour the eye reads.
func _paint_card_text(label: Label, colour: Color) -> void:
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", colour)
	label.add_theme_constant_override("outline_size", 3)


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
