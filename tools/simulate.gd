extends SceneTree

## Balance harness: plays N runs headlessly and reports how far they got.
##   godot --headless --path . --script tools/simulate.gd -- 20 3
## Args: [runs] [skill_nodes_bought]

const POLICY_TURN_CAP := 4000

var _verbose: bool = false
## Fight everything for the experience instead of rushing the stairwell.
var _aggressive: bool = false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 10
	var upgrades: int = int(args[1]) if args.size() > 1 else 0
	for extra: String in args.slice(2):
		if extra == "verbose":
			_verbose = true
		elif extra == "aggressive":
			_aggressive = true

	var depths: Array = []
	var deaths := 0
	var escapes := 0
	for i in runs:
		Dice.seed_with(1000 + i * 37)
		var state := GameState.new()
		state.global["skill_points"] = 99
		var bought := 0
		for node: Dictionary in GameState.skill_nodes():
			if bought >= upgrades:
				break
			if state.purchase_node(str(node["id"])):
				bought += 1
		state.global["skill_points"] = 0

		var session := FloorSession.new(state)
		session.build(1)
		if _verbose:
			print("  roster:")
			for e: Entity in session.entities:
				print("    %-24s hp=%3d ac=%2d atk=+%d dmg=%-8s range=%d rank=%d" % [
					e.display_name, e.max_hp, e.ac(), e.attack_bonus(),
					e.damage_expr(), e.reach(), e.rank])
		var turns := 0
		while not session.is_over() and turns < POLICY_TURN_CAP:
			turns += 1
			if session.is_player_turn():
				if _verbose:
					print("    t%-4d hp=%2d/%-2d pos=%s foes_seen=%d moves=%d" % [
						turns, session.player.current_hp, session.player.max_hp,
						str(session.player.grid_pos), session.visible_enemies().size(),
						session.moves_left()])
				_play(session)
			else:
				var events := session.run_enemy_turn()
				if _verbose:
					for e: Dictionary in events:
						if str(e.get("text", "")) != "":
							print("      | ", e["text"])
		depths.append(session.depth)
		if session.phase == FloorSession.Phase.DEAD:
			deaths += 1
		elif session.phase == FloorSession.Phase.ESCAPED:
			escapes += 1
		print("run %2d: reached floor %2d in %5d turns (%s) kills=%d" % [
			i, session.depth, turns, _phase_name(session.phase), int(state.run["kills"])])

	depths.sort()
	var total := 0
	for d: int in depths:
		total += d
	print("\n%d runs, %d upgrades: mean floor %.1f, median %d, deaths %d, escapes %d" % [
		runs, upgrades, float(total) / float(runs), depths[depths.size() / 2], deaths, escapes])
	quit(0)

func _phase_name(phase: int) -> String:
	match phase:
		FloorSession.Phase.DEAD: return "died"
		FloorSession.Phase.ESCAPED: return "escaped"
		_: return "stalled"

## Same greedy policy the playthrough test uses: head for the stairs, fight
## whatever blocks the way.
func _play(session: FloorSession) -> void:
	var player: Entity = session.player
	var hurt: float = float(player.current_hp) / maxf(1.0, float(player.max_hp))
	var threatened: bool = not session.visible_enemies().is_empty()

	# Defensive bonus actions first: shield up when threatened, drink when low.
	if session.has_bonus() and hurt < 0.45:
		var potion := _find_consumable(session, "heal")
		if potion >= 0:
			session.player_use_item(potion)
	if session.has_bonus() and threatened and not player.has_condition("shielded"):
		for spell: Dictionary in session.known_spells():
			if str(spell.get("action", "")) == "bonus" and str(spell.get("kind", "")) == "buff" \
					and session.can_cast(spell):
				session.player_cast(str(spell["id"]), player.grid_pos)
				break
	if session.has_action() and hurt < 0.4:
		for spell: Dictionary in session.known_spells():
			if str(spell.get("kind", "")) == "heal" and session.can_cast(spell):
				session.player_cast(str(spell["id"]), player.grid_pos)
				break

	if session.has_action():
		var foe := _adjacent(session)
		if foe != null:
			session.player_attack(foe)
	if session.has_action():
		var seen := session.visible_enemies()
		if not seen.is_empty():
			var target: Entity = seen[0]
			for spell: Dictionary in session.known_spells():
				if str(spell.get("target", "")) != "enemy" or not session.can_cast(spell):
					continue
				if MapData.chebyshev(player.grid_pos, target.grid_pos) <= int(spell.get("range", 1)):
					session.player_cast(str(spell["id"]), target.grid_pos)
					break
	if session.has_action() and session.adjacent_container() != Vector2i(-1, -1):
		session.player_loot()
	if session.moves_left() > 0:
		var goal: Vector2i = session.map.stairs_pos
		if _aggressive:
			var seen := session.visible_enemies()
			# Leave the stairwell guard alone until the rest of the wing is down.
			var quarry: Array = []
			for e: Entity in seen:
				if e.guard_radius <= 0:
					quarry.append(e)
			if not quarry.is_empty():
				goal = _closest(session.player, quarry).grid_pos
		_step_toward(session, goal)
	if session.on_stairs() and bool(session.can_descend()["ok"]):
		session.descend()
		return
	session.end_player_turn()

func _closest(from: Entity, candidates: Array) -> Entity:
	var best: Entity = candidates[0]
	for e: Entity in candidates:
		if MapData.chebyshev(from.grid_pos, e.grid_pos) < MapData.chebyshev(from.grid_pos, best.grid_pos):
			best = e
	return best

func _find_consumable(session: FloorSession, effect: String) -> int:
	var list: Array = session.state.consumables()
	for i in list.size():
		if str((list[i] as Dictionary).get("effect", "")) == effect:
			return i
	return -1

func _adjacent(session: FloorSession) -> Entity:
	for e: Entity in session.entities:
		if e.is_alive() and e.is_hostile_to(session.player) and Combat.can_attack(session.player, e, session.map):
			return e
	return null

func _step_toward(session: FloorSession, goal: Vector2i) -> void:
	var occupied := session.tm.occupied_tiles(session.player)
	var path := session.map.find_path(session.player.grid_pos, goal, occupied, true)
	if path.size() < 2:
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
		path = path.slice(0, path.size() - 1)
	var budget: int = session.moves_left()
	if path.size() > budget + 1:
		path = path.slice(0, budget + 1)
	if path.size() >= 2:
		session.player_move(path)
