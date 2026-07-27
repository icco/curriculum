extends "res://tests/TestCase.gd"

## Integrity of the content library: ids unique, cross-references resolvable,
## enum fields consistent with the data they imply.

func test_library_loads_with_content() -> void:
	truthy(Roster.spells().size() >= 8, "spells present")
	truthy(Roster.enemies().size() >= 8, "enemies present")
	truthy(Roster.loot_items().size() >= 10, "loot present")
	truthy(Roster.skill_nodes().size() >= 10, "skill nodes present")

func test_ids_are_present_and_unique() -> void:
	for group: Array in [Roster.spells(), Roster.enemies(), Roster.loot_items(), Roster.skill_nodes()]:
		var seen: Dictionary = {}
		for item: Resource in group:
			var id: StringName = item.get("id")
			ne(str(id), "", "%s has an id" % item.resource_path)
			falsy(seen.has(id), "id %s is unique" % id)
			seen[id] = true

func test_every_spell_is_reachable_and_coherent() -> void:
	for spell: SpellData in Roster.spells():
		ne(spell.display_name, "", "%s has a name" % spell.id)
		ne(spell.description, "", "%s has a description" % spell.id)
		if spell.kind in [SpellData.Kind.ATTACK, SpellData.Kind.AUTO, SpellData.Kind.SAVE]:
			ne(spell.damage, "", "offensive spell %s deals damage" % spell.id)
			truthy(spell.range_tiles > 0, "offensive spell %s has range" % spell.id)
		if spell.kind == SpellData.Kind.BUFF:
			truthy(spell.has_condition(), "buff %s applies a condition" % spell.id)
		if spell.aoe > 0:
			eq(spell.target, SpellData.Target.TILE, "burst %s is aimed at a tile" % spell.id)
		# Either a starting spell or purchasable, never neither.
		truthy(spell.starting or spell.unlock_cost > 0,
			"%s is either known from the start or costs insight" % spell.id)

func test_starting_spells_cover_the_basics() -> void:
	var starting := Roster.starting_spells()
	truthy(starting.size() >= 3, "at least three spells from loop one")
	var kinds: Array = []
	for id: StringName in starting:
		kinds.append(Roster.spell(id).kind)
	truthy(kinds.has(SpellData.Kind.ATTACK) or kinds.has(SpellData.Kind.AUTO),
		"a way to deal damage on the first loop")
	var has_cantrip := false
	for id: StringName in starting:
		if Roster.spell(id).is_cantrip():
			has_cantrip = true
	truthy(has_cantrip, "a slot-free option exists")

func test_every_depth_has_a_grunt_and_a_boss() -> void:
	for depth in range(1, GameState.FINAL_FLOOR + 1):
		truthy(Roster.ids_for_role(EnemyData.Role.GRUNT, depth).size() > 0,
			"floor %d has grunt archetypes" % depth)
		truthy(Roster.ids_for_role(EnemyData.Role.BOSS, depth).size() > 0,
			"floor %d has a boss archetype" % depth)

func test_enemy_bands_and_stats_are_sane() -> void:
	for e: EnemyData in Roster.enemies():
		truthy(e.min_depth <= e.max_depth, "%s has a valid depth band" % e.id)
		ne(e.hit_dice, "", "%s has hit dice" % e.id)
		truthy(Dice.average(e.hit_dice) > 0.0, "%s rolls positive hit points" % e.id)
		ne(e.damage_dice, "", "%s has damage dice" % e.id)
		truthy(e.armour_class >= 8 and e.armour_class <= 25, "%s AC is in range" % e.id)
		truthy(e.xp_value > 0, "%s is worth experience" % e.id)

func test_boss_progression_covers_the_whole_climb() -> void:
	# Every floor's boss should be a step up from the one before.
	var previous := 0.0
	for depth in [1, 4, 8, GameState.FINAL_FLOOR]:
		var best := 0.0
		for id: StringName in Roster.ids_for_role(EnemyData.Role.BOSS, depth):
			best = maxf(best, Dice.average(Roster.enemy(id).hit_dice))
		truthy(best > previous, "floor %d bosses are tougher than earlier ones" % depth)
		previous = best

func test_loot_entries_are_usable() -> void:
	for item: LootItemData in Roster.loot_items():
		ne(item.display_name, "", "%s has a name" % item.id)
		truthy(item.weight > 0.0, "%s can actually drop" % item.id)
		if item.is_consumable():
			ne(item.effect, LootItemData.Effect.NONE, "consumable %s does something" % item.id)
			if item.effect == LootItemData.Effect.HEAL:
				ne(item.power, "", "healing item %s has a power" % item.id)
		else:
			truthy(item.score() > 0.0, "gear %s is worth equipping" % item.id)

func test_loot_is_drawable_at_every_depth() -> void:
	Dice.seed_with(9090)
	for depth in range(1, GameState.FINAL_FLOOR + 1):
		var item := Roster.roll_loot(depth)
		truthy(item != null, "floor %d can drop something" % depth)
		truthy(item.min_depth <= depth, "drop respects its depth floor")

func test_skill_node_references_resolve() -> void:
	for node: SkillNodeData in Roster.skill_nodes():
		ne(node.display_name, "", "%s has a name" % node.id)
		ne(node.description, "", "%s has a description" % node.id)
		truthy(node.cost > 0, "%s costs insight" % node.id)
		for req: StringName in node.requires:
			truthy(Roster.skill_node(req) != null,
				"%s requires %s, which exists" % [node.id, req])
		if node.effect_type == SkillNodeData.EffectType.UNLOCK_SPELL:
			truthy(Roster.spell(node.spell_id) != null,
				"%s unlocks %s, which exists" % [node.id, node.spell_id])
		else:
			truthy(node.value > 0, "%s grants something" % node.id)

func test_skill_prerequisites_are_not_circular() -> void:
	for node: SkillNodeData in Roster.skill_nodes():
		var seen: Dictionary = {node.id: true}
		var frontier: Array = node.requires.duplicate()
		var guard := 0
		while not frontier.is_empty() and guard < 64:
			guard += 1
			var next: StringName = frontier.pop_back()
			falsy(seen.has(next) and next == node.id, "%s does not require itself" % node.id)
			if seen.has(next):
				continue
			seen[next] = true
			var req := Roster.skill_node(next)
			if req != null:
				frontier.append_array(req.requires)
		truthy(guard < 64, "%s prerequisite chain terminates" % node.id)

func test_every_unlockable_spell_has_a_node() -> void:
	var unlocked_by_nodes: Dictionary = {}
	for node: SkillNodeData in Roster.skill_nodes():
		if node.effect_type == SkillNodeData.EffectType.UNLOCK_SPELL:
			unlocked_by_nodes[node.spell_id] = true
	for spell: SpellData in Roster.unlockable_spells():
		truthy(unlocked_by_nodes.has(spell.id),
			"%s can be learned from some skill node" % spell.id)

func test_ability_enum_round_trips() -> void:
	for a: String in Entity.ABILITIES:
		eq(Entity.ability_key(Entity.ability_from_key(a)), a, "%s survives the round trip" % a)
	eq(Entity.ability_key(Entity.Ability.INT), "int", "INT maps to the stats key")
