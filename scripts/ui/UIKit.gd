class_name UIKit
extends RefCounted

## Builders for the game's Controls. Touch targets are sized for thumbs
## (>= 48dp) and colours come from ArtFactory so the palette stays in one place.

const TOUCH_MIN := 52.0
const RADIUS := 10

static func stylebox(color: Color, radius: int = RADIUS, border: int = 0,
		border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	if border > 0:
		box.border_width_left = border
		box.border_width_right = border
		box.border_width_top = border
		box.border_width_bottom = border
		box.border_color = border_color
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

## Panels never eat touches; only buttons do.
static func panel(color: Color = ArtFactory.UI_PANEL, alpha: float = 0.92) -> PanelContainer:
	var p := PanelContainer.new()
	var c := color
	c.a = alpha
	p.add_theme_stylebox_override("panel", stylebox(c))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func label(text: String, size: int = 18, color: Color = ArtFactory.UI_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, accent: Color = ArtFactory.UI_ACCENT, wide: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(wide, TOUCH_MIN * 1.6), TOUCH_MIN)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", ArtFactory.UI_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", ArtFactory.UI_DIM)
	b.add_theme_stylebox_override("normal", stylebox(Color(0.13, 0.16, 0.23, 0.96), RADIUS, 2, accent))
	b.add_theme_stylebox_override("hover", stylebox(Color(0.19, 0.24, 0.33, 0.98), RADIUS, 2, accent))
	b.add_theme_stylebox_override("pressed", stylebox(accent.darkened(0.35), RADIUS, 2, accent))
	b.add_theme_stylebox_override("disabled", stylebox(Color(0.11, 0.12, 0.16, 0.8), RADIUS, 2, Color(1, 1, 1, 0.08)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

## A big, unmissable call to action (Confirm, Start Loop, ...).
static func primary_button(text: String, accent: Color = ArtFactory.UI_GOOD) -> Button:
	var b := button(text, accent, 200.0)
	b.custom_minimum_size = Vector2(200, TOUCH_MIN + 8)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_stylebox_override("normal", stylebox(accent.darkened(0.45), RADIUS, 2, accent))
	b.add_theme_stylebox_override("hover", stylebox(accent.darkened(0.25), RADIUS, 2, accent))
	b.add_theme_stylebox_override("pressed", stylebox(accent.darkened(0.6), RADIUS, 2, accent))
	return b

static func bar(fill: Color, height: float = 16.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(160, height)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("background", stylebox(Color(0, 0, 0, 0.55), 6))
	p.add_theme_stylebox_override("fill", stylebox(fill, 6))
	return p

static func spacer(expand_h: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## Full-screen dim behind a modal screen.
static func scrim(alpha: float = 0.82) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.025, 0.04, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r
