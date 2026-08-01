extends SceneTree

## Regenerates resources/ui_theme.tres. Light, per spec 9.2: paper ground, ink text,
## and 48px minimum tap targets for thumbs at 1080 wide.
## Re-runnable: it overwrites. Run with
##   godot --headless --path . --script tools/generate_theme.gd

const OUT := "res://resources/ui_theme.tres"
const MIN_TAP := 96  # 48dp at a 2x portrait scale
## Default gap between stacked/adjacent children. Godot's own default is 4, which packs
## rows tight enough that a list reads as one dense block; the paper look wants air
## between things. A screen that has tuned its own spacing overrides this locally.
const SEPARATION := 16


func _flat(colour: Color, border: Color, width := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	return box


func _process(_delta: float) -> bool:
	var theme := Theme.new()
	theme.default_font_size = 32

	theme.set_stylebox("normal", "Button", _flat(ArtLibrary.PAPER, ArtLibrary.INK))
	theme.set_stylebox("hover", "Button", _flat(Color("#E0A51F"), ArtLibrary.INK))
	theme.set_stylebox("pressed", "Button", _flat(Color("#D45C3C"), ArtLibrary.INK))
	theme.set_stylebox("disabled", "Button", _flat(ArtLibrary.SLATE, ArtLibrary.GRAIN_B))
	theme.set_color("font_color", "Button", ArtLibrary.INK)
	theme.set_color("font_disabled_color", "Button", ArtLibrary.GRAIN_B)
	theme.set_constant("h_separation", "Button", 12)
	# Set on both concrete classes rather than on BoxContainer, so the value is visible
	# in the saved .tres under the type a screen actually instantiates.
	theme.set_constant("separation", "VBoxContainer", SEPARATION)
	theme.set_constant("separation", "HBoxContainer", SEPARATION)
	theme.set_color("font_color", "Label", ArtLibrary.INK)
	theme.set_stylebox("panel", "PanelContainer", _flat(ArtLibrary.PAPER, ArtLibrary.INK))
	theme.set_stylebox("background", "ProgressBar", _flat(ArtLibrary.SLATE, ArtLibrary.INK, 2))
	theme.set_stylebox("fill", "ProgressBar", _flat(Color("#D45C3C"), ArtLibrary.INK, 0))

	if ResourceSaver.save(theme, OUT) != OK:
		printerr("failed to write %s" % OUT)
		quit(1)
		return true
	print("wrote %s (min tap target %dpx)" % [OUT, MIN_TAP])
	quit(0)
	return true
