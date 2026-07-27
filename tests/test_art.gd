extends "res://tests/TestCase.gd"

## The asset pipeline: background keying, trimming, and the per-sprite fallback
## that lets a partial art set work.

const ImportAssets := preload("res://tools/import_assets.gd")
const ExtractTile := preload("res://tools/extract_tile.gd")

func after_each() -> void:
	ArtLibrary.set_enabled(true)
	ArtLibrary.clear_cache()

func _magenta_with_square(size: int, square: Rect2i) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1))
	for y in range(square.position.y, square.end.y):
		for x in range(square.position.x, square.end.x):
			img.set_pixel(x, y, Color(0.2, 0.4, 0.8))
	return img

func test_keying_removes_the_background_and_keeps_the_subject() -> void:
	var img := _magenta_with_square(32, Rect2i(8, 8, 16, 16))
	ImportAssets.key_out_background(img, Color(1, 0, 1), 0.28, 0.12)
	eq(img.get_pixel(0, 0).a, 0.0, "corner background is transparent")
	eq(img.get_pixel(2, 30).a, 0.0, "edge background is transparent")
	eq(img.get_pixel(16, 16).a, 1.0, "subject is untouched")
	between(img.get_pixel(16, 16).b, 0.79, 0.81, "subject colour survives")

func test_keying_tolerates_compression_noise() -> void:
	# Midjourney output is never a perfectly flat key.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color(0.97 + 0.01 * (x % 2), 0.03, 0.96))
	ImportAssets.key_out_background(img, Color(1, 0, 1), 0.28, 0.12)
	var opaque := 0
	for y in 8:
		for x in 8:
			if img.get_pixel(x, y).a > 0.0:
				opaque += 1
	eq(opaque, 0, "near-magenta noise still keys out")

func test_keying_leaves_unrelated_colours_alone() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.2, 0.9))  # pink, but not the key
	ImportAssets.key_out_background(img, Color(1, 0, 1), 0.05, 0.01)
	eq(img.get_pixel(1, 1).a, 1.0, "a colour outside the tolerance is kept")

## The colour a real generation came back with when the prompt asked for bright
## magenta: the style reference dragged the whole frame toward its own palette.
const DUSTY_ROSE := Color(0.518, 0.263, 0.322)

func _background_with_square(size: int, background: Color, square: Rect2i, subject: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(background)
	for y in range(square.position.y, square.end.y):
		for x in range(square.position.x, square.end.x):
			img.set_pixel(x, y, subject)
	return img

func test_background_is_read_from_the_image_not_assumed() -> void:
	# Midjourney ignores hex codes, so the key has to be measured.
	var img := _background_with_square(64, DUSTY_ROSE, Rect2i(16, 16, 32, 32), Color(0.23, 0.27, 0.31))
	var key := ImportAssets.sample_background(img)
	eq(key.a, 1.0, "a flat background is found")
	between(ImportAssets._rgb_distance(key, DUSTY_ROSE), 0.0, 0.01, "the key is the actual background")

func test_keying_a_sampled_background_spares_the_dark_palette() -> void:
	# Dark blue-grey stone sits ~0.29 from that dusty rose — inside the old 0.40
	# cut, safely outside the tight one the sampling buys.
	var stone := Color(0.23, 0.27, 0.31)
	var img := _background_with_square(64, DUSTY_ROSE, Rect2i(16, 16, 32, 32), stone)
	var key := ImportAssets.sample_background(img)
	ImportAssets.key_out_background(img, key, ImportAssets.TOLERANCE, ImportAssets.FEATHER)
	eq(img.get_pixel(0, 0).a, 0.0, "background keys out")
	eq(img.get_pixel(32, 32).a, 1.0, "dark stone is untouched")

func test_one_spoiled_corner_does_not_move_the_key() -> void:
	# A cast shadow falling into a corner is common; it must not become the key.
	var img := _background_with_square(64, DUSTY_ROSE, Rect2i(0, 52, 12, 12), Color(0.2, 0.1, 0.12))
	var key := ImportAssets.sample_background(img)
	eq(key.a, 1.0, "three good corners still agree")
	between(ImportAssets._rgb_distance(key, DUSTY_ROSE), 0.0, 0.01, "the shadowed corner is outvoted")

func test_a_background_that_is_not_flat_is_rejected() -> void:
	# Better to skip the sprite than to key out an arbitrary colour.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(float(x) / 64.0, 0.2, float(y) / 64.0))
	eq(ImportAssets.sample_background(img).a, 0.0, "a gradient background is refused")

func test_downscaling_does_not_fringe_the_sprite_with_the_key() -> void:
	# The key colour lives on in the RGB of transparent pixels; a plain resize
	# averages it back in and haloes the silhouette.
	var img := _background_with_square(256, Color(1, 0, 1), Rect2i(32, 32, 192, 192), Color(0.2, 0.3, 0.4))
	ImportAssets.key_out_background(img, Color(1, 0, 1), ImportAssets.TOLERANCE, ImportAssets.FEATHER)
	ImportAssets.resize_without_halo(img, 64, 32)
	var worst := 0.0
	for y in 32:
		for x in 64:
			var c := img.get_pixel(x, y)
			if c.a > 0.2:
				worst = maxf(worst, c.r - c.b)
	truthy(worst < 0.1, "no pink bleeds into the edges (worst r-b was %.3f)" % worst)

func test_trim_crops_to_the_subject() -> void:
	var img := _magenta_with_square(64, Rect2i(20, 10, 8, 12))
	ImportAssets.key_out_background(img, Color(1, 0, 1), 0.28, 0.12)
	var trimmed := ImportAssets.trim_transparent(img)
	truthy(trimmed != null, "something survives the trim")
	eq(trimmed.get_width(), 8, "cropped to subject width")
	eq(trimmed.get_height(), 12, "cropped to subject height")

func test_trim_reports_an_entirely_keyed_image() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1))
	ImportAssets.key_out_background(img, Color(1, 0, 1), 0.28, 0.12)
	truthy(ImportAssets.trim_transparent(img) == null, "an all-background image is rejected")

## A Midjourney "floor tile" is really a slab: a diamond top face extruded into
## side walls, with a shadow thrown on the backdrop. Both have to go.
func _slab(size: int, backdrop: Color, extrusion: int, shadow: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(backdrop)
	if shadow:
		for y in range(size - 40, size - 10):
			for x in range(10, 70):
				img.set_pixel(x, y, Color(backdrop.r * 0.6, backdrop.g * 0.6, backdrop.b * 0.6))
	var cx := size / 2.0
	var half_w := 80.0
	var half_h := 40.0
	var cy := 60.0
	for x in range(int(cx - half_w), int(cx + half_w)):
		var span := half_h * (1.0 - absf(x - cx) / half_w)
		var top := int(cy - span)
		for y in range(top, int(cy + span) + extrusion):
			if y < 0 or y >= size:
				continue
			img.set_pixel(x, y, Color(0.23, 0.27, 0.31) if y <= cy + span else Color(0.15, 0.17, 0.2))
	return img

func test_top_face_ignores_the_extrusion_below_it() -> void:
	var img := _slab(200, DUSTY_ROSE, 30, false)
	var solid := ExtractTile.flood_backdrop(img, DUSTY_ROSE)
	var face := ExtractTile.top_face(solid, 200, 200)
	between(float(face.size.x) / float(face.size.y), 1.9, 2.1, "the top face comes out 2:1")
	truthy(face.end.y < 110, "the side walls are left behind (bottom at %d)" % face.end.y)

func test_a_cast_shadow_is_not_mistaken_for_the_tile() -> void:
	# The shadow is darker than the backdrop but shares its hue; the tile does
	# not. Without this the shadow drags the tile's left edge out with it.
	var img := _slab(200, DUSTY_ROSE, 30, true)
	var solid := ExtractTile.flood_backdrop(img, DUSTY_ROSE)
	var face := ExtractTile.top_face(solid, 200, 200)
	eq(face.position.x, 20, "the left vertex is the tile's, not the shadow's")

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
