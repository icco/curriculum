extends SceneTree

## Converts every accepted raw generator output under assets/source/<id>/accepted.*
## into the real .png sprite ArtLibrary looks for at assets/sprites/<id>.png, then
## reports which manifest subjects still have no accepted art.
##
## The conversion has to happen here rather than in tools/recraft.py because Recraft
## serves WebP regardless of what the URL implies, and Python in this project has no
## image codec available (no Pillow). Godot already ships WebP/JPG/PNG decoders for
## its own importer, so it does the decode-and-re-encode instead of adding a Python
## dependency the rest of the toolchain doesn't have.
##
## Run via tools/import-assets.sh, which runs this and then `--headless --import` --
## a .png is not loadable by ResourceLoader until Godot has imported it.
##
## Usage: godot --headless --path . --script tools/import_assets.gd

const MANIFEST_PATH := "res://assets/prompts/manifest.json"
const SOURCE_DIR := "res://assets/source"
const SPRITE_DIR := "res://assets/sprites"

# CardView's TextureRect has no aspect-preserving stretch mode (BattleScreen's
# figure one does), so a sprite whose aspect doesn't already match CARD_SIZE (2:3)
# gets non-uniformly stretched -- circles become ellipses. Recraft has no 2:3
# size option (see assets/prompts/manifest.json's "sizes" comment), so card art is
# generated square and padded here with cream margin top and bottom to exactly 2:3
# before it ever reaches CardView. The padding also reads as the intended "printed
# plate" margin from the art direction, not just a technical workaround.
const CARD_ASPECT := 1.5  # height / width, matching CardView.CARD_SIZE's 200x300


func _load_image_bytes(bytes: PackedByteArray, ext: String) -> Image:
	var image := Image.new()
	var err: Error
	match ext:
		"png":
			err = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = image.load_jpg_from_buffer(bytes)
		"webp":
			err = image.load_webp_from_buffer(bytes)
		_:
			printerr("import_assets: unrecognised extension .%s" % ext)
			return null
	if err != OK:
		printerr("import_assets: failed to decode (%s): %d" % [ext, err])
		return null
	return image


## Sniffs magic bytes rather than trusting the accepted file's extension, for the
## same reason tools/recraft.py does when it first writes the file: Recraft serves
## WebP no matter what the response implied, and a stale extension from a manual
## rename would otherwise pick the wrong decoder.
func _sniff_ext(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


## Pads a square card illustration to CARD_ASPECT with solid cream margin, top and
## bottom, so it matches CardView.CARD_SIZE's aspect exactly and its untouched,
## default-stretch TextureRect can't distort it.
func _pad_to_card_aspect(image: Image) -> Image:
	var w := image.get_width()
	var target_h := int(round(float(w) * CARD_ASPECT))
	if target_h <= image.get_height():
		return image
	# blit_rect requires the two images to share a format -- Recraft's output
	# decodes as RGB8 (no alpha), not this canvas's RGBA8, without this.
	image.convert(Image.FORMAT_RGBA8)
	var padded := Image.create(w, target_h, false, Image.FORMAT_RGBA8)
	# Recraft's own cream drifts a few values off the nominal #F7EADD (warmer,
	# slightly pinker) -- padding with the literal hex left a visible seam where
	# the margin met the generated ground. Sampling the corner instead always
	# matches whatever cream this particular image actually came back with.
	padded.fill(image.get_pixel(2, 2))
	var y_offset := (target_h - image.get_height()) / 2
	padded.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, y_offset))
	return padded


func _find_accepted(subject_id: String) -> String:
	var dir_path := "%s/%s" % [SOURCE_DIR, subject_id]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		# assets/source lives inside the project, so Godot's own importer leaves an
		# accepted.png.import sidecar right next to accepted.png; without excluding
		# it, "begins_with" also matches that sidecar as if it were image data.
		if name.begins_with("accepted.") and not name.ends_with(".import"):
			return "%s/%s" % [dir_path, name]
		name = dir.get_next()
	return ""


func _process(_delta: float) -> bool:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		printerr("import_assets: cannot open %s" % MANIFEST_PATH)
		quit(1)
		return true
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	if manifest == null:
		printerr("import_assets: manifest.json failed to parse")
		quit(1)
		return true

	var converted := 0
	var missing: Array = []
	var failed: Array = []

	for subject in manifest["subjects"]:
		var subject_id: String = subject["id"]
		var accepted_path := _find_accepted(subject_id)
		if accepted_path == "":
			missing.append(subject_id)
			continue

		var f := FileAccess.open(accepted_path, FileAccess.READ)
		if f == null:
			failed.append("%s: cannot open %s" % [subject_id, accepted_path])
			continue
		var bytes := f.get_buffer(f.get_length())
		var ext := _sniff_ext(bytes)
		if ext == "":
			failed.append("%s: %s matches no known image format" % [subject_id, accepted_path])
			continue

		var image := _load_image_bytes(bytes, ext)
		if image == null:
			failed.append("%s: failed to decode %s" % [subject_id, accepted_path])
			continue

		if subject.get("category") == "card":
			image = _pad_to_card_aspect(image)

		var sprite_path := "%s/%s.png" % [SPRITE_DIR, subject_id]
		var sprite_dir := sprite_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sprite_dir))
		var save_err := image.save_png(sprite_path)
		if save_err != OK:
			failed.append("%s: save_png failed: %d" % [subject_id, save_err])
			continue
		converted += 1

	print("import_assets: converted %d accepted source(s) to sprites" % converted)
	if not failed.is_empty():
		print("import_assets: %d failure(s):" % failed.size())
		for msg in failed:
			print("  - %s" % msg)
	print("import_assets: %d subject(s) still have no accepted art (fine -- ArtLibrary paints a fallback):" % missing.size())
	for m in missing:
		print("  - %s" % m)

	if not failed.is_empty():
		quit(1)
		return true
	quit(0)
	return true
