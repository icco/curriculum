class_name FloorSession
extends RefCounted

## One floor of the academy in play. Owns the map, the roster and the turn loop,
## and exposes every player action as a function returning event dictionaries.
## Deliberately free of scene nodes so a whole 12-floor run can be played out
## headlessly in a test.

enum Phase { PLAYER, ENEMY, DEAD, ESCAPED }

const SIGHT_RADIUS := 9
const SHORT_REST_FRACTION := 0.35
const TERM_BREAK := 4    ## every Nth floor is a full rest
const BOSS_GUARD_RADIUS := 6

var state: GameState
var map: MapData
var player: Entity
var entities: Array = []
var tm: TurnManager
var depth: int = 1
var phase: int = Phase.PLAYER
var boss: Entity

var _interacted_this_turn: bool = false
var _pending: Array = []

func _init(game_state: GameState = null) -> void:
	state = game_state if game_state != null else GameState.new()

# ------------------------------------------------------------------ setup

## Generates a floor and puts the roster on it. Returns opening log events.
func build(new_depth: int) -> Array:
	depth = new_depth
	state.run["depth"] = depth
	var generated := MapGenerator.new().generate(depth)
	map = generated["map"]
	entities = []
	boss = null

	player = Roster.make_player(state.global, state.player_level())
	state.restore_player(player)
	if player.current_hp <= 0:
		player.current_hp = player.max_hp
	player.grid_pos = map.entry_pos
	entities.append(player)

	for spawn: Dictionary in generated["spawns"]:
		var role := str(spawn["role"])
		var enemy := Roster.make_enemy(role, depth)
		if role == "boss" and depth >= GameState.FINAL_FLOOR:
			enemy = Roster.make_enemy_by_id("rector", depth)
		enemy.grid_pos = spawn["pos"]
		enemy.home_pos = enemy.grid_pos
		if role == "boss":
			# Lecturers hold the stairwell instead of hunting across the floor,
			# so a fast player can gamble on slipping past them.
			enemy.guard_radius = BOSS_GUARD_RADIUS
			boss = enemy
		entities.append(enemy)

	tm = TurnManager.new()
	tm.events_logged.connect(_collect)
	tm.setup(map, entities)
	phase = Phase.PLAYER
	update_fov()

	var events: Array = [{
		"type": "info",
		"text": "%s — Floor %d. %s prowls this wing." % [
			state.month_name(), depth,
			boss.display_name if boss != null else "Something"],
	}]
	events.append_array(begin_first_turn())
	return events

func _collect(list: Array) -> void:
	_pending.append_array(list)

func _drain() -> Array:
	var out := _pending.duplicate()
	_pending.clear()
	return out

func begin_first_turn() -> Array:
	var events: Array = []
	# Advance until the player is up; enemies acting first is handled by the
	# controller calling run_enemy_turn().
	var actor := tm.advance()
	events.append_array(_drain())
	events.append_array(_sync_phase(actor))
	return events

# ---------------------------------------------------------------- queries

func current_actor() -> Entity:
	return tm.current()

func is_player_turn() -> bool:
	return phase == Phase.PLAYER and tm.current() == player

func is_over() -> bool:
	return phase == Phase.DEAD or phase == Phase.ESCAPED

func moves_left() -> int:
	return tm.moves_left(player)

func has_action() -> bool:
	return tm.has_action(player)

func has_bonus() -> bool:
	return tm.has_bonus(player)

func enemies_alive() -> int:
	var count := 0
	for e: Entity in entities:
		if e.is_alive() and e.team == Entity.Team.ENEMY:
			count += 1
	return count

func entity_at(cell: Vector2i) -> Entity:
	for e: Entity in entities:
		if e.is_alive() and e.grid_pos == cell:
			return e
	return null

func reachable_cells() -> Dictionary:
	return tm.reachable(player)

func update_fov() -> void:
	map.recompute_fov(player.grid_pos, SIGHT_RADIUS)

## Cells the player could attack from where they stand.
func attackable_cells() -> Array:
	var out: Array = []
	for e: Entity in entities:
		if e.is_alive() and e.is_hostile_to(player) and Combat.can_attack(player, e, map):
			out.append(e.grid_pos)
	return out

func visible_enemies() -> Array:
	var out: Array = []
	for e: Entity in entities:
		if e.is_alive() and e.is_hostile_to(player) and map.is_visible(e.grid_pos):
			out.append(e)
	return out

func known_spells() -> Array:
	var out: Array = []
	for id: String in player.known_spells:
		var spell := Roster.spell(id)
		if not spell.is_empty():
			out.append(spell)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level", 0)) < int(b.get("level", 0)))
	return out

func can_cast(spell: Dictionary) -> bool:
	if not Combat.spell_slot_available(player, spell):
		return false
	var action := str(spell.get("action", "action"))
	if action == "bonus":
		return tm.has_bonus(player)
	return tm.has_action(player)

func on_stairs() -> bool:
	return player.grid_pos == map.stairs_pos

func adjacent_container() -> Vector2i:
	for dir: Vector2i in MapData.DIRS_8:
		var cell: Vector2i = player.grid_pos + dir
		if map.containers.has(cell) and not bool((map.containers[cell] as Dictionary).get("looted", false)):
			return cell
	return Vector2i(-1, -1)

func adjacent_door() -> Vector2i:
	for dir: Vector2i in MapData.DIRS_4:
		var cell: Vector2i = player.grid_pos + dir
		if map.doors.has(cell):
			return cell
	return Vector2i(-1, -1)

# --------------------------------------------------------- player actions

func player_move(path: Array) -> Array:
	if not is_player_turn() or path.size() < 2:
		return []
	var result := tm.move_along(player, path)
	var events: Array = [{
		"type": "move", "actor": player, "path": result["steps"], "quiet": true, "text": "",
	}]
	events.append_array(result["events"] as Array)
	update_fov()
	events.append_array(_check_player_state())
	return events

func player_attack(target: Entity) -> Array:
	if not is_player_turn() or target == null or not target.is_alive():
		return []
	if not tm.has_action(player):
		return [{"type": "info", "text": "No action left this turn."}]
	if not Combat.can_attack(player, target, map):
		return [{"type": "info", "text": "%s is out of reach." % target.display_name}]
	tm.spend_action(player)
	var event := Combat.weapon_attack(player, target, map)
	var events: Array = [event]
	if not target.is_alive():
		events.append_array(_register_kill(target))
	return events

func player_cast(spell_id: String, center: Vector2i) -> Array:
	if not is_player_turn():
		return []
	var spell := Roster.spell(spell_id)
	if spell.is_empty():
		return [{"type": "info", "text": "You do not know that spell."}]
	if not player.known_spells.has(spell_id):
		return [{"type": "info", "text": "You have not learned %s yet." % str(spell.get("name", spell_id))}]
	if not Combat.spell_slot_available(player, spell):
		return [{"type": "info", "text": "No level %d slots left." % int(spell.get("level", 0))}]
	var uses_bonus := str(spell.get("action", "action")) == "bonus"
	if uses_bonus and not tm.has_bonus(player):
		return [{"type": "info", "text": "No bonus action left."}]
	if not uses_bonus and not tm.has_action(player):
		return [{"type": "info", "text": "No action left this turn."}]
	if int(spell.get("range", 0)) > 0:
		var distance := MapData.chebyshev(player.grid_pos, center)
		if distance > int(spell["range"]):
			return [{"type": "info", "text": "Out of range."}]
		if not map.has_line_of_sight(player.grid_pos, center):
			return [{"type": "info", "text": "No line of sight to that tile."}]
	if str(spell.get("kind", "")) == "teleport" and not map.is_walkable(center):
		return [{"type": "info", "text": "You cannot land there."}]

	if uses_bonus:
		tm.spend_bonus(player)
	else:
		tm.spend_action(player)

	var events := Combat.cast_spell(player, spell, center, entities, map)
	for event: Dictionary in events.duplicate():
		if str(event.get("type", "")) == "death":
			events.append_array(_register_kill(event["target"]))
	update_fov()
	return events

func player_dash() -> Array:
	if not is_player_turn() or not tm.dash(player):
		return [{"type": "info", "text": "No action left to Dash with."}]
	return [{"type": "info", "text": "%s dashes — movement doubled." % player.display_name}]

func player_loot() -> Array:
	if not is_player_turn():
		return []
	var cell := adjacent_container()
	if cell == Vector2i(-1, -1):
		return [{"type": "info", "text": "No reliquary within reach."}]
	if not tm.spend_action(player):
		return [{"type": "info", "text": "No action left this turn."}]
	(map.containers[cell] as Dictionary)["looted"] = true
	var item := Roster.roll_loot("locker", depth)
	if item.is_empty():
		return [{"type": "loot", "cell": cell, "item": {}, "text": "The reliquary is empty. Someone got here first."}]
	return [{"type": "loot", "cell": cell, "item": item, "text": _take_item(item)}]

## Auto-equips upgrades so mobile play needs no inventory screen.
func _take_item(item: Dictionary) -> String:
	var slot := str(item.get("slot", "trinket"))
	var name := str(item.get("name", "something"))
	if slot == "consumable":
		state.add_consumable(item)
		return "Found %s. Stowed in your bag." % name
	var current: Dictionary = player.equipped_gear.get(slot, {})
	if current.is_empty() or _item_score(item) > _item_score(current):
		player.equipped_gear[slot] = item
		return "Found %s — equipped." % name
	return "Found %s, but your %s is better. Left behind." % [name, str(current.get("name", slot))]

static func _item_score(item: Dictionary) -> float:
	var score := 0.0
	score += Dice.average(str(item.get("damage_dice", "0")))
	score += float(item.get("attack_bonus", 0)) * 2.0
	score += float(item.get("damage_bonus", 0)) * 1.5
	score += float(item.get("ac_bonus", 0)) * 3.0
	return score

func player_use_item(index: int) -> Array:
	if not is_player_turn():
		return []
	var list: Array = state.consumables()
	if index < 0 or index >= list.size():
		return [{"type": "info", "text": "Nothing to use."}]
	if not tm.has_bonus(player):
		return [{"type": "info", "text": "No bonus action left."}]
	tm.spend_bonus(player)
	var item := state.take_consumable(index)
	var name := str(item.get("name", "item"))
	match str(item.get("effect", "heal")):
		"heal":
			var healed := player.heal(Combat.roll_damage(str(item.get("power", "2d4"))))
			return [{"type": "heal", "target": player, "amount": healed,
				"text": "%s restores %d hit points." % [name, healed]}]
		"dash":
			tm.spend_move(player, -Combat.movement_for(player))
			return [{"type": "info", "text": "%s — you surge forward." % name}]
		"cleanse":
			player.conditions.clear()
			return [{"type": "info", "text": "%s clears your head." % name}]
	return [{"type": "info", "text": "%s does nothing useful." % name}]

## Doors are a free object interaction, once per turn.
func player_toggle_door() -> Array:
	if not is_player_turn():
		return []
	var cell := adjacent_door()
	if cell == Vector2i(-1, -1):
		return [{"type": "info", "text": "No door within reach."}]
	if _interacted_this_turn:
		return [{"type": "info", "text": "You have already handled a door this turn."}]
	var door: Dictionary = map.doors[cell]
	var opened: bool
	if bool(door.get("open", false)):
		if entity_at(cell) != null:
			return [{"type": "info", "text": "Something is standing in the doorway."}]
		map.close_door(cell)
		opened = false
	else:
		if not map.open_door(cell):
			return [{"type": "info", "text": "The door is locked. You need another way round."}]
		opened = true
	_interacted_this_turn = true
	update_fov()
	return [{"type": "door", "cell": cell, "open": opened,
		"text": "You %s the door." % ("open" if opened else "close")}]

func end_player_turn() -> Array:
	if not is_player_turn():
		return []
	state.capture_player(player)
	tm.end_turn()
	return advance()

# ------------------------------------------------------------- turn cycle

## Moves to the next combatant. Returns log events; check `phase` afterwards.
func advance() -> Array:
	if is_over():
		return []
	var actor := tm.advance()
	var events := _drain()
	events.append_array(_sync_phase(actor))
	return events

func _sync_phase(actor: Entity) -> Array:
	var events: Array = []
	if actor == null:
		phase = Phase.DEAD if not player.is_alive() else Phase.PLAYER
		return events
	if not player.is_alive():
		phase = Phase.DEAD
		return events
	if actor == player:
		phase = Phase.PLAYER
		_interacted_this_turn = false
		update_fov()
		events.append({"type": "turn", "actor": player, "text": "Your move."})
	else:
		phase = Phase.ENEMY
	return events

## Runs the current enemy's entire turn.
func run_enemy_turn() -> Array:
	var actor := tm.current()
	if actor == null or actor == player or not actor.is_alive():
		return advance()
	var events := EnemyAI.take_turn(actor, tm)
	for event: Dictionary in events.duplicate():
		if str(event.get("type", "")) == "death":
			var victim: Entity = event["target"]
			if victim != player:
				events.append_array(_register_kill(victim))
	update_fov()
	events.append_array(_check_player_state())
	if is_over():
		return events
	events.append_array(advance())
	return events

func _register_kill(victim: Entity) -> Array:
	if victim == player or victim.team == Entity.Team.PLAYER:
		return []
	var events: Array = []
	var new_level := state.note_kill(victim.xp_value)
	if new_level > 0:
		var gained := Roster.apply_level(player, new_level, state.global)
		events.append({
			"type": "level_up", "target": player, "level": new_level,
			"text": "You piece more of the loop together — level %d! +%d max HP." % [new_level, gained],
		})
	if victim == boss:
		state.set_story_flag("beat_%s_floor_%d" % [victim.id, depth])
		events.append({"type": "info",
			"text": "%s falls. The stairwell is yours." % victim.display_name})
	if enemies_alive() == 0:
		events.append({"type": "info", "text": "The wing is clear."})
	return events

func _check_player_state() -> Array:
	if player.is_alive():
		return []
	phase = Phase.DEAD
	return [{"type": "player_died", "text": "You black out. The bell tolls. It is September again."}]

# ------------------------------------------------------------- descending

func can_descend() -> Dictionary:
	if not on_stairs():
		return {"ok": false, "reason": "Find the stairwell first."}
	if depth >= GameState.FINAL_FLOOR and boss != null and boss.is_alive():
		return {"ok": false, "reason": "%s blocks the exit. Deal with them." % boss.display_name}
	return {"ok": true, "reason": ""}

## Takes the stairs. Rebuilds this session on the next floor, or wins the run.
func descend() -> Array:
	var check := can_descend()
	if not bool(check["ok"]):
		return [{"type": "info", "text": str(check["reason"])}]

	state.note_floor_cleared()
	if depth >= GameState.FINAL_FLOOR:
		phase = Phase.ESCAPED
		return [{"type": "escaped",
			"text": "You walk out through the cloister gate into open air. The loop breaks."}]

	var rest := _short_rest()
	state.capture_player(player)
	var events: Array = [{"type": "descend", "text": "You take the stair down to %s." % GameState.month_for(depth + 1)}]
	events.append_array(rest)
	events.append_array(build(depth + 1))
	return events

func _short_rest() -> Array:
	var events: Array = []
	var full: bool = depth % TERM_BREAK == 0
	if full:
		player.heal(player.max_hp)
		player.restore_all_slots()
		player.conditions.clear()
		events.append({"type": "info", "text": "Term break: fully rested, all slots recovered."})
		return events
	var healed := player.heal(int(ceil(player.max_hp * SHORT_REST_FRACTION)))
	# A short rest gives back one slot of each level you have.
	for key: String in player.spell_slots:
		var used := int(player.slots_used.get(key, 0))
		if used > 0:
			player.slots_used[key] = used - 1
	player.conditions.clear()
	events.append({"type": "info", "text": "A moment on the landing: +%d HP and a slot back." % healed})
	return events
