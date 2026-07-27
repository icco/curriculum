extends SceneTree

## Turns raw Midjourney output into game-ready sprites.
##
##   godot --headless --path . --script tools/import_assets.gd -- [--status]
##
## Reads assets/source/<category>/<name>.png, keys out the flat background,
## trims the transparent margin, scales to the slot's target size and writes
## assets/sprites/<category>/<name>.png. Midjourney cannot output transparency,
## so every prompt asks for a flat chroma background — see assets/prompts/midjourney.md.

const SOURCE_DIR := "res://assets/source"
const OUT_DIR := "res://assets/sprites"

## The key colour is read from the image's corners rather than assumed. The
## prompts ask for magenta, but Midjourney ignores hex codes and a style
## reference recolours the whole frame — one real generation came back with a
## #844352 background, 0.87 away from magenta, which a fixed key cannot touch.
## What it does deliver is a *uniform* background, so sampling it is reliable.
const CHROMA := Color(1.0, 0.0, 1.0)
## Because the key is measured rather than guessed, the cut can be tight: the
## corners of a real generation agree to within ~0.012. Anything looser starts
## eating the dark blue-greys and violets this art direction is built from.
const TOLERANCE := 0.05
## Pixels this close to the key are faded rather than cut, to soften edges.
const FEATHER := 0.03
## Corners disagreeing by more than this mean the background is not flat.
const CORNER_AGREEMENT := 0.05
## Size of the patch sampled at each corner, as a fraction of the short side.
const CORNER_PATCH := 0.02

## Tiles must match the isometric grid exactly.
const TILE_SIZE := Vector2i(64, 32)
const BLOCK_SIZE := Vector2i(64, 64)

## Per-sprite target heights in pixels, on a scale where a 1.7m figure is 48px —
## the same reference the prompts state. Scaling every sprite to one height would
## make a stool as tall as a bookshelf and a novice as tall as the Rector, so this
## table — not the source images — is what keeps relative scale honest.
const HEIGHTS := {
	# props
	"desk": 30, "chair": 26, "brazier": 40, "podium": 34,
	"rune_slate": 48, "reliquary": 52, "reliquary_looted": 52, "bookshelf": 62,
	# entities: a person is 48, rank reads through size
	"player": 48, "novice": 44, "disputation_adept": 46, "illusionist": 47,
	"battle_chanter": 50, "proctor": 50, "visiting_lecturer": 50,
	"senior_warden": 52, "alchemy_master": 52, "drillmaster": 56,
	"vice_chancellor": 58, "rector": 66,
}
const DEFAULT_PROP_HEIGHT := 48
const DEFAULT_ENTITY_HEIGHT := 48

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	if OS.get_cmdline_user_args().has("--status"):
		_report_status()
		quit(0)
		return true
	var count := 0
	for category: String in ["tiles", "props", "entities"]:
		count += _import_category(category)
	print("imported %d sprites into %s" % [count, OUT_DIR])
	_report_status()
	quit(0)
	return true

func _import_category(category: String) -> int:
	var in_dir := "%s/%s" % [SOURCE_DIR, category]
	var dir := DirAccess.open(in_dir)
	if dir == null:
		return 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, category]))
	var count := 0
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.to_lower().ends_with(".png") or file.to_lower().ends_with(".jpg"):
			if _import_one(category, file):
				count += 1
		file = dir.get_next()
	dir.list_dir_end()
	return count

func _import_one(category: String, file: String) -> bool:
	var name := file.get_basename()
	var image := Image.load_from_file(ProjectSettings.globalize_path(
		"%s/%s/%s" % [SOURCE_DIR, category, file]))
	if image == null:
		push_error("could not read %s/%s" % [category, file])
		return false
	image.convert(Image.FORMAT_RGBA8)

	var key := sample_background(image)
	if key.a < 1.0:
		push_warning("%s/%s has no flat background to key; corners disagree" % [category, file])
		return false
	key_out_background(image, key, TOLERANCE, FEATHER)
	var trimmed := trim_transparent(image)
	if trimmed == null:
		push_warning("%s/%s is entirely background after keying" % [category, file])
		return false
	_fit(trimmed, category, name)

	var out := "%s/%s/%s.png" % [OUT_DIR, category, name]
	var err := trimmed.save_png(ProjectSettings.globalize_path(out))
	if err != OK:
		push_error("could not write %s: %d" % [out, err])
		return false
	print("  %-28s -> %dx%d" % ["%s/%s" % [category, name], trimmed.get_width(), trimmed.get_height()])
	return true

func _fit(image: Image, category: String, name: String) -> void:
	if category == "tiles":
		var target := BLOCK_SIZE if name.begins_with("block_") else TILE_SIZE
		resize_without_halo(image, target.x, target.y)
		return
	var height: int = target_height(category, name)
	if image.get_height() == height:
		return
	var scale := float(height) / float(image.get_height())
	resize_without_halo(image, maxi(1, int(round(image.get_width() * scale))), height)

## Downscales without dragging the keyed-out background back in.
##
## Keying only zeroes alpha; the transparent pixels keep their original colour,
## and a filtered resize happily averages that colour into the edge. Shrinking a
## 1000px tile to 64px samples far enough to fringe the whole silhouette with
## the key. Weighting colour by alpha first, then dividing it back out, means
## invisible pixels contribute nothing. Exposed for tests.
static func resize_without_halo(image: Image, width: int, height: int) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0039:  # 1/255: nothing worth recovering
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			image.set_pixel(x, y, Color(
				minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))

## Target height for a sprite, preserving relative scale across a category.
static func target_height(category: String, name: String) -> int:
	if HEIGHTS.has(name):
		return int(HEIGHTS[name])
	push_warning("no height for %s/%s; using the category default" % [category, name])
	return DEFAULT_PROP_HEIGHT if category == "props" else DEFAULT_ENTITY_HEIGHT

# ------------------------------------------------------------- image ops

## Reads the background colour out of the image's four corners. Returns it with
## alpha 1, or a fully transparent colour if the corners disagree — a subject
## bleeding into a corner or a shadow cast onto the backdrop should stop the
## import, not silently key out the wrong colour.
##
## Picks whichever corner sits closest to the other three rather than averaging
## them, so one bad corner shifts nothing. Exposed for tests.
static func sample_background(image: Image) -> Color:
	var patch := maxi(2, int(mini(image.get_width(), image.get_height()) * CORNER_PATCH))
	var corners: Array[Color] = []
	for origin: Vector2i in [
		Vector2i(0, 0),
		Vector2i(image.get_width() - patch, 0),
		Vector2i(0, image.get_height() - patch),
		Vector2i(image.get_width() - patch, image.get_height() - patch),
	]:
		corners.append(_patch_average(image, origin, patch))

	var best := corners[0]
	var best_spread := INF
	for candidate: Color in corners:
		var spread := 0.0
		for other: Color in corners:
			spread += _rgb_distance(candidate, other)
		if spread < best_spread:
			best_spread = spread
			best = candidate

	var agreeing := 0
	for corner: Color in corners:
		if _rgb_distance(corner, best) <= CORNER_AGREEMENT:
			agreeing += 1
	if agreeing < 3:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(best.r, best.g, best.b, 1.0)

static func _patch_average(image: Image, origin: Vector2i, size: int) -> Color:
	var total := Vector3.ZERO
	for y in range(origin.y, origin.y + size):
		for x in range(origin.x, origin.x + size):
			var c := image.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
	total /= float(size * size)
	return Color(total.x, total.y, total.z)

static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## Makes pixels near `key` transparent, feathering the boundary so edges do not
## alias. Exposed for tests.
static func key_out_background(image: Image, key: Color, tolerance: float, feather: float) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var distance := Vector3(c.r - key.r, c.g - key.g, c.b - key.b).length()
			if distance <= tolerance:
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			elif distance <= tolerance + feather:
				var alpha: float = (distance - tolerance) / feather
				# Pull the key's hue out of the fringe so it does not glow.
				image.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha))

## Crops fully transparent rows and columns. Returns null if nothing is left.
static func trim_transparent(image: Image) -> Image:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	return image.get_region(used)

# ---------------------------------------------------------------- status

func _report_status() -> void:
	var inventory := ArtLibrary.inventory()
	var present: int = (inventory["tiles"] as Array).size() + (inventory["props"] as Array).size() \
		+ (inventory["entities"] as Array).size()
	var missing: Array = inventory["missing"]
	print("\nart present: %d, still procedural: %d" % [present, missing.size()])
	if not missing.is_empty():
		print("missing (drawn procedurally until supplied):")
		for key: String in missing:
			print("  assets/source/%s.png" % key)
