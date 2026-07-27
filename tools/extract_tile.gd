extends SceneTree

## Cuts the top face out of a Midjourney floor tile and lays it on a clean key.
##
##   godot --headless --path . --script tools/extract_tile.gd -- <image> <name>
##
## Midjourney will not draw a bare 2:1 diamond. Ask for a floor tile and it
## returns a slab: a diamond top face extruded into side walls, usually with a
## shadow thrown onto the backdrop. Both are fatal downstream — the importer
## squashes whatever it is given into 64x32, so the side walls compress the top
## face out of projection, and the shadow inflates the trim box.
##
## Rather than fight the prompt, this takes the good-looking render and does the
## geometry itself: it finds the slab, discards the extrusion, masks to an exact
## 2:1 diamond and writes the result to assets/source/tiles/<name>.png on flat
## magenta, ready for the normal importer.

const ImportAssets := preload("res://tools/import_assets.gd")

const OUT_DIR := "res://assets/source/tiles"
## What the extracted tile is laid on. Exact, because we draw it ourselves.
const KEY := Color(1.0, 0.0, 1.0)
## Backdrop pixels are within this of the sampled colour...
const FLAT_TOLERANCE := 0.06
## ...or share its hue at a lower brightness, which is what a cast shadow is.
## Measured on a real render: shadow on a rose backdrop holds a hue dot product
## of 0.982-0.993, while the tile's own dark stone sits at 0.89 — a wide gap.
const SHADOW_CHROMA := 0.97
const SHADOW_DARKEST := 0.35

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: extract_tile.gd -- <image> <name>")
		quit(1)
		return true
	quit(0 if _extract(args[0], args[1]) else 1)
	return true

func _extract(source: String, name: String) -> bool:
	var image := Image.load_from_file(source)
	if image == null:
		push_error("could not read %s" % source)
		return false
	image.convert(Image.FORMAT_RGBA8)

	var key := ImportAssets.sample_background(image)
	if key.a < 1.0:
		push_error("%s has no flat backdrop to work from" % source)
		return false
	var solid := flood_backdrop(image, key)
	print("backdrop #%s, %d pixels" % [key.to_html(false), image.get_width() * image.get_height() - _count(solid)])

	var face := top_face(solid, image.get_width(), image.get_height())
	if face == Rect2i():
		push_error("could not find a slab in %s" % source)
		return false
	print("top face %dx%d at %s (%.2f:1)" % [face.size.x, face.size.y, face.position,
		float(face.size.x) / float(face.size.y)])

	var out := diamond(image, solid, face)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("could not write %s: %d" % [path, err])
		return false
	print("wrote %s (%dx%d)" % [path, out.get_width(), out.get_height()])
	return true

# ------------------------------------------------------------------ geometry

## Flood fills the backdrop inward from the border, returning a mask of the
## pixels that are *not* backdrop. Flooding rather than colour-matching the
## whole image keeps a stone the same hue as the backdrop from being punched
## out of the middle of the tile.
static func flood_backdrop(image: Image, key: Color) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	solid.fill(1)

	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)

	while not stack.is_empty():
		var i: int = stack.pop_back()
		if solid[i] == 0:
			continue
		var x := i % w
		var y := i / w
		if not _is_backdrop(image.get_pixel(x, y), key):
			continue
		solid[i] = 0
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)
	return solid

## True for the backdrop itself, and for a shadow cast onto it: same hue,
## darker. Anything the tile is made of differs in hue, not just brightness.
static func _is_backdrop(c: Color, key: Color) -> bool:
	if Vector3(c.r - key.r, c.g - key.g, c.b - key.b).length() <= FLAT_TOLERANCE:
		return true
	var v := Vector3(c.r, c.g, c.b)
	var k := Vector3(key.r, key.g, key.b)
	if v.length() < 0.001 or k.length() < 0.001:
		return false
	var brightness := v.length() / k.length()
	if brightness > 1.02 or brightness < SHADOW_DARKEST:
		return false
	return v.normalized().dot(k.normalized()) >= SHADOW_CHROMA

## The top face of the slab, as a rect.
##
## The top face is a parallelogram, so its fourth corner is fixed by the other
## three: bottom = left + right - top. Finding those three needs only the
## silhouette's extremes, which the extrusion below cannot move — it hangs
## *under* the left and right vertices, never beside or above them. Guessing the
## extrusion's height directly is what the first attempt got wrong.
static func top_face(solid: PackedByteArray, w: int, h: int) -> Rect2i:
	var min_x := w
	var max_x := -1
	var top_y := -1
	for y in h:
		for x in w:
			if solid[y * w + x] == 0:
				continue
			if top_y < 0:
				top_y = y
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	if max_x < 0:
		return Rect2i()

	var left_y := _first_row(solid, w, h, min_x)
	var right_y := _first_row(solid, w, h, max_x)
	var bottom_y := left_y + right_y - top_y
	if bottom_y <= top_y:
		return Rect2i()
	return Rect2i(min_x, top_y, max_x - min_x + 1, mini(bottom_y, h - 1) - top_y + 1)

## The first row in a column that is part of the subject — the left or right
## vertex of the top face, where the side wall starts.
static func _first_row(solid: PackedByteArray, w: int, h: int, x: int) -> int:
	for y in h:
		if solid[y * w + x] == 1:
			return y
	return 0

## Crops to the top face and masks it to a true 2:1 diamond on flat magenta.
## Masking rather than trusting the render is the point: the game's grid needs
## the diamond to be exactly twice as wide as it is tall, and Midjourney draws
## whatever isometric angle it feels like.
static func diamond(image: Image, solid: PackedByteArray, face: Rect2i) -> Image:
	var w := face.size.x
	var h := maxi(1, int(round(face.size.x / 2.0)))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(KEY)
	var half_w := w / 2.0
	var half_h := h / 2.0
	var scale_y := float(face.size.y) / float(h)
	for y in h:
		for x in w:
			var dx: float = absf(x + 0.5 - half_w) / half_w
			var dy: float = absf(y + 0.5 - half_h) / half_h
			if dx + dy > 1.0:
				continue
			var src_x: int = face.position.x + x
			var src_y: int = face.position.y + int(y * scale_y)
			src_y = mini(src_y, image.get_height() - 1)
			if solid[src_y * image.get_width() + src_x] == 0:
				continue
			out.set_pixel(x, y, image.get_pixel(src_x, src_y))
	return out

static func _count(mask: PackedByteArray) -> int:
	var n := 0
	for v: int in mask:
		n += v
	return n
