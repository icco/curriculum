extends TestCase

## CI calls these by name. This repo keeps .github/ unmodified, so a missing script or a
## renamed export preset breaks the workflows — and a bad preset surfaces as an export
## failure with an empty error list, which is why the config is asserted here instead.


func suite_name() -> String:
	return "tooling"


func _text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func run() -> void:
	for script in [
		"res://tools/check.sh",
		"res://tools/ci-install-godot.sh",
		"res://tools/export-web.sh",
		"res://tools/ci-android-editor-settings.sh",
		"res://tools/shot.sh",
	]:
		check(FileAccess.file_exists(script), "%s exists" % script)

	var presets := _text("res://export_presets.cfg")
	for preset in ["Web", "Linux", "Android"]:
		check(presets.contains('name="%s"' % preset), "preset %s declared" % preset)
	# release.yml hardcodes this filename.
	check(presets.contains("curriculum.x86_64"), "linux binary named curriculum.x86_64")
	# The Web export refuses to build without this, reporting an empty error list.
	check(
		presets.contains("vram_texture_compression/for_mobile=false"),
		"web preset disables mobile vram compression"
	)
	# Portrait on Android, matching the project's handheld orientation.
	check(presets.contains("screen/orientation=1"), "android exports portrait")

	check(FileAccess.file_exists("res://Dockerfile"), "Dockerfile exists")
	var nginx := _text("res://docker/nginx.conf")
	check(nginx.contains("healthz"), "nginx serves /healthz")
	check(nginx.contains("application/wasm"), "nginx types wasm")
	check(nginx.contains("listen 8080"), "nginx listens on 8080")
