class_name IsoDraw
extends RefCounted

## Shared isometric drawing primitives used by prop and entity sprites.
## All shapes are drawn around a local origin that sits at the centre of the
## tile the object stands on.

const HALF_W := 32.0
const HALF_H := 16.0

static func diamond_points(scale: float = 1.0, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		offset + Vector2(-HALF_W * scale, 0),
		offset + Vector2(0, -HALF_H * scale),
		offset + Vector2(HALF_W * scale, 0),
		offset + Vector2(0, HALF_H * scale),
	])

## Flat diamond on the ground, e.g. range highlights.
static func tile(ci: CanvasItem, color: Color, scale: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
	ci.draw_colored_polygon(diamond_points(scale, offset), color)

static func tile_outline(ci: CanvasItem, color: Color, width: float = 2.0, scale: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
	var pts := diamond_points(scale, offset)
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	ci.draw_polyline(loop, color, width, true)

## An isometric box standing on the tile: `foot` is the footprint as a
## fraction of the tile, `height` is in pixels.
static func box(ci: CanvasItem, foot: float, height: float, top: Color, base_offset: Vector2 = Vector2.ZERO) -> void:
	var hw := HALF_W * foot
	var hh := HALF_H * foot
	var left_col := Color(top.r * 0.72, top.g * 0.72, top.b * 0.74)
	var right_col := Color(top.r * 0.5, top.g * 0.5, top.b * 0.54)
	var up := Vector2(0, -height)

	var l := base_offset + Vector2(-hw, 0)
	var t := base_offset + Vector2(0, -hh)
	var r := base_offset + Vector2(hw, 0)
	var b := base_offset + Vector2(0, hh)

	ci.draw_colored_polygon(PackedVector2Array([l, b, b + up, l + up]), left_col)
	ci.draw_colored_polygon(PackedVector2Array([b, r, r + up, b + up]), right_col)
	ci.draw_colored_polygon(PackedVector2Array([l + up, t + up, r + up, b + up]), top)

static func shadow(ci: CanvasItem, foot: float = 0.55, alpha: float = 0.3) -> void:
	ci.draw_colored_polygon(diamond_points(foot), Color(0, 0, 0, alpha))

## Upright billboard slab (lockers, chalkboards) facing the camera.
static func slab(ci: CanvasItem, width: float, height: float, color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var rect := Rect2(offset + Vector2(-width / 2.0, -height), Vector2(width, height))
	ci.draw_rect(rect, color)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.35, rect.size.y)), Color(1, 1, 1, 0.06))
	ci.draw_rect(rect, Color(0, 0, 0, 0.45), false, 1.5)
