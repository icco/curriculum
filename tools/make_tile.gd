extends SceneTree

## Turns a flat top-down texture into an isometric floor tile.
##
##   godot --headless --path . --script tools/make_tile.gd -- <texture> <name>
##
## Reads a square, orthographic, evenly lit texture (see assets/prompts/recraft.md)
## and projects it onto the game's 2:1 diamond: rotate 45 degrees, halve the
## vertical scale, mask to the diamond. Writes assets/source/tiles/<name>.png with
## an alpha channel, ready for tools/import_assets.gd.
##
## Deriving the geometry is the whole point. No image generator reliably draws a
## diamond exactly twice as wide as it is tall — ask for one and you get a slab at
## whatever isometric angle it likes, which then has to be measured and corrected.
## A square texture has no geometry to get wrong, so the projection is exact every
## time and the model only has to paint.

const OUT_DIR := "res://assets/source/tiles"
## Where the accepted texture is kept, at KEEP_WIDTH square, so the projection can
## be redone later without regenerating the art.
const TEXTURE_DIR := "res://assets/source/textures"
const KEEP_WIDTH := 512
## Output width; height is always half of it. Larger than the final 64x32 so the
## importer's downscale still has detail to work with.
const WIDTH := 512
## The tile's outer rim is darkened by this much, fading over RIM pixels, so
## adjacent tiles read as separate cells. A seamless texture has no edge of its
## own, and without this the isometric grid dissolves into one field of stone.
const RIM_DARKEN := 0.35
const RIM := 0.06  ## as a fraction of the half-diagonal

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

	# Keep a copy of the accepted texture next to the rejects, which are ignored.
	# Everything this tool bakes in — the rim darkening above all — is impossible
	# to retune from the projected tile alone, and regenerating gives different
	# art, so without this the rim is a one-way door. 512 is ample for a 64px
	# destination and a fraction of the original's weight.
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
## Walks the *destination* and samples the source, so every output pixel is
## filled — the forward mapping would leave holes. Diamond coordinates run along
## the tile's own axes: u and v are the distances to the two diagonals, each in
## [-1, 1], and |u| + |v| <= 1 is inside. That pair is exactly the texture's
## coordinate system rotated 45 degrees, so it doubles as the texture lookup.
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
			# Normalised offset from the tile centre, in half-widths/half-heights.
			var dx := (x + 0.5 - half_w) / half_w
			var dy := (y + 0.5 - half_h) / half_h
			var edge: float = absf(dx) + absf(dy)
			if edge > 1.0:
				continue
			# Rotate into the texture's axes: the diamond's two diagonals.
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
