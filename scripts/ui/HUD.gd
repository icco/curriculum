class_name HUD
extends CanvasLayer

## In-game interface. Emits intents; Main decides what they mean.
##
## Every container is MOUSE_FILTER_IGNORE so taps fall through to the board;
## only buttons capture input.

signal action_pressed(action: String)
signal spell_chosen(spell_id: StringName)
signal item_chosen(index: int)
signal confirm_pressed
signal cancel_pressed

const LOG_LINES := 6

var _status_line: Label
var _meta_line: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _slot_line: Label
var _turn_banner: Label
var _log: RichTextLabel
var _confirm_row: Control
var _confirm_button: Button
var _hint: Label
var _spell_panel: PanelContainer
var _spell_list: VBoxContainer
var _item_panel: PanelContainer
var _item_list: VBoxContainer
var _buttons: Dictionary = {}
var _log_history: Array = []

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.apply_theme(root)
	add_child(root)

	_build_status(root)
	_build_turn_banner(root)
	_build_log(root)
	_build_action_bar(root)
	_build_confirm(root)
	_build_spell_panel(root)
	_build_item_panel(root)

# ------------------------------------------------------------------ layout

func _build_status(root: Control) -> void:
	var holder := UIKit.panel()
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.position = Vector2(16, 16)
	holder.custom_minimum_size = Vector2(300, 0)
	root.add_child(holder)

	var col := UIKit.vbox(4)
	holder.add_child(col)

	_status_line = UIKit.label("September — Floor 1", &"StatusLabel")
	col.add_child(_status_line)
	_meta_line = UIKit.label("Lv 1 · Loop 1 · 0 insight", &"DimLabel")
	col.add_child(_meta_line)

	var hp_row := UIKit.hbox()
	col.add_child(hp_row)
	_hp_bar = UIKit.bar(18)
	hp_row.add_child(_hp_bar)
	_hp_text = UIKit.label("20/20")
	hp_row.add_child(_hp_text)

	_slot_line = UIKit.label("Slots  L1 2/2", &"DimLabel")
	col.add_child(_slot_line)

func _build_turn_banner(root: Control) -> void:
	_turn_banner = UIKit.label("", &"BannerLabel")
	_turn_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_banner.anchor_left = 0.5
	_turn_banner.anchor_right = 0.5
	_turn_banner.position = Vector2(-140, 22)
	_turn_banner.custom_minimum_size = Vector2(280, 0)
	_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_turn_banner)

func _build_log(root: Control) -> void:
	var holder := UIKit.panel(&"LogPanel")
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = 16
	holder.offset_top = -232
	holder.offset_right = 452
	holder.offset_bottom = -104
	root.add_child(holder)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 15)
	holder.add_child(_log)

func _build_action_bar(root: Control) -> void:
	var holder := UIKit.panel()
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -430
	holder.offset_right = 430
	holder.offset_top = -84
	holder.offset_bottom = -16
	root.add_child(holder)

	var row := UIKit.hbox(8, true)
	holder.add_child(row)

	for spec: Array in [
		["spells", "Spells", &""],
		["items", "Items", &""],
		["dash", "Dash", &""],
		["loot", "Reliquary", &""],
		["door", "Door", &""],
		["descend", "Stairs", &""],
		["end_turn", "End Turn", &"DangerButton"],
	]:
		var b := UIKit.button(str(spec[1]), spec[2])
		b.pressed.connect(_on_action.bind(str(spec[0])))
		row.add_child(b)
		_buttons[str(spec[0])] = b

func _build_confirm(root: Control) -> void:
	_confirm_row = UIKit.hbox(12, true)
	_confirm_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_confirm_row.anchor_left = 0.5
	_confirm_row.anchor_right = 0.5
	_confirm_row.anchor_top = 1.0
	_confirm_row.anchor_bottom = 1.0
	_confirm_row.offset_left = -240
	_confirm_row.offset_right = 240
	_confirm_row.offset_top = -164
	_confirm_row.offset_bottom = -96
	_confirm_row.visible = false
	root.add_child(_confirm_row)

	_confirm_button = UIKit.button("Confirm", &"PrimaryButton", 200.0)
	_confirm_button.pressed.connect(func() -> void: confirm_pressed.emit())
	_confirm_row.add_child(_confirm_button)

	var cancel := UIKit.button("Cancel", &"DimButton")
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	_confirm_row.add_child(cancel)

	_hint = UIKit.label("", &"HintLabel")
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -340
	_hint.offset_right = 340
	_hint.offset_top = -198
	_hint.offset_bottom = -172
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)

func _build_spell_panel(root: Control) -> void:
	_spell_panel = UIKit.panel()
	_spell_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_spell_panel.anchor_left = 1.0
	_spell_panel.anchor_right = 1.0
	_spell_panel.anchor_top = 0.5
	_spell_panel.anchor_bottom = 0.5
	_spell_panel.offset_left = -320
	_spell_panel.offset_right = -16
	_spell_panel.offset_top = -200
	_spell_panel.offset_bottom = 170
	_spell_panel.visible = false
	root.add_child(_spell_panel)

	var col := UIKit.vbox()
	_spell_panel.add_child(col)
	col.add_child(UIKit.label("Spells", &"HeadingLabel"))
	_spell_list = UIKit.vbox()
	col.add_child(_spell_list)

func _build_item_panel(root: Control) -> void:
	_item_panel = UIKit.panel()
	_item_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_item_panel.anchor_left = 1.0
	_item_panel.anchor_right = 1.0
	_item_panel.anchor_top = 0.5
	_item_panel.anchor_bottom = 0.5
	_item_panel.offset_left = -320
	_item_panel.offset_right = -16
	_item_panel.offset_top = -160
	_item_panel.offset_bottom = 120
	_item_panel.visible = false
	root.add_child(_item_panel)

	var col := UIKit.vbox()
	_item_panel.add_child(col)
	col.add_child(UIKit.label("Bag", &"HeadingLabel"))
	_item_list = UIKit.vbox()
	col.add_child(_item_list)

func _on_action(name: String) -> void:
	action_pressed.emit(name)

# ------------------------------------------------------------------ updates

func set_status(month: String, depth: int, level: int, loop: int, insight: int) -> void:
	_status_line.text = "%s — Floor %d" % [month, depth]
	_meta_line.text = "Lv %d  ·  Loop %d  ·  %d insight" % [level, loop, insight]

func set_vitals(player: Entity, moves: int) -> void:
	_hp_bar.max_value = maxf(1.0, float(player.max_hp))
	_hp_bar.value = float(player.current_hp)
	var frac: float = float(player.current_hp) / maxf(1.0, float(player.max_hp))
	var fill: Color = ArtFactory.UI_GOOD
	if frac < 0.6:
		fill = Color("ffb300")
	if frac < 0.3:
		fill = ArtFactory.UI_DANGER
	UIKit.set_bar_fill(_hp_bar, fill)
	_hp_text.text = "%d/%d" % [player.current_hp, player.max_hp]

	var parts: Array = []
	for key: String in ["level_1", "level_2", "level_3"]:
		var total := int(player.spell_slots.get(key, 0))
		if total > 0:
			parts.append("L%s %d/%d" % [key.substr(6), player.slots_left(int(key.substr(6))), total])
	parts.append("move %d" % moves)
	if not player.conditions.is_empty():
		parts.append(", ".join(player.conditions.keys()))
	_slot_line.text = "  ·  ".join(parts)

func set_banner(text: String, color: Color = ArtFactory.UI_ACCENT) -> void:
	_turn_banner.text = text
	_turn_banner.add_theme_color_override("font_color", color)

func set_hint(text: String) -> void:
	_hint.text = text

func show_confirm(label: String = "Confirm") -> void:
	_confirm_button.text = label
	_confirm_row.visible = true

func hide_confirm() -> void:
	_confirm_row.visible = false

func set_action_enabled(action: String, enabled: bool) -> void:
	if _buttons.has(action):
		(_buttons[action] as Button).disabled = not enabled

func log_line(text: String, color: Color = ArtFactory.UI_TEXT) -> void:
	if text.strip_edges() == "":
		return
	_log_history.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	while _log_history.size() > LOG_LINES:
		_log_history.pop_front()
	_log.text = "\n".join(_log_history)

func clear_log() -> void:
	_log_history.clear()
	_log.text = ""

# ------------------------------------------------------------------- panels

func toggle_spells(spells: Array, player: Entity, castable: Callable) -> void:
	_item_panel.visible = false
	_spell_panel.visible = not _spell_panel.visible
	if not _spell_panel.visible:
		return
	for child: Node in _spell_list.get_children():
		child.queue_free()
	if spells.is_empty():
		_spell_list.add_child(UIKit.label("Nothing learned yet.", &"DimLabel"))
		return
	for spell: SpellData in spells:
		var cost: String = "cantrip" if spell.is_cantrip() \
			else "L%d (%d left)" % [spell.level, player.slots_left(spell.level)]
		var b := UIKit.tinted_button("%s — %s" % [spell.display_name, cost], spell.color, 280.0)
		b.disabled = not bool(castable.call(spell))
		b.tooltip_text = spell.description
		b.pressed.connect(func() -> void: spell_chosen.emit(spell.id))
		_spell_list.add_child(b)

func toggle_items(items: Array) -> void:
	_spell_panel.visible = false
	_item_panel.visible = not _item_panel.visible
	if not _item_panel.visible:
		return
	for child: Node in _item_list.get_children():
		child.queue_free()
	if items.is_empty():
		_item_list.add_child(UIKit.label("Your bag is empty.", &"DimLabel"))
		return
	for i in items.size():
		var item: LootItemData = items[i]
		var b := UIKit.button(item.display_name, &"ListButton", 280.0)
		b.pressed.connect(func() -> void: item_chosen.emit(i))
		_item_list.add_child(b)

func close_panels() -> void:
	_spell_panel.visible = false
	_item_panel.visible = false

func panels_open() -> bool:
	return _spell_panel.visible or _item_panel.visible
