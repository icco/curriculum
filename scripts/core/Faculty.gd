class_name Faculty
extends RefCounted

## This run's examiners: one variant per examiner in the content library, with the
## warded school rolled fresh for the run.
##
## Why this exists. The brief calls an examiner's wards and weaknesses "hidden", and
## says discovering one grants a multiplier "for the rest of the run" — both of which
## only mean something if they differ between runs. Authored into the .tres roster they
## were fixed forever, so a player who had been through the catalog twice knew every
## matchup before starting.
##
## Variants are DUPLICATES. Rolling onto the library's own EnemyData would write through
## to a shared Resource and leak across runs — the same bug spec section 4 calls the
## easiest to get wrong invisibly, and the reason card XP lives on CardInstance rather
## than CardData. Nothing here writes to a loaded resource.
##
## Generation is pure in (library, seed), which is what lets a save store a single
## integer and rebuild the identical faculty. Everything the roll is constrained by is
## read off the ContentLibrary — including the schools the player opens with, which come
## from `starting_deck` and NOT from the run's current deck. See
## ContentLibrary.opening_schools() for why that distinction decides whether a continued
## run faces the faculty it started against.
##
##
## WHY ONLY THE WARD IS ROLLED
##
## The weak school stays as authored, and that is a measured decision rather than a
## half-finished one. Over 120 runs across 12 generated worlds, greedy bot:
##
##     authored weak + authored ward   17.5% graduated, 10.4 courses/run
##     authored weak + random ward     15.0% graduated,  9.8 courses/run   <- shipped
##     random weak   + authored ward    6.7% graduated
##     random weak   + random ward      3.3% graduated,  6.9 courses/run
##
## The authored weaknesses are load-bearing content, not decoration. Two things they
## were doing by hand:
##
## 1. They are an implicit tutorial. The opening courses are weak to Cinder and Ink —
##    exactly the starting deck — and warded against Frost, which the player owns none
##    of. That teaches the weakness mechanic while the deck is still four Sparks and
##    four Guards.
## 2. The whole roster was tuned against them. Every examiner's hit points and deck were
##    balanced assuming a particular matchup, so rolling the weakness changes the
##    difficulty of every fight at once.
##
## Constraining the roll was tried and is not sufficient: forcing EVERY examiner to be
## weak to a school the player already owns still only reached 7.5%, less than half the
## way back. Making weaknesses generative means retuning the roster to be
## school-agnostic — no deck degenerate under any assignment, no difficulty resting on
## the player's opening schools — which is the same job as making the decks generative,
## and belongs with it rather than bolted onto this.

var _variants := {}  ## enemy_name -> EnemyData
var _order: Array[String] = []


## `content` may be null — that is what a suite constructing a bare Run gets, and it
## leaves the faculty empty and every examiner on its authored schools.
func _init(content: ContentLibrary, content_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = content_seed

	var roster: Array = []
	var starting_schools: Array[int] = []
	if content != null:
		for base in content.enemies:
			if base != null:
				roster.append(base)
		starting_schools = content.opening_schools()

	# Dealt from a stratified bag rather than rolled independently. Uniform rolls
	# cluster: with nine examiners and five schools, worlds where one school is nobody's
	# ward are common rather than a tail case. Dealing a full shuffled set of schools
	# before repeating any keeps each run's spread even.
	var wards := _deal(roster.size(), rng)

	for i in roster.size():
		var base: EnemyData = roster[i]

		# Both ward rules resolve as ONE constrained pick, not two sequential patches.
		# Applied in sequence they fight: the "never weak and warded alike" fix-up ran
		# after the defensive rule and could hand the ward straight back to a starting
		# school, which test_faculty caught at 5 seeds in 60.
		#
		# Rule A, spec section 5: never weak and warded to the same school.
		# Rule B: a defensive examiner is never warded against a school the player opens
		# with. Halving the player's damage against a deck that is mostly Block does not
		# make a hard fight, it makes an unbreakable one — with this unconstrained,
		# Proctor's Inspection measured a 43% loss over 11.1 turns, the stalemate its own
		# roster entry in generate_enemies.gd warns about.
		var defensive := _is_defensive(base)
		if wards[i] == base.weak_school or (defensive and starting_schools.has(wards[i])):
			var allowed: Array[int] = []
			for school in Schools.ALL:
				if school == base.weak_school:
					continue
				if defensive and starting_schools.has(school):
					continue
				allowed.append(school)
			# Rule B is a preference, rule A is not: if excluding the player's schools
			# leaves nothing, fall back to any school that merely is not the weakness.
			if allowed.is_empty():
				for school in Schools.ALL:
					if school != base.weak_school:
						allowed.append(school)
			wards[i] = allowed[rng.randi_range(0, allowed.size() - 1)]

		var variant: EnemyData = base.duplicate()
		# duplicate() copies the exported properties, but the deck array is shared with
		# the library's resource. Nothing here edits it; duplicating anyway means a
		# later generative-deck pass cannot silently write through to it.
		variant.deck = base.deck.duplicate()
		# The name is the Bestiary's key and must survive untouched, or knowledge
		# learned about "Glass Tutor" stops applying to the Glass Tutor.
		variant.enemy_name = base.enemy_name
		variant.weak_school = base.weak_school
		variant.warded_school = wards[i]

		_variants[variant.enemy_name] = variant
		_order.append(variant.enemy_name)


## Whether an examiner wins by outlasting rather than by hitting. Measured off the deck
## it actually holds, so a deck retuned in generate_enemies.gd moves this with it rather
## than leaving a hardcoded name list behind.
static func _is_defensive(enemy: EnemyData) -> bool:
	if enemy.deck.is_empty():
		return false
	var defensive := 0
	for card in enemy.deck:
		for effect in card.effects:
			if effect.get("kind", "") in [CardData.BLOCK, CardData.HEAL]:
				defensive += 1
				break
	return float(defensive) / float(enemy.deck.size()) >= 0.4


## `count` schools, drawn so every school appears before any repeats. Fisher-Yates
## against the run's own generator, so the result is a pure function of the seed.
static func _deal(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var bag: Array[int] = []
	while bag.size() < count:
		var batch: Array[int] = []
		batch.assign(Schools.ALL)
		for i in range(batch.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := batch[i]
			batch[i] = batch[j]
			batch[j] = swap
		bag.append_array(batch)
	return bag.slice(0, count)


## This run's version of an examiner. Falls back to the base resource when the faculty
## has no entry for it, so a caller built without a library (most suites) keeps the
## authored schools instead of crashing.
func examiner(base: EnemyData) -> EnemyData:
	if base == null:
		return null
	return _variants.get(base.enemy_name, base)


## Every variant, in library order — what the Bestiary screen should list, so it shows
## this run's schools rather than the authored ones.
func all() -> Array:
	var out: Array = []
	for enemy_name in _order:
		out.append(_variants[enemy_name])
	return out


func is_empty() -> bool:
	return _order.is_empty()
