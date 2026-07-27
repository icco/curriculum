extends "res://tests/TestCase.gd"

func before_each() -> void:
	Dice.seed_with(8675309)

func _room(w: int = 24, h: int = 24) -> MapData:
	var m := MapData.new()
	m.setup(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			m.set_tile(Vector2i(x, y), MapData.Tile.FLOOR)
	return m

func _hero(pos: Vector2i) -> Entity:
	var e := Entity.new()
	e.display_name = "Wren"
	e.team = Entity.Team.PLAYER
	e.rank = Entity.Rank.HERO
	e.grid_pos = pos
	e.stats = {"str": 10, "dex": 14, "con": 12, "int": 16, "wis": 12, "cha": 10}
	e.ac_base = 10
	e.max_hp = 40
	e.current_hp = 40
	e.speed_tiles = 6
	e.damage_dice = "1d6"
	return e

func _brute(pos: Vector2i, rank: int = Entity.Rank.GRUNT) -> Entity:
	var e := Entity.new()
	e.display_name = "Jock"
	e.team = Entity.Team.ENEMY
	e.rank = rank
	e.grid_pos = pos
	e.stats = {"str": 16, "dex": 12, "con": 14, "int": 8, "wis": 10, "cha": 10}
	e.ac_base = 10
	e.max_hp = 24
	e.current_hp = 24
	e.speed_tiles = 6
	e.proficiency = 2
	e.attack_ability = "str"
	e.damage_dice = "1d8"
	e.attack_range = 1
	return e

func _sniper(pos: Vector2i) -> Entity:
	var e := _brute(pos)
	e.display_name = "Debate Sniper"
	e.attack_ability = "dex"
	e.stats["dex"] = 15
	e.attack_range = 7
	e.damage_dice = "1d6"
	return e

func _manager(roster: Array, m: MapData) -> TurnManager:
	var tm := TurnManager.new()
	tm.setup(m, roster)
	return tm

func _give_turn(tm: TurnManager, actor: Entity) -> void:
	var guard := 0
	while tm.current() != actor and guard < 50:
		tm.advance()
		guard += 1

func test_melee_closes_distance_and_attacks() -> void:
	var m := _room()
	var hero := _hero(Vector2i(5, 10))
	var brute := _brute(Vector2i(12, 10))
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	var events := EnemyAI.take_turn(brute, tm)
	truthy(MapData.chebyshev(brute.grid_pos, hero.grid_pos) < 7, "the brute closed the gap")
	var moved := false
	for e: Dictionary in events:
		if str(e.get("type", "")) == "move":
			moved = true
	truthy(moved, "a move event was produced")

func test_adjacent_melee_attacks_without_moving() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	var brute := _brute(Vector2i(11, 10))
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	var start := brute.grid_pos
	var events := EnemyAI.take_turn(brute, tm)
	eq(brute.grid_pos, start, "no need to move when already adjacent")
	var attacked := false
	for e: Dictionary in events:
		if str(e.get("type", "")) == "attack":
			attacked = true
	truthy(attacked, "the brute swings")

func test_melee_eventually_reaches_a_distant_hero() -> void:
	var m := _room(30, 30)
	var hero := _hero(Vector2i(4, 15))
	# Just inside aggro range; anything further and the enemy has not noticed
	# the player yet, which is covered by test_ai_is_idle_when_nothing_is_visible.
	var brute := _brute(Vector2i(16, 15))
	var tm := _manager([hero, brute], m)
	for turn in 4:
		_give_turn(tm, brute)
		EnemyAI.take_turn(brute, tm)
	eq(MapData.chebyshev(brute.grid_pos, hero.grid_pos), 1,
		"repeated turns bring the brute into melee across the room")

func test_ranged_enemy_keeps_its_distance() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	var sniper := _sniper(Vector2i(15, 10))
	var tm := _manager([hero, sniper], m)
	_give_turn(tm, sniper)
	EnemyAI.take_turn(sniper, tm)
	var dist: int = MapData.chebyshev(sniper.grid_pos, hero.grid_pos)
	truthy(dist > 1, "a sniper does not walk into melee (distance %d)" % dist)
	truthy(dist <= sniper.attack_range, "but stays within weapon range")

func test_enemy_without_line_of_sight_does_not_attack() -> void:
	var m := _room()
	var hero := _hero(Vector2i(4, 10))
	var sniper := _sniper(Vector2i(18, 10))
	for y in range(1, 23):
		m.set_tile(Vector2i(11, y), MapData.Tile.WALL)
	var tm := _manager([hero, sniper], m)
	_give_turn(tm, sniper)
	var events := EnemyAI.take_turn(sniper, tm)
	for e: Dictionary in events:
		ne(str(e.get("type", "")), "attack", "cannot shoot through a solid wall")

func test_badly_hurt_grunt_retreats() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	# Started out of reach: fleeing from an adjacent hero would provoke an
	# opportunity attack, which is tested separately.
	var brute := _brute(Vector2i(13, 10))
	brute.current_hp = 2
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	EnemyAI.take_turn(brute, tm)
	truthy(MapData.chebyshev(brute.grid_pos, hero.grid_pos) > 3,
		"a nearly-dead grunt runs rather than closing in")

func test_fleeing_from_melee_provokes_the_player() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	hero.ac_base = 10
	hero.damage_dice = "1d6"
	var brute := _brute(Vector2i(11, 10))
	brute.current_hp = 2
	brute.ac_base = -40  # the hero's reaction cannot miss
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	var events := EnemyAI.take_turn(brute, tm)
	var provoked := false
	for e: Dictionary in events:
		if str(e.get("type", "")) == "opportunity":
			provoked = true
	truthy(provoked, "breaking away from the hero draws an opportunity attack")
	falsy(brute.is_alive(), "a 2 hp grunt does not survive the parting shot")

func test_boss_does_not_flee_and_follows_up() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	hero.ac_base = -40  # every swing lands so the follow-up is observable
	var boss := _brute(Vector2i(11, 10), Entity.Rank.BOSS)
	boss.current_hp = 3
	var tm := _manager([hero, boss], m)
	_give_turn(tm, boss)
	var events := EnemyAI.take_turn(boss, tm)
	eq(boss.grid_pos, Vector2i(11, 10), "a cornered boss stands its ground")
	var attacks := 0
	for e: Dictionary in events:
		if str(e.get("type", "")) == "attack":
			attacks += 1
	eq(attacks, 2, "bosses attack twice when they do not move")

func test_ai_targets_the_weakest_reachable_hero() -> void:
	var m := _room()
	var healthy := _hero(Vector2i(9, 10))
	healthy.display_name = "Healthy"
	var wounded := _hero(Vector2i(11, 10))
	wounded.display_name = "Wounded"
	wounded.current_hp = 2
	var brute := _brute(Vector2i(10, 10))
	var tm := _manager([healthy, wounded, brute], m)
	_give_turn(tm, brute)
	var events := EnemyAI.take_turn(brute, tm)
	var struck := ""
	for e: Dictionary in events:
		if str(e.get("type", "")) == "attack":
			struck = (e["target"] as Entity).display_name
	eq(struck, "Wounded", "the AI finishes off the weakest target")

func test_ai_is_idle_when_nothing_is_visible() -> void:
	var m := _room(30, 30)
	var hero := _hero(Vector2i(3, 3))
	var brute := _brute(Vector2i(26, 26))
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	var events := EnemyAI.take_turn(brute, tm)
	for e: Dictionary in events:
		ne(str(e.get("type", "")), "attack", "no attacks from across the school")

func test_stunned_enemy_does_nothing() -> void:
	var m := _room()
	var hero := _hero(Vector2i(10, 10))
	var brute := _brute(Vector2i(11, 10))
	brute.add_condition("stunned", 2)
	var tm := _manager([hero, brute], m)
	_give_turn(tm, brute)
	var start := brute.grid_pos
	var events := EnemyAI.take_turn(brute, tm)
	eq(events.size(), 0, "a stunned enemy produces no events")
	eq(brute.grid_pos, start, "and does not move")

func test_full_enemy_round_never_crashes_on_generated_floors() -> void:
	# Smoke test: run several full rounds of AI on real generated maps.
	for s in 6:
		Dice.seed_with(1500 + s)
		var result := MapGenerator.new().generate(2 + s)
		var map: MapData = result["map"]
		var hero := _hero(map.entry_pos)
		var roster: Array = [hero]
		for spawn: Dictionary in result["spawns"]:
			var e := Roster.make_enemy(str(spawn["role"]), 2 + s)
			e.grid_pos = spawn["pos"]
			roster.append(e)
		var tm := _manager(roster, map)
		for turn in roster.size() * 2:
			var actor: Entity = tm.advance()
			if actor == null:
				break
			if actor.team == Entity.Team.ENEMY:
				EnemyAI.take_turn(actor, tm)
			truthy(map.is_walkable(actor.grid_pos) or actor == hero,
				"actor %s stands on legal ground at %s" % [actor.display_name, str(actor.grid_pos)])
