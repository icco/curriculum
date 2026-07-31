class_name RegistrationScreen
extends Control

## The draft. Keeping exactly `cap` cards is the run's recurring decision, and cutting
## a card destroys its XP — which is why every card on this screen shows its progress.
## A Spark trained to 4/5 competes against a strictly better untrained Frost Lance;
## without the XP readout that trade-off is invisible.

signal registration_complete(kept)

var draft: Draft = null
var selected: Array = []

var _confirm: Button = null
var _counter: Label = null
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

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	root.add_child(UIKit.label("Registration", 40))
	_counter = UIKit.label("", 30)
	root.add_child(_counter)
	root.add_child(UIKit.label("Cutting a card loses the experience it earned.", 22))

	# A ScrollContainer legitimately needs to intercept scroll input to work at all —
	# the "every container ignores the mouse" rule is for containers that only exist
	# to lay out taps meant for something beneath them. This one IS the tap target.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_grid)

	for card in draft.own:
		_grid.add_child(_entry(card, false))
	for card in draft.offered:
		_grid.add_child(_entry(card, true))

	_confirm = UIKit.button("Confirm")
	_confirm.pressed.connect(_on_confirm)
	root.add_child(_confirm)


func _entry(card, is_offered: bool) -> Control:
	var column := UIKit.transparent(VBoxContainer.new())
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 120)
	# Every entry names its card's XP progress ("3/5" or "mastered") — the whole point
	# of this screen, since cutting a card destroys whatever progress it shows here.
	button.text = "%s\n%s%s" % [
		card.data.card_name,
		card.progress(),
		"  (theirs)" if is_offered else "",
	]
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): toggle(card))
	button.set_meta("card", card)
	column.add_child(button)
	return column


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
	if _counter != null:
		_counter.text = "Keep %d of %d" % [selected.size(), draft.cap]
	if _confirm != null:
		_confirm.disabled = not can_confirm()
	if _grid == null:
		return
	for column in _grid.get_children():
		for child in column.get_children():
			if child is Button and child.has_meta("card"):
				child.modulate = (
					Color("#E0A51F") if selected.has(child.get_meta("card")) else Color.WHITE
				)


func _on_confirm() -> void:
	if not can_confirm():
		return
	var kept := draft.keep(selected)
	if kept.is_empty():
		return  # Draft refused it; leave the screen up rather than losing the deck
	registration_complete.emit(kept)
