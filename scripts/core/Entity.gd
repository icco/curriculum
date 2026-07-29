class_name Entity
extends RefCounted

## A combatant. Pure data + rules math; it never reaches back into the map or
## the scene tree, which keeps it free of cyclic dependencies.

enum Team { PLAYER, ENEMY }
enum Rank { GRUNT, ELITE, BOSS, HERO }
## Content resources refer to abilities by enum; stats stay string-keyed.
enum Ability { STR, DEX, CON, INT, WIS, CHA }

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]

static func ability_key(ability: Ability) -> String:
	return ABILITIES[clampi(int(ability), 0, ABILITIES.size() - 1)]

static func ability_from_key(key: String) -> Ability:
	var index := ABILITIES.find(key.to_lower())
	return (index if index >= 0 else Ability.STR) as Ability

var id: String = "entity"
## Sprite lookup key; separate from `id` so save ids and art file names can
## differ (the protagonist is "player_01" but its art is entities/player.png).
var art_id: String = "entity"
var display_name: String = "Someone"
var team: int = Team.ENEMY
var rank: int = Rank.GRUNT
var level: int = 1

var stats: Dictionary = {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}
var ac_base: int = 10
var max_hp: int = 8
var current_hp: int = 8
var speed_tiles: int = 6
var proficiency: int = 2

# Attacks
var attack_ability: String = "str"
var weapon_name: String = "Fists"
var damage_dice: String = "1d4"
var attack_range: int = 1

# Magic
var casting_ability: String = "int"
var spell_slots: Dictionary = {}      # {"level_1": 2}
var slots_used: Dictionary = {}       # {"level_1": 1}
var unlocked_spells: Array = []       # spell ids
var known_spells: Array = []          # what this entity may cast this run

# Gear + effects
var equipped_gear: Dictionary = {}    ## slot key -> LootItemData
var conditions: Dictionary = {}       # id -> rounds remaining (-1 = until removed)
var bonus_ac: int = 0                 # from conditions/gear, recomputed on demand

# Placement + presentation
var grid_pos: Vector2i = Vector2i.ZERO
## Bosses guard a post rather than roaming: they will not chase further than
## `guard_radius` from `home_pos`. Zero means no leash.
var home_pos: Vector2i = Vector2i.ZERO
var guard_radius: int = 0
## Somewhere a shout came from. A wandering enemy heads here instead of drifting.
var alerted_to: Vector2i = Vector2i(-1, -1)
var shuts_doors: bool = false
var calls_allies: bool = false
var tint: Color = Color(0.8, 0.8, 0.9)
var xp_value: int = 5

# ---------------------------------------------------------------- ability math

static func ability_mod(score: int) -> int:
	return int(floor((score - 10) / 2.0))

func mod(ability: String) -> int:
	return ability_mod(int(stats.get(ability, 10)))

func ac() -> int:
	var total := ac_base + mod("dex") + bonus_ac + gear_ac_bonus()
	if has_condition("shielded"):
		total += 5
	return total

func save_bonus(ability: String) -> int:
	# Everyone is proficient in their own best save; keeps the math readable.
	var bonus := mod(ability)
	if ability == best_save_ability():
		bonus += proficiency
	if has_condition("stunned") and (ability == "dex" or ability == "str"):
		bonus -= 5
	return bonus

func best_save_ability() -> String:
	var best := "con"
	var best_score := -99
	for a: String in ABILITIES:
		if int(stats.get(a, 10)) > best_score:
			best_score = int(stats.get(a, 10))
			best = a
	return best

func attack_bonus() -> int:
	return mod(attack_ability) + proficiency + gear_attack_bonus()

func spell_attack_bonus() -> int:
	return mod(casting_ability) + proficiency

func spell_save_dc() -> int:
	return 8 + proficiency + mod(casting_ability)

func weapon() -> LootItemData:
	return equipped_gear.get("weapon", null)

func damage_expr() -> String:
	var held := weapon()
	var dice: String = damage_dice
	if held != null and held.damage_dice != "":
		dice = held.damage_dice
	var flat: int = mod(attack_ability) + gear_damage_bonus()
	if flat == 0:
		return dice
	return "%s%s%d" % [dice, "+" if flat > 0 else "", flat]

func weapon_label() -> String:
	var held := weapon()
	return held.display_name if held != null else weapon_name

func reach() -> int:
	var held := weapon()
	return held.range_tiles if held != null else attack_range

func gear_attack_bonus() -> int:
	var total := 0
	for item: LootItemData in equipped_gear.values():
		total += item.attack_bonus
	return total

func gear_damage_bonus() -> int:
	var total := 0
	for item: LootItemData in equipped_gear.values():
		total += item.damage_bonus
	return total

func gear_ac_bonus() -> int:
	var total := 0
	for item: LootItemData in equipped_gear.values():
		total += item.ac_bonus
	return total

## Equipped gear as slot -> id, for saving.
func gear_ids() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in equipped_gear:
		out[slot] = str((equipped_gear[slot] as LootItemData).id)
	return out

func equip_ids(ids: Dictionary) -> void:
	equipped_gear.clear()
	for slot: String in ids:
		var item := Roster.loot_item(StringName(ids[slot]))
		if item != null:
			equipped_gear[slot] = item

# ------------------------------------------------------------------- lifecycle

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> int:
	var dealt: int = mini(amount, current_hp)
	current_hp = maxi(0, current_hp - amount)
	return dealt

func heal(amount: int) -> int:
	var healed: int = mini(amount, max_hp - current_hp)
	current_hp += healed
	return healed

func is_hostile_to(other: Entity) -> bool:
	return team != other.team

# ------------------------------------------------------------------ conditions

func add_condition(cond: String, rounds: int = 1) -> void:
	conditions[cond] = maxi(int(conditions.get(cond, 0)), rounds)

func has_condition(cond: String) -> bool:
	return conditions.has(cond)

## Ticks condition durations at the start of this entity's turn.
func tick_conditions() -> Array:
	var expired: Array = []
	for cond: String in conditions.keys():
		var left := int(conditions[cond])
		if left < 0:
			continue
		left -= 1
		if left <= 0:
			conditions.erase(cond)
			expired.append(cond)
		else:
			conditions[cond] = left
	return expired

func can_act() -> bool:
	return is_alive() and not has_condition("stunned")

# ---------------------------------------------------------------- spell slots

func slots_left(slot_level: int) -> int:
	var key := "level_%d" % slot_level
	return int(spell_slots.get(key, 0)) - int(slots_used.get(key, 0))

func spend_slot(slot_level: int) -> bool:
	if slot_level <= 0:
		return true  # cantrip
	if slots_left(slot_level) <= 0:
		return false
	var key := "level_%d" % slot_level
	slots_used[key] = int(slots_used.get(key, 0)) + 1
	return true

func restore_all_slots() -> void:
	slots_used.clear()

# ------------------------------------------------------------ serialisation

func to_dict() -> Dictionary:
	return {
		"id": id,
		"art_id": art_id,
		"name": display_name,
		"team": team,
		"rank": rank,
		"level": level,
		"stats": stats.duplicate(),
		"ac": ac_base,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"speed_tiles": speed_tiles,
		"proficiency": proficiency,
		"attack_ability": attack_ability,
		"casting_ability": casting_ability,
		"weapon_name": weapon_name,
		"damage_dice": damage_dice,
		"attack_range": attack_range,
		"shuts_doors": shuts_doors,
		"calls_allies": calls_allies,
		"spell_slots": spell_slots.duplicate(),
		"slots_used": slots_used.duplicate(),
		"unlocked_spells": unlocked_spells.duplicate(),
		"known_spells": known_spells.duplicate(),
		"equipped_gear": gear_ids(),
		"conditions": conditions.duplicate(),
		"xp_value": xp_value,
		"tint": tint.to_html(false),
	}

static func from_dict(data: Dictionary) -> Entity:
	var e := Entity.new()
	e.id = str(data.get("id", "entity"))
	e.art_id = str(data.get("art_id", e.id))
	e.display_name = str(data.get("name", "Someone"))
	e.team = int(data.get("team", Team.ENEMY))
	e.rank = int(data.get("rank", Rank.GRUNT))
	e.level = int(data.get("level", 1))
	var s: Dictionary = data.get("stats", {})
	for a: String in ABILITIES:
		e.stats[a] = int(s.get(a, 10))
	e.ac_base = int(data.get("ac", 10))
	e.max_hp = int(data.get("max_hp", 8))
	e.current_hp = int(data.get("current_hp", e.max_hp))
	e.speed_tiles = int(data.get("speed_tiles", 6))
	e.proficiency = int(data.get("proficiency", 2))
	e.attack_ability = str(data.get("attack_ability", "str"))
	e.casting_ability = str(data.get("casting_ability", "int"))
	e.weapon_name = str(data.get("weapon_name", "Fists"))
	e.damage_dice = str(data.get("damage_dice", "1d4"))
	e.attack_range = int(data.get("attack_range", 1))
	e.shuts_doors = bool(data.get("shuts_doors", false))
	e.calls_allies = bool(data.get("calls_allies", false))
	e.spell_slots = (data.get("spell_slots", {}) as Dictionary).duplicate()
	e.slots_used = (data.get("slots_used", {}) as Dictionary).duplicate()
	e.unlocked_spells = (data.get("unlocked_spells", []) as Array).duplicate()
	e.known_spells = (data.get("known_spells", e.unlocked_spells) as Array).duplicate()
	e.equip_ids(data.get("equipped_gear", {}))
	e.conditions = (data.get("conditions", {}) as Dictionary).duplicate()
	e.xp_value = int(data.get("xp_value", 5))
	e.loot_table = str(data.get("loot_table", ""))
	if data.has("tint"):
		e.tint = Color(str(data["tint"]))
	return e

