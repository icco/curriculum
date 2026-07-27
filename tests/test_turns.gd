extends "res://tests/TestCase.gd"

func before_each() -> void:
	Dice.seed_with(5150)

func _make(name: String, team: int, pos: Vector2i, dex: int = 12) -> Entity:
	var e := Entity.new()
	e.display_name = name
	e.team = team
	e.grid_pos = pos
	e.stats = {"str": 14, "dex": dex, "con": 12, "int": 10, "wis": 10, "cha": 10}
	e.ac_base = 10
	e.max_hp = 30
	e.current_hp = 30
	e.speed_tiles = 6
	e.proficiency = 2
	e.attack_ability = "str"
	e.damage_dice = "1d6"
	e.attack_range = 1
	return e

func _room(w: int = 20, h: int = 20) -> MapData:
	var m := MapData.new()
	m.setup(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			m.set_tile(Vector2i(x, y), MapData.Tile.FLOOR)
	return m

func _manager(roster: Array, m: MapData = null) -> TurnManager:
	var tm := TurnManager.new()
	tm.setup(m if m != null else _room(), roster)
	return tm

func test_initiative_is_sorted_high_to_low() -> void:
	var roster: Array = []
	for i in 6:
		roster.append(_make("F%d" % i, Entity.Team.ENEMY, Vector2i(i + 2, 2)))
	var tm := _manager(roster)
	eq(tm.order.size(), 6, "everyone is in the order")
	for i in range(1, tm.order.size()):
		var prev: int = int(tm.initiative[tm.order[i - 1]])
		var cur: int = int(tm.initiative[tm.order[i]])
		truthy(prev >= cur, "initiative descends (%d then %d)" % [prev, cur])

func test_advance_cycles_and_counts_rounds() -> void:
	var roster: Array = [
		_make("A", Entity.Team.PLAYER, Vector2i(2, 2)),
		_make("B", Entity.Team.ENEMY, Vector2i(4, 2)),
		_make("C", Entity.Team.ENEMY, Vector2i(6, 2)),
	]
	var tm := _manager(roster)
	eq(tm.round_number, 0, "no rounds before the first turn")
	var seen: Array = []
	for i in 3:
		seen.append(tm.advance())
	eq(tm.round_number, 1, "first pass is round 1")
	eq(seen.size(), 3, "three turns taken")
	truthy(seen[0] != seen[1] and seen[1] != seen[2], "each combatant acts once per round")
	tm.advance()
	eq(tm.round_number, 2, "wrapping starts a new round")

func test_dead_combatants_are_skipped() -> void:
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 2))
	var b := _make("B", Entity.Team.ENEMY, Vector2i(4, 2))
	var c := _make("C", Entity.Team.ENEMY, Vector2i(6, 2))
	var tm := _manager([a, b, c])
	b.current_hp = 0
	for i in 6:
		var e: Entity = tm.advance()
		ne(e, b, "a downed combatant never gets a turn")

func test_turn_budget_resets_each_turn() -> void:
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 2))
	var tm := _manager([a])
	tm.advance()
	eq(tm.moves_left(a), 6, "full movement at turn start")
	truthy(tm.has_action(a), "action available")
	truthy(tm.has_bonus(a), "bonus action available")
	truthy(tm.has_reaction(a), "reaction available")

	truthy(tm.spend_action(a), "action spends once")
	falsy(tm.spend_action(a), "action cannot be spent twice")
	tm.spend_move(a, 4)
	eq(tm.moves_left(a), 2, "movement is deducted")

	tm.advance()
	eq(tm.moves_left(a), 6, "movement refreshes next turn")
	truthy(tm.has_action(a), "action refreshes next turn")

func test_dash_converts_action_into_movement() -> void:
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 2))
	var tm := _manager([a])
	tm.advance()
	truthy(tm.dash(a), "dash succeeds with an action available")
	eq(tm.moves_left(a), 12, "dash doubles remaining movement")
	falsy(tm.has_action(a), "dash consumes the action")
	falsy(tm.dash(a), "cannot dash twice")

func test_stunned_entity_gets_no_budget() -> void:
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 2))
	a.add_condition("stunned", 3)
	var tm := _manager([a])
	tm.advance()
	eq(tm.moves_left(a), 0, "no movement while stunned")
	falsy(tm.has_action(a), "no action while stunned")

func test_movement_is_limited_by_remaining_budget() -> void:
	var m := _room()
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 10))
	var tm := _manager([a], m)
	tm.advance()
	var reachable: Dictionary = tm.reachable(a)["cost"]
	truthy(reachable.has(Vector2i(8, 10)), "6 tiles away is reachable")
	falsy(reachable.has(Vector2i(9, 10)), "7 tiles away is not")

	var path := tm.path_for(a, Vector2i(8, 10))
	var result := tm.move_along(a, path)
	eq(a.grid_pos, Vector2i(8, 10), "entity arrives")
	eq(tm.moves_left(a), 0, "movement fully spent")
	eq((result["steps"] as Array).size(), 6, "six steps walked")

func test_path_does_not_route_through_other_combatants() -> void:
	var m := _room()
	var a := _make("A", Entity.Team.PLAYER, Vector2i(5, 10))
	var wall_of_flesh: Array = [a]
	for y in range(8, 13):
		wall_of_flesh.append(_make("B%d" % y, Entity.Team.ENEMY, Vector2i(6, y)))
	var tm := _manager(wall_of_flesh, m)
	tm.advance()
	var occupied := tm.occupied_tiles(a)
	truthy(occupied.has(Vector2i(6, 10)), "occupancy map includes other fighters")
	var reachable: Dictionary = tm.reachable(a)["cost"]
	falsy(reachable.has(Vector2i(6, 10)), "cannot stop on an occupied tile")

func test_opportunity_attack_when_leaving_reach() -> void:
	var m := _room()
	var runner := _make("Runner", Entity.Team.PLAYER, Vector2i(5, 10))
	var guard := _make("Guard", Entity.Team.ENEMY, Vector2i(6, 10))
	guard.ac_base = 10
	runner.ac_base = -50  # so the reaction attack always connects
	var tm := _manager([runner, guard], m)
	tm.advance()
	# Give the runner the turn regardless of initiative.
	while tm.current() != runner:
		tm.advance()
	var hp_before := runner.current_hp
	var path := tm.path_for(runner, Vector2i(2, 10))
	var result := tm.move_along(runner, path)
	var provoked := false
	for event: Dictionary in result["events"]:
		if str(event.get("type", "")) == "opportunity":
			provoked = true
			truthy(str(event["text"]).begins_with("Opportunity attack!"), "event is labelled")
	truthy(provoked, "walking out of reach provokes a reaction")
	truthy(runner.current_hp < hp_before, "the reaction attack landed")
	falsy(tm.has_reaction(guard), "the guard's reaction is used up")

func test_no_opportunity_attack_when_staying_adjacent() -> void:
	var m := _room()
	var runner := _make("Runner", Entity.Team.PLAYER, Vector2i(5, 10))
	var guard := _make("Guard", Entity.Team.ENEMY, Vector2i(6, 10))
	var tm := _manager([runner, guard], m)
	tm.advance()
	while tm.current() != runner:
		tm.advance()
	# Step from (5,10) to (6,9)-adjacent tile (5,9): still beside the guard.
	var result := tm.move_along(runner, [Vector2i(5, 10), Vector2i(5, 9)])
	for event: Dictionary in result["events"]:
		ne(str(event.get("type", "")), "opportunity", "shuffling within reach is safe")

func test_reaction_only_fires_once_per_round() -> void:
	var m := _room()
	var runner := _make("Runner", Entity.Team.PLAYER, Vector2i(5, 10))
	var guard := _make("Guard", Entity.Team.ENEMY, Vector2i(6, 10))
	runner.speed_tiles = 12
	var tm := _manager([runner, guard], m)
	while tm.current() != runner:
		tm.advance()
	tm.move_along(runner, [Vector2i(5, 10), Vector2i(4, 10)])
	falsy(tm.has_reaction(guard), "reaction spent")
	# Walk back into reach and out again; no second reaction this round.
	var events: Array = tm.move_along(runner, [Vector2i(4, 10), Vector2i(5, 10), Vector2i(4, 10)])["events"]
	for event: Dictionary in events:
		ne(str(event.get("type", "")), "opportunity", "no second reaction in the same round")

func test_team_alive_tracks_wipeouts() -> void:
	var a := _make("A", Entity.Team.PLAYER, Vector2i(2, 2))
	var b := _make("B", Entity.Team.ENEMY, Vector2i(4, 2))
	var tm := _manager([a, b])
	truthy(tm.team_alive(Entity.Team.PLAYER), "player alive")
	truthy(tm.team_alive(Entity.Team.ENEMY), "enemy alive")
	b.current_hp = 0
	falsy(tm.team_alive(Entity.Team.ENEMY), "enemy team wiped")
	truthy(tm.hostiles_of(a).is_empty(), "no hostiles remain")
