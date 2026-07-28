extends SceneTree

## Turns generated art into game-ready sprites.
##
##   godot --headless --path . --script tools/import_assets.gd -- [--status]
##
## Reads assets/source/<category>/<name>, trims the transparent margin, scales to
## the slot's target size and writes assets/sprites/<category>/<name>.png. Input
## must already carry alpha: tools/recraft.py asks for a cutout, tools/make_tile.gd
## builds tile alpha from geometry. See assets/prompts/recraft.md.

const SOURCE_DIR := "res://assets/source"
const OUT_DIR := "res://assets/sprites"

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
		# .webp matters: it is what Recraft actually returns, and cutouts in that
		# format were being skipped without a word.
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
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

	if is_fully_opaque(image):
		push_warning("%s/%s has no transparency; run it through tools/recraft.py cutout"
			% [category, file])
		return false
	var trimmed := trim_transparent(image)
	if trimmed == null:
		push_warning("%s/%s is entirely transparent" % [category, file])
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

## Downscales without dragging invisible colour back in. Transparent pixels keep
## their RGB, and a filtered resize averages it into the edge — enough to fringe a
## whole silhouette when shrinking 1000px to 64px. Weighting by alpha first and
## dividing it back out means invisible pixels contribute nothing. For tests.
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

## True when nothing is transparent, meaning the cutout step was skipped. Such an
## image imports as a rectangle with its backdrop baked in, which does not look
## wrong until it is on screen, so the caller refuses it. Exposed for tests.
static func is_fully_opaque(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 1.0:
				return false
	return true

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
			print("  assets/source/%s" % key)
