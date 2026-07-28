class_name ArtFactory
extends RefCounted

## Procedural fallback art: every texture is painted here at startup, so the
## game is playable before any artwork exists.

const TILE_W := 64
const TILE_H := 32
const BLOCK_H := 32  ## how far a wall/door block rises above its floor diamond

## Floor tile ids inside the floor atlas (one column each).
enum Floor { HALL, LECTURE_HALL, ALCHEMY, SCRIPTORIUM, REFECTORY, TRAINING_YARD, VAULT, STUDY, STAIRS }
## Block tile ids inside the block atlas.
enum Block { DOOR }

const ROOM_FLOOR := {
	"lecture_hall": Floor.LECTURE_HALL,
	"alchemy_lab": Floor.ALCHEMY,
	"scriptorium": Floor.SCRIPTORIUM,
	"refectory": Floor.REFECTORY,
	"training_yard": Floor.TRAINING_YARD,
	"vault_row": Floor.VAULT,
	"proctors_study": Floor.STUDY,
}

const FLOOR_STYLE := {
	Floor.HALL: {"base": Color("4a4f5c"), "alt": Color("545a68"), "line": Color("3a3e49"), "pattern": "checker"},
	Floor.LECTURE_HALL: {"base": Color("6b5a45"), "alt": Color("6b5a45"), "line": Color("53442f"), "pattern": "plain"},
	Floor.ALCHEMY: {"base": Color("46596b"), "alt": Color("4d6274"), "line": Color("354552"), "pattern": "grid"},
	Floor.SCRIPTORIUM: {"base": Color("6b3f42"), "alt": Color("6b3f42"), "line": Color("532f33"), "pattern": "plain"},
	Floor.REFECTORY: {"base": Color("5e6b44"), "alt": Color("6a7850"), "line": Color("4a5436"), "pattern": "checker"},
	Floor.TRAINING_YARD: {"base": Color("8a6a3a"), "alt": Color("8a6a3a"), "line": Color("6d5330"), "pattern": "planks"},
	Floor.VAULT: {"base": Color("4f5560"), "alt": Color("4f5560"), "line": Color("3c414a"), "pattern": "plain"},
	Floor.STUDY: {"base": Color("3f5749"), "alt": Color("3f5749"), "line": Color("31443a"), "pattern": "plain"},
	Floor.STAIRS: {"base": Color("2f6b8a"), "alt": Color("3a7ea1"), "line": Color("235268"), "pattern": "stairs"},
}

# ------------------------------------------------------------------ tileset

## Builds the isometric TileSet used by the floor and block layers.
## Returns {tileset: TileSet, floor_source: int, block_source: int}
static func build_tileset() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = Vector2i(TILE_W, TILE_H)

	var floor_count: int = Floor.size()
	var floor_img := Image.create(TILE_W * floor_count, TILE_H, false, Image.FORMAT_RGBA8)
	floor_img.fill(Color(0, 0, 0, 0))
	for i in floor_count:
		if not _blit_art(floor_img, ArtLibrary.floor_key(i), i * TILE_W, 0, Vector2i(TILE_W, TILE_H)):
			_paint_floor(floor_img, i * TILE_W, i)
	var floor_src := TileSetAtlasSource.new()
	floor_src.texture = ImageTexture.create_from_image(floor_img)
	floor_src.texture_region_size = Vector2i(TILE_W, TILE_H)
	for i in floor_count:
		floor_src.create_tile(Vector2i(i, 0))
	var floor_id := ts.add_source(floor_src)

	var block_count: int = Block.size()
	var block_h := TILE_H + BLOCK_H
	var block_img := Image.create(TILE_W * block_count, block_h, false, Image.FORMAT_RGBA8)
	block_img.fill(Color(0, 0, 0, 0))
	var block_size := Vector2i(TILE_W, block_h)
	if not _blit_art(block_img, ArtLibrary.block_key(Block.DOOR), Block.DOOR * TILE_W, 0, block_size):
		_paint_door(block_img, Block.DOOR * TILE_W)
	var block_src := TileSetAtlasSource.new()
	block_src.texture = ImageTexture.create_from_image(block_img)
	block_src.texture_region_size = Vector2i(TILE_W, block_h)
	for i in block_count:
		block_src.create_tile(Vector2i(i, 0))
		# The block art is TILE_H+BLOCK_H tall but its footprint is the bottom
		# diamond, so lift the sprite until that diamond lands on the cell.
		var data: TileData = block_src.get_tile_data(Vector2i(i, 0), 0)
		data.texture_origin = Vector2i(0, -BLOCK_H / 2)
	var block_id := ts.add_source(block_src)

	return {"tileset": ts, "floor_source": floor_id, "block_source": block_id}

## Copies an authored sprite into the atlas, scaling it to the cell. Returns
## false when there is no art for that key, so the caller paints instead.
static func _blit_art(target: Image, key: String, x: int, y: int, size: Vector2i) -> bool:
	var tex := ArtLibrary.texture(key)
	if tex == null:
		return false
	var src := tex.get_image()
	if src == null:
		return false
	src = src.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	if src.get_size() != size:
		src.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	target.blit_rect(src, Rect2i(Vector2i.ZERO, size), Vector2i(x, y))
	return true

# -------------------------------------------------------------- primitives

## Half-width of the diamond on row `y` of a TILE_H tall diamond.
static func _diamond_half(y: int) -> int:
	var t: float = 1.0 - absf(float(y) - (TILE_H - 1) / 2.0) / (TILE_H / 2.0)
	return int(round(t * TILE_W / 2.0))

static func _paint_floor(img: Image, x0: int, kind: int) -> void:
	var style: Dictionary = FLOOR_STYLE.get(kind, FLOOR_STYLE[Floor.HALL])
	var base: Color = style["base"]
	var alt: Color = style["alt"]
	var line: Color = Color(base.r * 0.72, base.g * 0.72, base.b * 0.72)
	var pattern: String = style["pattern"]

	for y in TILE_H:
		var half := _diamond_half(y)
		for x in range(TILE_W / 2 - half, TILE_W / 2 + half):
			var col: Color = base
			match pattern:
				"checker":
					if ((x / 8) + (y / 4)) % 2 == 0:
						col = alt
				"grid":
					if x % 16 < 1 or y % 8 < 1:
						col = alt
				"planks":
					if (y / 3) % 2 == 0:
						col = Color(base.r * 1.06, base.g * 1.04, base.b * 0.98)
				"stairs":
					var band := int((x + y * 2) / 10) % 2
					col = alt if band == 0 else base
			# Edge shading reads as a tile border without a separate grid pass.
			if x <= TILE_W / 2 - half + 1 or x >= TILE_W / 2 + half - 2:
				col = line
			if y == 0 or y == TILE_H - 1:
				col = line
			col = _jitter(col, x0 + x, y, 0.03)
			img.set_pixel(x0 + x, y, col)

static func _paint_door(img: Image, x0: int) -> void:
	_paint_block(img, x0, Color("9a7448"), Color("7d5c37"), Color("5c4228"), "panel")

## Draws an isometric cube: top diamond plus the two visible side faces.
static func _paint_block(img: Image, x0: int, top: Color, left: Color, right: Color, style: String) -> void:
	var h := img.get_height()
	# Side faces first, then the top diamond over them.
	for x in TILE_W:
		var edge_y: float
		var face: Color
		if x < TILE_W / 2:
			edge_y = TILE_H / 2.0 + x * float(TILE_H) / float(TILE_W)
			face = left
		else:
			edge_y = TILE_H - (x - TILE_W / 2.0) * float(TILE_H) / float(TILE_W)
			face = right
		for dy in range(BLOCK_H):
			var y := int(edge_y) + dy
			if y < 0 or y >= h:
				continue
			var col := face
			if style == "panel" and (x % 16 < 2 or dy < 2 or dy > BLOCK_H - 4):
				col = Color(face.r * 0.8, face.g * 0.8, face.b * 0.8)
			# Vertical falloff gives the block some volume.
			var shade: float = 1.0 - float(dy) / float(BLOCK_H) * 0.25
			col = Color(col.r * shade, col.g * shade, col.b * shade)
			img.set_pixel(x0 + x, y, _jitter(col, x0 + x, y, 0.02))
	for y in TILE_H:
		var half := _diamond_half(y)
		for x in range(TILE_W / 2 - half, TILE_W / 2 + half):
			var col: Color = top
			if x <= TILE_W / 2 - half + 1 or x >= TILE_W / 2 + half - 2:
				col = Color(top.r * 0.78, top.g * 0.78, top.b * 0.82)
			img.set_pixel(x0 + x, y, _jitter(col, x0 + x, y, 0.02))

## Deterministic per-pixel noise so surfaces are not flat, without an RNG.
static func _jitter(col: Color, x: int, y: int, amount: float) -> Color:
	var h: int = (x * 73856093) ^ (y * 19349663)
	var n: float = float(absi(h) % 1000) / 1000.0 - 0.5
	var f: float = 1.0 + n * amount * 2.0
	return Color(clampf(col.r * f, 0, 1), clampf(col.g * f, 0, 1), clampf(col.b * f, 0, 1))

# ------------------------------------------------------------ shared colors

const TEAM_PLAYER := Color("4fc3f7")
const ELITE_TRIM := Color("ffca28")
const BOSS_TRIM := Color("ab47bc")

const UI_BG := Color("11141c")
const UI_PANEL := Color("1c2130")
const UI_ACCENT := Color("4fc3f7")
const UI_TEXT := Color("e8eaf0")
const UI_DIM := Color("8891a5")
const UI_DANGER := Color("ef5350")
const UI_GOOD := Color("66bb6a")
