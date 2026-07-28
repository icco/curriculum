extends "res://tests/TestCase.gd"

func _open_room(w: int = 12, h: int = 12) -> MapData:
	var m := MapData.new()
	m.setup(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			m.set_tile(Vector2i(x, y), MapData.Tile.FLOOR)
	for x in w:
		m.set_tile(Vector2i(x, 0), MapData.Tile.WALL)
		m.set_tile(Vector2i(x, h - 1), MapData.Tile.WALL)
	for y in h:
		m.set_tile(Vector2i(0, y), MapData.Tile.WALL)
		m.set_tile(Vector2i(w - 1, y), MapData.Tile.WALL)
	return m

func test_bounds_and_tiles() -> void:
	var m := _open_room()
	truthy(m.in_bounds(Vector2i(0, 0)), "origin in bounds")
	falsy(m.in_bounds(Vector2i(-1, 3)), "negative out of bounds")
	falsy(m.in_bounds(Vector2i(12, 3)), "past width out of bounds")
	eq(m.tile_at(Vector2i(99, 99)), MapData.Tile.VOID, "out of bounds reads as void")
	truthy(m.is_walkable(Vector2i(5, 5)), "floor is walkable")
	falsy(m.is_walkable(Vector2i(0, 5)), "wall is not walkable")

func test_props_block_movement() -> void:
	var m := _open_room()
	m.set_prop(Vector2i(4, 4), MapData.Prop.DESK)
	falsy(m.is_walkable(Vector2i(4, 4)), "desk blocks the tile")
	m.set_prop(Vector2i(4, 4), MapData.Prop.NONE)
	truthy(m.is_walkable(Vector2i(4, 4)), "cleared tile walkable again")

func test_bresenham_endpoints_and_continuity() -> void:
	var line := MapData.bresenham(Vector2i(1, 1), Vector2i(6, 4))
	eq(line[0], Vector2i(1, 1), "starts at origin")
	eq(line[-1], Vector2i(6, 4), "ends at target")
	for i in range(1, line.size()):
		var step: Vector2i = line[i] - line[i - 1]
		truthy(absi(step.x) <= 1 and absi(step.y) <= 1, "steps are contiguous")
	eq(MapData.bresenham(Vector2i(3, 3), Vector2i(3, 3)).size(), 1, "degenerate line")

func test_line_of_sight_blocked_by_wall() -> void:
	var m := _open_room()
	for y in range(1, 11):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	falsy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(9, 5)), "wall blocks sight")
	truthy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(4, 5)), "clear side is visible")

func test_low_props_grant_half_cover_without_blocking() -> void:
	var m := _open_room()
	m.set_prop(Vector2i(5, 5), MapData.Prop.DESK)
	truthy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(8, 5)), "you can shoot over a desk")
	eq(m.cover_between(Vector2i(2, 5), Vector2i(8, 5)), MapData.Cover.HALF, "desk = half cover")
	eq(MapData.cover_bonus(MapData.Cover.HALF), 2, "half cover is +2")

func test_tall_props_give_three_quarters_when_hugged() -> void:
	var m := _open_room()
	m.set_prop(Vector2i(7, 5), MapData.Prop.CHEST)
	# Locker sits directly in front of the defender at (8,5).
	truthy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(8, 5)), "adjacent locker still allows the shot")
	eq(m.cover_between(Vector2i(2, 5), Vector2i(8, 5)), MapData.Cover.THREE_QUARTERS, "locker = 3/4 cover")
	eq(MapData.cover_bonus(MapData.Cover.THREE_QUARTERS), 5, "3/4 cover is +5")
	# The same locker far from the defender blocks the shot entirely.
	falsy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(10, 5)), "distant locker blocks sight")

func test_doors_gate_movement_and_sight() -> void:
	var m := _open_room()
	var d := Vector2i(6, 5)
	for y in range(1, 11):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	m.set_tile(d, MapData.Tile.DOOR)
	m.doors[d] = {"open": false, "locked": false}
	falsy(m.is_walkable(d), "closed door blocks movement")
	falsy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(9, 5)), "closed door blocks sight")
	truthy(m.open_door(d), "door opens")
	truthy(m.is_walkable(d), "open door is walkable")
	truthy(m.has_line_of_sight(Vector2i(2, 5), Vector2i(9, 5)), "open door lets sight through")

	m.doors[d] = {"open": false, "locked": true}
	falsy(m.open_door(d), "locked door refuses to open")

func test_flood_fill_respects_budget() -> void:
	var m := _open_room(20, 20)
	var result := m.flood_fill(Vector2i(10, 10), 3)
	var cost: Dictionary = result["cost"]
	truthy(cost.has(Vector2i(13, 10)), "3 tiles away is reachable")
	falsy(cost.has(Vector2i(14, 10)), "4 tiles away is out of budget")
	eq(cost[Vector2i(13, 13)], 3, "diagonals cost one step")

func test_flood_fill_avoids_occupied_tiles() -> void:
	var m := _open_room()
	var blocked := {Vector2i(6, 5): true}
	var cost: Dictionary = m.flood_fill(Vector2i(5, 5), 1, blocked)["cost"]
	falsy(cost.has(Vector2i(6, 5)), "cannot stand on an occupied tile")

func test_path_reconstruction() -> void:
	var m := _open_room(20, 20)
	var path := m.find_path(Vector2i(2, 2), Vector2i(9, 6))
	truthy(path.size() > 0, "path exists in an open room")
	eq(path[0], Vector2i(2, 2), "path starts at origin")
	eq(path[-1], Vector2i(9, 6), "path ends at target")
	for i in range(1, path.size()):
		truthy(MapData.chebyshev(path[i], path[i - 1]) == 1, "path steps are adjacent")
		truthy(m.is_walkable(path[i]), "path stays on walkable ground")

func test_path_to_blocked_goal_requires_opt_in() -> void:
	var m := _open_room()
	var blocked := {Vector2i(8, 5): true}
	eq(m.find_path(Vector2i(2, 5), Vector2i(8, 5), blocked).size(), 0, "blocked goal is unreachable")
	var allowed := m.find_path(Vector2i(2, 5), Vector2i(8, 5), blocked, true)
	truthy(allowed.size() > 0, "opt-in reaches an occupied goal for attacking")

func test_unreachable_returns_empty() -> void:
	var m := _open_room()
	for y in range(0, 12):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	eq(m.find_path(Vector2i(2, 5), Vector2i(9, 5)).size(), 0, "sealed rooms have no path")

func test_fov_marks_visible_and_explored() -> void:
	var m := _open_room(20, 20)
	for y in range(1, 19):
		m.set_tile(Vector2i(10, y), MapData.Tile.WALL)
	m.recompute_fov(Vector2i(5, 10), 8)
	truthy(m.is_visible(Vector2i(7, 10)), "near open tile visible")
	falsy(m.is_visible(Vector2i(14, 10)), "behind the wall is hidden")
	truthy(m.is_explored(Vector2i(7, 10)), "seen tiles become explored")
	m.recompute_fov(Vector2i(2, 2), 3)
	falsy(m.is_visible(Vector2i(7, 10)), "no longer in sight")
	truthy(m.is_explored(Vector2i(7, 10)), "but stays explored")

## The doorway cases the basic door test does not reach: standing in one, and a
## lock being distinguishable from a plain shut door.
func test_standing_in_an_open_doorway_sees_both_sides() -> void:
	var m := MapData.new()
	m.setup(12, 12)
	for x in range(1, 11):
		m.set_tile(Vector2i(x, 5), MapData.Tile.FLOOR)
	for y in range(1, 11):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	var d := Vector2i(6, 5)
	m.set_tile(d, MapData.Tile.DOOR)
	m.doors[d] = {"open": true, "locked": false}
	truthy(m.has_line_of_sight(d, Vector2i(2, 5)), "sees back the way it came")
	truthy(m.has_line_of_sight(d, Vector2i(9, 5)), "and through to the far side")

func test_a_lock_is_not_just_a_shut_door() -> void:
	var m := MapData.new()
	m.setup(8, 8)
	m.set_tile(Vector2i(4, 4), MapData.Tile.DOOR)
	m.doors[Vector2i(4, 4)] = {"open": false, "locked": false}
	truthy(m.is_openable_door(Vector2i(4, 4)), "a shut door can be opened")
	falsy(m.is_locked_door(Vector2i(4, 4)), "and is not locked")
	m.doors[Vector2i(4, 4)]["locked"] = true
	falsy(m.is_openable_door(Vector2i(4, 4)), "a locked door cannot just be opened")
	truthy(m.is_locked_door(Vector2i(4, 4)), "and reports as locked")
	m.doors[Vector2i(4, 4)] = {"open": true, "locked": true}
	falsy(m.is_locked_door(Vector2i(4, 4)), "an open door is not a lock in the way")

func test_pathing_can_be_told_to_route_through_shut_doors() -> void:
	# What lets an enemy plan to open a door instead of giving up.
	var m := MapData.new()
	m.setup(12, 12)
	for x in range(1, 11):
		m.set_tile(Vector2i(x, 5), MapData.Tile.FLOOR)
	for y in range(1, 11):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	var d := Vector2i(6, 5)
	m.set_tile(d, MapData.Tile.DOOR)
	m.doors[d] = {"open": false, "locked": false}
	truthy(m.find_path(Vector2i(2, 5), Vector2i(9, 5)).is_empty(), "normally there is no way through")
	var through: Array = m.find_path(Vector2i(2, 5), Vector2i(9, 5), {}, false, true)
	truthy(not through.is_empty(), "with through_doors there is a route")
	eq(MapData.closed_door_on(m, through), d, "and the door on it is found")
	m.doors[d]["locked"] = true
	truthy(m.find_path(Vector2i(2, 5), Vector2i(9, 5), {}, false, true).is_empty(),
		"a locked door is still a wall to pathing")
