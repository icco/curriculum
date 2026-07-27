class_name Combat
extends RefCounted

## D&D 5e-flavoured resolution. Every function is pure: it takes entities and
## a map, mutates hit points/conditions, and returns event dictionaries that
## the UI can animate and print.

# ---------------------------------------------------------------- rolls

## Rolls damage, doubling the dice (not the modifier) on a critical hit.
static func roll_damage(expr: String, crit: bool = false) -> int:
	var parsed := Dice.parse_expr(expr)
	var count: int = parsed.count * (2 if crit else 1)
	var total: int = parsed.flat
	if parsed.sides > 0:
		total += Dice.roll(count, parsed.sides)
	return maxi(0, total)

## `d20 + bonus` against a target number, with 5e crit/fumble rules.
static func d20_check(bonus: int, target: int) -> Dictionary:
	var roll := Dice.d20()
	var total := roll + bonus
	var crit: bool = roll == 20
	var fumble: bool = roll == 1
	return {
		"roll": roll,
		"bonus": bonus,
		"total": total,
		"target": target,
		"crit": crit,
		"fumble": fumble,
		"success": crit or (not fumble and total >= target),
	}

static func saving_throw(target: Entity, ability: String, dc: int) -> Dictionary:
	var result := d20_check(target.save_bonus(ability), dc)
	result["ability"] = ability
	result["dc"] = dc
	return result

# --------------------------------------------------------------- attacks

## Effective AC of `defender` against an attack originating at `from`.
static func defended_ac(defender: Entity, from: Vector2i, map: MapData) -> Dictionary:
	var cover := map.cover_between(from, defender.grid_pos)
	return {"ac": defender.ac() + MapData.cover_bonus(cover), "cover": cover}

static func can_attack(attacker: Entity, defender: Entity, map: MapData) -> bool:
	if not attacker.is_alive() or not defender.is_alive():
		return false
	if MapData.chebyshev(attacker.grid_pos, defender.grid_pos) > attacker.reach():
		return false
	if attacker.reach() <= 1:
		return true
	return map.has_line_of_sight(attacker.grid_pos, defender.grid_pos)

## A weapon attack. Returns an event describing everything that happened.
static func weapon_attack(attacker: Entity, defender: Entity, map: MapData, tag: String = "attack") -> Dictionary:
	var shield := defended_ac(defender, attacker.grid_pos, map)
	var check := d20_check(attacker.attack_bonus(), int(shield["ac"]))
	var event := {
		"type": tag,
		"attacker": attacker,
		"target": defender,
		"weapon": attacker.weapon_label(),
		"cover": shield["cover"],
		"roll": check["roll"],
		"total": check["total"],
		"target_ac": shield["ac"],
		"hit": check["success"],
		"crit": check["crit"],
		"damage": 0,
		"killed": false,
	}
	if check["success"]:
		var dmg := roll_damage(attacker.damage_expr(), check["crit"])
		event["damage"] = defender.take_damage(dmg)
		event["killed"] = not defender.is_alive()
	event["text"] = describe_attack(event)
	return event

static func describe_attack(event: Dictionary) -> String:
	var attacker: Entity = event["attacker"]
	var target: Entity = event["target"]
	var cover_note := ""
	if int(event["cover"]) != MapData.Cover.NONE:
		cover_note = " (%s, AC %d)" % [MapData.cover_name(event["cover"]), int(event["target_ac"])]
	if not bool(event["hit"]):
		return "%s misses %s with %s — rolled %d vs AC %d%s." % [
			attacker.display_name, target.display_name, event["weapon"],
			int(event["total"]), int(event["target_ac"]), cover_note]
	var crit_note: String = "CRITICAL! " if bool(event["crit"]) else ""
	var text := "%s%s hits %s with %s for %d damage." % [
		crit_note, attacker.display_name, target.display_name, event["weapon"], int(event["damage"])]
	if bool(event["killed"]):
		text += " %s is out of the fight!" % target.display_name
	return text

# ----------------------------------------------------------------- spells

## Cantrips gain dice at levels 5 and 11, as in 5e. Levelled spells do not.
static func spell_damage_expr(caster: Entity, spell: Dictionary) -> String:
	var expr := str(spell.get("damage", "1d6"))
	if int(spell.get("level", 0)) != 0:
		return expr
	var multiplier := 1
	if caster.level >= 5:
		multiplier += 1
	if caster.level >= 11:
		multiplier += 1
	if multiplier == 1:
		return expr
	var parsed := Dice.parse_expr(expr)
	if parsed.sides <= 0:
		return expr
	var flat: int = parsed.flat
	var suffix: String = "" if flat == 0 else ("+%d" % flat if flat > 0 else str(flat))
	return "%dd%d%s" % [parsed.count * multiplier, parsed.sides, suffix]

static func spell_slot_available(caster: Entity, spell: Dictionary) -> bool:
	var level := int(spell.get("level", 0))
	return level == 0 or caster.slots_left(level) > 0

## Every entity a spell would touch when aimed at `center`.
static func spell_targets(caster: Entity, spell: Dictionary, center: Vector2i, entities: Array, map: MapData) -> Array:
	var aoe := int(spell.get("aoe", 0))
	var target_kind := str(spell.get("target", "enemy"))
	var out: Array = []
	if target_kind == "self":
		return [caster]
	for e: Entity in entities:
		if not e.is_alive():
			continue
		if aoe > 0:
			if MapData.chebyshev(e.grid_pos, center) > aoe:
				continue
			if not map.has_line_of_sight(center, e.grid_pos):
				continue
		elif e.grid_pos != center:
			continue
		if target_kind == "enemy" and not e.is_hostile_to(caster):
			continue
		if target_kind == "ally" and e.is_hostile_to(caster):
			continue
		out.append(e)
	return out

## Resolves a spell. `center` is the aimed tile; `entities` is the full roster.
## Returns a list of events; the first one is always of type "cast".
static func cast_spell(caster: Entity, spell: Dictionary, center: Vector2i, entities: Array, map: MapData) -> Array:
	var events: Array = []
	var level := int(spell.get("level", 0))
	if not caster.spend_slot(level):
		return [{"type": "fizzle", "text": "%s has no level %d slots left." % [caster.display_name, level]}]

	events.append({
		"type": "cast",
		"attacker": caster,
		"spell": spell,
		"center": center,
		"text": "%s casts %s." % [caster.display_name, str(spell.get("name", "a spell"))],
	})

	var kind := str(spell.get("kind", "attack"))
	match kind:
		"teleport":
			var from := caster.grid_pos
			caster.grid_pos = center
			events.append({
				"type": "teleport", "attacker": caster, "from": from, "to": center,
				"text": "%s blinks from %s to %s." % [caster.display_name, str(from), str(center)],
			})
		"buff":
			var effect: Dictionary = spell.get("effect", {})
			var cond := str(effect.get("condition", "shielded"))
			caster.add_condition(cond, int(effect.get("rounds", 1)))
			events.append({
				"type": "buff", "attacker": caster, "condition": cond,
				"text": "%s is %s." % [caster.display_name, cond],
			})
		"heal":
			var amount := roll_damage(str(spell.get("damage", "1d8"))) + caster.mod(caster.casting_ability)
			var healed := caster.heal(amount)
			events.append({
				"type": "heal", "attacker": caster, "target": caster, "amount": healed,
				"text": "%s recovers %d hit points." % [caster.display_name, healed],
			})
		_:
			for target: Entity in spell_targets(caster, spell, center, entities, map):
				events.append_array(_resolve_offensive(caster, spell, target, map))
			if events.size() == 1:
				events.append({"type": "whiff", "text": "The spell fizzles against empty air."})
	return events

static func _resolve_offensive(caster: Entity, spell: Dictionary, target: Entity, map: MapData) -> Array:
	var kind := str(spell.get("kind", "attack"))
	var spell_name := str(spell.get("name", "the spell"))
	var events: Array = []

	match kind:
		"attack":
			var shield := defended_ac(target, caster.grid_pos, map)
			var check := d20_check(caster.spell_attack_bonus(), int(shield["ac"]))
			var event := {
				"type": "spell_attack", "attacker": caster, "target": target, "spell": spell,
				"roll": check["roll"], "total": check["total"], "target_ac": shield["ac"],
				"cover": shield["cover"], "hit": check["success"], "crit": check["crit"],
				"damage": 0, "killed": false,
			}
			if check["success"]:
				var dmg := roll_damage(spell_damage_expr(caster, spell), check["crit"])
				event["damage"] = target.take_damage(dmg)
				event["killed"] = not target.is_alive()
				var crit_note: String = "CRITICAL! " if bool(check["crit"]) else ""
				event["text"] = "%s%s strikes %s for %d %s damage." % [
					crit_note, spell_name, target.display_name, int(event["damage"]),
					str(spell.get("damage_type", "force"))]
			else:
				event["text"] = "%s streaks past %s (rolled %d vs AC %d)." % [
					spell_name, target.display_name, int(check["total"]), int(shield["ac"])]
			events.append(event)

		"auto":
			var darts := int(spell.get("darts", 1))
			var total := 0
			for i in darts:
				total += roll_damage(spell_damage_expr(caster, spell))
			var dealt := target.take_damage(total)
			events.append({
				"type": "spell_auto", "attacker": caster, "target": target, "spell": spell,
				"damage": dealt, "killed": not target.is_alive(),
				"text": "%s hits %s automatically for %d damage." % [spell_name, target.display_name, dealt],
			})

		"save":
			var ability := str(spell.get("save_ability", "dex"))
			var dc := caster.spell_save_dc()
			var save := saving_throw(target, ability, dc)
			var base := roll_damage(spell_damage_expr(caster, spell))
			var dmg := base
			if bool(save["success"]):
				dmg = int(base / 2.0) if str(spell.get("save_effect", "half")) == "half" else 0
			var dealt := target.take_damage(dmg)
			var event := {
				"type": "spell_save", "attacker": caster, "target": target, "spell": spell,
				"save_roll": save["roll"], "save_total": save["total"], "dc": dc,
				"saved": save["success"], "damage": dealt, "killed": not target.is_alive(),
				"condition": "",
			}
			var effect: Dictionary = spell.get("effect", {})
			if not bool(save["success"]) and not effect.is_empty() and target.is_alive():
				var cond := str(effect.get("condition", ""))
				if cond != "":
					target.add_condition(cond, int(effect.get("rounds", 1)))
					event["condition"] = cond
			var outcome: String = "resists" if bool(save["success"]) else "fails"
			event["text"] = "%s %s the %s save (%d vs DC %d) and takes %d." % [
				target.display_name, outcome, ability.to_upper(), int(save["total"]), dc, dealt]
			if event["condition"] != "":
				event["text"] += " Now %s!" % event["condition"]
			events.append(event)

	if not target.is_alive():
		events.append({
			"type": "death", "target": target,
			"text": "%s is out of the fight!" % target.display_name,
		})
	return events

# ------------------------------------------------------------- conditions

## Applied at the start of an entity's turn, before it acts.
static func tick_start_of_turn(entity: Entity) -> Array:
	var events: Array = []
	if entity.has_condition("burning"):
		var dmg := entity.take_damage(Dice.roll(1, 4))
		events.append({
			"type": "condition", "target": entity, "damage": dmg,
			"text": "%s burns for %d." % [entity.display_name, dmg],
		})
		if not entity.is_alive():
			events.append({"type": "death", "target": entity,
				"text": "%s is out of the fight!" % entity.display_name})
	for expired: String in entity.tick_conditions():
		events.append({
			"type": "condition_end", "target": entity, "condition": expired,
			"text": "%s is no longer %s." % [entity.display_name, expired],
		})
	return events

## Movement allowance after conditions and gear.
static func movement_for(entity: Entity) -> int:
	var speed := entity.speed_tiles
	if entity.has_condition("slowed"):
		speed = maxi(1, int(speed / 2.0))
	if entity.has_condition("stunned"):
		return 0
	return speed
