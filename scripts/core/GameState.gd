class_name GameState
extends RefCounted

## The time-loop persistence engine.
##
## GlobalState survives death: everything the protagonist has *learned*.
## RunState is the current loop and is thrown away when the loop fails.

const SAVE_PATH := "user://curriculum_save.json"
const SKILLS_PATH := "res://data/skills.json"
const SAVE_VERSION := 1

const MONTHS := [
	"September", "October", "November", "December", "January", "February",
	"March", "April", "May", "June", "July", "August",
]
const FINAL_FLOOR := 12

static var _skills: Array = []

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

static func skill_nodes() -> Array:
	if not _skills.is_empty():
		return _skills
	var file := FileAccess.open(SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: cannot open %s" % SKILLS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_skills = (parsed as Dictionary).get("nodes", [])
	return _skills

static func skill_node(id: String) -> Dictionary:
	for node: Dictionary in skill_nodes():
		if str(node["id"]) == id:
			return node
	return {}

func has_node_unlocked(id: String) -> bool:
	return (global["skill_nodes"] as Array).has(id)

## A node is offered once its prerequisites are met and it is not already taken.
func node_available(id: String) -> bool:
	var node := skill_node(id)
	if node.is_empty() or has_node_unlocked(id):
		return false
	for req: String in node.get("requires", []):
		if not has_node_unlocked(req):
			return false
	return true

func can_afford(id: String) -> bool:
	var node := skill_node(id)
	return not node.is_empty() and int(global["skill_points"]) >= int(node.get("cost", 0))

func purchase_node(id: String) -> bool:
	if not node_available(id) or not can_afford(id):
		return false
	var node := skill_node(id)
	global["skill_points"] = int(global["skill_points"]) - int(node.get("cost", 0))
	(global["skill_nodes"] as Array).append(id)
	_apply_effect(node.get("effect", {}))
	return true

func _apply_effect(effect: Dictionary) -> void:
	var type := str(effect.get("type", ""))
	match type:
		"unlock_spell":
			var spell_id := str(effect.get("value", ""))
			if spell_id != "" and not (global["unlocked_spells"] as Array).has(spell_id):
				(global["unlocked_spells"] as Array).append(spell_id)
		"stat":
			var ability := str(effect.get("ability", "int"))
			var bonuses: Dictionary = global["stat_bonuses"]
			bonuses[ability] = int(bonuses.get(ability, 0)) + int(effect.get("value", 1))
		_:
			if global.has(type):
				global[type] = int(global[type]) + int(effect.get("value", 0))

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
	player.equipped_gear = (run["gear"] as Dictionary).duplicate(true)
	player.conditions = (run["conditions"] as Dictionary).duplicate()

func capture_player(player: Entity) -> void:
	run["hp"] = player.current_hp
	run["slots_used"] = player.slots_used.duplicate()
	run["gear"] = player.equipped_gear.duplicate(true)
	run["conditions"] = player.conditions.duplicate()

func consumables() -> Array:
	return run["consumables"]

func add_consumable(item: Dictionary) -> void:
	(run["consumables"] as Array).append(item)

func take_consumable(index: int) -> Dictionary:
	var list: Array = run["consumables"]
	if index < 0 or index >= list.size():
		return {}
	var item: Dictionary = list[index]
	list.remove_at(index)
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
