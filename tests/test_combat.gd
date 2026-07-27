extends "res://tests/TestCase.gd"

func before_each() -> void:
	Dice.seed_with(20240)

func _fighter(name: String, team: int, pos: Vector2i) -> Entity:
	var e := Entity.new()
	e.display_name = name
	e.team = team
	e.grid_pos = pos
	e.stats = {"str": 16, "dex": 12, "con": 14, "int": 16, "wis": 10, "cha": 10}
	e.ac_base = 10
	e.max_hp = 40
	e.current_hp = 40
	e.proficiency = 2
	e.attack_ability = "str"
	e.casting_ability = "int"
	e.damage_dice = "1d8"
	e.attack_range = 1
	e.spell_slots = {"level_1": 2}
	return e

func _room(w: int = 16, h: int = 16) -> MapData:
	var m := MapData.new()
	m.setup(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			m.set_tile(Vector2i(x, y), MapData.Tile.FLOOR)
	return m

# ---------------------------------------------------------------- math

func test_ability_modifiers_follow_5e() -> void:
	eq(Entity.ability_mod(10), 0, "10 is +0")
	eq(Entity.ability_mod(11), 0, "11 is +0")
	eq(Entity.ability_mod(16), 3, "16 is +3")
	eq(Entity.ability_mod(8), -1, "8 is -1")
	eq(Entity.ability_mod(7), -2, "7 is -2")
	eq(Entity.ability_mod(20), 5, "20 is +5")

func test_spell_dc_and_bonuses() -> void:
	var e := _fighter("Caster", Entity.Team.PLAYER, Vector2i.ZERO)
	# 8 + proficiency 2 + int mod 3
	eq(e.spell_save_dc(), 13, "spell save DC")
	eq(e.spell_attack_bonus(), 5, "spell attack bonus")
	eq(e.attack_bonus(), 5, "weapon attack bonus (str 16, prof 2)")

func test_crit_doubles_dice_but_not_modifier() -> void:
	for i in 400:
		var normal := Combat.roll_damage("2d6+3")
		between(normal, 5, 15, "2d6+3 normal")
		var crit := Combat.roll_damage("2d6+3", true)
		between(crit, 7, 27, "2d6+3 crit doubles only the dice")

func test_natural_twenty_always_hits_and_one_always_misses() -> void:
	var crits := 0
	var hits := 0
	for i in 3000:
		var check := Combat.d20_check(0, 500)
		if check["success"]:
			hits += 1
			truthy(check["crit"], "only a natural 20 beats an impossible AC")
			crits += 1
	truthy(hits > 60 and hits < 240, "roughly 5%% of rolls are natural 20s (got %d/3000)" % hits)

	var misses := 0
	for i in 3000:
		var check := Combat.d20_check(50, -100)
		if not check["success"]:
			misses += 1
			truthy(check["fumble"], "only a natural 1 misses a trivial AC")
	truthy(misses > 60 and misses < 240, "roughly 5%% of rolls are natural 1s (got %d/3000)" % misses)

# --------------------------------------------------------------- cover

func test_cover_raises_effective_ac() -> void:
	var m := _room()
	var attacker := _fighter("A", Entity.Team.PLAYER, Vector2i(2, 5))
	var defender := _fighter("D", Entity.Team.ENEMY, Vector2i(8, 5))
	var bare: int = int(Combat.defended_ac(defender, attacker.grid_pos, m)["ac"])
	eq(bare, defender.ac(), "no cover means plain AC")

	m.set_prop(Vector2i(5, 5), MapData.Prop.DESK)
	var half := Combat.defended_ac(defender, attacker.grid_pos, m)
	eq(int(half["ac"]), bare + 2, "half cover adds 2 AC")

	m.set_prop(Vector2i(5, 5), MapData.Prop.NONE)
	m.set_prop(Vector2i(7, 5), MapData.Prop.RELIQUARY)
	var three := Combat.defended_ac(defender, attacker.grid_pos, m)
	eq(int(three["ac"]), bare + 5, "three-quarters cover adds 5 AC")

func test_shield_condition_adds_five_ac() -> void:
	var e := _fighter("D", Entity.Team.ENEMY, Vector2i.ZERO)
	var before := e.ac()
	e.add_condition("shielded", 2)
	eq(e.ac(), before + 5, "Textbook Barrier grants +5 AC")

func test_reach_and_line_of_sight_gate_attacks() -> void:
	var m := _room()
	var melee := _fighter("Melee", Entity.Team.PLAYER, Vector2i(2, 5))
	var far := _fighter("Far", Entity.Team.ENEMY, Vector2i(8, 5))
	falsy(Combat.can_attack(melee, far, m), "melee cannot reach across the room")
	far.grid_pos = Vector2i(3, 5)
	truthy(Combat.can_attack(melee, far, m), "adjacent is in reach")

	var archer := _fighter("Archer", Entity.Team.PLAYER, Vector2i(2, 5))
	archer.attack_range = 8
	far.grid_pos = Vector2i(9, 5)
	truthy(Combat.can_attack(archer, far, m), "ranged attack in the open")
	for y in range(1, 15):
		m.set_tile(Vector2i(6, y), MapData.Tile.WALL)
	falsy(Combat.can_attack(archer, far, m), "a wall breaks the shot")

# ------------------------------------------------------------- attacking

func test_weapon_attack_applies_damage_and_kills() -> void:
	var m := _room()
	var attacker := _fighter("Bruiser", Entity.Team.PLAYER, Vector2i(4, 4))
	var defender := _fighter("Victim", Entity.Team.ENEMY, Vector2i(5, 4))
	defender.ac_base = -50  # cannot be missed except on a natural 1
	defender.current_hp = 3
	var killed := false
	for i in 20:
		if not defender.is_alive():
			break
		var event := Combat.weapon_attack(attacker, defender, m)
		if bool(event["hit"]):
			truthy(int(event["damage"]) > 0, "a hit deals damage")
		if bool(event["killed"]):
			killed = true
	truthy(killed, "a 3 hp defender dies to repeated hits")
	eq(defender.current_hp, 0, "hp floors at zero")
	falsy(defender.is_alive(), "dead entities report as such")

func test_attack_event_text_mentions_cover() -> void:
	var m := _room()
	m.set_prop(Vector2i(5, 5), MapData.Prop.DESK)
	var attacker := _fighter("A", Entity.Team.PLAYER, Vector2i(2, 5))
	var defender := _fighter("D", Entity.Team.ENEMY, Vector2i(8, 5))
	defender.ac_base = 90
	var event := Combat.weapon_attack(attacker, defender, m)
	truthy(str(event["text"]).contains("half cover"), "miss text explains the cover penalty")

# --------------------------------------------------------------- spells

func test_spell_slots_are_consumed_and_exhausted() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	var target := _fighter("Target", Entity.Team.ENEMY, Vector2i(6, 4))
	var spell := Roster.spell(&"ink_barrage")
	truthy(spell != null, "spell data loads")
	eq(caster.slots_left(1), 2, "starts with two level 1 slots")

	Combat.cast_spell(caster, spell, target.grid_pos, [caster, target], m)
	eq(caster.slots_left(1), 1, "one slot spent")
	Combat.cast_spell(caster, spell, target.grid_pos, [caster, target], m)
	eq(caster.slots_left(1), 0, "both slots spent")
	var events := Combat.cast_spell(caster, spell, target.grid_pos, [caster, target], m)
	eq(str(events[0]["type"]), "fizzle", "third cast fizzles")

func test_cantrips_never_consume_slots() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	var target := _fighter("Target", Entity.Team.ENEMY, Vector2i(6, 4))
	var cantrip := Roster.spell(&"slate_shard")
	eq(int(cantrip["level"]), 0, "chalk dart is a cantrip")
	for i in 5:
		var events := Combat.cast_spell(caster, cantrip, target.grid_pos, [caster, target], m)
		ne(str(events[0]["type"]), "fizzle", "cantrips are always available")
	eq(caster.slots_left(1), 2, "slots untouched")

func test_auto_hit_spell_always_damages() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	var target := _fighter("Target", Entity.Team.ENEMY, Vector2i(6, 4))
	target.ac_base = 200
	caster.spell_slots = {"level_1": 20}
	var before := target.current_hp
	Combat.cast_spell(caster, Roster.spell(&"ink_barrage"), target.grid_pos, [caster, target], m)
	truthy(target.current_hp < before, "Spitball Barrage ignores AC entirely")

func test_save_spell_halves_on_success_and_applies_conditions() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	caster.spell_slots = {"level_1": 99}
	var spell := Roster.spell(&"writ_of_detention")
	var saw_stun := false
	var saw_save := false
	for i in 60:
		var target := _fighter("Target", Entity.Team.ENEMY, Vector2i(6, 4))
		var events := Combat.cast_spell(caster, spell, target.grid_pos, [caster, target], m)
		for event: Dictionary in events:
			if str(event.get("type", "")) != "spell_save":
				continue
			if bool(event["saved"]):
				saw_save = true
				eq(int(event["damage"]), 0, "a successful save against Detention Slip negates damage")
				falsy(target.has_condition("stunned"), "no stun on a save")
			else:
				truthy(int(event["damage"]) > 0, "a failed save takes damage")
				truthy(target.has_condition("stunned"), "a failed save is stunned")
				saw_stun = true
	truthy(saw_stun and saw_save, "both save outcomes occur over 60 casts")

func test_save_effect_half_leaves_partial_damage() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	caster.spell_slots = {"level_1": 99}
	var spell := Roster.spell(&"sudden_examination")
	var saw_half := false
	for i in 80:
		var target := _fighter("Target", Entity.Team.ENEMY, Vector2i(6, 4))
		target.stats["int"] = 20  # good save, so successes are common
		for event: Dictionary in Combat.cast_spell(caster, spell, target.grid_pos, [caster, target], m):
			if str(event.get("type", "")) == "spell_save" and bool(event["saved"]):
				truthy(int(event["damage"]) > 0, "Pop Quiz still stings on a save")
				saw_half = true
	truthy(saw_half, "half-damage saves observed")

func test_heal_buff_and_teleport() -> void:
	var m := _room()
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(4, 4))
	caster.spell_slots = {"level_1": 9, "level_2": 9}
	caster.current_hp = 5
	Combat.cast_spell(caster, Roster.spell(&"restorative_study"), caster.grid_pos, [caster], m)
	truthy(caster.current_hp > 5, "Study Hall heals")
	truthy(caster.current_hp <= caster.max_hp, "healing cannot exceed max hp")

	Combat.cast_spell(caster, Roster.spell(&"grimoire_ward"), caster.grid_pos, [caster], m)
	truthy(caster.has_condition("shielded"), "Textbook Barrier applies its condition")

	Combat.cast_spell(caster, Roster.spell(&"corridor_step"), Vector2i(8, 8), [caster], m)
	eq(caster.grid_pos, Vector2i(8, 8), "Hall Pass moves the caster")

func test_aoe_hits_everyone_in_radius_with_line_of_sight() -> void:
	var m := _room(20, 20)
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(3, 10))
	caster.spell_slots = {"level_2": 9}
	var near := _fighter("Near", Entity.Team.ENEMY, Vector2i(10, 10))
	var edge := _fighter("Edge", Entity.Team.ENEMY, Vector2i(12, 10))
	var far := _fighter("Far", Entity.Team.ENEMY, Vector2i(15, 10))
	var roster: Array = [caster, near, edge, far]
	var spell := Roster.spell(&"conflagration")
	eq(spell.aoe, 2, "Fire Drill has a 2 tile burst")
	var hit := Combat.spell_targets(caster, spell, Vector2i(11, 10), roster, m)
	truthy(hit.has(near), "target 1 tile from centre is caught")
	truthy(hit.has(edge), "target on the radius edge is caught")
	falsy(hit.has(far), "target outside the radius is spared")
	falsy(hit.has(caster), "enemy-only spell skips the caster")

func test_aoe_respects_walls() -> void:
	var m := _room(20, 20)
	var caster := _fighter("Caster", Entity.Team.PLAYER, Vector2i(3, 10))
	var shielded := _fighter("Behind", Entity.Team.ENEMY, Vector2i(12, 10))
	for y in range(1, 19):
		m.set_tile(Vector2i(11, y), MapData.Tile.WALL)
	var hit := Combat.spell_targets(caster, Roster.spell(&"conflagration"), Vector2i(10, 10), [caster, shielded], m)
	falsy(hit.has(shielded), "a wall between blast centre and target blocks it")

# ------------------------------------------------------------ conditions

func test_burning_ticks_and_expires() -> void:
	var e := _fighter("Torch", Entity.Team.ENEMY, Vector2i.ZERO)
	e.add_condition("burning", 2)
	var before := e.current_hp
	var events := Combat.tick_start_of_turn(e)
	truthy(e.current_hp < before, "burning deals damage at turn start")
	truthy(e.has_condition("burning"), "still burning after one tick")
	Combat.tick_start_of_turn(e)
	falsy(e.has_condition("burning"), "burning expires after two ticks")
	truthy(events.size() > 0, "condition events are reported")

func test_stunned_blocks_actions_and_movement() -> void:
	var e := _fighter("Held", Entity.Team.ENEMY, Vector2i.ZERO)
	eq(Combat.movement_for(e), e.speed_tiles, "normal speed")
	e.add_condition("stunned", 1)
	falsy(e.can_act(), "stunned entities cannot act")
	eq(Combat.movement_for(e), 0, "stunned entities cannot move")

func test_slowed_halves_movement() -> void:
	var e := _fighter("Slow", Entity.Team.ENEMY, Vector2i.ZERO)
	e.speed_tiles = 6
	e.add_condition("slowed", 2)
	eq(Combat.movement_for(e), 3, "slowed halves speed")
