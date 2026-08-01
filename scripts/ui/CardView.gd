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
## How long a card takes to slide to its place in the fan.
const SETTLE_TIME := 0.16

var card: CardInstance = null

var _dragging := false
var _drag_start := Vector2.ZERO
var _home := Vector2.ZERO
var _playable := true
## The CardData this view's face was drawn from, so sync() can tell when a card has
## evolved underneath a REUSED view and only then pay for a rebuild.
var _rendered_data: CardData = null
var _progress_box: Label = null
var _tween: Tween = null


func setup(instance: CardInstance) -> void:
	card = instance
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Brings a reused view up to date. Views persist across a refresh now, so two things
## can drift underneath one: the card can EVOLVE mid-battle (CardInstance swaps its
## CardData pointer), which needs the whole face redrawn, and it can bank XP, which
## only needs its progress line rewritten. Rebuilding unconditionally would throw away
## the persistence this exists to provide.
func sync() -> void:
	if card == null:
		return
	if card.data != _rendered_data:
		_build()
	elif _progress_box != null and card.can_evolve():
		_progress_box.text = card.progress()


func _build() -> void:
	# remove_child is NOT redundant with queue_free here. queue_free is deferred to
	# the end of the frame, so without the explicit removal this view would still be
	# holding its old face's nodes for the rest of the tick -- and _build then adds a
	# second full set on top of them.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_progress_box = null
	if card == null:
		return
	_rendered_data = card.data

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
	name_box.size = Vector2(CARD_SIZE.x - 20, 26)
	# Centred, not left: left-aligned text starting flush at the label's own edge
	# lost its leading glyph once rotated ("Ink Blot" rendered as "nk Blot") even
	# though the card itself had room to spare. Centring moves the first character
	# away from that edge.
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

	# Evolution progress. A row of one-tick-per-XP does not generalise: at a
	# threshold of 24 (higher-tier cards on the five-level evolution track) that is
	# 24 ticks at the old fixed spacing, landing hundreds of pixels off a ~200px
	# card. Text scales to any threshold, and CardInstance.progress() also carries
	# which level the card is on ("L2 3/9"), which discrete ticks never showed.
	if card.can_evolve():
		_progress_box = UIKit.label(card.progress(), 16)
		_progress_box.position = Vector2(10, CARD_SIZE.y - 20)
		_progress_box.size = Vector2(CARD_SIZE.x - 20, 16)
		_progress_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_paint_card_text(_progress_box, text_colour)
		add_child(_progress_box)


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
				parts.append(
					"%d %s" % [amount, UIKit.status_name(effect.get("status", Statuses.Kind.BURN))]
				)
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


## Colours a card label and gives it a same-colour outline, which thickens every
## glyph a little without changing the colour the eye reads — cheap insurance for
## thin strokes against the card's grainy painted background.
func _paint_card_text(label: Label, colour: Color) -> void:
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", colour)
	label.add_theme_constant_override("outline_size", 3)


func set_playable(value: bool) -> void:
	_playable = value
	modulate.a = 1.0 if value else 0.45


## Moves the card to its place in the fan, sliding rather than snapping when it can.
##
## `animate` is false for a card being dealt for the first time — it has no meaningful
## previous position to travel from, so it is placed and then slid the short distance
## HandFan offsets it by. Falls back to an instant move whenever there is no live
## SceneTree, which is how every headless suite builds these.
func settle_at(target: Vector2, target_rotation: float, animate: bool) -> void:
	_home = target
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	if not animate or not is_inside_tree():
		position = target
		rotation = target_rotation
		return
	_tween = create_tween().set_parallel()
	(
		_tween
		. tween_property(self, "position", target, SETTLE_TIME)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_property(self, "rotation", target_rotation, SETTLE_TIME)


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
