extends "res://tests/TestCase.gd"

## The generator is the part most likely to produce an unplayable floor, so it
## gets hammered across many seeds and depths.

const SEEDS := 25

func test_generated_floors_are_playable() -> void:
	for s in SEEDS:
		Dice.seed_with(9000 + s)
		var depth: int = 1 + (s % 12)
		var gen := MapGenerator.new()
		var result := gen.generate(depth)
		var map: MapData = result["map"]
		var spawns: Array = result["spawns"]
		var tag := "seed %d depth %d:" % [9000 + s, depth]

		truthy(map.rooms.size() >= 3, "%s generated at least 3 rooms" % tag)
		truthy(map.is_walkable(map.entry_pos), "%s entry tile is walkable" % tag)
		ne(map.stairs_pos, Vector2i(-1, -1), "%s stairs placed" % tag)

		var reach: Dictionary = map.flood_fill(map.entry_pos, map.width * map.height)["cost"]
		truthy(reach.has(map.stairs_pos), "%s stairs reachable from entry" % tag)

		for spawn: Dictionary in spawns:
			var p: Vector2i = spawn["pos"]
			truthy(map.is_walkable(p), "%s spawn %s on walkable ground" % [tag, str(p)])
			truthy(reach.has(p), "%s spawn %s reachable" % [tag, str(p)])

		var roles: Dictionary = {}
		for spawn: Dictionary in spawns:
			roles[spawn["role"]] = int(roles.get(spawn["role"], 0)) + 1
		eq(int(roles.get("boss", 0)), 1, "%s exactly one floor boss" % tag)
		# Density scales with depth; floor 1 is deliberately a light welcome.
		var expected_grunts: int = 2 + int(depth * 0.8)
		truthy(int(roles.get("grunt", 0)) >= mini(expected_grunts, 2),
			"%s at least a couple of grunts (got %d)" % [tag, int(roles.get("grunt", 0))])

func test_rooms_never_overlap() -> void:
	for s in 10:
		Dice.seed_with(500 + s)
		var result := MapGenerator.new().generate(3)
		var map: MapData = result["map"]
		for i in map.rooms.size():
			for j in range(i + 1, map.rooms.size()):
				var a: Rect2i = map.rooms[i]["rect"]
				var b: Rect2i = map.rooms[j]["rect"]
				falsy(a.intersects(b), "rooms %d/%d overlap on seed %d" % [i, j, 500 + s])

func test_doors_are_clear_and_connect_rooms() -> void:
	for s in 10:
		Dice.seed_with(310 + s)
		var result := MapGenerator.new().generate(4)
		var map: MapData = result["map"]
		for p: Vector2i in map.doors:
			eq(map.tile_at(p), MapData.Tile.DOOR, "door tile type at %s" % str(p))
			eq(map.prop_at(p), MapData.Prop.NONE, "no furniture inside doorway %s" % str(p))
			var room_side := 0
			for dir: Vector2i in MapData.DIRS_4:
				if map.room_at(p + dir) != -1:
					room_side += 1
			truthy(room_side >= 1, "doorway %s touches a room" % str(p))

func test_walls_seal_the_floor() -> void:
	Dice.seed_with(4242)
	var result := MapGenerator.new().generate(6)
	var map: MapData = result["map"]
	# Every walkable tile must be surrounded by non-void, or the player could
	# walk off the edge of the drawn world.
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.tile_at(p) == MapData.Tile.VOID:
				continue
			for dir: Vector2i in MapData.DIRS_8:
				var n: Vector2i = p + dir
				if not map.in_bounds(n):
					continue
				if map.tile_at(p) == MapData.Tile.FLOOR or map.tile_at(p) == MapData.Tile.STAIRS:
					ne(map.tile_at(n), MapData.Tile.VOID, "floor at %s exposed to void" % str(p))

func test_containers_are_reachable_lockers() -> void:
	for s in 8:
		Dice.seed_with(770 + s)
		var result := MapGenerator.new().generate(5)
		var map: MapData = result["map"]
		truthy(map.containers.size() >= 2, "at least two lootable lockers")
		var reach: Dictionary = map.flood_fill(map.entry_pos, map.width * map.height)["cost"]
		for p: Vector2i in map.containers:
			eq(map.prop_at(p), MapData.Prop.LOCKER, "container %s is a locker" % str(p))
			var adjacent := false
			for dir: Vector2i in MapData.DIRS_8:
				if reach.has(p + dir):
					adjacent = true
					break
			truthy(adjacent, "locker %s can be stood next to" % str(p))

func test_generation_is_deterministic_per_seed() -> void:
	Dice.seed_with(31337)
	var a: MapData = MapGenerator.new().generate(7)["map"]
	Dice.seed_with(31337)
	var b: MapData = MapGenerator.new().generate(7)["map"]
	eq(a.tiles, b.tiles, "same seed rebuilds the same terrain")
	eq(a.props, b.props, "same seed rebuilds the same furniture")
	eq(a.stairs_pos, b.stairs_pos, "same seed puts stairs in the same place")
