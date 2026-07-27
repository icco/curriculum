class_name TurnManager
extends RefCounted

## Initiative order plus the 5e action economy. Owns no scene nodes so the
## whole turn loop can be exercised headlessly.

signal turn_started(entity: Entity)
signal turn_ended(entity: Entity)
signal round_started(round_number: int)
signal events_logged(events: Array)

var map: MapData
var entities: Array = []      ## Array[Entity]
var order: Array = []         ## Array[Entity], initiative order
var initiative: Dictionary = {}
var index: int = -1
var round_number: int = 0

## Per-entity budget for the current turn.
var budget: Dictionary = {}   ## Entity -> {move, action, bonus, reaction}

func setup(new_map: MapData, roster: Array) -> void:
	map = new_map
	entities = roster
	roll_initiative()

func roll_initiative() -> void:
	initiative.clear()
	order.clear()
	for e: Entity in entities:
		# Rolled once per floor; ties break on dex then on name for stability.
		initiative[e] = Dice.d20() + e.mod("dex")
		order.append(e)
	order.sort_custom(func(a: Entity, b: Entity) -> bool:
		if int(initiative[a]) != int(initiative[b]):
			return int(initiative[a]) > int(initiative[b])
		if a.mod("dex") != b.mod("dex"):
			return a.mod("dex") > b.mod("dex")
		return a.display_name < b.display_name)
	index = -1
	round_number = 0

func current() -> Entity:
	if index < 0 or index >= order.size():
		return null
	return order[index]

func living_order() -> Array:
	var out: Array = []
	for e: Entity in order:
		if e.is_alive():
			out.append(e)
	return out

## Advances to the next living combatant and opens its turn.
func advance() -> Entity:
	if living_order().is_empty():
		return null
	var guard := 0
	while guard < order.size() * 2 + 2:
		guard += 1
		index += 1
		if index >= order.size():
			index = 0
			_begin_round()
		elif round_number == 0:
			# The very first turn of the fight opens round 1.
			_begin_round()
		var e: Entity = order[index]
		if e.is_alive():
			_open_turn(e)
			return e
	return null

func _begin_round() -> void:
	round_number += 1
	round_started.emit(round_number)

func _open_turn(e: Entity) -> void:
	var events := Combat.tick_start_of_turn(e)
	if not events.is_empty():
		events_logged.emit(events)
	if not e.is_alive():
		turn_ended.emit(e)
		return
	budget[e] = {
		"move": Combat.movement_for(e),
		"action": e.can_act(),
		"bonus": e.can_act(),
		"reaction": true,
	}
	turn_started.emit(e)

func end_turn() -> void:
	var e := current()
	if e != null:
		turn_ended.emit(e)

# ---------------------------------------------------------------- budgets

func moves_left(e: Entity) -> int:
	return int((budget.get(e, {}) as Dictionary).get("move", 0))

func has_action(e: Entity) -> bool:
	return bool((budget.get(e, {}) as Dictionary).get("action", false))

func has_bonus(e: Entity) -> bool:
	return bool((budget.get(e, {}) as Dictionary).get("bonus", false))

## A combatant that has not taken a turn yet still has its reaction, so this
## defaults to true rather than reading as "spent".
func has_reaction(e: Entity) -> bool:
	if not e.is_alive():
		return false
	return bool((budget.get(e, {}) as Dictionary).get("reaction", true))

func spend_action(e: Entity) -> bool:
	if not has_action(e):
		return false
	(budget[e] as Dictionary)["action"] = false
	return true

func spend_bonus(e: Entity) -> bool:
	if not has_bonus(e):
		return false
	(budget[e] as Dictionary)["bonus"] = false
	return true

func spend_reaction(e: Entity) -> bool:
	if not has_reaction(e):
		return false
	if not budget.has(e):
		budget[e] = {"move": 0, "action": false, "bonus": false, "reaction": true}
	(budget[e] as Dictionary)["reaction"] = false
	return true

func spend_move(e: Entity, steps: int) -> void:
	if budget.has(e):
		(budget[e] as Dictionary)["move"] = maxi(0, moves_left(e) - steps)

## Dash: trade the action for a second helping of movement.
func dash(e: Entity) -> bool:
	if not spend_action(e):
		return false
	(budget[e] as Dictionary)["move"] = moves_left(e) + Combat.movement_for(e)
	return true

# --------------------------------------------------------------- movement

func occupied_tiles(exclude: Entity = null) -> Dictionary:
	var out: Dictionary = {}
	for e: Entity in entities:
		if e == exclude or not e.is_alive():
			continue
		out[e.grid_pos] = e
	return out

## Tiles `e` can reach with its remaining movement.
func reachable(e: Entity) -> Dictionary:
	return map.flood_fill(e.grid_pos, moves_left(e), occupied_tiles(e))

func path_for(e: Entity, target: Vector2i) -> Array:
	var result := reachable(e)
	if not (result["cost"] as Dictionary).has(target):
		return []
	return MapData.reconstruct_path(result["came_from"], target)

## Walks `e` along `path` (which starts on its current tile), provoking
## opportunity attacks. Returns {steps, events, stopped_early}.
func move_along(e: Entity, path: Array) -> Dictionary:
	var events: Array = []
	var walked: Array = []
	var stopped := false
	if path.size() < 2:
		return {"steps": [], "events": events, "stopped_early": false}
	for i in range(1, path.size()):
		var from: Vector2i = e.grid_pos
		var to: Vector2i = path[i]
		if moves_left(e) <= 0:
			stopped = true
			break
		events.append_array(_provoke(e, from, to))
		if not e.is_alive():
			stopped = true
			break
		e.grid_pos = to
		walked.append(to)
		spend_move(e, 1)
	# Events are returned rather than emitted: callers already have them, and
	# emitting here too would log every reaction twice.
	return {"steps": walked, "events": events, "stopped_early": stopped}

## Opportunity attacks: leaving a hostile's reach with its reaction up.
func _provoke(mover: Entity, from: Vector2i, to: Vector2i) -> Array:
	var events: Array = []
	for other: Entity in entities:
		if other == mover or not other.is_alive() or not other.is_hostile_to(mover):
			continue
		if not has_reaction(other):
			continue
		var reach: int = maxi(1, mini(other.reach(), 1))
		var was_adjacent: bool = MapData.chebyshev(other.grid_pos, from) <= reach
		var still_adjacent: bool = MapData.chebyshev(other.grid_pos, to) <= reach
		if not was_adjacent or still_adjacent:
			continue
		spend_reaction(other)
		var event := Combat.weapon_attack(other, mover, map, "opportunity")
		event["text"] = "Opportunity attack! " + str(event["text"])
		events.append(event)
		if not mover.is_alive():
			events.append({"type": "death", "target": mover,
				"text": "%s is out of the fight!" % mover.display_name})
			break
	return events

# ------------------------------------------------------------------ status

func hostiles_of(e: Entity) -> Array:
	var out: Array = []
	for other: Entity in entities:
		if other.is_alive() and other.is_hostile_to(e):
			out.append(other)
	return out

func team_alive(team: int) -> bool:
	for e: Entity in entities:
		if e.is_alive() and e.team == team:
			return true
	return false

func remove_dead() -> Array:
	var removed: Array = []
	for e: Entity in entities.duplicate():
		if not e.is_alive():
			removed.append(e)
	return removed
