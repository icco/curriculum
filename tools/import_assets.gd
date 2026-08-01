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


func _find_accepted(subject_id: String) -> String:
	var dir_path := "%s/%s" % [SOURCE_DIR, subject_id]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("accepted."):
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
