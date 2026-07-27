class_name LoopScreen
extends CanvasLayer

## The between-loops screen: what the failed loop earned, and the skill tree
## where insight is spent. Doubles as the victory screen.

signal continue_pressed

var _scrim: ColorRect
var _root: Control
var _title: Label
var _summary: Label
var _insight: Label
var _node_list: VBoxContainer
var _continue: Button
var _state: GameState

func _ready() -> void:
	layer = 20
	_scrim = UIKit.scrim()
	_scrim.visible = false
	add_child(_scrim)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	var panel := UIKit.panel(ArtFactory.UI_PANEL, 0.98)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	_title = UIKit.label("The loop resets", 34, ArtFactory.UI_ACCENT)
	col.add_child(_title)
	_summary = UIKit.label("", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	_insight = UIKit.label("", 20, Color("ffd54f"))
	col.add_child(_insight)

	col.add_child(UIKit.label("What you remember", 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	col.add_child(scroll)
	_node_list = VBoxContainer.new()
	_node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_node_list)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_continue = UIKit.primary_button("Start the loop again")
	_continue.pressed.connect(_on_continue)
	row.add_child(_continue)

func is_open() -> bool:
	return _root.visible

func show_loop_failed(state: GameState, summary: Dictionary) -> void:
	_state = state
	_title.text = "The bell rings. It is September again."
	_summary.text = "You made it to floor %d and put down %d classmates before the loop caught you. Gear is gone. What you learned is not." % [
		int(summary.get("depth", 1)), int(summary.get("kills", 0))]
	_continue.text = "Start loop %d" % int(state.global["loops"])
	_refresh()
	_open()

func show_victory(state: GameState, summary: Dictionary) -> void:
	_state = state
	_title.text = "You walked out."
	_summary.text = "Twelve floors, %d classmates, and one very surprised Principal. The loop is broken — but the school is still there tomorrow, if you want another run at it." % int(summary.get("kills", 0))
	_continue.text = "Run it again"
	_refresh()
	_open()

func _open() -> void:
	_scrim.visible = true
	_root.visible = true

func _close() -> void:
	_scrim.visible = false
	_root.visible = false

func _on_continue() -> void:
	_close()
	continue_pressed.emit()

func _refresh() -> void:
	_insight.text = "Insight banked: %d   ·   deepest floor reached: %d" % [
		int(_state.global["skill_points"]), int(_state.global["deepest_floor"])]
	for child: Node in _node_list.get_children():
		child.queue_free()

	var offered := 0
	for node: Dictionary in GameState.skill_nodes():
		var id := str(node["id"])
		if _state.has_node_unlocked(id):
			var owned := UIKit.label("✓ %s — %s" % [str(node["name"]), str(node["description"])],
				16, ArtFactory.UI_GOOD)
			owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_node_list.add_child(owned)
			continue
		if not _state.node_available(id):
			continue
		offered += 1
		var affordable := _state.can_afford(id)
		var b := UIKit.button("%s — %d insight" % [str(node["name"]), int(node["cost"])],
			ArtFactory.UI_ACCENT if affordable else ArtFactory.UI_DIM, 420.0)
		b.disabled = not affordable
		b.tooltip_text = str(node["description"])
		b.pressed.connect(_on_buy.bind(id))
		_node_list.add_child(b)
		var desc := UIKit.label("    %s" % str(node["description"]), 14, ArtFactory.UI_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_node_list.add_child(desc)

	if offered == 0:
		_node_list.add_child(UIKit.label("Nothing new to remember yet — survive deeper to earn insight.",
			16, ArtFactory.UI_DIM))

func _on_buy(id: String) -> void:
	if _state.purchase_node(id):
		_state.save()
		_refresh()
