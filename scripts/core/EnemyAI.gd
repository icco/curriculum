class_name EnemyAI
extends RefCounted

## Decides and executes an enemy turn. State is mutated immediately and an
## ordered event list is returned, so the presentation layer can replay the
## turn as animation while the rules stay headlessly testable.

const AGGRO_RANGE := 13
const FLEE_THRESHOLD := 0.25

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
	var hurt: bool = float(actor.current_hp) / maxf(1.0, float(actor.max_hp)) <= FLEE_THRESHOLD

	if hurt and actor.rank == Entity.Rank.GRUNT:
		events.append_array(_retreat(actor, tm, hostiles))
		return events

	# Reposition, then swing. Ranged fighters look for a spot with cover.
	events.append_array(_reposition(actor, tm, target))
	events.append_array(_attack_if_able(actor, tm, target))

	# Teachers and monitors press the advantage with a bonus-action follow-up.
	if actor.rank != Entity.Rank.GRUNT and target.is_alive() and tm.has_bonus(actor):
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
		var score := _score_cell(actor, cell, target, map)
		# Nearer options win ties so movement looks purposeful.
		score -= float(cost[cell]) * 0.05
		if score > best_score:
			best_score = score
			best_cell = cell

	# Nothing useful in range: try dashing to close the gap.
	if best_cell == actor.grid_pos and actor.reach() <= 1 and tm.has_action(actor):
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
	if not Dice.chance(0.45):
		return []
	var reach := tm.reachable(actor)
	var cells: Array = (reach["cost"] as Dictionary).keys()
	cells.erase(actor.grid_pos)
	if cells.is_empty():
		return []
	var destination: Vector2i = Dice.pick(cells)
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
