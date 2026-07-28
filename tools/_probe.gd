extends SceneTree
const ImportAssets := preload("res://tools/import_assets.gd")
func _process(_d: float) -> bool:
	var S := "/private/tmp/claude-501/-Users-nat-Projects-curriculum/eae3b895-5a3d-4e1b-a5cd-773afd5a8106/scratchpad/"
	var args := OS.get_cmdline_user_args()
	var category: String = args[0]
	var names := args.slice(1)
	var cell := Vector2i(300, 340)
	var sheet := Image.create(cell.x * 4, cell.y * names.size(), false, Image.FORMAT_RGBA8)
	# Two backdrops, since contrast against the floor is the thing that fails.
	sheet.fill(Color(0.07, 0.07, 0.09, 1))
	for row in names.size():
		var target := ImportAssets.target_height(category, names[row])
		for i in 4:
			var path := "res://assets/source/%s/%s-%d.webp" % [category, names[row], i + 1]
			if not FileAccess.file_exists(path):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			img.convert(Image.FORMAT_RGBA8)
			var trimmed := ImportAssets.trim_transparent(img)
			if trimmed == null:
				continue
			var scale := float(target) / float(trimmed.get_height())
			ImportAssets.resize_without_halo(trimmed,
				maxi(1, int(round(trimmed.get_width() * scale))), target)
			var big := trimmed.duplicate()
			big.resize(big.get_width() * 4, big.get_height() * 4, Image.INTERPOLATE_NEAREST)
			var origin := Vector2i(i * cell.x + 10, row * cell.y + 10)
			sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), origin)
			sheet.blend_rect(trimmed, Rect2i(Vector2i.ZERO, trimmed.get_size()),
				Vector2i(i * cell.x + 10, row * cell.y + 300))
	sheet.save_png(S + "figures.png")
	quit(0)
	return true
