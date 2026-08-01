class_name ArtLibrary
extends RefCounted

## Sprite lookup with a per-key procedural fallback, so a half-finished art set renders
## correctly and one illustration can drop in at a time.

const PAPER := Color("#F7EADD")
const INK := Color("#000000")
const SLATE := Color("#A3B0AC")
const GRAIN_A := Color("#999189")
const GRAIN_B := Color("#6C6661")

const SPRITE_DIR := "res://assets/sprites"

static var _cache := {}


static func _sprite_path(key: String) -> String:
	return "%s/%s.png" % [SPRITE_DIR, key]


## A .png is unusable until Godot has imported it — writing the file is not enough,
## which is why tools/import-assets.sh runs --import.
static func has_sprite(key: String) -> bool:
	return ResourceLoader.exists(_sprite_path(key))


## Looks up a sprite, falling back to painted art per key.
##
## `school` matters for cards and must be the card's REAL school. Without it the fallback
## derives one by hashing the key, which gives a stable colour but the WRONG one — a
## Cinder card painted Frost blue. The school's ink is the player's only at-a-glance cue
## for the weakness mechanic, so a wrong colour is a gameplay bug, not a cosmetic one.
## Pass -1 only for keys that are not cards.
static func texture(key: String, size: Vector2i, school: int = -1) -> Texture2D:
	# Cache first. This used to call has_sprite() — and so ResourceLoader.exists(), a
	# filesystem check — on EVERY call before consulting the cache, including the
	# per-refresh lookup BattleScreen makes for the examiner figure. Only the painted
	# fallback was ever cached; the question "is there a sprite for this?" was asked
	# again every time, and its answer cannot change while the game is running.
	var cache_key := "%s@%dx%d@%d" % [key, size.x, size.y, school]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var resolved: Texture2D = null
	if has_sprite(key):
		resolved = load(_sprite_path(key))
	if resolved == null:
		resolved = _paint(key, size, school)
	_cache[cache_key] = resolved
	return resolved


## Drops every cached texture. Nothing calls this in normal play — the cache is bounded
## by the number of distinct art keys, not by play length — but a caller regenerating
## art on disk needs a way to stop serving the old answer to has_sprite().
static func clear_cache() -> void:
	_cache.clear()


static func _paint(key: String, size: Vector2i, school: int) -> Texture2D:
	if key.begins_with("cards/"):
		return ArtFactory.card_face(school if school >= 0 else _school_for(key), size)
	if key.begins_with("entities/"):
		return ArtFactory.figure(key, size)
	if key.begins_with("courses/"):
		return ArtFactory.medallion(1, size)
	return ArtFactory.figure(key, size)


## Last-resort school for a card key with no school supplied: stable per key, so two
## different cards do not paint identically. Callers that know the real school pass it.
static func _school_for(key: String):
	return Schools.ALL[absi(hash(key)) % Schools.ALL.size()]


## Which of these keys are still drawn procedurally. Drives the art manifest.
static func missing_keys(keys: Array) -> Array:
	var out: Array = []
	var seen := {}
	for key in keys:
		if seen.has(key):
			continue
		seen[key] = true
		if not has_sprite(key):
			out.append(key)
	return out
