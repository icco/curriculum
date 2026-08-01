extends TestCase

## Per-run examiner variants: deterministic from the seed, never written back to the
## shared roster resources.


func suite_name() -> String:
	return "faculty"


func _card(school: int, kind: String, amount: int) -> CardData:
	var d := CardData.new()
	d.card_name = "c%d%s" % [school, kind]
	d.school = school
	d.cost = 1
	d.effects = [{"kind": kind, "amount": amount}] as Array[Dictionary]
	return d


func _enemy(name: String, weak: int, warded: int, deck: Array) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.max_hp = 40
	e.mana_per_turn = 2
	e.weak_school = weak
	e.warded_school = warded
	var typed: Array[CardData] = []
	typed.assign(deck)
	e.deck = typed
	return e


func _roster() -> Array:
	var hit := _card(Schools.School.CINDER, CardData.DAMAGE, 6)
	var block := _card(Schools.School.WARD, CardData.BLOCK, 6)
	return [
		_enemy("Aggressive", Schools.School.INK, Schools.School.FROST, [hit, hit, hit, hit, hit]),
		_enemy("Turtle", Schools.School.ROT, Schools.School.WARD, [block, block, block, hit, hit]),
		_enemy("Mixed", Schools.School.FROST, Schools.School.CINDER, [hit, hit, hit, block, hit]),
	]


## A library around a roster. `opening` is the starting deck's schools -- the faculty
## reads them from the library rather than from any run's deck, so a suite that wants to
## constrain the roll states them here.
func _library(roster: Array, opening: Array = []) -> ContentLibrary:
	var lib := ContentLibrary.new()
	var enemies: Array[EnemyData] = []
	enemies.assign(roster)
	lib.enemies = enemies
	var start: Array[CardData] = []
	for school in opening:
		start.append(_card(school, CardData.DAMAGE, 6))
	lib.starting_deck = start
	# The card index has to hold every card the roster plays, or CardPool has no candidate
	# for any slot and every deck falls back to its authored self -- which would leave this
	# suite testing the school rolls against a deck roll that silently did nothing.
	var cards: Array[CardData] = []
	for enemy in roster:
		for card in enemy.deck:
			if not cards.has(card):
				cards.append(card)
	lib.cards = cards
	return lib


func run() -> void:
	# Deterministic in the seed: the whole save format rests on this, since a save
	# stores one integer and rebuilds the faculty from it rather than serialising
	# nine examiners.
	var a := Faculty.new(_library(_roster()), 4242)
	var b := Faculty.new(_library(_roster()), 4242)
	for name in ["Aggressive", "Turtle", "Mixed"]:
		var one: EnemyData = a.examiner(_enemy(name, 0, 0, []))
		var two: EnemyData = b.examiner(_enemy(name, 0, 0, []))
		eq(one.warded_school, two.warded_school, "%s rolls the same ward for the same seed" % name)

	# Different seeds must actually produce different worlds, or "generative" is a
	# label rather than a behaviour. Checked across many seeds rather than two,
	# since any single pair can legitimately collide.
	var seen := {}
	for seed_value in range(1, 40):
		var faculty := Faculty.new(_library(_roster()), seed_value)
		var signature := ""
		for enemy in faculty.all():
			signature += "%d," % enemy.warded_school
		seen[signature] = true
	check(seen.size() > 1, "different seeds produce different faculties")

	# The shared roster resources must come back untouched. Writing the roll onto the
	# library's own EnemyData would leak it into every later run in the session --
	# the Resource-is-a-shared-singleton trap spec section 4 calls out.
	var roster := _roster()
	var before: Array = []
	for enemy in roster:
		# The deck is compared CARD BY CARD, not by size. A generator that swapped a
		# deck's contents in place while keeping its length -- exactly what a
		# substitution bug writing through to the library looks like -- passes every
		# size-based assertion identically.
		before.append([enemy.weak_school, enemy.warded_school, enemy.deck.duplicate()])
	var faculty := Faculty.new(_library(roster), 99)
	for i in roster.size():
		eq(
			[roster[i].weak_school, roster[i].warded_school, roster[i].deck],
			before[i],
			"%s's roster resource is unmodified, deck contents included" % roster[i].enemy_name
		)
		var variant: EnemyData = faculty.examiner(roster[i])
		neq(variant, roster[i], "the variant is a distinct object")
		eq(variant.enemy_name, roster[i].enemy_name, "the name survives -- it is the Bestiary's key")
		# Non-aliasing has to be probed by writing, not by comparing: GDScript compares
		# arrays element-wise, so a variant deck that IS the roster's array compares equal
		# to it and so does an independent copy with the same contents. Only a write tells
		# them apart -- and aliasing here is the leak that would put a rolled deck onto the
		# library's shared EnemyData for the rest of the session.
		var roster_size: int = roster[i].deck.size()
		variant.deck.append(variant.deck[0])
		eq(roster[i].deck.size(), roster_size, "the variant's deck is its own array, not the roster's")
		variant.deck.resize(roster_size)

	# Spec section 5: never weak and warded to the same school, at any seed.
	# Also: a defensive examiner is never warded against a school the player opens
	# with, or halving their damage against a mostly-Block deck makes it unbreakable
	# rather than merely hard.
	var starting := [Schools.School.CINDER, Schools.School.WARD]
	for seed_value in range(1, 60):
		var f := Faculty.new(_library(_roster(), starting), seed_value)
		for enemy in f.all():
			neq(
				enemy.warded_school,
				enemy.weak_school,
				"seed %d: %s is not both weak and warded to one school" % [seed_value, enemy.enemy_name]
			)
			if enemy.enemy_name == "Turtle":
				check(
					not starting.has(enemy.warded_school),
					"seed %d: the block-heavy examiner is not warded against a starting school"
					% seed_value
				)

	# An empty roster is legal -- it is what a suite building a bare Run gets -- and
	# must leave examiners on their authored schools rather than crashing.
	var bare := Faculty.new(null, 7)
	check(bare.is_empty(), "no roster means an empty faculty")
	var untouched := _enemy("Solo", Schools.School.ROT, Schools.School.INK, [])
	eq(bare.examiner(untouched), untouched, "an unknown examiner falls back to its own resource")
	eq(bare.examiner(null), null, "a null examiner does not crash the lookup")

	_check_generated_rosters()


## The rules the generator has to hold against the REAL content, which is the only content
## whose difficulty was ever measured. A synthetic three-examiner roster cannot exercise
## the cost curve, the status profile or the evolution ladder these depend on.
func _check_generated_rosters() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var opening := library.opening_schools()
	var syllabus := {}  ## examiner name -> schools of the syllabus cards it hands out
	var earliest := {}  ## examiner name -> lowest tier it is met at
	for course in library.courses:
		if course.examiner == null:
			continue
		var key: String = course.examiner.enemy_name
		earliest[key] = mini(int(earliest.get(key, 99)), int(course.tier))
		if not syllabus.has(key):
			syllabus[key] = []
		if course.guaranteed_card_drop != null:
			syllabus[key].append(course.guaranteed_card_drop.school)

	var authored := {}
	for enemy in library.enemies:
		authored[enemy.enemy_name] = enemy

	var substituted := 0
	var total_slots := 0
	var seeds := 25
	for seed_value in range(1, seeds):
		var faculty := Faculty.new(library, seed_value)
		substituted += faculty.slots_substituted
		total_slots += faculty.slots_filled
		for enemy in faculty.all():
			var base: EnemyData = authored[enemy.enemy_name]
			var where := "seed %d, %s" % [seed_value, enemy.enemy_name]

			# --- the deck keeps the shape its difficulty was tuned against ---
			eq(enemy.deck.size(), base.deck.size(), "%s: deck size held" % where)
			var teaches := []
			var cost := 0
			var base_cost := 0
			var damage := 0
			var base_damage := 0
			var statuses := {}
			var base_statuses := {}
			var heals := false
			for i in enemy.deck.size():
				var card: CardData = enemy.deck[i]
				var was: CardData = base.deck[i]
				# Library cards only. A generated CardData has no resource_path, and
				# SaveGame serialises a drafted card BY path -- so an invented card would
				# vanish from the player's deck on the next load.
				check(
					card.resource_path != "" and library.cards.has(card),
					"%s: slot %d is a real library card (%s)" % [where, i, card.card_name]
				)
				if not teaches.has(card.school):
					teaches.append(card.school)
				cost += card.cost
				base_cost += was.cost
				damage += CardPool.direct_damage(card)
				base_damage += CardPool.direct_damage(was)
				heals = heals or CardPool.heals(card)
				for kind in CardPool.statuses_applied(card):
					statuses[kind] = int(statuses.get(kind, 0)) + int(
						CardPool.statuses_applied(card)[kind]
					)
				for kind in CardPool.statuses_applied(was):
					base_statuses[kind] = int(base_statuses.get(kind, 0)) + int(
						CardPool.statuses_applied(was)[kind]
					)

			# The cost curve is the tuning rule generate_enemies.gd spends a paragraph on:
			# at 2 mana an all-1-cost deck plays TWO cards a turn, and dropping Alchemy
			# Master's only 2-cost card took Necrology 201 from a 37% loss to 53%. It has
			# to survive a re-roll exactly, not approximately.
			eq(cost, base_cost, "%s: total mana cost unchanged" % where)
			# The status profile likewise, and exactly: Chill and Blot are non-linear in
			# their own stack count, so "close" is not a defence.
			eq(statuses, base_statuses, "%s: status profile unchanged" % where)
			check(
				absi(damage - base_damage) <= maxi(4, int(0.2 * float(base_damage))),
				"%s: direct damage within tolerance (%d vs %d)" % [where, damage, base_damage]
			)
			# A Decay examiner must never also carry sustain: nothing shrinks a Decay
			# stack and it grows every tick, so healing through it heals into an unbounded
			# number. Structural now -- statuses cannot move between slots -- but asserted
			# because it is the invariant, not the mechanism, that matters.
			check(
				not (heals and int(statuses.get(Statuses.Kind.DECAY, 0)) > 0),
				"%s: does not pair Decay with sustain" % where
			)

			# --- the schools stay learnable ---
			neq(enemy.warded_school, enemy.weak_school, "%s: not both weak and warded alike" % where)
			for school in syllabus.get(enemy.enemy_name, []):
				if not teaches.has(school):
					teaches.append(school)
			# Never weak to a school nothing can deal damage in. Ward's whole line is Block
			# and healing, so weak-to-Ward multiplies the player's Block and does nothing to
			# shorten the fight -- five of those on one roster is what made the world seeded
			# 504 unwinnable.
			neq(
				enemy.weak_school,
				Schools.School.WARD,
				"%s: not weak to a school with no damage cards" % where
			)
			if int(earliest.get(enemy.enemy_name, 99)) <= 1:
				# Tier 1 is the tutorial and its guarantee outranks the flavour rule: the
				# weakness is something the opening deck can hit with, taught or not.
				check(
					opening.has(enemy.weak_school),
					"%s: a tier-1 examiner is weak to a school the player opens with" % where
				)
				check(
					enemy.warded_school != Schools.School.CINDER,
					"%s: a tier-1 examiner is not warded against the opening damage school" % where
				)
			else:
				check(
					teaches.has(enemy.weak_school),
					"%s: weak to a school it teaches" % where
				)

	# The anti-no-op assertion. Every rule above is satisfied perfectly by a generator that
	# returns the authored deck for every slot -- which would pass this whole suite while
	# having generated nothing, the same way a probe policy that never fires reads as a
	# cleared exploit. Measured at ~39%; the floor is set well below that to leave tuning
	# room without letting it fall to zero unnoticed.
	var rate := 100.0 * float(substituted) / maxf(1.0, float(total_slots))
	check(rate > 20.0, "the generator actually substitutes (%.0f%% of slots)" % rate)
