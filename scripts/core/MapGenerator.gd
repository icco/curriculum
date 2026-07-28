class_name MapGenerator
extends RefCounted

## NetHack-flavoured floor plan generator dressed up as an academy wing:
## rejection-sampled rectangular rooms joined by one-tile hallways, then
## furnished with cover props, warded chests, doors and a stairwell.

const ROOM_KINDS := {
	"lecture_hall": {"label": "Lecture Hall", "weight": 4.0, "min": Vector2i(6, 5), "max": Vector2i(11, 8)},
	"alchemy_lab": {"label": "Alchemy Laboratory", "weight": 2.0, "min": Vector2i(7, 6), "max": Vector2i(11, 9)},
	"scriptorium": {"label": "Scriptorium", "weight": 1.5, "min": Vector2i(8, 7), "max": Vector2i(13, 10)},
	"refectory": {"label": "Refectory", "weight": 1.0, "min": Vector2i(9, 8), "max": Vector2i(14, 11)},
	"training_yard": {"label": "Training Yard", "weight": 1.0, "min": Vector2i(10, 8), "max": Vector2i(14, 11)},
	"vault_row": {"label": "Vault Row", "weight": 2.0, "min": Vector2i(5, 4), "max": Vector2i(9, 7)},
	"proctors_study": {"label": "Proctor's Study", "weight": 1.5, "min": Vector2i(5, 4), "max": Vector2i(8, 6)},
}

var width: int = 46
var height: int = 46
var max_rooms: int = 11
var depth: int = 1

## Returns {map: MapData, spawns: Array, rooms: Array}
func generate(floor_depth: int, w: int = 46, h: int = 46) -> Dictionary:
	depth = floor_depth
	width = w
	height = h

	var map := MapData.new()
	map.setup(width, height)

	_place_rooms(map)
	_carve_corridors(map)
	_raise_walls(map)
	_place_doors(map)
	_furnish(map)

	var entry := _choose_entry(map)
	map.entry_pos = entry

	var reach: Dictionary = map.flood_fill(entry, width * height).cost
	_place_stairs(map, entry, reach)

	var spawns := _plan_spawns(map, entry, reach)
	return {"map": map, "spawns": spawns, "rooms": map.rooms}

# ---------------------------------------------------------------- rooms

func _place_rooms(map: MapData) -> void:
	var kind_weights: Dictionary = {}
	for k: String in ROOM_KINDS:
		kind_weights[k] = ROOM_KINDS[k]["weight"]

	var attempts := 0
	while map.rooms.size() < max_rooms and attempts < 300:
		attempts += 1
		var kind: String = Dice.weighted(kind_weights)
		var spec: Dictionary = ROOM_KINDS[kind]
		var min_size: Vector2i = spec["min"]
		var max_size: Vector2i = spec["max"]
		var rw: int = Dice.range_i(min_size.x, max_size.x)
		var rh: int = Dice.range_i(min_size.y, max_size.y)
		if rw + 4 >= width or rh + 4 >= height:
			continue
		var rx: int = Dice.range_i(2, width - rw - 3)
		var ry: int = Dice.range_i(2, height - rh - 3)
		var rect := Rect2i(rx, ry, rw, rh)
		if _overlaps(map, rect):
			continue
		var id: int = map.rooms.size()
		map.rooms.append({"rect": rect, "kind": kind, "label": spec["label"], "id": id})
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var p := Vector2i(x, y)
				map.set_tile(p, MapData.Tile.FLOOR)
				map.room_ids[map.idx(p)] = id

func _overlaps(map: MapData, rect: Rect2i) -> bool:
	# Grow by 2 so neighbouring rooms always have a wall (and ideally a hallway)
	# between them.
	var padded := rect.grow(2)
	for room: Dictionary in map.rooms:
		if padded.intersects(room["rect"] as Rect2i):
			return true
	return false

# ------------------------------------------------------------- corridors

func _carve_corridors(map: MapData) -> void:
	if map.rooms.size() < 2:
		return
	var order: Array = map.rooms.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = (a["rect"] as Rect2i).get_center()
		var cb: Vector2i = (b["rect"] as Rect2i).get_center()
		return ca.x + ca.y < cb.x + cb.y)

	for i in range(order.size() - 1):
		_connect(map, order[i], order[i + 1])

	# A couple of loops so the floor is not a pure tree; better tactics.
	var extra: int = 1 + int(map.rooms.size() / 5)
	for i in extra:
		var a: Dictionary = Dice.pick(map.rooms)
		var b: Dictionary = Dice.pick(map.rooms)
		if a["id"] != b["id"]:
			_connect(map, a, b)

func _connect(map: MapData, room_a: Dictionary, room_b: Dictionary) -> void:
	var a: Vector2i = (room_a["rect"] as Rect2i).get_center()
	var b: Vector2i = (room_b["rect"] as Rect2i).get_center()
	if Dice.chance(0.5):
		_carve_h(map, a.x, b.x, a.y)
		_carve_v(map, a.y, b.y, b.x)
	else:
		_carve_v(map, a.y, b.y, a.x)
		_carve_h(map, a.x, b.x, b.y)

func _carve_h(map: MapData, x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		_carve(map, Vector2i(x, y))

func _carve_v(map: MapData, y0: int, y1: int, x: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		_carve(map, Vector2i(x, y))

func _carve(map: MapData, p: Vector2i) -> void:
	if not map.in_bounds(p):
		return
	if map.tile_at(p) == MapData.Tile.VOID:
		map.set_tile(p, MapData.Tile.FLOOR)

# ------------------------------------------------------------- walls/doors

func _raise_walls(map: MapData) -> void:
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if map.tile_at(p) != MapData.Tile.VOID:
				continue
			for dir: Vector2i in MapData.DIRS_8:
				if map.tile_at(p + dir) == MapData.Tile.FLOOR:
					map.set_tile(p, MapData.Tile.WALL)
					break

func _place_doors(map: MapData) -> void:
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if map.tile_at(p) != MapData.Tile.FLOOR or map.room_at(p) != -1:
				continue
			# A corridor tile touching a room interior is that room's threshold.
			var touching := -1
			var touch_count := 0
			for dir: Vector2i in MapData.DIRS_4:
				var r := map.room_at(p + dir)
				if r != -1 and map.tile_at(p + dir) == MapData.Tile.FLOOR:
					touching = r
					touch_count += 1
			if touching == -1 or touch_count > 1:
				continue
			map.set_tile(p, MapData.Tile.DOOR)
			var locked: bool = Dice.chance(0.06 + 0.01 * depth)
			map.doors[p] = {"open": Dice.chance(0.55) and not locked, "locked": locked}

# ---------------------------------------------------------------- furniture

func _furnish(map: MapData) -> void:
	for room: Dictionary in map.rooms:
		match str(room["kind"]):
			"lecture_hall": _furnish_lecture_hall(map, room)
			"alchemy_lab": _furnish_alchemy_lab(map, room)
			"scriptorium": _furnish_scriptorium(map, room)
			"refectory": _furnish_refectory(map, room)
			"training_yard": _furnish_training_yard(map, room)
			"vault_row": _furnish_chests(map, room)
			"proctors_study": _furnish_study(map, room)
	_scatter_hall_props(map)
	_clear_thresholds(map)

## Tiles beside a doorway must stay clear or floors can pinch shut.
func _clear_thresholds(map: MapData) -> void:
	for p: Vector2i in map.doors:
		map.set_prop(p, MapData.Prop.NONE)
		for dir: Vector2i in MapData.DIRS_8:
			map.set_prop(p + dir, MapData.Prop.NONE)

func _try_prop(map: MapData, p: Vector2i, prop: int) -> void:
	if map.tile_at(p) != MapData.Tile.FLOOR:
		return
	if map.prop_at(p) != MapData.Prop.NONE:
		return
	map.set_prop(p, prop)

func _furnish_lecture_hall(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	# Desks in rows with an aisle, chalkboard on the north wall.
	for y in range(rect.position.y + 1, rect.end.y - 1, 2):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			if (x - rect.position.x) % 3 == 0:
				continue
			if Dice.chance(0.82):
				_try_prop(map, Vector2i(x, y), MapData.Prop.DESK)
	for x in range(rect.position.x + 1, rect.end.x - 1):
		if Dice.chance(0.5):
			_try_prop(map, Vector2i(x, rect.position.y), MapData.Prop.RUNE_SLATE)
	_try_prop(map, Vector2i(rect.position.x + 1, rect.position.y + 1), MapData.Prop.PODIUM)

func _furnish_alchemy_lab(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	for y in range(rect.position.y + 1, rect.end.y - 1, 3):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			if Dice.chance(0.7):
				_try_prop(map, Vector2i(x, y), MapData.Prop.DESK)
	for i in 3:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.BOOKSHELF)
	_try_prop(map, map.random_floor_in_room(room), MapData.Prop.CHEST)

func _furnish_scriptorium(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	for x in range(rect.position.x + 1, rect.end.x - 1, 2):
		for y in range(rect.position.y + 1, rect.end.y - 2):
			if Dice.chance(0.75):
				_try_prop(map, Vector2i(x, y), MapData.Prop.BOOKSHELF)
	for i in 4:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.CHAIR)

func _furnish_refectory(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	for y in range(rect.position.y + 2, rect.end.y - 1, 3):
		for x in range(rect.position.x + 2, rect.end.x - 2):
			if Dice.chance(0.8):
				_try_prop(map, Vector2i(x, y), MapData.Prop.DESK)
	for i in 3:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.BRAZIER)

func _furnish_training_yard(map: MapData, room: Dictionary) -> void:
	for i in 5:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.CHAIR)
	for i in 2:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.CHEST)

func _furnish_chests(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	for x in range(rect.position.x, rect.end.x):
		if Dice.chance(0.7):
			_try_prop(map, Vector2i(x, rect.position.y), MapData.Prop.CHEST)
		if Dice.chance(0.7):
			_try_prop(map, Vector2i(x, rect.end.y - 1), MapData.Prop.CHEST)

func _furnish_study(map: MapData, room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	_try_prop(map, rect.position, MapData.Prop.DESK)
	_try_prop(map, Vector2i(rect.end.x - 1, rect.position.y), MapData.Prop.BOOKSHELF)
	_try_prop(map, Vector2i(rect.position.x, rect.end.y - 1), MapData.Prop.CHEST)
	for i in 2:
		_try_prop(map, map.random_floor_in_room(room), MapData.Prop.CHAIR)

## Lockers and bins line the hallways too, giving cover in the open.
func _scatter_hall_props(map: MapData) -> void:
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if map.tile_at(p) != MapData.Tile.FLOOR or map.room_at(p) != -1:
				continue
			var wall_neighbors := 0
			for dir: Vector2i in MapData.DIRS_4:
				if map.tile_at(p + dir) == MapData.Tile.WALL:
					wall_neighbors += 1
			# Only decorate wide spots, never pinch a one-tile hallway shut.
			if wall_neighbors >= 2:
				continue
			if Dice.chance(0.03):
				_try_prop(map, p, MapData.Prop.CHEST)
			elif Dice.chance(0.03):
				_try_prop(map, p, MapData.Prop.BRAZIER)

# ---------------------------------------------------------------- placement

func _choose_entry(map: MapData) -> Vector2i:
	if map.rooms.is_empty():
		return Vector2i(width / 2, height / 2)
	var room: Dictionary = map.rooms[0]
	var p: Vector2i = map.random_floor_in_room(room)
	if p == Vector2i(-1, -1):
		for y in height:
			for x in width:
				if map.is_walkable(Vector2i(x, y)):
					return Vector2i(x, y)
	return p

func _place_stairs(map: MapData, entry: Vector2i, reach: Dictionary) -> void:
	var best := Vector2i(-1, -1)
	var best_dist := -1
	for cell: Vector2i in reach:
		if cell == entry:
			continue
		if map.room_at(cell) == -1:
			continue
		var d: int = reach[cell]
		if d > best_dist:
			best_dist = d
			best = cell
	if best == Vector2i(-1, -1):
		for cell: Vector2i in reach:
			best = cell
			break
	map.stairs_pos = best
	map.set_tile(best, MapData.Tile.STAIRS)

## Decides what lives where. Returns descriptors, not Entities, so the caller
## owns roster construction.
func _plan_spawns(map: MapData, entry: Vector2i, reach: Dictionary) -> Array:
	var spawns: Array = []
	var taken: Dictionary = {entry: true, map.stairs_pos: true}

	# Installing lockers can occupy floor tiles, so reachability is recomputed
	# before anything is placed on the grid.
	_place_containers(map, reach)
	reach = map.flood_fill(entry, width * height)["cost"]

	# Boss teacher guards the stairwell.
	var boss_pos: Vector2i = _free_near(map, map.stairs_pos, reach, taken)
	if boss_pos != Vector2i(-1, -1):
		spawns.append({"pos": boss_pos, "role": "boss", "room": map.room_at(boss_pos)})
		taken[boss_pos] = true

	# One shuffled pool of reachable tiles, preferring rooms away from the entry.
	# Later tiers are fallbacks so cramped floors still fill their roster.
	var far_pool: Array = []
	var near_pool: Array = []
	var last_resort: Array = []
	for cell: Vector2i in reach:
		if taken.has(cell):
			continue
		var d: int = MapData.chebyshev(cell, entry)
		if map.room_at(cell) != -1 and d >= 8:
			far_pool.append(cell)
		elif map.room_at(cell) != -1 and d >= 4:
			near_pool.append(cell)
		elif d >= 3:
			last_resort.append(cell)
	var pool: Array = Dice.shuffled(far_pool)
	pool.append_array(Dice.shuffled(near_pool))
	pool.append_array(Dice.shuffled(last_resort))

	# One student against a whole wing: keep the crowd survivable.
	var grunt_budget: int = 2 + int(depth * 0.8)
	var elite_budget: int = int(depth / 3.0) + (1 if depth >= 3 else 0)
	var cursor := 0
	for role: String in ["grunt", "elite"]:
		var budget: int = grunt_budget if role == "grunt" else elite_budget
		for i in budget:
			if cursor >= pool.size():
				break
			var p: Vector2i = pool[cursor]
			cursor += 1
			taken[p] = true
			spawns.append({"pos": p, "role": role, "room": map.room_at(p)})

	return spawns

## Turns lockers into lootable containers, adding a few if the floor plan did
## not produce enough. Any locker we add is validated so it cannot wall off
## part of the map.
func _place_containers(map: MapData, reach: Dictionary) -> void:
	var loot_target: int = clampi(2 + int(depth / 2), 3, 6)
	var locker_cells: Array = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if map.prop_at(p) == MapData.Prop.CHEST and _adjacent_reachable(map, p, reach):
				locker_cells.append(p)

	for p: Vector2i in Dice.shuffled(locker_cells).slice(0, loot_target):
		map.containers[p] = {"looted": false, "table": "locker"}

	if map.containers.size() >= loot_target:
		return

	# Short on lockers: install some against room walls.
	var candidates: Array = []
	for cell: Vector2i in reach:
		if map.room_at(cell) == -1 or cell == map.entry_pos or cell == map.stairs_pos:
			continue
		if map.doors.has(cell):
			continue
		var wall_neighbors := 0
		for dir: Vector2i in MapData.DIRS_4:
			if map.tile_at(cell + dir) == MapData.Tile.WALL:
				wall_neighbors += 1
		if wall_neighbors >= 1:
			candidates.append(cell)

	var baseline: int = reach.size()
	for p: Vector2i in Dice.shuffled(candidates):
		if map.containers.size() >= loot_target:
			break
		map.set_prop(p, MapData.Prop.CHEST)
		var after: Dictionary = map.flood_fill(map.entry_pos, width * height)["cost"]
		if after.size() < baseline - 1:
			map.set_prop(p, MapData.Prop.NONE)  # would have sealed something off
			continue
		baseline = after.size()
		map.containers[p] = {"looted": false, "table": "locker"}

func _adjacent_reachable(map: MapData, p: Vector2i, reach: Dictionary) -> bool:
	for dir: Vector2i in MapData.DIRS_8:
		if reach.has(p + dir):
			return true
	return false

## Close enough to guard the stairwell, far enough to slip past.
const BOSS_MIN_DISTANCE := 3
const BOSS_MAX_DISTANCE := 6

func _free_near(map: MapData, origin: Vector2i, reach: Dictionary, taken: Dictionary) -> Vector2i:
	var in_band: Array = []
	var fallback := Vector2i(-1, -1)
	var fallback_d := 999
	for cell: Vector2i in reach:
		if taken.has(cell):
			continue
		var d: int = MapData.chebyshev(cell, origin)
		if d >= BOSS_MIN_DISTANCE and d <= BOSS_MAX_DISTANCE:
			in_band.append(cell)
		elif d > 0 and d < fallback_d:
			fallback_d = d
			fallback = cell
	if in_band.is_empty():
		return fallback
	# Prefer a spot in the stairwell's own room so the guard reads as deliberate.
	var same_room: Array = []
	var room := map.room_at(origin)
	for cell: Vector2i in in_band:
		if map.room_at(cell) == room:
			same_room.append(cell)
	return Dice.pick(same_room if not same_room.is_empty() else in_band)
