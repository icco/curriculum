extends SceneTree

## Projects a flat top-down texture onto the game's 2:1 isometric tile.
##
##   godot --headless --path . --script tools/make_tile.gd -- <texture> <name>
##
## Writes assets/source/tiles/<name>.png with alpha, for tools/import-assets.sh.
## Deriving the diamond beats asking for one: no generator reliably draws a shape
## exactly twice as wide as it is tall. See assets/prompts/recraft.md.

const OUT_DIR := "res://assets/source/tiles"
## Where the accepted texture is kept, so the projection can be redone later.
const TEXTURE_DIR := "res://assets/source/textures"
const KEEP_WIDTH := 512
## Output width; height is always half. Above 64x32 so the importer has detail left.
const WIDTH := 512
## A seamless texture has no edge of its own, so the rim is darkened here or the
## grid dissolves into one field of stone.
const RIM_DARKEN := 0.35
const RIM := 0.06  ## fraction of the half-diagonal it fades over

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: make_tile.gd -- <texture> <name>")
		quit(1)
		return true
	quit(0 if _build(args[0], args[1]) else 1)
	return true

func _build(source: String, name: String) -> bool:
	var texture := Image.load_from_file(source)
	if texture == null:
		push_error("could not read %s" % source)
		return false
	texture.convert(Image.FORMAT_RGBA8)

	# Regenerating gives different art, so without a kept copy the baked-in rim is
	# a one-way door. 512 is ample for a 64px destination.
	var keep := texture.duplicate()
	if keep.get_width() > KEEP_WIDTH:
		keep.resize(KEEP_WIDTH, KEEP_WIDTH, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURE_DIR))
	keep.save_png(ProjectSettings.globalize_path("%s/%s.png" % [TEXTURE_DIR, name]))

	var tile := project(texture, WIDTH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := tile.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("could not write %s: %d" % [path, err])
		return false
	print("wrote %s (%dx%d) from %dx%d texture"
		% [path, tile.get_width(), tile.get_height(), texture.get_width(), texture.get_height()])
	return true

## Projects a top-down texture onto a 2:1 diamond `width` across.
##
## Walks the destination and samples the source; the forward mapping would leave
## holes. The diamond's own axes are the texture's rotated 45 degrees, so the
## inside test doubles as the texture lookup.
static func project(texture: Image, width: int) -> Image:
	var height := width / 2
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var half_w := width / 2.0
	var half_h := height / 2.0
	var tw := texture.get_width()
	var th := texture.get_height()

	for y in height:
		for x in width:
			# Offset from the centre, in half-widths and half-heights.
			var dx := (x + 0.5 - half_w) / half_w
			var dy := (y + 0.5 - half_h) / half_h
			var edge: float = absf(dx) + absf(dy)
			if edge > 1.0:
				continue
			# Rotate into the texture's axes.
			var u := (dx + dy + 1.0) * 0.5
			var v := (dy - dx + 1.0) * 0.5
			var sx := clampi(int(u * tw), 0, tw - 1)
			var sy := clampi(int(v * th), 0, th - 1)
			var c := texture.get_pixel(sx, sy)
			var shade := _rim_shade(edge)
			out.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, 1.0))
	return out

## Multiplier that darkens the outer rim of the diamond, easing in over RIM.
static func _rim_shade(edge: float) -> float:
	if edge <= 1.0 - RIM:
		return 1.0
	var t: float = (edge - (1.0 - RIM)) / RIM
	return lerpf(1.0, 1.0 - RIM_DARKEN, clampf(t, 0.0, 1.0))
