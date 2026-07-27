extends SceneTree

## Generates resources/ui_theme.tres. Editing the numbers here and re-running
## beats hand-editing a Theme resource.
##   godot --headless --path . --script tools/generate_theme.gd

const OUT := "res://resources/ui_theme.tres"
const RADIUS := 10
const TOUCH_MIN := 52

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var theme := Theme.new()
	theme.default_font_size = 18

	_panel(theme, "PanelContainer", ArtFactory.UI_PANEL, 0.92)
	_panel_variation(theme, "LogPanel", ArtFactory.UI_BG, 0.72)
	_panel_variation(theme, "ScreenPanel", ArtFactory.UI_PANEL, 0.98)

	_label(theme, "Label", 18, ArtFactory.UI_TEXT)
	_label_variation(theme, "TitleLabel", 34, ArtFactory.UI_ACCENT)
	_label_variation(theme, "HeadingLabel", 22, ArtFactory.UI_TEXT)
	_label_variation(theme, "StatusLabel", 20, ArtFactory.UI_TEXT)
	_label_variation(theme, "DimLabel", 15, ArtFactory.UI_DIM)
	_label_variation(theme, "BannerLabel", 26, ArtFactory.UI_ACCENT)
	_label_variation(theme, "HintLabel", 17, ArtFactory.UI_DIM)
	_label_variation(theme, "GoodLabel", 16, ArtFactory.UI_GOOD)
	_label_variation(theme, "InsightLabel", 20, Color("ffd54f"))

	_button(theme, "Button", ArtFactory.UI_ACCENT, 18, Vector2(TOUCH_MIN * 1.6, TOUCH_MIN))
	_button_variation(theme, "PrimaryButton", ArtFactory.UI_GOOD, 21, Vector2(200, TOUCH_MIN + 8), true)
	_button_variation(theme, "DangerButton", ArtFactory.UI_DANGER, 18, Vector2(TOUCH_MIN * 1.6, TOUCH_MIN))
	_button_variation(theme, "DimButton", ArtFactory.UI_DIM, 18, Vector2(TOUCH_MIN * 1.6, TOUCH_MIN))
	_button_variation(theme, "ListButton", ArtFactory.UI_ACCENT, 18, Vector2(280, TOUCH_MIN))

	_progress(theme, "ProgressBar", ArtFactory.UI_GOOD)

	var err := ResourceSaver.save(theme, OUT)
	print("theme -> %s (err %d, %d variations)" % [OUT, err, theme.get_type_variation_list("Button").size()
		+ theme.get_type_variation_list("Label").size() + theme.get_type_variation_list("PanelContainer").size()])
	quit(0 if err == OK else 1)
	return true

static func _box(color: Color, radius: int = RADIUS, border: int = 0,
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

func _panel(theme: Theme, type: String, color: Color, alpha: float) -> void:
	var c := color
	c.a = alpha
	theme.set_stylebox("panel", type, _box(c))

func _panel_variation(theme: Theme, name: String, color: Color, alpha: float) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "PanelContainer")
	_panel(theme, name, color, alpha)

func _label(theme: Theme, type: String, size: int, color: Color) -> void:
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, color)
	theme.set_color("font_outline_color", type, Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", type, 4)

func _label_variation(theme: Theme, name: String, size: int, color: Color) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Label")
	_label(theme, name, size, color)

func _button(theme: Theme, type: String, accent: Color, size: int, min_size: Vector2,
		filled: bool = false) -> void:
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, ArtFactory.UI_TEXT)
	theme.set_color("font_hover_color", type, Color.WHITE)
	theme.set_color("font_disabled_color", type, ArtFactory.UI_DIM)
	var normal := accent.darkened(0.45) if filled else Color(0.13, 0.16, 0.23, 0.96)
	var hover := accent.darkened(0.25) if filled else Color(0.19, 0.24, 0.33, 0.98)
	theme.set_stylebox("normal", type, _box(normal, RADIUS, 2, accent))
	theme.set_stylebox("hover", type, _box(hover, RADIUS, 2, accent))
	theme.set_stylebox("pressed", type, _box(accent.darkened(0.6), RADIUS, 2, accent))
	theme.set_stylebox("disabled", type,
		_box(Color(0.11, 0.12, 0.16, 0.8), RADIUS, 2, Color(1, 1, 1, 0.08)))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_constant("minimum_size_x", type, int(min_size.x))
	theme.set_constant("minimum_size_y", type, int(min_size.y))

func _button_variation(theme: Theme, name: String, accent: Color, size: int,
		min_size: Vector2, filled: bool = false) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Button")
	_button(theme, name, accent, size, min_size, filled)

func _progress(theme: Theme, type: String, fill: Color) -> void:
	theme.set_stylebox("background", type, _box(Color(0, 0, 0, 0.55), 6))
	theme.set_stylebox("fill", type, _box(fill, 6))
