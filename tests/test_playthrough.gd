extends "res://tests/TestCase.gd"

## Plays the game with a scripted policy instead of a person. This is the
## strongest check that the whole loop actually works: floors get cleared,
## stairs get taken, death resets the loop, and floor 12 can be escaped.

## Deep floors field a dozen combatants, so a full 12-floor run costs a lot of
## individual actor turns. Generous cap: this is a liveness guard, not a budget.
const MAX_TURNS := 25000

func before_each() -> void:
	Dice.seed_with(24601)

# --------------------------------------------------------------- the policy

## One player turn of a deliberately simple tactician: head for the stairs,
## hitting whatever gets in the way. Chasing fleeing enemies around the floor
## is a losing strategy, so this policy does not.
func _play_turn(session: FloorSession) -> void:
	var player: Entity = session.player

	# 1. Hit anything already in reach.
	if session.has_action():
		var reachable_foe: Entity = _adjacent_foe(session)
		if reachable_foe != null:
			session.player_attack(reachable_foe)

	# 2. Otherwise sling a spell at whatever is visible.
	if session.has_action():
		var seen := session.visible_enemies()
		if not seen.is_empty():
			var target: Entity = _nearest(player, seen)
			for spell: Dictionary in session.known_spells():
				if str(spell.get("target", "")) != "enemy" or not session.can_cast(spell):
					continue
				if MapData.chebyshev(player.grid_pos, target.grid_pos) <= int(spell.get("range", 1)):
					session.player_cast(str(spell["id"]), target.grid_pos)
					break

	# 3. Loot anything beside us with a spare action.
	if session.has_action() and session.adjacent_container() != Vector2i(-1, -1):
		session.player_loot()

	# 4. Always advance on the stairwell.
	if session.moves_left() > 0:
		_step_toward(session, session.map.stairs_pos)

	# 5. Swing again if the move brought someone into reach.
	if session.has_action():
		var foe: Entity = _adjacent_foe(session)
		if foe != null:
			session.player_attack(foe)

	# 6. Take the stairs if we are standing on them.
	if session.on_stairs() and bool(session.can_descend()["ok"]):
		session.descend()
		return

	session.end_player_turn()

func _adjacent_foe(session: FloorSession) -> Entity:
	for e: Entity in session.entities:
		if e.is_alive() and e.is_hostile_to(session.player) and Combat.can_attack(session.player, e, session.map):
			return e
	return null

func _nearest(from: Entity, candidates: Array) -> Entity:
	var best: Entity = candidates[0]
	for e: Entity in candidates:
		if MapData.chebyshev(from.grid_pos, e.grid_pos) < MapData.chebyshev(from.grid_pos, best.grid_pos):
			best = e
	return best

func _step_toward(session: FloorSession, goal: Vector2i) -> void:
	var occupied := session.tm.occupied_tiles(session.player)
	var path := session.map.find_path(session.player.grid_pos, goal, occupied, true)
	if path.size() < 2:
		# Bodies in a corridor can seal the only route. Advance along the route
		# that ignores them and stop where the plug starts, so it can be fought
		# through rather than waited out.
		path = session.map.find_path(session.player.grid_pos, goal, {}, true)
		var cut: int = path.size()
		for i in range(1, path.size()):
			if occupied.has(path[i]):
				cut = i
				break
		path = path.slice(0, cut)
		if path.size() < 2:
			return
	elif occupied.has(goal) or not session.map.is_walkable(goal):
		# Never step onto the goal when it is occupied; stop beside it.
		path = path.slice(0, path.size() - 1)
	var budget: int = session.moves_left()
	if path.size() > budget + 1:
		path = path.slice(0, budget + 1)
	if path.size() >= 2:
		session.player_move(path)

## Drives a session until it ends or the turn cap is hit.
## Returns {turns, descents, ended}
func _drive(session: FloorSession, turn_cap: int = MAX_TURNS) -> Dictionary:
	var turns := 0
	var start_depth: int = session.depth
	var max_depth: int = session.depth
	while not session.is_over() and turns < turn_cap:
		turns += 1
		if session.is_player_turn():
			_play_turn(session)
		else:
			session.run_enemy_turn()
		max_depth = maxi(max_depth, session.depth)
	return {
		"turns": turns,
		"descents": max_depth - start_depth,
		"depth": session.depth,
		"ended": session.is_over(),
		"phase": session.phase,
	}

# ----------------------------------------------------------------- tests

func test_a_single_floor_can_be_played_and_left() -> void:
	var state := GameState.new()
	# A survivable protagonist so the floor gets finished rather than lost.
	state.global["bonus_hp"] = 120
	var session := FloorSession.new(state)
	var opening := session.build(1)
	truthy(opening.size() > 0, "building a floor produces log events")
	eq(session.depth, 1, "starts on floor 1")
	truthy(session.enemies_alive() > 0, "the floor is populated")

	var result := _drive(session, 900)
	truthy(int(result["descents"]) >= 1 or bool(result["ended"]),
		"the policy either descends or dies (turns=%d depth=%d)" % [int(result["turns"]), int(result["depth"])])

## Proves the twelve-floor structure end to end: every floor is traversable
## from its entry to its stairwell, descending advances the month, and the exit
## on floor 12 ends the run in victory. Combat is taken out of the picture on
## purpose — survivability is a balance question, tested separately below.
func test_walking_the_whole_academy_reaches_the_exit() -> void:
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(1)
	var months_seen: Array = []

	for expected_depth in range(1, GameState.FINAL_FLOOR + 1):
		eq(session.depth, expected_depth, "on floor %d" % expected_depth)
		months_seen.append(session.state.month_name())
		_clear_the_wing(session)

		var turns := 0
		while not session.on_stairs() and turns < 400:
			turns += 1
			if session.is_player_turn():
				if session.moves_left() > 0:
					_step_toward(session, session.map.stairs_pos)
				if not session.on_stairs():
					session.end_player_turn()
			else:
				session.run_enemy_turn()
		truthy(session.on_stairs(),
			"walked from the entry to the stairwell on floor %d in %d turns" % [expected_depth, turns])
		session.descend()

	eq(int(session.phase), FloorSession.Phase.ESCAPED, "leaving floor 12 wins the run")
	eq(int(state.run["floors_cleared"]), GameState.FINAL_FLOOR, "all twelve floors counted")
	eq(months_seen.size(), 12, "twelve months of the loop were visited")
	eq(str(months_seen[0]), "September", "the loop opens in September")
	eq(str(months_seen[11]), "August", "and ends in August")

## Removes the roster so traversal can be measured on its own.
func _clear_the_wing(session: FloorSession) -> void:
	for e: Entity in session.entities:
		if e != session.player:
			e.current_hp = 0

## Balance sanity: an upgraded protagonist driven by the simple policy should
## usually get off the first floor. A guard against gross imbalance, not a
## tuning target — use tools/simulate.gd for actual tuning.
func test_a_modest_run_can_clear_early_floors() -> void:
	var got_off_floor_one := 0
	var attempts := 6
	for s in attempts:
		Dice.seed_with(2200 + s * 17)
		var state := GameState.new()
		state.global["skill_points"] = 12
		for node_id: String in ["reading_circle", "corridor_savvy", "first_circle", "examination_recall", "tenure"]:
			state.purchase_node(node_id)
		var session := FloorSession.new(state)
		session.build(1)
		var result := _drive(session, 1500)
		if int(result["descents"]) >= 1:
			got_off_floor_one += 1
	truthy(got_off_floor_one >= attempts / 2,
		"an upgraded protagonist reaches floor 2 at least half the time (%d/%d)" % [got_off_floor_one, attempts])

## Killing things during a run raises the protagonist's level, hit points and
## spell slots, so deeper floors stay survivable.
func test_kills_level_the_protagonist_up_mid_run() -> void:
	Dice.seed_with(6161)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(3)
	eq(state.player_level(), 1, "runs open at level 1")
	var start_hp: int = session.player.max_hp
	var start_slots: int = int(session.player.spell_slots.get("level_1", 0))
	var start_proficiency: int = session.player.proficiency

	# Award enough experience to cross several thresholds.
	var levelled := false
	for e: Entity in session.entities:
		if e == session.player:
			continue
		e.current_hp = 0
		for event: Dictionary in session._register_kill(e):
			if str(event.get("type", "")) == "level_up":
				levelled = true
	truthy(levelled, "clearing a floor produced at least one level up")
	truthy(state.player_level() > 1, "level advanced with experience")
	truthy(session.player.max_hp > start_hp, "max hit points grew")
	truthy(int(session.player.spell_slots.get("level_1", 0)) >= start_slots, "slots did not shrink")
	truthy(session.player.proficiency >= start_proficiency, "proficiency did not shrink")

	# The level survives being rebuilt on the next floor.
	session.player.grid_pos = session.map.stairs_pos
	session.descend()
	eq(session.player.level, state.player_level(), "the new floor rebuilds at the earned level")
	truthy(session.player.max_hp > start_hp, "and keeps the extra hit points")

func test_level_progression_tables() -> void:
	eq(GameState.level_for_xp(0), 1, "no experience is level 1")
	eq(GameState.level_for_xp(24), 1, "just short of the threshold")
	eq(GameState.level_for_xp(25), 2, "crossing a threshold levels up")
	eq(GameState.level_for_xp(999999), GameState.XP_CURVE.size(), "the curve caps out")
	var low := Roster.slots_for_level(1)
	eq(int(low["level_1"]), 2, "level 1 has two first-level slots, per the spec")
	eq(int(low["level_2"]), 0, "and no second-level slots")
	var high := Roster.slots_for_level(12)
	truthy(int(high["level_1"]) > int(low["level_1"]), "slots grow with level")
	truthy(int(high["level_3"]) > 0, "third-level slots eventually open up")

## Cantrips gain dice at 5 and 11 like their 5e counterparts.
func test_cantrip_damage_scales_with_level() -> void:
	var caster := Roster.make_player({}, 1)
	var cantrip := Roster.spell("slate_shard")
	eq(Combat.spell_damage_expr(caster, cantrip), "1d10", "one die at level 1")
	caster = Roster.make_player({}, 5)
	eq(Combat.spell_damage_expr(caster, cantrip), "2d10", "two dice at level 5")
	caster = Roster.make_player({}, 11)
	eq(Combat.spell_damage_expr(caster, cantrip), "3d10", "three dice at level 11")
	var levelled := Roster.spell("sudden_examination")
	eq(Combat.spell_damage_expr(caster, levelled), "2d8", "levelled spells do not scale")

func test_every_floor_generates_and_opens_cleanly() -> void:
	# Each depth builds, spawns its own boss type and stays internally sound.
	for depth in range(1, GameState.FINAL_FLOOR + 1):
		Dice.seed_with(600 + depth)
		var state := GameState.new()
		var session := FloorSession.new(state)
		session.build(depth)
		truthy(session.boss != null, "floor %d has a boss" % depth)
		eq(session.boss.rank, Entity.Rank.BOSS, "floor %d boss is ranked as one" % depth)
		truthy(session.map.is_walkable(session.player.grid_pos), "floor %d entry is standable" % depth)
		truthy(session.enemies_alive() >= 3, "floor %d has a roster" % depth)
		eq(session.state.month_name(), GameState.month_for(depth), "floor %d maps to a month" % depth)
		if depth == GameState.FINAL_FLOOR:
			eq(session.boss.id, "rector", "the last floor is guarded by the Rector")

func test_death_ends_the_run_and_resets_the_loop() -> void:
	var state := GameState.new()
	state.global["unlocked_spells"] = ["sudden_examination"]
	var session := FloorSession.new(state)
	session.build(6)  # deep floor, level 1 character: this will not go well
	session.player.max_hp = 4
	session.player.current_hp = 4
	session.player.equipped_gear = {"weapon": {"name": "Oak Quarterstaff", "damage_dice": "1d8"}}
	state.add_consumable({"name": "Vial of Cordial", "effect": "heal", "power": "2d4"})

	var result := _drive(session, 2000)
	eq(int(result["phase"]), FloorSession.Phase.DEAD, "a 4 hp character on floor 6 dies")

	var summary := state.fail_loop()
	truthy(int(summary["insight"]) >= 0, "insight is banked from the failed loop")
	eq(int(state.run["depth"]), 1, "the loop resets to floor 1")
	truthy((state.run["gear"] as Dictionary).is_empty(), "gear is lost with the loop")
	truthy((state.run["consumables"] as Array).is_empty(), "consumables are lost with the loop")
	truthy((state.global["unlocked_spells"] as Array).has("sudden_examination"), "learned magic survives")
	eq(int(state.global["loops"]), 2, "the loop counter advances")

func test_new_loop_starts_a_fresh_floor_one() -> void:
	var state := GameState.new()
	state.global["bonus_hp"] = 200
	var first := FloorSession.new(state)
	first.build(1)
	_drive(first, 600)
	state.fail_loop()

	var second := FloorSession.new(state)
	second.build(1)
	eq(second.depth, 1, "the new loop starts in September")
	eq(second.player.current_hp, second.player.max_hp, "and at full health")
	truthy(second.player.equipped_gear.is_empty(), "with nothing but the uniform")

func test_stairs_on_the_final_floor_are_gated_by_the_boss() -> void:
	Dice.seed_with(99)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(GameState.FINAL_FLOOR)
	session.player.grid_pos = session.map.stairs_pos
	var blocked := session.can_descend()
	falsy(bool(blocked["ok"]), "cannot leave while the Rector lives")
	truthy(str(blocked["reason"]).contains("Rector"), "the refusal names them")

	session.boss.current_hp = 0
	var allowed := session.can_descend()
	truthy(bool(allowed["ok"]), "with the Rector down the exit opens")
	var events := session.descend()
	eq(int(session.phase), FloorSession.Phase.ESCAPED, "taking the exit wins the run")
	var found := false
	for e: Dictionary in events:
		if str(e.get("type", "")) == "escaped":
			found = true
	truthy(found, "an escape event is logged")

func test_descending_grants_a_short_rest() -> void:
	Dice.seed_with(4004)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(1)
	session.player.max_hp = 40
	session.player.current_hp = 5
	session.player.slots_used = {"level_1": 2}
	session.player.grid_pos = session.map.stairs_pos
	for e: Entity in session.entities:
		if e != session.player:
			e.current_hp = 0
	session.descend()
	eq(session.depth, 2, "arrived on floor 2")
	truthy(session.player.current_hp > 5, "the landing restored some health")
	truthy(session.player.slots_left(1) > 0, "and a spell slot")

func test_term_break_is_a_full_rest() -> void:
	Dice.seed_with(707)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(4)  # 4 % TERM_BREAK == 0
	session.player.current_hp = 1
	session.player.slots_used = {"level_1": 2}
	session.player.grid_pos = session.map.stairs_pos
	for e: Entity in session.entities:
		if e != session.player:
			e.current_hp = 0
	session.descend()
	eq(session.player.current_hp, session.player.max_hp, "term break heals fully")
	eq(session.player.slots_left(1), int(session.player.spell_slots["level_1"]), "and refills every slot")

func test_looting_a_locker_equips_gear() -> void:
	Dice.seed_with(31)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(3)
	# Stand next to a known container and open it.
	var container: Vector2i = (session.map.containers.keys() as Array)[0]
	var spot := Vector2i(-1, -1)
	for dir: Vector2i in MapData.DIRS_8:
		if session.map.is_walkable(container + dir):
			spot = container + dir
			break
	ne(spot, Vector2i(-1, -1), "there is somewhere to stand")
	session.player.grid_pos = spot
	while not session.is_player_turn():
		session.advance()
	var events := session.player_loot()
	eq(str(events[0]["type"]), "loot", "looting produces a loot event")
	truthy(bool((session.map.containers[container] as Dictionary)["looted"]), "the locker is marked looted")
	var gained: bool = not session.player.equipped_gear.is_empty() or not state.consumables().is_empty()
	truthy(gained, "something was actually gained")

func test_player_cannot_act_outside_their_turn() -> void:
	Dice.seed_with(15)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(2)
	while session.is_player_turn():
		session.end_player_turn()
	falsy(session.is_player_turn(), "an enemy holds the initiative")
	eq(session.player_attack(session.visible_enemies()[0] if not session.visible_enemies().is_empty() else null).size(), 0,
		"attacks are refused out of turn")
	eq(session.player_move([session.player.grid_pos, session.player.grid_pos + Vector2i(1, 0)]).size(), 0,
		"movement is refused out of turn")
	eq(session.player_cast("slate_shard", session.player.grid_pos).size(), 0,
		"casting is refused out of turn")

func test_action_economy_is_enforced_for_the_player() -> void:
	Dice.seed_with(1717)
	var state := GameState.new()
	var session := FloorSession.new(state)
	session.build(1)
	while not session.is_player_turn():
		session.advance()
	truthy(session.has_action(), "turn starts with an action")
	session.player_cast("slate_shard", session.player.grid_pos + Vector2i(1, 0))
	falsy(session.has_action(), "casting a cantrip spends the action")
	var refused := session.player_cast("slate_shard", session.player.grid_pos + Vector2i(1, 0))
	eq(str(refused[0]["type"]), "info", "a second cast is refused")
	truthy(session.has_bonus(), "the bonus action is still free")
	session.player_cast("grimoire_ward", session.player.grid_pos)
	falsy(session.has_bonus(), "the bonus action spell consumed it")
	truthy(session.player.has_condition("shielded"), "and it took effect")
