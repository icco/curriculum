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
	if has_sprite(key):
		var loaded: Texture2D = load(_sprite_path(key))
		if loaded != null:
			return loaded

	var cache_key := "%s@%dx%d@%d" % [key, size.x, size.y, school]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var painted: Texture2D = _paint(key, size, school)
	_cache[cache_key] = painted
	return painted


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
