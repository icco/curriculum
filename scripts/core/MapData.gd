class_name MapData
extends RefCounted

## The floor grid. Owns terrain, props, visibility and all spatial queries
## (line of sight, cover, reachability). Knows nothing about rendering.

enum Tile { VOID, FLOOR, WALL, DOOR, STAIRS }
enum Prop { NONE, DESK, CHAIR, BRAZIER, CHEST, BOOKSHELF, RUNE_SLATE, PODIUM }
enum Cover { NONE, HALF, THREE_QUARTERS }

## Waist-high props: they cost movement and grant half cover, but you can see
## and shoot over them.
const LOW_PROPS := [Prop.DESK, Prop.CHAIR, Prop.BRAZIER, Prop.PODIUM]
## Props taller than a person: three-quarters cover to anyone standing against
## them, and a hard sight blocker at any greater distance.
const TALL_PROPS := [Prop.CHEST, Prop.BOOKSHELF, Prop.RUNE_SLATE]

const DIRS_8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const DIRS_4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int = 0
var height: int = 0
var tiles: PackedByteArray = PackedByteArray()
var props: PackedByteArray = PackedByteArray()
var room_ids: PackedInt32Array = PackedInt32Array()  # -1 = corridor/void

var explored: PackedByteArray = PackedByteArray()
var visible_cells: PackedByteArray = PackedByteArray()

var rooms: Array = []            # Array[Dictionary] {rect, kind, id}
var doors: Dictionary = {}       # Vector2i -> {"open": bool, "locked": bool}
var containers: Dictionary = {}  # Vector2i -> {"looted": bool, "table": String}
var stairs_pos: Vector2i = Vector2i(-1, -1)
var entry_pos: Vector2i = Vector2i(-1, -1)

func setup(w: int, h: int) -> void:
	width = w
	height = h
	var count := w * h
	tiles = PackedByteArray()
	tiles.resize(count)
	tiles.fill(Tile.VOID)
	props = PackedByteArray()
	props.resize(count)
	props.fill(Prop.NONE)
	explored = PackedByteArray()
	explored.resize(count)
	visible_cells = PackedByteArray()
	visible_cells.resize(count)
	room_ids = PackedInt32Array()
	room_ids.resize(count)
	room_ids.fill(-1)

func idx(p: Vector2i) -> int:
	return p.y * width + p.x

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func tile_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return Tile.VOID
	return tiles[idx(p)]

func set_tile(p: Vector2i, t: int) -> void:
	if in_bounds(p):
		tiles[idx(p)] = t

func prop_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return Prop.NONE
	return props[idx(p)]

func set_prop(p: Vector2i, pr: int) -> void:
	if in_bounds(p):
		props[idx(p)] = pr

func room_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return -1
	return room_ids[idx(p)]

# ------------------------------------------------------------------ movement

## True if the terrain lets a creature stand here (ignores other creatures).
func is_walkable(p: Vector2i) -> bool:
	var t := tile_at(p)
	if t == Tile.VOID or t == Tile.WALL:
		return false
	if t == Tile.DOOR and not is_door_open(p):
		return false
	return prop_at(p) == Prop.NONE

func is_door_open(p: Vector2i) -> bool:
	var d: Dictionary = doors.get(p, {})
	return bool(d.get("open", false))

func open_door(p: Vector2i) -> bool:
	if not doors.has(p):
		return false
	var d: Dictionary = doors[p]
	if bool(d.get("locked", false)):
		return false
	d["open"] = true
	doors[p] = d
	return true

## A shut door that is not locked, so anything with hands can open it.
func is_openable_door(p: Vector2i) -> bool:
	if tile_at(p) != Tile.DOOR or is_door_open(p):
		return false
	return not bool((doors.get(p, {}) as Dictionary).get("locked", false))

func is_locked_door(p: Vector2i) -> bool:
	if tile_at(p) != Tile.DOOR or is_door_open(p):
		return false
	return bool((doors.get(p, {}) as Dictionary).get("locked", false))

## First shut door along `path`, or (-1, -1). What stands between an actor and
## where it wanted to go.
static func closed_door_on(map: MapData, path: Array) -> Vector2i:
	for cell: Vector2i in path:
		if map.is_openable_door(cell):
			return cell
	return Vector2i(-1, -1)

func close_door(p: Vector2i) -> bool:
	if not doors.has(p):
		return false
	var d: Dictionary = doors[p]
	d["open"] = false
	doors[p] = d
	return true

# ------------------------------------------------------------- line of sight

## True if the tile stops sight entirely for a viewer standing anywhere.
func blocks_sight(p: Vector2i) -> bool:
	var t := tile_at(p)
	if t == Tile.WALL or t == Tile.VOID:
		return true
	if t == Tile.DOOR and not is_door_open(p):
		return true
	return TALL_PROPS.has(prop_at(p))

## Integer Bresenham line, inclusive of both endpoints.
static func bresenham(from: Vector2i, to: Vector2i) -> Array:
	var points: Array = []
	var x0 := from.x
	var y0 := from.y
	var dx: int = absi(to.x - x0)
	var dy: int = -absi(to.y - y0)
	var sx: int = 1 if x0 < to.x else -1
	var sy: int = 1 if y0 < to.y else -1
	var err := dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == to.x and y0 == to.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points

## Can `from` see `to`? Tall props directly beside the target still allow the
## shot (that is what three-quarters cover models), anything else blocks.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	var line := bresenham(from, to)
	for i in range(1, line.size() - 1):
		var c: Vector2i = line[i]
		if blocks_sight(c) and not (TALL_PROPS.has(prop_at(c)) and chebyshev(c, to) <= 1):
			return false
	return true

## Cover the defender gains against an attack originating at `from`.
func cover_between(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return Cover.NONE
	var best := Cover.NONE
	var line := bresenham(from, to)
	for i in range(1, line.size() - 1):
		var c: Vector2i = line[i]
		var pr := prop_at(c)
		if TALL_PROPS.has(pr):
			best = maxi(best, Cover.THREE_QUARTERS)
		elif LOW_PROPS.has(pr):
			best = maxi(best, Cover.HALF)
		elif tile_at(c) == Tile.DOOR and is_door_open(c):
			best = maxi(best, Cover.HALF)
	return best

static func cover_bonus(cover: int) -> int:
	match cover:
		Cover.HALF: return 2
		Cover.THREE_QUARTERS: return 5
		_: return 0

static func cover_name(cover: int) -> String:
	match cover:
		Cover.HALF: return "half cover"
		Cover.THREE_QUARTERS: return "three-quarters cover"
		_: return ""

static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# ------------------------------------------------------------- fog of war

func recompute_fov(origin: Vector2i, radius: int) -> void:
	visible_cells.fill(0)
	if not in_bounds(origin):
		return
	for y in range(maxi(0, origin.y - radius), mini(height, origin.y + radius + 1)):
		for x in range(maxi(0, origin.x - radius), mini(width, origin.x + radius + 1)):
			var p := Vector2i(x, y)
			if chebyshev(p, origin) > radius:
				continue
			if _visible_from(origin, p):
				var i := idx(p)
				visible_cells[i] = 1
				explored[i] = 1

## Sight for fog purposes: a wall you can draw an unobstructed line to is lit,
## so room edges do not read as holes.
func _visible_from(origin: Vector2i, target: Vector2i) -> bool:
	if origin == target:
		return true
	var line := bresenham(origin, target)
	for i in range(1, line.size() - 1):
		if blocks_sight(line[i]):
			return false
	return true

func is_visible(p: Vector2i) -> bool:
	return in_bounds(p) and visible_cells[idx(p)] == 1

func is_explored(p: Vector2i) -> bool:
	return in_bounds(p) and explored[idx(p)] == 1

# ----------------------------------------------------------- reachability

## Dijkstra/BFS flood fill from `origin` limited to `budget` steps.
## `blocked` is a Dictionary of Vector2i -> true for occupied tiles.
## Returns {cost: {Vector2i:int}, came_from: {Vector2i:Vector2i}}.
func flood_fill(origin: Vector2i, budget: int, blocked: Dictionary = {}) -> Dictionary:
	var cost: Dictionary = {origin: 0}
	var came_from: Dictionary = {}
	var frontier: Array = [origin]
	var head := 0
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		var cur_cost: int = cost[cur]
		if cur_cost >= budget:
			continue
		for dir: Vector2i in DIRS_8:
			var nxt: Vector2i = cur + dir
			if cost.has(nxt) or blocked.has(nxt) or not is_walkable(nxt):
				continue
			if dir.x != 0 and dir.y != 0:
				# No squeezing diagonally between two blocked tiles.
				var a := Vector2i(cur.x + dir.x, cur.y)
				var b := Vector2i(cur.x, cur.y + dir.y)
				if not is_walkable(a) or not is_walkable(b):
					continue
				if blocked.has(a) and blocked.has(b):
					continue
			cost[nxt] = cur_cost + 1
			came_from[nxt] = cur
			frontier.append(nxt)
	return {"cost": cost, "came_from": came_from}

static func reconstruct_path(came_from: Dictionary, target: Vector2i) -> Array:
	var path: Array = [target]
	var cur := target
	while came_from.has(cur):
		cur = came_from[cur]
		path.push_front(cur)
	return path

## Shortest path from -> to ignoring a step budget. Returns [] when unreachable.
## `to` may itself be blocked when `allow_blocked_goal` is set (used to walk up
## to an enemy rather than onto it).
## `through_doors` lets the path run through closed but unlocked doors, for
## actors that can open one. The door still costs them a turn to open, so the
## caller has to notice it is there — see closed_door_on().
func find_path(from: Vector2i, to: Vector2i, blocked: Dictionary = {},
		allow_blocked_goal: bool = false, through_doors: bool = false) -> Array:
	if from == to:
		return [from]
	var goal_blocked: bool = blocked.has(to) or not is_walkable(to)
	if goal_blocked and not allow_blocked_goal:
		return []
	var frontier: Array = [from]
	var head := 0
	var came_from: Dictionary = {}
	var seen: Dictionary = {from: true}
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		if cur == to:
			return reconstruct_path(came_from, to)
		for dir: Vector2i in DIRS_8:
			var nxt: Vector2i = cur + dir
			if seen.has(nxt):
				continue
			var passable: bool = is_walkable(nxt) and not blocked.has(nxt)
			if through_doors and not passable and not blocked.has(nxt) and is_openable_door(nxt):
				passable = true
			if not passable and not (nxt == to and allow_blocked_goal):
				continue
			if dir.x != 0 and dir.y != 0:
				var a := Vector2i(cur.x + dir.x, cur.y)
				var b := Vector2i(cur.x, cur.y + dir.y)
				var corner_ok: bool = is_walkable(a) or (through_doors and is_openable_door(a))
				corner_ok = corner_ok and (is_walkable(b) or (through_doors and is_openable_door(b)))
				if not corner_ok:
					continue
			seen[nxt] = true
			came_from[nxt] = cur
			frontier.append(nxt)
	return []

## Any free tile inside a room, used for spawning.
func random_floor_in_room(room: Dictionary, blocked: Dictionary = {}) -> Vector2i:
	var rect: Rect2i = room["rect"]
	for attempt in 60:
		var p := Vector2i(
			Dice.range_i(rect.position.x, rect.end.x - 1),
			Dice.range_i(rect.position.y, rect.end.y - 1)
		)
		if is_walkable(p) and not blocked.has(p):
			return p
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if is_walkable(p) and not blocked.has(p):
				return p
	return Vector2i(-1, -1)
