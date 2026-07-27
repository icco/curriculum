class_name UIKit
extends RefCounted

## Factories for the Controls the UI builds at runtime (spell lists, skill
## nodes). Styling lives in resources/ui_theme.tres — these only pick a theme
## type variation, never override styleboxes.

const THEME_PATH := "res://resources/ui_theme.tres"
const TOUCH_MIN := 52.0

static var _theme: Theme

static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
	return _theme

## Applies the theme once, at the root of a UI tree; children inherit it.
static func apply_theme(control: Control) -> void:
	control.theme = theme()

## Panels never eat touches; only buttons do.
static func panel(variation: StringName = &"") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != &"":
		p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, variation: StringName = &"", min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(maxf(min_width, TOUCH_MIN * 1.6), TOUCH_MIN)
	return b

## Spell buttons carry their spell's colour, which a theme variation cannot
## express. The only place a per-instance style override is used.
static func tinted_button(text: String, accent: Color, min_width: float = 0.0) -> Button:
	var b := button(text, &"ListButton", min_width)
	for state: String in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = (theme().get_stylebox(state, "ListButton") as StyleBoxFlat).duplicate()
		box.border_color = accent
		b.add_theme_stylebox_override(state, box)
	return b

static func bar(height: float = 16.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(160, height)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Recolours a ProgressBar fill (health changes colour as it drops).
static func set_bar_fill(bar_node: ProgressBar, color: Color) -> void:
	var box: StyleBoxFlat = (theme().get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate()
	box.bg_color = color
	bar_node.add_theme_stylebox_override("fill", box)

static func vbox(separation: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", separation)
	return v

static func hbox(separation: int = 8, centred: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", separation)
	if centred:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h

## Full-screen dim behind a modal screen.
static func scrim(alpha: float = 0.82) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.025, 0.04, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r
