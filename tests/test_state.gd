extends "res://tests/TestCase.gd"

## GlobalState vs RunState: what survives a failed loop and what does not.

const TEST_SAVE := "user://curriculum_test_save.json"

func before_each() -> void:
	Dice.seed_with(4321)

func test_defaults_match_the_spec_shape() -> void:
	var state := GameState.new()
	eq(int(state.run["depth"]), 1, "runs start on floor 1")
	eq(int(state.global["skill_points"]), 0, "no insight banked yet")
	eq(int(state.global["loops"]), 1, "first loop")
	truthy((state.global["unlocked_spells"] as Array).is_empty(), "nothing learned yet")
	eq(state.month_name(), "September", "floor 1 is September")
	eq(GameState.month_for(12), "August", "floor 12 is August")

func test_player_is_built_from_global_state() -> void:
	var state := GameState.new()
	var plain := Roster.make_player(state.global)
	eq(plain.max_hp, Roster.BASE_HP, "level 1 hit points come from the base pool")
	eq(plain.ac(), 12, "base AC is 12 (10 + dex 14)")
	eq(plain.speed_tiles, 6, "30ft of movement is 6 tiles")
	eq(int(plain.spell_slots["level_1"]), 2, "two level 1 slots")
	eq(plain.mod("int"), 3, "int 16 gives +3")

	state.global["bonus_hp"] = 8
	state.global["bonus_ac"] = 2
	state.global["bonus_speed"] = 1
	state.global["bonus_slots_1"] = 1
	state.global["stat_bonuses"] = {"int": 2}
	var upgraded := Roster.make_player(state.global)
	eq(upgraded.max_hp, Roster.BASE_HP + 8, "hit point upgrades apply")
	eq(upgraded.ac(), 14, "AC upgrades apply")
	eq(upgraded.speed_tiles, 7, "speed upgrades apply")
	eq(int(upgraded.spell_slots["level_1"]), 3, "slot upgrades apply")
	eq(upgraded.mod("int"), 4, "stat upgrades apply")
	eq(upgraded.spell_save_dc(), 14, "and raise the spell save DC")

func test_starting_spells_are_always_known() -> void:
	var state := GameState.new()
	var player := Roster.make_player(state.global)
	for id: StringName in Roster.starting_spells():
		truthy(player.known_spells.has(id), "%s is known from the first loop" % id)
	truthy(player.known_spells.has(&"slate_shard"), "the cantrip is available")
	falsy(player.known_spells.has(&"conflagration"), "later spells must be unlocked")

func test_skill_tree_gating_and_purchase() -> void:
	var state := GameState.new()
	truthy(state.node_available(&"reading_circle"), "a root node is offered")
	falsy(state.node_available(&"second_circle"), "a gated node is hidden")
	falsy(state.can_afford(&"reading_circle"), "cannot buy without insight")
	falsy(state.purchase_node(&"reading_circle"), "purchase refused when broke")

	state.global["skill_points"] = 10
	truthy(state.purchase_node(&"reading_circle"), "purchase succeeds")
	eq(int(state.global["skill_points"]), 8, "insight is deducted")
	eq(int(state.global["bonus_hp"]), 4, "the effect is applied")
	falsy(state.node_available(&"reading_circle"), "nodes cannot be bought twice")
	falsy(state.purchase_node(&"reading_circle"), "and the purchase is refused")

	truthy(state.purchase_node(&"first_circle"), "another root node")
	truthy(state.node_available(&"second_circle"), "prerequisites now met")

func test_spell_unlock_nodes_teach_spells_permanently() -> void:
	var state := GameState.new()
	state.global["skill_points"] = 20
	truthy(state.purchase_node(&"examination_recall"), "bought the Pop Quiz node")
	truthy((state.global["unlocked_spells"] as Array).has("sudden_examination"), "spell recorded in GlobalState")
	var player := Roster.make_player(state.global)
	truthy(player.known_spells.has(&"sudden_examination"), "the next protagonist knows it")

	state.fail_loop()
	var next := Roster.make_player(state.global)
	truthy(next.known_spells.has(&"sudden_examination"), "and still knows it after the loop resets")

func test_stat_node_applies_to_the_named_ability() -> void:
	var state := GameState.new()
	state.global["skill_points"] = 30
	state.purchase_node(&"examination_recall")
	truthy(state.purchase_node(&"honours_list"), "Honour Roll requires Pop Quiz")
	eq(int((state.global["stat_bonuses"] as Dictionary)["int"]), 1, "int bonus recorded")

func test_fail_loop_banks_insight_and_wipes_the_run() -> void:
	var state := GameState.new()
	state.run["xp"] = 120
	state.run["floors_cleared"] = 3
	state.run["gear"] = {"weapon": "oak_quarterstaff"}
	state.add_consumable(&"vial_of_cordial")
	state.run["depth"] = 4

	var expected := int(120 / 12.0) + 3 * 2
	var summary := state.fail_loop()
	eq(int(summary["insight"]), expected, "insight comes from kills and depth")
	eq(int(state.global["skill_points"]), expected, "banked into GlobalState")
	eq(int(state.global["deepest_floor"]), 4, "deepest floor remembered")
	eq(int(state.run["depth"]), 1, "run resets to floor 1")
	truthy((state.run["gear"] as Dictionary).is_empty(), "gear lost")
	truthy(state.consumable_ids().is_empty(), "consumables lost")
	eq(int(state.run["xp"]), 0, "xp reset")

func test_win_sets_the_escape_flag() -> void:
	var state := GameState.new()
	state.run["floors_cleared"] = 12
	state.win_run()
	truthy(bool(state.global["escaped"]), "escape recorded")
	truthy(bool(state.story_flag("escaped_academy")), "story flag set")

func test_story_flags_persist_across_loops() -> void:
	var state := GameState.new()
	state.set_story_flag("met_the_janitor")
	state.fail_loop()
	truthy(bool(state.story_flag("met_the_janitor")), "story progress is not undone by death")

func test_run_state_round_trips_through_the_player_entity() -> void:
	var state := GameState.new()
	var player := Roster.make_player(state.global)
	player.current_hp = 7
	player.spend_slot(1)
	player.equip_ids({"weapon": "iron_stylus"})
	player.add_condition("shielded", 2)
	state.capture_player(player)

	var rebuilt := Roster.make_player(state.global)
	state.restore_player(rebuilt)
	eq(rebuilt.current_hp, 7, "hit points restored")
	eq(rebuilt.slots_left(1), 1, "spent slots restored")
	eq((rebuilt.equipped_gear["weapon"] as LootItemData).display_name, "Iron Stylus", "gear restored")
	truthy(rebuilt.has_condition("shielded"), "conditions restored")

func test_save_and_load_round_trip() -> void:
	GameState.wipe(TEST_SAVE)
	var state := GameState.new()
	state.global["skill_points"] = 5
	state.global["unlocked_spells"] = ["sudden_examination", "corridor_step"]
	state.global["loops"] = 7
	state.set_story_flag("beat_visiting_lecturer_floor_1")
	state.run["depth"] = 3
	state.run["hp"] = 9
	truthy(state.save(TEST_SAVE), "save writes")

	var loaded := GameState.new()
	truthy(loaded.load_from(TEST_SAVE), "load reads")
	eq(int(loaded.global["skill_points"]), 5, "insight persisted")
	eq((loaded.global["unlocked_spells"] as Array).size(), 2, "spells persisted")
	eq(int(loaded.global["loops"]), 7, "loop count persisted")
	truthy(bool(loaded.story_flag("beat_visiting_lecturer_floor_1")), "story flags persisted")
	eq(int(loaded.run["depth"]), 3, "run depth persisted")
	eq(int(loaded.run["hp"]), 9, "run hit points persisted")
	GameState.wipe(TEST_SAVE)

func test_loading_a_missing_save_is_harmless() -> void:
	GameState.wipe(TEST_SAVE)
	var state := GameState.new()
	falsy(state.load_from(TEST_SAVE), "reports that there was nothing to load")
	eq(int(state.run["depth"]), 1, "and leaves defaults intact")

func test_partial_saves_are_filled_with_defaults() -> void:
	var state := GameState.new()
	state.from_dict({"global": {"skill_points": 3}, "run": {"depth": 5}})
	eq(int(state.global["skill_points"]), 3, "provided value kept")
	eq(int(state.global["loops"]), 1, "missing value defaulted")
	eq(int(state.run["depth"]), 5, "provided run value kept")
	eq(int(state.run["xp"]), 0, "missing run value defaulted")
