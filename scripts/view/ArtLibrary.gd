class_name ArtLibrary
extends RefCounted

## Looks up hand-authored sprites under assets/sprites/, falling back to the
## procedural art when a file is absent. The fallback is per sprite, not all or
## nothing, so a partial art set works while more is still being generated.

const SPRITE_DIR := "res://assets/sprites"

## Tile art is drawn on a 2:1 isometric diamond this size.
const TILE_SIZE := Vector2i(64, 32)

static var _cache: Dictionary = {}     ## key -> Texture2D or null
static var _enabled: bool = true

## Turn art off entirely (used by tests to exercise the procedural path).
static func set_enabled(value: bool) -> void:
	if _enabled != value:
		_enabled = value
		_cache.clear()

## `key` is a path under assets/sprites without extension, e.g. "props/desk".
static func texture(key: String) -> Texture2D:
	if not _enabled:
		return null
	if _cache.has(key):
		return _cache[key]
	var path := "%s/%s.png" % [SPRITE_DIR, key]
	var found: Texture2D = null
	if ResourceLoader.exists(path):
		found = load(path) as Texture2D
	_cache[key] = found
	return found

static func has(key: String) -> bool:
	return texture(key) != null

static func clear_cache() -> void:
	_cache.clear()

# ------------------------------------------------------------------ keys

static func floor_key(kind: int) -> String:
	return "tiles/floor_%s" % _enum_name(ArtFactory.Floor, kind)

static func block_key(kind: int) -> String:
	return "tiles/block_%s" % _enum_name(ArtFactory.Block, kind)

static func prop_key(prop: int, looted: bool = false) -> String:
	var name := _enum_name(MapData.Prop, prop)
	if looted and has("props/%s_looted" % name):
		return "props/%s_looted" % name
	return "props/%s" % name

## Entities fall back to a per-rank silhouette when a portrait is missing.
static func entity_key(id: String) -> String:
	return "entities/%s" % id

static func _enum_name(enum_dict: Dictionary, value: int) -> String:
	for key: String in enum_dict:
		if int(enum_dict[key]) == value:
			return key.to_lower()
	return "unknown"

# ------------------------------------------------------------------ drawing

## Draws a sprite standing on the tile at the local origin: horizontally
## centred, with its base on the tile centre.
static func draw_standing(ci: CanvasItem, tex: Texture2D, extra_lift: float = 0.0) -> void:
	var size := tex.get_size()
	ci.draw_texture(tex, Vector2(-size.x * 0.5, -size.y + extra_lift))

## Reports what is present, for the asset status tool.
static func inventory() -> Dictionary:
	var out: Dictionary = {"tiles": [], "props": [], "entities": [], "missing": []}
	for kind: int in ArtFactory.Floor.values():
		var key := floor_key(kind)
		(out["tiles"] if has(key) else out["missing"]).append(key)
	for kind: int in ArtFactory.Block.values():
		var key := block_key(kind)
		(out["tiles"] if has(key) else out["missing"]).append(key)
	for prop: int in MapData.Prop.values():
		if prop == MapData.Prop.NONE:
			continue
		var key := prop_key(prop)
		(out["props"] if has(key) else out["missing"]).append(key)
	var ids: Array = ["player"]
	for e: EnemyData in Roster.enemies():
		ids.append(str(e.id))
	for id: String in ids:
		var key := entity_key(id)
		(out["entities"] if has(key) else out["missing"]).append(key)
	return out
