class_name BattleScreen
extends Control

## Top half examiner, bottom half player and hand, per the brief. Replays the event
## arrays Battle returns; never computes a rule itself. The examiner's intent is
## always shown some text, even when there is none to telegraph — the design
## guarantees the player is never hit by untelegraphed damage, so a blank label
## here would look like a broken promise rather than a deliberate "hesitates".

signal battle_finished(battle)

var battle: Battle = null

var hand_fan: HandFan = null
var end_turn_button: Button = null
var intent_label: Label = null
var log_label: Label = null
var examiner_bar: ProgressBar = null
var player_bar: ProgressBar = null
var mana_label: Label = null
var piles_label: Label = null
var examiner_figure: TextureRect = null

const LOG_LINES := 6

var _log_lines: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(fight: Battle) -> void:
	battle = fight
	_build()
	replay(battle.start() if battle.turns == 0 else [])
	refresh()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# --- Top half: the examiner ---
	var top := UIKit.transparent(VBoxContainer.new())
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top)

	examiner_figure = TextureRect.new()
	examiner_figure.custom_minimum_size = Vector2(360, 520)
	examiner_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	examiner_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	examiner_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(examiner_figure)

	top.add_child(UIKit.label(battle.examiner.display_name, 40))
	examiner_bar = ProgressBar.new()
	examiner_bar.custom_minimum_size = Vector2(600, 40)
	examiner_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(examiner_bar)

	intent_label = UIKit.label("", 28)
	top.add_child(intent_label)

	log_label = UIKit.label("", 24)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(log_label)

	# --- Bottom half: the player ---
	var bottom := UIKit.transparent(VBoxContainer.new())
	root.add_child(bottom)

	player_bar = ProgressBar.new()
	player_bar.custom_minimum_size = Vector2(600, 40)
	player_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(player_bar)

	var row := UIKit.transparent(HBoxContainer.new())
	bottom.add_child(row)
	mana_label = UIKit.label("", 32)
	row.add_child(mana_label)
	piles_label = UIKit.label("", 24)
	row.add_child(piles_label)

	hand_fan = HandFan.new()
	hand_fan.custom_minimum_size = Vector2(1080, 340)
	hand_fan.size = Vector2(1080, 340)
	hand_fan.card_play_requested.connect(_on_card_played)
	bottom.add_child(hand_fan)

	end_turn_button = UIKit.button("End Turn")
	end_turn_button.pressed.connect(_on_end_turn)
	bottom.add_child(end_turn_button)


func _on_card_played(card) -> void:
	if battle == null or battle.finished:
		return
	replay(battle.play_card(card))
	refresh()
	_check_finished()


func _on_end_turn() -> void:
	if battle == null or battle.finished:
		return
	replay(battle.end_turn())
	refresh()
	_check_finished()


func _check_finished() -> void:
	if battle != null and battle.finished:
		end_turn_button.disabled = true
		battle_finished.emit(battle)


## Appends each event's text. Never mutates the battle: core has already resolved it,
## and this only renders what already happened.
func replay(events: Array) -> void:
	for event in events:
		var text: String = str(event.get("text", ""))
		if text != "":
			_log_lines.append(text)
	while _log_lines.size() > LOG_LINES:
		_log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(_log_lines)


func refresh() -> void:
	if battle == null:
		return
	examiner_bar.max_value = maxi(1, battle.examiner.max_hp)
	examiner_bar.value = battle.examiner.hp
	player_bar.max_value = maxi(1, battle.player.max_hp)
	player_bar.value = battle.player.hp

	examiner_figure.texture = ArtLibrary.texture(
		battle.examiner_art_id(), Vector2i(360, 520)
	)

	var block_text := "" if battle.player.block <= 0 else "  block %d" % battle.player.block
	mana_label.text = "%d/%d mana%s" % [battle.player.mana, battle.player.mana_per_turn, block_text]
	piles_label.text = (
		"draw %d  discard %d"
		% [battle.player_deck.draw_pile.size(), battle.player_deck.discard_pile.size()]
	)

	# The examiner's intent must always read as something, even when there is
	# nothing telegraphed — a blank label here would look like a bug, not the
	# deliberate "no untelegraphed damage" guarantee the rules layer makes.
	if battle.examiner_intent != null:
		intent_label.text = "Next: %s" % battle.examiner_intent.data.card_name
	else:
		intent_label.text = "Next: hesitating"

	hand_fan.set_hand(battle.player_deck.hand)
	hand_fan.set_playable(func(card): return battle.can_play(card))
