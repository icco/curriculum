class_name GameState
extends RefCounted

## The time-loop persistence engine.
##
## GlobalState survives death: everything the protagonist has *learned*.
## RunState is the current loop and is thrown away when the loop fails.

const SAVE_PATH := "user://curriculum_save.json"
const SAVE_VERSION := 1

const MONTHS := [
	"September", "October", "November", "December", "January", "February",
	"March", "April", "May", "June", "July", "August",
]
const FINAL_FLOOR := 12

var global: Dictionary = {}
var run: Dictionary = {}

func _init() -> void:
	global = default_global()
	run = default_run()

static func default_global() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": "Wren",
		"unlocked_spells": [],
		"skill_nodes": [],
		"skill_points": 0,
		"bonus_hp": 0,
		"bonus_ac": 0,
		"bonus_speed": 0,
		"bonus_slots_1": 0,
		"bonus_slots_2": 0,
		"bonus_slots_3": 0,
		"stat_bonuses": {},
		"story_flags": {},
		"loops": 1,
		"deepest_floor": 1,
		"lifetime_insight": 0,
		"escaped": false,
	}

static func default_run() -> Dictionary:
	return {
		"depth": 1,
		"level": 1,
		"hp": -1,              # -1 means "start at full"
		"slots_used": {},
		"gear": {},
		"consumables": [],
		"conditions": {},
		"xp": 0,
		"kills": 0,
		"floors_cleared": 0,
	}

## Experience needed to reach each level, index 0 being level 1.
const XP_CURVE := [0, 25, 70, 140, 240, 380, 560, 800, 1100, 1450, 1850, 2350]

static func level_for_xp(xp: int) -> int:
	var level := 1
	for i in XP_CURVE.size():
		if xp >= int(XP_CURVE[i]):
			level = i + 1
	return level

func player_level() -> int:
	return int(run["level"])

func xp_to_next_level() -> int:
	var next: int = player_level()  # index of the next threshold
	if next >= XP_CURVE.size():
		return 0
	return maxi(0, int(XP_CURVE[next]) - int(run["xp"]))

# ------------------------------------------------------------- skill tree

static func skill_nodes() -> Array[SkillNodeData]:
	return Roster.skill_nodes()

static func skill_node(id: StringName) -> SkillNodeData:
	return Roster.skill_node(id)

func has_node_unlocked(id: StringName) -> bool:
	return (global["skill_nodes"] as Array).has(str(id))

## A node is offered once its prerequisites are met and it is not already taken.
func node_available(id: StringName) -> bool:
	var node := skill_node(id)
	if node == null or has_node_unlocked(id):
		return false
	for req: StringName in node.requires:
		if not has_node_unlocked(req):
			return false
	return true

func can_afford(id: StringName) -> bool:
	var node := skill_node(id)
	return node != null and int(global["skill_points"]) >= node.cost

func purchase_node(id: StringName) -> bool:
	if not node_available(id) or not can_afford(id):
		return false
	var node := skill_node(id)
	global["skill_points"] = int(global["skill_points"]) - node.cost
	(global["skill_nodes"] as Array).append(str(id))
	_apply_effect(node)
	return true

func _apply_effect(node: SkillNodeData) -> void:
	match node.effect_type:
		SkillNodeData.EffectType.UNLOCK_SPELL:
			var spell_id := str(node.spell_id)
			if spell_id != "" and not (global["unlocked_spells"] as Array).has(spell_id):
				(global["unlocked_spells"] as Array).append(spell_id)
		SkillNodeData.EffectType.ABILITY_SCORE:
			var ability := Entity.ability_key(node.ability)
			var bonuses: Dictionary = global["stat_bonuses"]
			bonuses[ability] = int(bonuses.get(ability, 0)) + node.value
		_:
			var key := node.global_key()
			if key != "" and global.has(key):
				global[key] = int(global[key]) + node.value

# --------------------------------------------------------------- the loop

func current_depth() -> int:
	return int(run["depth"])

static func month_for(depth: int) -> String:
	return MONTHS[clampi(depth - 1, 0, MONTHS.size() - 1)]

func month_name() -> String:
	return month_for(current_depth())

## Insight is the meta currency: earned from kills and depth, spent on skills.
func insight_earned() -> int:
	return int(float(run["xp"]) / 12.0) + int(run["floors_cleared"]) * 2

## Called when the loop fails. Wipes the run, banks insight, keeps knowledge.
func fail_loop() -> Dictionary:
	var gained := insight_earned()
	global["skill_points"] = int(global["skill_points"]) + gained
	global["lifetime_insight"] = int(global["lifetime_insight"]) + gained
	global["loops"] = int(global["loops"]) + 1
	global["deepest_floor"] = maxi(int(global["deepest_floor"]), current_depth())
	var summary := {
		"insight": gained,
		"depth": current_depth(),
		"kills": int(run["kills"]),
		"loop": int(global["loops"]),
	}
	run = default_run()
	return summary

func win_run() -> Dictionary:
	var summary := fail_loop()
	global["escaped"] = true
	(global["story_flags"] as Dictionary)["escaped_academy"] = true
	return summary

## Banks experience. Returns the new level if the kill caused a level up, else 0.
func note_kill(xp: int) -> int:
	run["xp"] = int(run["xp"]) + xp
	run["kills"] = int(run["kills"]) + 1
	var level := level_for_xp(int(run["xp"]))
	if level > player_level():
		run["level"] = level
		return level
	return 0

func note_floor_cleared() -> void:
	run["floors_cleared"] = int(run["floors_cleared"]) + 1
	global["deepest_floor"] = maxi(int(global["deepest_floor"]), current_depth())

func set_story_flag(flag: String, value: Variant = true) -> void:
	(global["story_flags"] as Dictionary)[flag] = value

func story_flag(flag: String) -> Variant:
	return (global["story_flags"] as Dictionary).get(flag, false)

# ---------------------------------------------------- run <-> entity sync

## Applies the saved run to a freshly built player entity.
func restore_player(player: Entity) -> void:
	if int(run["hp"]) >= 0:
		player.current_hp = clampi(int(run["hp"]), 0, player.max_hp)
	player.slots_used = (run["slots_used"] as Dictionary).duplicate()
	player.equip_ids(run["gear"])
	player.conditions = (run["conditions"] as Dictionary).duplicate()

func capture_player(player: Entity) -> void:
	run["hp"] = player.current_hp
	run["slots_used"] = player.slots_used.duplicate()
	run["gear"] = player.gear_ids()
	run["conditions"] = player.conditions.duplicate()

## Consumables are stored as ids and resolved through Roster.
func consumable_ids() -> Array:
	return run["consumables"]

func consumables() -> Array[LootItemData]:
	var out: Array[LootItemData] = []
	for id: Variant in run["consumables"]:
		var item := Roster.loot_item(StringName(id))
		if item != null:
			out.append(item)
	return out

func consumable_at(index: int) -> LootItemData:
	var list: Array = run["consumables"]
	if index < 0 or index >= list.size():
		return null
	return Roster.loot_item(StringName(list[index]))

func add_consumable(id: StringName) -> void:
	(run["consumables"] as Array).append(str(id))

func take_consumable(index: int) -> LootItemData:
	var item := consumable_at(index)
	if item != null:
		(run["consumables"] as Array).remove_at(index)
	return item

# ------------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {"global": global, "run": run}

func from_dict(data: Dictionary) -> void:
	var loaded_global: Dictionary = data.get("global", {})
	global = default_global()
	for key: String in loaded_global:
		global[key] = loaded_global[key]
	var loaded_run: Dictionary = data.get("run", {})
	run = default_run()
	for key: String in loaded_run:
		run[key] = loaded_run[key]

func save(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	return true

func load_from(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	from_dict(parsed)
	return true

static func wipe(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
