extends TestCase


func suite_name() -> String:
	return "combatant"


func run() -> void:
	var c := Combatant.new("Student", 60, 3)
	eq(c.hp, 60, "starts at full")
	eq(c.mana, 0, "mana starts empty until refilled")
	c.refill_mana()
	eq(c.mana, 3, "refilled to per-turn")

	# Block absorbs damage before HP, and is consumed by it.
	c.gain_block(10)
	eq(c.take_damage(4), 0, "block ate it all")
	eq(c.block, 6, "block partly spent")
	eq(c.hp, 60, "hp untouched")
	eq(c.take_damage(10), 4, "overflow reaches hp")
	eq(c.block, 0, "block exhausted")
	eq(c.hp, 56, "lost the overflow only")

	# Healing cannot exceed max.
	c.heal(100)
	eq(c.hp, 60, "healing caps at max")

	# HP floors at zero and reports down.
	eq(c.is_down(), false, "not down at full")
	c.take_damage(999)
	eq(c.hp, 0, "hp floors at zero")
	eq(c.is_down(), true, "down at zero")
	almost(c.hp_fraction(), 0.0, "fraction is zero")

	# Self-inflicted cost (Rot's own-HP payments) bypasses block entirely — it is
	# paying, not being hit, so take_damage's absorption must not apply.
	var d := Combatant.new("Payer", 20, 0)
	d.gain_block(10)
	d.pay_hp(5)
	eq(d.block, 10, "pay_hp does not touch block")
	eq(d.hp, 15, "pay_hp reduces hp directly, unabsorbed")
	d.pay_hp(999)
	eq(d.hp, 0, "pay_hp floors at zero")

	# Mana spending refuses what it cannot afford.
	var m := Combatant.new("M", 10, 3)
	m.refill_mana()
	eq(m.spend_mana(2), true, "afforded two")
	eq(m.mana, 1, "one left")
	eq(m.spend_mana(2), false, "cannot afford two more")
	eq(m.mana, 1, "failed spend changed nothing")
	m.refill_mana(2)
	eq(m.mana, 5, "bonus mana added on refill")

	# EnemyData builds a combatant and declares its secrets.
	var novice: EnemyData = load("res://resources/enemies/novice.tres")
	check(novice != null, "novice loads")
	if novice == null:
		return
	eq(novice.enemy_name, "Novice", "name")
	eq(novice.weak_school, Schools.School.INK, "novice is weak to ink")
	eq(novice.warded_school, Schools.School.FROST, "novice wards frost")
	neq(novice.weak_school, novice.warded_school, "weak and warded differ")
	check(novice.deck.size() > 0, "novice has a deck")
	var body := novice.to_combatant()
	eq(body.hp, novice.max_hp, "combatant starts at full hp")
	eq(body.display_name, "Novice", "combatant carries the name")
	eq(body.mana_per_turn, novice.mana_per_turn, "combatant carries mana_per_turn")
