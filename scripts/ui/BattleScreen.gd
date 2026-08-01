class_name BattleScreen
extends Control

## Examiner at the top, player and hand at the bottom. Replays the event arrays
## Battle returns; never computes a rule itself.
##
## There is deliberately no telegraph of the examiner's next move: the fight is a
## genuine unknown. That makes the log and the player's own status readout the
## player's ONLY way to understand what is happening, so both have to be unambiguous
## about who did what to whom, not just terse event text.

signal battle_finished(battle)

var battle: Battle = null

var hand_fan: HandFan = null
var end_turn_button: Button = null
var log_label: Label = null
var examiner_bar: ProgressBar = null
var player_bar: ProgressBar = null
var examiner_hp_label: Label = null
var player_hp_label: Label = null
var examiner_status_label: Label = null
var player_status_label: Label = null
var block_label: Label = null
var mana_label: Label = null
var piles_label: Label = null
var examiner_figure: TextureRect = null

const FIGURE_SIZE := Vector2(380, 480)
## With no intent telegraph, the log carries real informational weight, so it holds
## more history than a decorative strip would — but it is still capped to a fixed
## panel height so it reads as a steady console rather than sprawling.
const LOG_LINES := 9

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
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# --- Examiner: clearly at the top, its own hit points and statuses visible. A
	# Burn or Chill stack the player applied is now part of reading the fight, since
	# nothing telegraphs what the examiner will do about it. The section (and its
	# portrait specifically) absorbs whatever vertical space the fixed-size sections
	# below do not need, so freed space grows a clearer, bigger examiner rather than
	# leaving an unexplained gap.
	var examiner_section := UIKit.transparent(VBoxContainer.new())
	examiner_section.add_theme_constant_override("separation", 8)
	examiner_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(examiner_section)

	examiner_figure = TextureRect.new()
	examiner_figure.custom_minimum_size = FIGURE_SIZE
	examiner_figure.size_flags_vertical = Control.SIZE_EXPAND_FILL
	examiner_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	examiner_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	examiner_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	examiner_section.add_child(examiner_figure)

	examiner_section.add_child(UIKit.label(battle.examiner.display_name, 40))

	var examiner_hp := _make_hp_row()
	examiner_bar = examiner_hp["bar"]
	examiner_hp_label = examiner_hp["label"]
	examiner_section.add_child(examiner_hp["row"])

	examiner_status_label = UIKit.label("", 22)
	examiner_section.add_child(examiner_status_label)

	# --- Log: what already happened, and to whom. Fixed height so it reads as a
	# steady console rather than sprawling to fill the screen. ---
	var log_panel := PanelContainer.new()
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.custom_minimum_size = Vector2(0, 300)
	root.add_child(log_panel)

	log_label = UIKit.label("", 24)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.add_child(log_label)

	# --- Player: hit points, block and mana have to be obvious at a glance -- with
	# no telegraph, this is the other half of the player's only information. ---
	var status_section := UIKit.transparent(VBoxContainer.new())
	status_section.add_theme_constant_override("separation", 10)
	root.add_child(status_section)

	var player_hp := _make_hp_row()
	player_bar = player_hp["bar"]
	player_hp_label = player_hp["label"]
	status_section.add_child(player_hp["row"])

	var stats_row := UIKit.transparent(HBoxContainer.new())
	status_section.add_child(stats_row)
	block_label = UIKit.label("", 28)
	stats_row.add_child(block_label)
	stats_row.add_child(UIKit.spacer())
	mana_label = UIKit.label("", 28)
	stats_row.add_child(mana_label)
	stats_row.add_child(UIKit.spacer())
	piles_label = UIKit.label("", 24)
	stats_row.add_child(piles_label)

	player_status_label = UIKit.label("", 22)
	status_section.add_child(player_status_label)

	# --- Hand: anchored at the very bottom, above the End Turn button. ---
	hand_fan = HandFan.new()
	# Height only: a hard 1080 minimum width would refuse to shrink into the screen's
	# edge gutter, so the fan alone would hang past the margin every other section
	# respects. It fills whatever width the gutter leaves and re-fans itself on resize.
	hand_fan.custom_minimum_size = Vector2(0, 330)
	hand_fan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_fan.card_play_requested.connect(_on_card_played)
	root.add_child(hand_fan)

	end_turn_button = UIKit.button("End Turn")
	end_turn_button.pressed.connect(_on_end_turn)
	root.add_child(end_turn_button)


## A labelled bar with its own numeric readout to one side, since a bare percentage
## bar does not say how many hit points are actually left.
func _make_hp_row() -> Dictionary:
	var row := UIKit.transparent(HBoxContainer.new())
	row.add_theme_constant_override("separation", 12)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var label := UIKit.label("", 26)
	label.custom_minimum_size = Vector2(170, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)

	return {"row": row, "bar": bar, "label": label}


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


## Appends each event's text, prefixed with who it happened to when the event says
## so. Never mutates the battle: core has already resolved it, and this only renders
## what already happened.
func replay(events: Array) -> void:
	for event in events:
		var text: String = str(event.get("text", ""))
		if text == "":
			continue
		var kind: String = str(event.get("type", ""))
		# Fallback for any damage event whose text omits its own amount. Battle now
		# phrases them all with the number in place ("6 damage", "4 from Burn"), so
		# this should not fire -- it is here so a future event that forgets cannot
		# silently render a hit with no figure attached. Guarded on `contains` so a
		# text that already has the number is not given a second one.
		if kind == "damage" and event.has("amount") and not text.contains(str(event["amount"])):
			text = "%s %d" % [text, int(event["amount"])]
		if kind == "damage" or kind == "status":
			var who := _actor_label(str(event.get("target", "")))
			if who != "" and not text.begins_with(who):
				# A bare "+3" from a status-inflicting card does not say WHICH status;
				# the kind is already on the event (from the effect that made it), so
				# name it rather than leaving the player to guess.
				if event.has("status"):
					var status_name := UIKit.status_name(event["status"])
					if not text.contains(status_name):
						text = "%s %s" % [text, status_name]
				text = "%s: %s" % [who, text]
		_log_lines.append(text)
	while _log_lines.size() > LOG_LINES:
		_log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(_log_lines)


func _actor_label(target: String) -> String:
	if target == "player":
		return "You"
	if target == "examiner" and battle != null:
		return battle.examiner.display_name
	return ""


func _status_summary(statuses: Statuses) -> String:
	var parts: Array[String] = []
	for kind in [Statuses.Kind.BURN, Statuses.Kind.CHILL, Statuses.Kind.BLOT, Statuses.Kind.DECAY]:
		var n := statuses.amount(kind)
		if n > 0:
			parts.append("%s %d" % [UIKit.status_name(kind), n])
	return ", ".join(parts)


func refresh() -> void:
	if battle == null:
		return
	examiner_bar.max_value = maxi(1, battle.examiner.max_hp)
	examiner_bar.value = battle.examiner.hp
	examiner_hp_label.text = "%d/%d hp" % [battle.examiner.hp, battle.examiner.max_hp]
	examiner_status_label.text = _status_summary(battle.examiner.statuses)

	player_bar.max_value = maxi(1, battle.player.max_hp)
	player_bar.value = battle.player.hp
	player_hp_label.text = "%d/%d hp" % [battle.player.hp, battle.player.max_hp]
	player_status_label.text = _status_summary(battle.player.statuses)

	examiner_figure.texture = ArtLibrary.texture(battle.examiner_art_id(), Vector2i(FIGURE_SIZE))

	block_label.text = "Block %d" % battle.player.block
	mana_label.text = "%d/%d mana" % [battle.player.mana, battle.player.mana_per_turn]
	piles_label.text = (
		"draw %d  discard %d"
		% [battle.player_deck.draw_pile.size(), battle.player_deck.discard_pile.size()]
	)

	hand_fan.set_hand(battle.player_deck.hand)
	hand_fan.set_playable(func(card): return battle.can_play(card))
