class_name RegistrationScreen
extends Control

## The draft. Keeping exactly `cap` cards is the run's recurring decision, and cutting
## a card destroys its XP — which is why every card on this screen shows its progress.
## A Spark trained to 4/5 competes against a strictly better untrained Frost Lance;
## without the XP readout that trade-off is invisible.

signal registration_complete(kept)

const ENTRY_HEIGHT := 128.0
const SELECTED_BORDER := 6
const BASE_BORDER := 2
## Fixed so the border width never changes a button's minimum size (content_margin
## defaults to -1, which derives the margin from border_width -- if selecting a card
## grew its border unevenly against its margin, the row would reflow on every tap).
const CONTENT_MARGIN := 16.0

var draft: Draft = null
var selected: Array = []

var _confirm: Button = null
var _counter: Label = null
var _status: Label = null
var _grid: GridContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(the_draft: Draft) -> void:
	draft = the_draft
	selected = []
	_build()
	_refresh()


func _build() -> void:
	for child in get_children():
		child.free()

	var margin := UIKit.transparent(MarginContainer.new())
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := UIKit.transparent(VBoxContainer.new())
	margin.add_child(root)

	root.add_child(UIKit.label("Registration", 40))
	_counter = UIKit.label("", 28)
	root.add_child(_counter)
	root.add_child(UIKit.label("Cutting a card loses the experience it earned.", 22))

	# A ScrollContainer legitimately needs to intercept scroll input to work at all —
	# the "every container ignores the mouse" rule is for containers that only exist
	# to lay out taps meant for something beneath them. This one IS the tap target.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	# The list is a single column, so it never needs to scroll sideways -- disabling
	# horizontal scroll makes the ScrollContainer clamp its child to its own width
	# instead of letting it float at whatever width its widest row's inline text
	# demanded, which is what clipped the old 4-column grid off the right edge.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	for card in draft.own:
		_grid.add_child(_entry(card, false))
	for card in draft.offered:
		_grid.add_child(_entry(card, true))

	# A persistent bottom bar, outside the scrolling list, so the Confirm button and
	# the reason it is (or isn't) enabled are always on screen together -- never
	# stranded below the fold with no explanation once the player scrolls the grid.
	var bar := UIKit.transparent(VBoxContainer.new())
	root.add_child(bar)
	_status = UIKit.label("", 22)
	bar.add_child(_status)

	_confirm = UIKit.button("Confirm")
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm.pressed.connect(_on_confirm)
	bar.add_child(_confirm)


## One school's ink, washed nearly to the paper colour, so every entry reads its
## school at a glance without needing light text over a solid ink field -- even Ink's
## own black tints down to a legible warm grey against black text.
func _tint(school: int) -> Color:
	return Schools.colour(school).lerp(ArtLibrary.PAPER, 0.72)


func _entry_style(school: int, selected_now: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _tint(school)
	style.border_color = ArtLibrary.INK if selected_now else Schools.colour(school)
	var border: float = SELECTED_BORDER if selected_now else BASE_BORDER
	style.set_border_width_all(border)
	# Keep the margin fixed regardless of border width so a tap never reflows the row.
	style.content_margin_left = CONTENT_MARGIN
	style.content_margin_right = CONTENT_MARGIN
	style.content_margin_top = CONTENT_MARGIN
	style.content_margin_bottom = CONTENT_MARGIN
	style.set_corner_radius_all(6)
	return style


func _entry(card, is_offered: bool) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Every entry names its card's XP progress ("3/5" or "mastered") — the whole point
	# of this screen, since cutting a card destroys whatever progress it shows here.
	# The school name is spelled out too, not just colour-coded, so the school cue
	# still reads for a colourblind player.
	button.text = "%s\n%s  •  %s" % [
		card.data.card_name,
		Schools.display_name(card.data.school),
		card.progress(),
	]
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): toggle(card))
	button.set_meta("card", card)
	button.set_meta("school", card.data.school)

	var style := _entry_style(card.data.school, false)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)

	if is_offered:
		button.add_child(_new_badge())

	return button


## A small "NEW" chip pinned to the button's top-right corner -- ownership as a shape
## and colour, not an easy-to-miss "(theirs)" suffix buried in the label text.
func _new_badge() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#E0A51F")
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "NEW"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", ArtLibrary.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	return panel


## Adds the card to the selection, or removes it if it is already selected. Refuses to
## add past `draft.cap` rather than silently evicting an existing pick to make room —
## a wrong-size or surprise-swapped selection is worse than a no-op tap.
func toggle(card) -> void:
	if selected.has(card):
		selected.erase(card)
	else:
		if selected.size() >= draft.cap:
			return  # the cap is the rule; refuse rather than silently swap
		selected.append(card)
	_refresh()


func can_confirm() -> bool:
	return draft != null and selected.size() == draft.cap


func _refresh() -> void:
	var remaining: int = maxi(0, draft.cap - selected.size()) if draft != null else 0
	if _counter != null and draft != null:
		_counter.text = (
			"Choose %d cards to keep — %d more to pick" % [draft.cap, remaining]
			if remaining > 0
			else "Choose %d cards to keep — ready to confirm" % draft.cap
		)
	if _status != null:
		_status.text = (
			"Tap Confirm to lock in this deck."
			if can_confirm()
			else "Pick %d more card%s to enable Confirm." % [remaining, "" if remaining == 1 else "s"]
		)
	if _confirm != null:
		_confirm.disabled = not can_confirm()
	if _grid == null:
		return
	for child in _grid.get_children():
		if child is Button and child.has_meta("card"):
			var is_selected: bool = selected.has(child.get_meta("card"))
			var style := _entry_style(int(child.get_meta("school")), is_selected)
			child.add_theme_stylebox_override("normal", style)
			child.add_theme_stylebox_override("hover", style)
			child.add_theme_stylebox_override("pressed", style)
			child.add_theme_stylebox_override("focus", style)


func _on_confirm() -> void:
	if not can_confirm():
		return
	var kept := draft.keep(selected)
	if kept.is_empty():
		return  # Draft refused it; leave the screen up rather than losing the deck
	registration_complete.emit(kept)
