extends SceneTree

## Builds an isometric wall or door block from flat textures.
##
##   godot --headless --path . --script tools/make_block.gd -- <material> <name> [face]
##
## Writes assets/source/tiles/<name>.png with alpha, for tools/import-assets.sh.
##
## Standard isometric practice: take a flat square and scale, shear and rotate it
## once per visible face, then shade the three faces differently. Same reason as
## tools/make_tile.gd — the footprint has to line up with the grid exactly, which
## no generator manages, so the geometry is constructed and the model only paints
## flat material. `face` is an optional second texture for the front-left face,
## which is how a door gets into a wall block.

const OUT_DIR := "res://assets/source/tiles"
## Accepted textures are kept here, as tools/make_tile.gd does: the shading below
## is baked into the output, and regenerating gives different art.
const TEXTURE_DIR := "res://assets/source/textures"
const KEEP_WIDTH := 512
## Output is WIDTH wide; the top face is WIDTH/2 tall and the block rises RISE
## below it, matching the 64x64 block cell whose footprint is its bottom half.
const WIDTH := 512
const RISE := 256
## One light source, so the faces have to differ or the cube reads flat.
const SHADE_TOP := 1.0
const SHADE_LEFT := 0.72
const SHADE_RIGHT := 0.55

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: make_block.gd -- <material> <name> [face]")
		quit(1)
		return true
	quit(0 if _build(args[0], args[1], args[2] if args.size() > 2 else "") else 1)
	return true

func _build(material_path: String, name: String, face_path: String) -> bool:
	var material := _load(material_path)
	if material == null:
		return false
	var face: Image = null
	if face_path != "":
		face = _load(face_path)
		if face == null:
			return false

	_keep(material, material_path)
	if face != null:
		_keep(face, face_path)

	var block := construct(material, face, WIDTH, RISE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := block.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("could not write %s: %d" % [path, err])
		return false
	print("wrote %s (%dx%d)" % [path, block.get_width(), block.get_height()])
	return true

## Saves the accepted texture under its own name, minus any -N variant suffix.
func _keep(texture: Image, path: String) -> void:
	var stem := path.get_file().get_basename()
	var dash := stem.rfind("-")
	if dash > 0 and stem.substr(dash + 1).is_valid_int():
		stem = stem.substr(0, dash)
	var copy := texture.duplicate()
	if copy.get_width() > KEEP_WIDTH:
		copy.resize(KEEP_WIDTH, KEEP_WIDTH, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURE_DIR))
	copy.save_png(ProjectSettings.globalize_path("%s/%s.png" % [TEXTURE_DIR, stem]))

func _load(path: String) -> Image:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("could not read %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

## Assembles the three faces. `face`, when given, replaces the front-left one.
##
## Walks the destination like tools/make_tile.gd does, testing the top diamond
## first and then the two side parallelograms. Each side is parametrised along its
## own top edge, so the texture shears with the face instead of being sampled from
## screen space.
static func construct(material: Image, face: Image, width: int, rise: int) -> Image:
	var top_h := width / 2
	var out := Image.create(width, top_h + rise, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var half_w := width / 2.0
	var quarter := top_h / 2.0

	for y in out.get_height():
		for x in out.get_width():
			# Top face: the same 2:1 diamond a floor tile uses.
			var dx := (x + 0.5 - half_w) / half_w
			var dy := (y + 0.5 - quarter) / quarter
			if absf(dx) + absf(dy) <= 1.0:
				var u := (dx + dy + 1.0) * 0.5
				var v := (dy - dx + 1.0) * 0.5
				out.set_pixel(x, y, _sample(material, u, v, SHADE_TOP))
				continue

			var on_left := x < half_w
			# Distance along the face's top edge, 0 at the outer vertex.
			var along: float = (x + 0.5) / half_w if on_left else (x + 0.5 - half_w) / half_w
			if along < 0.0 or along > 1.0:
				continue
			var edge_y: float = quarter + along * quarter if on_left else top_h - along * quarter
			var down := (y + 0.5 - edge_y) / float(rise)
			if down < 0.0 or down > 1.0:
				continue
			var source := material
			var shade := SHADE_RIGHT
			if on_left:
				shade = SHADE_LEFT
				if face != null:
					source = face
			out.set_pixel(x, y, _sample(source, along, down, shade))
	return out

static func _sample(texture: Image, u: float, v: float, shade: float) -> Color:
	var sx := clampi(int(u * texture.get_width()), 0, texture.get_width() - 1)
	var sy := clampi(int(v * texture.get_height()), 0, texture.get_height() - 1)
	var c := texture.get_pixel(sx, sy)
	return Color(c.r * shade, c.g * shade, c.b * shade, 1.0)
