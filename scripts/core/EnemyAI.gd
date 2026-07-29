class_name EnemyAI
extends RefCounted

## Decides and executes an enemy turn. State is mutated immediately and an
## ordered event list is returned, so the presentation layer can replay the
## turn as animation while the rules stay headlessly testable.

const AGGRO_RANGE := 13
const FLEE_THRESHOLD := 0.25
## How far a shout carries.
const SHOUT_RANGE := 12

## Runs the whole turn for `actor`. Returns events in the order they happened.
static func take_turn(actor: Entity, tm: TurnManager) -> Array:
	var events: Array = []
	if not actor.is_alive() or not actor.can_act():
		return events

	var map: MapData = tm.map
	var hostiles := _visible_hostiles(actor, tm)
	if hostiles.is_empty():
		events.append_array(_wander(actor, tm))
		return events

	var target: Entity = _pick_target(actor, hostiles, map)
	# Remember where they were. Shut a door in its face and it comes after this.
	actor.alerted_to = target.grid_pos
	if actor.calls_allies:
		events.append_array(_shout(actor, tm, target))
	var hurt: bool = float(actor.current_hp) / maxf(1.0, float(actor.max_hp)) <= FLEE_THRESHOLD

	if hurt and actor.rank == Entity.Rank.GRUNT:
		events.append_array(_retreat(actor, tm, hostiles))
		return events

	# A gatekeeper would rather hold the door than close the distance.
	if actor.shuts_doors:
		var shut := _shut_a_door(actor, tm, target)
		if not shut.is_empty():
			return shut

	# Reposition, then swing. Ranged fighters look for a spot with cover.
	events.append_array(_reposition(actor, tm, target))
	events.append_array(_attack_if_able(actor, tm, target))

	# Wounded teachers and monitors get desperate and swing twice. Gating this
	# on their own health keeps opening rounds survivable for a fresh loop.
	var enraged: bool = float(actor.current_hp) / maxf(1.0, float(actor.max_hp)) <= 0.5
	if enraged and actor.rank != Entity.Rank.GRUNT and target.is_alive() and tm.has_bonus(actor):
		if Combat.can_attack(actor, target, tm.map):
			tm.spend_bonus(actor)
			var extra := Combat.weapon_attack(actor, target, tm.map, "attack")
			extra["text"] = "Follow-up: " + str(extra["text"])
			events.append(extra)
			if not target.is_alive():
				events.append({"type": "death", "target": target,
					"text": "%s is out of the fight!" % target.display_name})
	return events

# ------------------------------------------------------------- perception

static func _visible_hostiles(actor: Entity, tm: TurnManager) -> Array:
	var out: Array = []
	for other: Entity in tm.hostiles_of(actor):
		if MapData.chebyshev(actor.grid_pos, other.grid_pos) > AGGRO_RANGE:
			continue
		if not tm.map.has_line_of_sight(actor.grid_pos, other.grid_pos):
			continue
		out.append(other)
	return out

## Prefers whoever can be finished off, then whoever is closest.
static func _pick_target(actor: Entity, hostiles: Array, map: MapData) -> Entity:
	var best: Entity = hostiles[0]
	var best_score := -INF
	for other: Entity in hostiles:
		var dist: int = MapData.chebyshev(actor.grid_pos, other.grid_pos)
		var score: float = -float(dist) * 1.5
		score += (1.0 - float(other.current_hp) / maxf(1.0, float(other.max_hp))) * 6.0
		if other.current_hp <= Dice.average(actor.damage_expr()) * 1.5:
			score += 5.0
		if score > best_score:
			best_score = score
			best = other
	return best

# ------------------------------------------------------------- movement

static func _reposition(actor: Entity, tm: TurnManager, target: Entity) -> Array:
	var map: MapData = tm.map
	if Combat.can_attack(actor, target, map) and actor.reach() > 1:
		# Already able to shoot; only move if standing in the open with a
		# better covered tile within one step.
		return []
	if Combat.can_attack(actor, target, map):
		return []

	var reach := tm.reachable(actor)
	var cost: Dictionary = reach["cost"]
	var best_cell: Vector2i = actor.grid_pos
	var best_score := -INF
	for cell: Vector2i in cost:
		if _off_post(actor, cell):
			continue
		var score := _score_cell(actor, cell, target, map)
		# Nearer options win ties so movement looks purposeful.
		score -= float(cost[cell]) * 0.05
		if score > best_score:
			best_score = score
			best_cell = cell

	# Nothing useful in range: try dashing to close the gap.
	if best_cell == actor.grid_pos and actor.reach() <= 1 and tm.has_action(actor) \
			and actor.guard_radius <= 0:
		var far_path := map.find_path(actor.grid_pos, target.grid_pos, tm.occupied_tiles(actor), true)
		if far_path.size() > 2 and tm.dash(actor):
			reach = tm.reachable(actor)
			cost = reach["cost"]
			for cell: Vector2i in cost:
				var score := _score_cell(actor, cell, target, map)
				if score > best_score:
					best_score = score
					best_cell = cell

	if best_cell == actor.grid_pos:
		return []
	var path: Array = MapData.reconstruct_path(reach["came_from"], best_cell)
	var result := tm.move_along(actor, path)
	var events: Array = (result["events"] as Array).duplicate()
	events.push_front({
		"type": "move", "actor": actor, "path": result["steps"],
		"text": "%s moves." % actor.display_name,
	})
	return events

## Opens the first shut door between the actor and its target, when one is what
## stands in the way. Returns [] if there is no such door or no action left.
static func _open_the_way(actor: Entity, tm: TurnManager, goal: Vector2i) -> Array:
	if not tm.has_action(actor) or actor.guard_radius > 0:
		return []
	var map: MapData = tm.map
	var path: Array = map.find_path(actor.grid_pos, goal,
		tm.occupied_tiles(actor), true, true)
	if path.is_empty():
		return []
	var door: Vector2i = MapData.closed_door_on(map, path)
	if door == Vector2i(-1, -1) or MapData.chebyshev(actor.grid_pos, door) > 1:
		return []
	if not map.open_door(door):
		return []
	tm.spend_action(actor)
	return [{"type": "door", "cell": door, "open": true,
		"text": "%s opens the door." % actor.display_name}]

## Shuts an open door the target would have to come through, cutting the line
## between them. Costs the bonus, so it never replaces the attack.
static func _shut_a_door(actor: Entity, tm: TurnManager, target: Entity) -> Array:
	if not tm.has_bonus(actor):
		return []
	var map: MapData = tm.map
	for dir: Vector2i in MapData.DIRS_8:
		var cell: Vector2i = actor.grid_pos + dir
		if map.tile_at(cell) != MapData.Tile.DOOR or not map.is_door_open(cell):
			continue
		if tm.entity_at(cell) != null:
			continue
		# Only worth a turn if it actually breaks the line between them; a door
		# behind the actor changes nothing.
		map.close_door(cell)
		if map.has_line_of_sight(actor.grid_pos, target.grid_pos):
			map.open_door(cell)
			continue
		tm.spend_bonus(actor)
		return [{"type": "door", "cell": cell, "open": false,
			"text": "%s pulls the door shut." % actor.display_name}]
	return []

## Sends one unaware ally toward the trouble. Once only, and it costs the bonus.
static func _shout(actor: Entity, tm: TurnManager, target: Entity) -> Array:
	if not tm.has_bonus(actor):
		return []
	for ally: Entity in tm.allies_of(actor):
		if ally == actor or not ally.is_alive():
			continue
		if ally.alerted_to != Vector2i(-1, -1):
			continue
		if MapData.chebyshev(ally.grid_pos, actor.grid_pos) > SHOUT_RANGE:
			continue
		if tm.map.has_line_of_sight(ally.grid_pos, target.grid_pos):
			continue  # already in the fight
		ally.alerted_to = target.grid_pos
		tm.spend_bonus(actor)
		return [{"type": "info",
			"text": "%s shouts for help." % actor.display_name}]
	return []

## True if `cell` is outside a guard's leash.
static func _off_post(actor: Entity, cell: Vector2i) -> bool:
	if actor.guard_radius <= 0:
		return false
	return MapData.chebyshev(cell, actor.home_pos) > actor.guard_radius

## Higher is better: in weapon range, with line of sight, ideally behind cover.
static func _score_cell(actor: Entity, cell: Vector2i, target: Entity, map: MapData) -> float:
	var dist: int = MapData.chebyshev(cell, target.grid_pos)
	var score := 0.0
	var reach: int = actor.reach()
	if reach <= 1:
		score -= float(dist) * 2.0
		if dist == 1:
			score += 12.0
	else:
		if dist <= reach and map.has_line_of_sight(cell, target.grid_pos):
			score += 14.0
			# Keep some distance so melee cannot simply walk up.
			score += clampf(float(dist) - 2.0, 0.0, 4.0) * 1.5
			# Cover works in the shooter's favour too.
			score += float(MapData.cover_bonus(map.cover_between(target.grid_pos, cell))) * 0.8
		else:
			score -= float(dist) * 1.5
	return score

static func _retreat(actor: Entity, tm: TurnManager, hostiles: Array) -> Array:
	var reach := tm.reachable(actor)
	var cost: Dictionary = reach["cost"]
	var best_cell: Vector2i = actor.grid_pos
	var best_score := -INF
	for cell: Vector2i in cost:
		var score := 0.0
		for other: Entity in hostiles:
			score += float(MapData.chebyshev(cell, other.grid_pos))
			if not tm.map.has_line_of_sight(cell, other.grid_pos):
				score += 6.0
		if score > best_score:
			best_score = score
			best_cell = cell
	if best_cell == actor.grid_pos:
		return []
	var path: Array = MapData.reconstruct_path(reach["came_from"], best_cell)
	var result := tm.move_along(actor, path)
	var events: Array = (result["events"] as Array).duplicate()
	events.push_front({
		"type": "move", "actor": actor, "path": result["steps"],
		"text": "%s breaks off, badly hurt." % actor.display_name,
	})
	return events

## No one in sight: drift a few tiles so floors do not feel like statues.
static func _wander(actor: Entity, tm: TurnManager) -> Array:
	var summoned: bool = actor.alerted_to != Vector2i(-1, -1)
	if summoned:
		# Whoever we are following went somewhere. If a shut door is what stands
		# in the way, opening it is the turn.
		var opened := _open_the_way(actor, tm, actor.alerted_to)
		if not opened.is_empty():
			return opened
	if not summoned and not Dice.chance(0.45):
		return []
	var reach := tm.reachable(actor)
	var cells: Array = (reach["cost"] as Dictionary).keys()
	cells.erase(actor.grid_pos)
	if cells.is_empty():
		return []
	var destination: Vector2i = Dice.pick(cells)
	if summoned:
		# Head for the shout, and stop chasing it once we get there.
		var best := INF
		for cell: Vector2i in cells:
			var d := float(MapData.chebyshev(cell, actor.alerted_to))
			if d < best:
				best = d
				destination = cell
		if MapData.chebyshev(destination, actor.alerted_to) <= 1:
			actor.alerted_to = Vector2i(-1, -1)
	var path: Array = MapData.reconstruct_path(reach["came_from"], destination)
	var result := tm.move_along(actor, path)
	var events: Array = (result["events"] as Array).duplicate()
	events.push_front({
		"type": "move", "actor": actor, "path": result["steps"], "quiet": true,
		"text": "",
	})
	return events

# -------------------------------------------------------------- attacking

static func _attack_if_able(actor: Entity, tm: TurnManager, target: Entity) -> Array:
	if not tm.has_action(actor):
		return []
	if not Combat.can_attack(actor, target, tm.map):
		return []
	tm.spend_action(actor)
	var event := Combat.weapon_attack(actor, target, tm.map, "attack")
	var events: Array = [event]
	if not target.is_alive():
		events.append({"type": "death", "target": target,
			"text": "%s is out of the fight!" % target.display_name})
	return events
