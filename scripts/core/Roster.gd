class_name Roster
extends RefCounted

## Content access. Everything comes from one ContentLibrary resource, indexed by
## id on first use.

const LIBRARY_PATH := "res://resources/content_library.tres"

const BASE_HP := 20
const HP_PER_LEVEL := 6

static var _library: ContentLibrary
static var _spells: Dictionary = {}      ## StringName -> SpellData
static var _enemies: Dictionary = {}     ## StringName -> EnemyData
static var _loot: Dictionary = {}        ## StringName -> LootItemData
static var _skills: Dictionary = {}      ## StringName -> SkillNodeData

static func load_data(force: bool = false) -> void:
	if _library != null and not force:
		return
	_library = load(LIBRARY_PATH) as ContentLibrary
	if _library == null:
		push_error("Roster: cannot load %s" % LIBRARY_PATH)
		_library = ContentLibrary.new()
	_spells.clear()
	_enemies.clear()
	_loot.clear()
	_skills.clear()
	for s: SpellData in _library.spells:
		_spells[s.id] = s
	for e: EnemyData in _library.enemies:
		_enemies[e.id] = e
	for i: LootItemData in _library.loot:
		_loot[i.id] = i
	for n: SkillNodeData in _library.skills:
		_skills[n.id] = n

# ------------------------------------------------------------------ spells

static func spells() -> Array[SpellData]:
	load_data()
	return _library.spells

static func enemy(id: StringName) -> EnemyData:
	load_data()
	return _enemies.get(id, null)

static func spell(id: StringName) -> SpellData:
	load_data()
	return _spells.get(id, null)

static func starting_spells() -> Array[StringName]:
	load_data()
	var out: Array[StringName] = []
	for s: SpellData in _library.spells:
		if s.starting:
			out.append(s.id)
	return out

static func unlockable_spells() -> Array[SpellData]:
	load_data()
	var out: Array[SpellData] = []
	for s: SpellData in _library.spells:
		if not s.starting:
			out.append(s)
	out.sort_custom(func(a: SpellData, b: SpellData) -> bool: return a.unlock_cost < b.unlock_cost)
	return out

# ----------------------------------------------------------------- enemies

static func enemies() -> Array[EnemyData]:
	load_data()
	return _library.enemies

static func ids_for_role(role: EnemyData.Role, depth: int) -> Array[StringName]:
	load_data()
	var out: Array[StringName] = []
	for e: EnemyData in _library.enemies:
		if e.role == role and e.appears_at(depth):
			out.append(e.id)
	return out

static func role_from_key(key: String) -> EnemyData.Role:
	match key:
		"elite": return EnemyData.Role.ELITE
		"boss": return EnemyData.Role.BOSS
		_: return EnemyData.Role.GRUNT

## Builds an enemy for a role at a depth, scaling slightly with the floor.
static func make_enemy(role_key: String, depth: int) -> Entity:
	load_data()
	var role := role_from_key(role_key)
	var pool := ids_for_role(role, depth)
	if pool.is_empty():
		pool = ids_for_role(role, clampi(depth, 1, 12))
	if pool.is_empty():
		push_error("Roster: no enemy archetype for role %s" % role_key)
		return Entity.new()
	return make_enemy_by_id(Dice.pick(pool), depth)

static func make_enemy_by_id(id: StringName, depth: int) -> Entity:
	load_data()
	var def: EnemyData = _enemies.get(id, null)
	var e := Entity.new()
	if def == null:
		push_error("Roster: unknown enemy '%s'" % id)
		return e
	e.id = str(def.id)
	e.display_name = def.display_name
	e.team = Entity.Team.ENEMY
	e.rank = def.rank()
	e.stats = def.stats()
	e.ac_base = def.armour_class - Entity.ability_mod(def.score_dex)
	# Deeper floors field tougher versions of the same archetypes.
	var scale: int = maxi(0, depth - def.min_depth)
	var hp: int = maxi(1, Dice.roll_expr(def.hit_dice)) + scale * 2
	e.max_hp = hp
	e.current_hp = hp
	e.speed_tiles = def.speed_tiles
	e.proficiency = def.proficiency
	e.attack_ability = Entity.ability_key(def.attack_ability)
	e.casting_ability = Entity.ability_key(def.casting_ability)
	e.weapon_name = def.weapon_name
	e.damage_dice = def.damage_dice
	e.attack_range = def.attack_range
	e.xp_value = def.xp_value + scale
	e.tint = def.tint
	e.level = maxi(1, depth)
	return e

# ------------------------------------------------------------------ player

## Spell slots by class level, before GlobalState bonuses.
static func slots_for_level(level: int) -> Dictionary:
	return {
		"level_1": mini(4, 1 + int(ceil(level / 2.0))),
		"level_2": clampi(level - 2, 0, 3),
		"level_3": clampi(level - 4, 0, 3),
	}

## Sets hit points, proficiency and slots for `level`. Returns hit points gained.
static func apply_level(e: Entity, level: int, global: Dictionary) -> int:
	var previous_max := e.max_hp
	e.level = maxi(1, level)
	e.max_hp = BASE_HP + int(global.get("bonus_hp", 0)) + (e.level - 1) * HP_PER_LEVEL
	e.proficiency = 2 + int((e.level - 1) / 4.0)
	var slots := slots_for_level(e.level)
	slots["level_1"] = int(slots["level_1"]) + int(global.get("bonus_slots_1", 0))
	slots["level_2"] = int(slots["level_2"]) + int(global.get("bonus_slots_2", 0))
	slots["level_3"] = int(slots["level_3"]) + int(global.get("bonus_slots_3", 0))
	for key: String in slots.keys():
		if int(slots[key]) <= 0:
			slots.erase(key)
	e.spell_slots = slots
	var gained: int = e.max_hp - previous_max
	if gained > 0:
		e.current_hp += gained
	return gained

## The protagonist, built from GlobalState so time-loop upgrades carry over.
static func make_player(global: Dictionary = {}, level: int = 1) -> Entity:
	load_data()
	var e := Entity.new()
	e.id = "player_01"
	e.display_name = str(global.get("player_name", "Wren"))
	e.team = Entity.Team.PLAYER
	e.rank = Entity.Rank.HERO
	e.stats = {"str": 10, "dex": 14, "con": 12, "int": 16, "wis": 12, "cha": 10}
	var bonus_stats: Dictionary = global.get("stat_bonuses", {})
	for a: String in Entity.ABILITIES:
		e.stats[a] = int(e.stats[a]) + int(bonus_stats.get(a, 0))
	e.ac_base = 10 + int(global.get("bonus_ac", 0))
	e.speed_tiles = 6 + int(global.get("bonus_speed", 0))
	e.attack_ability = "dex"
	e.casting_ability = "int"
	# Every loop starts with the grimoire you were carrying when the bell rang.
	e.weapon_name = "Dog-eared Grimoire"
	e.damage_dice = "1d6"
	e.attack_range = 1
	e.tint = ArtFactory.TEAM_PLAYER
	e.xp_value = 0
	apply_level(e, level, global)
	e.current_hp = e.max_hp

	var known: Array = []
	for id: Variant in global.get("unlocked_spells", []):
		var name := StringName(id)
		if not known.has(name):
			known.append(name)
	for id: StringName in starting_spells():
		if not known.has(id):
			known.append(id)
	e.unlocked_spells = known
	e.known_spells = known.duplicate()
	return e

# -------------------------------------------------------------------- loot

static func loot_items() -> Array[LootItemData]:
	load_data()
	return _library.loot

static func loot_item(id: StringName) -> LootItemData:
	load_data()
	return _loot.get(id, null)

## Weighted draw from everything available at this depth.
static func roll_loot(depth: int) -> LootItemData:
	load_data()
	var weights: Dictionary = {}
	for item: LootItemData in _library.loot:
		if depth >= item.min_depth:
			weights[item.id] = item.weight
	if weights.is_empty():
		return null
	var pick: Variant = Dice.weighted(weights)
	return _loot.get(pick, null) if pick != null else null

# ------------------------------------------------------------------ skills

static func skill_nodes() -> Array[SkillNodeData]:
	load_data()
	return _library.skills

static func skill_node(id: StringName) -> SkillNodeData:
	load_data()
	return _skills.get(id, null)
