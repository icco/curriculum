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

## The background colour the prompts ask for. Anything within TOLERANCE of it
## becomes transparent.
const CHROMA := Color(1.0, 0.0, 1.0)
const TOLERANCE := 0.28
## Pixels this close to the key are faded rather than cut, to soften edges.
const FEATHER := 0.12

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

	key_out_background(image, CHROMA, TOLERANCE, FEATHER)
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
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		return
	var height: int = target_height(category, name)
	if image.get_height() == height:
		return
	var scale := float(height) / float(image.get_height())
	image.resize(maxi(1, int(round(image.get_width() * scale))), height, Image.INTERPOLATE_LANCZOS)

## Target height for a sprite, preserving relative scale across a category.
static func target_height(category: String, name: String) -> int:
	if HEIGHTS.has(name):
		return int(HEIGHTS[name])
	push_warning("no height for %s/%s; using the category default" % [category, name])
	return DEFAULT_PROP_HEIGHT if category == "props" else DEFAULT_ENTITY_HEIGHT

# ------------------------------------------------------------- image ops

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
