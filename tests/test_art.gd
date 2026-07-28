extends "res://tests/TestCase.gd"

## The asset pipeline: tile projection, trimming, scaling, and the per-sprite
## fallback that lets a partial art set work.

const ImportAssets := preload("res://tools/import_assets.gd")
const MakeTile := preload("res://tools/make_tile.gd")

func after_each() -> void:
	ArtLibrary.set_enabled(true)
	ArtLibrary.clear_cache()

func _checkerboard(size: int, a: Color, b: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, a if (x / 8 + y / 8) % 2 == 0 else b)
	return img

func _opaque_square(size: int, square: Rect2i, subject: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(square.position.y, square.end.y):
		for x in range(square.position.x, square.end.x):
			img.set_pixel(x, y, subject)
	return img

# ------------------------------------------------------- tile projection

func test_projection_is_exactly_two_to_one() -> void:
	# The grid depends on this, and no generator draws it reliably, so it is
	# derived rather than asked for.
	var tile: Image = MakeTile.project(_checkerboard(64, Color.RED, Color.BLUE), 256)
	eq(tile.get_width(), 256, "width is as requested")
	eq(tile.get_height(), 128, "height is exactly half the width")

func test_projection_fills_the_diamond_and_nothing_outside_it() -> void:
	var tile: Image = MakeTile.project(_checkerboard(64, Color.RED, Color.BLUE), 256)
	eq(tile.get_pixel(128, 64).a, 1.0, "the centre is opaque")
	eq(tile.get_pixel(128, 1).a, 1.0, "the top vertex is opaque")
	eq(tile.get_pixel(2, 64).a, 1.0, "the left vertex is opaque")
	eq(tile.get_pixel(0, 0).a, 0.0, "the top-left corner is outside the diamond")
	eq(tile.get_pixel(255, 127).a, 0.0, "the bottom-right corner is outside too")

func test_projection_samples_the_whole_texture() -> void:
	# The diamond maps to the full unit square, so a texture with distinct
	# quadrants must show all four of them.
	var tex := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var c := Color.RED if x < 32 else Color.LIME
			if y >= 32:
				c = Color.BLUE if x < 32 else Color.WHITE
			tex.set_pixel(x, y, c)
	var tile: Image = MakeTile.project(tex, 256)
	# Count by dominant channel rather than bucketing the colour: the rim shading
	# darkens every pixel it touches, so naive buckets would report four distinct
	# "colours" from a single flat one and the test would pass on anything.
	var found := {"red": 0, "green": 0, "blue": 0, "white": 0}
	for y in tile.get_height():
		for x in tile.get_width():
			var c := tile.get_pixel(x, y)
			if c.a < 0.9:
				continue
			var high := maxf(c.r, maxf(c.g, c.b))
			var low := minf(c.r, minf(c.g, c.b))
			if high - low < 0.15:
				found["white"] += 1
			elif c.r == high:
				found["red"] += 1
			elif c.g == high:
				found["green"] += 1
			else:
				found["blue"] += 1
	for quadrant: String in found:
		truthy(found[quadrant] > 200, "the %s quadrant lands on the tile (%d px)"
			% [quadrant, found[quadrant]])

func test_projection_darkens_the_rim_so_cells_stay_separate() -> void:
	# A seamless texture has no edge of its own; without this the isometric grid
	# dissolves into one field of stone.
	var flat := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flat.fill(Color(0.8, 0.8, 0.8))
	var tile: Image = MakeTile.project(flat, 256)
	var centre := tile.get_pixel(128, 64).r
	var near_edge := tile.get_pixel(128, 2).r
	truthy(near_edge < centre * 0.9, "the rim is darker than the middle (%.2f vs %.2f)" % [near_edge, centre])

# ------------------------------------------------------------- importing

func test_opaque_input_is_refused() -> void:
	# A sprite whose backdrop is baked in looks fine in the atlas and wrong on
	# screen, so the importer rejects it rather than scaling it.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.4, 0.5))
	truthy(ImportAssets.is_fully_opaque(img), "a cutout-less image is detected")
	img.set_pixel(0, 0, Color(0.4, 0.4, 0.5, 0.0))
	truthy(not ImportAssets.is_fully_opaque(img), "any transparency clears it")

func test_downscaling_does_not_fringe_the_sprite() -> void:
	# Transparent pixels keep their colour; a plain resize averages that colour
	# back in and haloes the silhouette.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 0))  # invisible, but a colour that would show
	for y in range(32, 224):
		for x in range(32, 224):
			img.set_pixel(x, y, Color(0.2, 0.3, 0.4, 1.0))
	ImportAssets.resize_without_halo(img, 64, 32)
	var worst := 0.0
	for y in 32:
		for x in 64:
			var c := img.get_pixel(x, y)
			if c.a > 0.2:
				worst = maxf(worst, c.r - c.b)
	truthy(worst < 0.1, "no magenta bleeds into the edges (worst r-b was %.3f)" % worst)

func test_trim_crops_to_the_subject() -> void:
	var img := _opaque_square(64, Rect2i(20, 10, 8, 12), Color(0.2, 0.4, 0.8))
	var trimmed := ImportAssets.trim_transparent(img)
	truthy(trimmed != null, "something survives the trim")
	eq(trimmed.get_width(), 8, "cropped to subject width")
	eq(trimmed.get_height(), 12, "cropped to subject height")

func test_trim_reports_an_entirely_transparent_image() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	truthy(ImportAssets.trim_transparent(img) == null, "an empty image is rejected")

func test_missing_art_falls_back_rather_than_erroring() -> void:
	ArtLibrary.clear_cache()
	truthy(ArtLibrary.texture("props/definitely_not_a_real_sprite") == null,
		"absent art resolves to null, not an error")
	falsy(ArtLibrary.has("entities/nobody"), "has() reports absence")

func test_art_keys_match_the_enum_names() -> void:
	eq(ArtLibrary.prop_key(MapData.Prop.RELIQUARY), "props/reliquary", "prop key from enum")
	eq(ArtLibrary.prop_key(MapData.Prop.RUNE_SLATE), "props/rune_slate", "underscored prop key")
	eq(ArtLibrary.floor_key(ArtFactory.Floor.SCRIPTORIUM), "tiles/floor_scriptorium", "floor key")
	eq(ArtLibrary.block_key(ArtFactory.Block.DOOR_OPEN), "tiles/block_door_open", "block key")
	eq(ArtLibrary.entity_key("rector"), "entities/rector", "entity key")

func test_inventory_lists_every_sprite_the_game_can_use() -> void:
	var inventory := ArtLibrary.inventory()
	var total: int = (inventory["tiles"] as Array).size() + (inventory["props"] as Array).size() \
		+ (inventory["entities"] as Array).size() + (inventory["missing"] as Array).size()
	# 9 floors + 3 blocks + 7 props + player + every enemy archetype.
	eq(total, 9 + 3 + 7 + 1 + Roster.enemies().size(), "inventory covers the full art set")
	for key: String in inventory["missing"]:
		falsy(ArtLibrary.has(key), "%s really is missing" % key)

## The procedural path must keep working, since it is what ships until art lands.
func test_tileset_builds_without_any_art() -> void:
	ArtLibrary.set_enabled(false)
	var built := ArtFactory.build_tileset()
	var tileset: TileSet = built["tileset"]
	truthy(tileset != null, "tileset builds")
	eq(tileset.get_source_count(), 2, "floor and block sources")
	var floor_source: TileSetAtlasSource = tileset.get_source(int(built["floor_source"]))
	eq(floor_source.get_tiles_count(), ArtFactory.Floor.size(), "every floor variant exists")
	eq(floor_source.texture.get_size(),
		Vector2(ArtFactory.TILE_W * ArtFactory.Floor.size(), ArtFactory.TILE_H),
		"atlas is the expected size")

## Scaling every sprite to one height would flatten the scale relationships this
## table exists to establish.
func test_import_heights_preserve_relative_scale() -> void:
	var chair := ImportAssets.target_height("props", "chair")
	var bookshelf := ImportAssets.target_height("props", "bookshelf")
	truthy(bookshelf > chair * 2, "a bookshelf towers over a stool (%d vs %d)" % [bookshelf, chair])
	var novice := ImportAssets.target_height("entities", "novice")
	var rector := ImportAssets.target_height("entities", "rector")
	truthy(rector > novice, "the Rector is bigger than a novice (%d vs %d)" % [rector, novice])
	eq(ImportAssets.target_height("entities", "player"), 48, "a person is the 48px reference")

func test_every_expected_sprite_has_a_target_height() -> void:
	# A missing entry would silently fall back to a generic height.
	for key: String in ArtLibrary.inventory()["missing"]:
		var name := key.get_file()
		if key.begins_with("tiles/"):
			continue
		truthy(ImportAssets.HEIGHTS.has(name), "%s has an import height" % name)
