class_name Roster
extends RefCounted

## Loads the JSON content files and turns them into Entities and loot.

const SPELLS_PATH := "res://data/spells.json"
const ENEMIES_PATH := "res://data/enemies.json"
const LOOT_PATH := "res://data/loot.json"

static var _spells: Dictionary = {}
static var _enemies: Dictionary = {}
static var _loot: Dictionary = {}
static var _loaded: bool = false

static func load_data(force: bool = false) -> void:
	if _loaded and not force:
		return
	_spells = _read_json(SPELLS_PATH)
	_enemies = _read_json(ENEMIES_PATH)
	_loot = _read_json(LOOT_PATH)
	_loaded = true

static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Roster: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Roster: %s is not a JSON object" % path)
		return {}
	return parsed

# ------------------------------------------------------------------ spells

static func spells() -> Dictionary:
	load_data()
	return _spells

static func spell(id: String) -> Dictionary:
	load_data()
	return _spells.get(id, {})

static func starting_spells() -> Array:
	load_data()
	var out: Array = []
	for id: String in _spells:
		if bool(_spells[id].get("starting", false)):
			out.append(id)
	out.sort()
	return out

static func unlockable_spells() -> Array:
	load_data()
	var out: Array = []
	for id: String in _spells:
		if not bool(_spells[id].get("starting", false)):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(_spells[a].get("unlock_cost", 0)) < int(_spells[b].get("unlock_cost", 0)))
	return out

# ----------------------------------------------------------------- enemies

static func enemies() -> Dictionary:
	load_data()
	return _enemies

static func ids_for_role(role: String, depth: int) -> Array:
	load_data()
	var out: Array = []
	for id: String in _enemies:
		var e: Dictionary = _enemies[id]
		if str(e.get("role", "grunt")) != role:
			continue
		if depth < int(e.get("min_depth", 1)) or depth > int(e.get("max_depth", 99)):
			continue
		out.append(id)
	out.sort()
	return out

## Builds an enemy for a role at a depth, scaling slightly with the floor.
static func make_enemy(role: String, depth: int) -> Entity:
	load_data()
	var pool := ids_for_role(role, depth)
	if pool.is_empty():
		pool = ids_for_role(role, clampi(depth, 1, 12))
	if pool.is_empty():
		pool = _enemies.keys()
	var id: String = Dice.pick(pool)
	return make_enemy_by_id(id, depth)

static func make_enemy_by_id(id: String, depth: int) -> Entity:
	load_data()
	var def: Dictionary = _enemies.get(id, {})
	var e := Entity.new()
	e.id = id
	e.display_name = str(def.get("name", "Student"))
	e.team = Entity.Team.ENEMY
	match str(def.get("role", "grunt")):
		"elite": e.rank = Entity.Rank.ELITE
		"boss": e.rank = Entity.Rank.BOSS
		_: e.rank = Entity.Rank.GRUNT
	var stats: Dictionary = def.get("stats", {})
	for a: String in Entity.ABILITIES:
		e.stats[a] = int(stats.get(a, 10))
	e.ac_base = int(def.get("ac", 11)) - Entity.ability_mod(e.stats["dex"])
	var hp: int = maxi(1, Dice.roll_expr(str(def.get("hp", "2d8"))))
	# Deeper floors field tougher versions of the same archetypes.
	var scale: int = maxi(0, depth - int(def.get("min_depth", 1)))
	hp += scale * 2
	e.max_hp = hp
	e.current_hp = hp
	e.speed_tiles = int(def.get("speed_tiles", 6))
	e.proficiency = int(def.get("proficiency", 2))
	e.attack_ability = str(def.get("attack_ability", "str"))
	e.casting_ability = str(def.get("casting_ability", "int"))
	e.weapon_name = str(def.get("weapon_name", "Fists"))
	e.damage_dice = str(def.get("damage_dice", "1d4"))
	e.attack_range = int(def.get("attack_range", 1))
	e.xp_value = int(def.get("xp_value", 5)) + scale
	e.tint = Color(str(def.get("tint", "ef5350")))
	e.level = maxi(1, depth)
	return e

# ------------------------------------------------------------------ player

## The protagonist, built from GlobalState so time-loop upgrades carry over.
static func make_player(global: Dictionary = {}) -> Entity:
	load_data()
	var e := Entity.new()
	e.id = "player_01"
	e.display_name = str(global.get("player_name", "Wren"))
	e.team = Entity.Team.PLAYER
	e.rank = Entity.Rank.HERO
	e.level = 1
	e.stats = {"str": 10, "dex": 14, "con": 12, "int": 16, "wis": 12, "cha": 10}
	var bonus_stats: Dictionary = global.get("stat_bonuses", {})
	for a: String in Entity.ABILITIES:
		e.stats[a] = int(e.stats[a]) + int(bonus_stats.get(a, 0))
	e.ac_base = 10 + int(global.get("bonus_ac", 0))
	e.max_hp = 12 + int(global.get("bonus_hp", 0))
	e.current_hp = e.max_hp
	e.speed_tiles = 6 + int(global.get("bonus_speed", 0))
	e.proficiency = 2
	e.attack_ability = "dex"
	e.casting_ability = "int"
	e.weapon_name = "Bare Hands"
	e.damage_dice = "1d4"
	e.attack_range = 1
	e.tint = ArtFactory.TEAM_PLAYER
	e.xp_value = 0

	var slots: Dictionary = {"level_1": 2 + int(global.get("bonus_slots_1", 0))}
	if int(global.get("bonus_slots_2", 0)) > 0:
		slots["level_2"] = int(global.get("bonus_slots_2", 0))
	if int(global.get("bonus_slots_3", 0)) > 0:
		slots["level_3"] = int(global.get("bonus_slots_3", 0))
	e.spell_slots = slots

	var known: Array = global.get("unlocked_spells", []).duplicate()
	for id: String in starting_spells():
		if not known.has(id):
			known.append(id)
	e.unlocked_spells = known
	e.known_spells = known.duplicate()
	return e

# -------------------------------------------------------------------- loot

static func roll_loot(table: String, depth: int) -> Dictionary:
	load_data()
	var entries: Array = _loot.get(table, [])
	var weights: Dictionary = {}
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if depth < int(entry.get("min_depth", 1)):
			continue
		weights[i] = float(entry.get("weight", 1))
	if weights.is_empty():
		return {}
	var pick: Variant = Dice.weighted(weights)
	if pick == null:
		return {}
	return (entries[int(pick)] as Dictionary).duplicate(true)
