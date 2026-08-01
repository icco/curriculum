class_name Faculty
extends RefCounted

## This run's examiners: one variant per examiner in the content library, with its weak
## school, its warded school and its DECK all rolled fresh for the run.
##
## Why this exists. The brief calls an examiner's wards and weaknesses "hidden", and says
## discovering one grants a multiplier "for the rest of the run" — both of which only mean
## something if they differ between runs. Authored into the .tres roster they were fixed
## forever, so a player who had been through the catalog twice knew every matchup before
## starting, and met the same five cards in the same fight every time.
##
## Variants are DUPLICATES. Rolling onto the library's own EnemyData would write through to
## a shared Resource and leak across runs — the same bug spec section 4 calls the easiest
## to get wrong invisibly, and the reason card XP lives on CardInstance rather than
## CardData. Nothing here writes to a loaded resource; the deck is rebuilt as a new array
## of references to library cards, never edited in place.
##
## Generation is pure in (library, seed), which is what lets a save store a single integer
## and rebuild the identical faculty. Everything the roll is constrained by is read off the
## ContentLibrary — including the schools the player opens with, which come from
## `starting_deck` and NOT from the run's current deck. See ContentLibrary.opening_schools()
## for why that distinction decides whether a continued run faces the faculty it started
## against.
##
##
## WHY THE DECK ROLL CANNOT MOVE THE DIFFICULTY MUCH, AND WHERE IT CAN
##
## An examiner's cards are resolved at a flat 1.0 scale (Battle._examiner_turn): the
## weak/ward multiplier is a property of the examiner being hit, so it applies to the
## PLAYER's cards only. An examiner's card therefore has no school-dependent power at all,
## and swapping a card for another of the same role, cost and size changes what the fight
## looks like without changing what it costs. That is the whole reason decks can be rolled
## at all, and it is why substitution is constrained on shape rather than on flavour.
##
## Three places it does bite, each guarded below:
##
## 1. STATUSES are not interchangeable. Decay grows by 2 a tick and can never be removed;
##    Chill cuts the player's damage, so it lengthens the fight that produces more Chill.
##    The roster was measured with a specific count of each. A roll may move one of these
##    around inside an examiner's deck; it may never hand an examiner one it never had, or
##    a bigger one than it authored.
## 2. The DECK IS THE DRAFT. Registration offers the player exactly what the examiner
##    played, so a deck rolled full of cards three tiers above its own would hand the
##    player a tier-3 deck at course one. The level band and size tolerance below are what
##    hold that.
## 3. SELF-DAMAGE cards (the Bitter Recall line) shorten the fight from the examiner's own
##    side and can kill it mid-turn — Battle stops casting on examiner.is_down(). Only a
##    slot authored with that drawback may take a card carrying it.
##
##
## WHY THE WEAKNESS ROLL IS CONSTRAINED AT ALL
##
## Rolling it unconstrained has been measured and is badly wrong: over 120 runs across 12
## worlds, greedy bot went from 17.5% graduating on authored weaknesses to 6.7% on uniform
## ones. The authored weaknesses were doing two jobs by hand. They were an implicit
## tutorial — the opening courses are weak to schools the starting deck holds and warded
## against ones it does not — and the whole roster was tuned assuming those matchups.
##
## The tutorial half is now a rule rather than a table (see _weak_allowed and _ward_allowed):
## an examiner met in a tier-1 course is weak to a school the player opens with, and is
## never warded against the one school they open with DAMAGE in. At tier 1 the player's
## deck is fixed and tiny — four Spark, four Guard, two Ink Blot — so halving their only
## damage school is not a hard fight, it is an unwinnable one. That is the same argument
## the defensive-ward rule already makes, applied to the opening.
##
## The tuning half is answered by the deck roll keeping every fight's shape, above.

## What the generator is allowed to vary. GENERATIVE is the game. The rest exist for
## tools/simulate.gd, and they are not decoration: the only way to attribute a difficulty
## change to the generator is to run the SAME plumbing with its output pinned to the
## authored content and check the baseline still reproduces. Getting that wrong is how the
## first attempt at this task misread broken plumbing as a broken generator.
enum Rolls {
	GENERATIVE,  ## decks, weaknesses and wards
	NONE,  ## nothing — the authored roster, through all of this machinery
	WARDS,  ## wards only, which is what shipped before decks and weaknesses landed
	SCHOOLS,  ## weaknesses and wards, authored decks
	DECKS,  ## decks only, authored schools
}

## How far from its own the level band around a slot reaches. One step: a slot authored
## with a base card can take that line's second form, and no further. Wider and an early
## examiner starts handing the player cards from the end of the evolution track.
const LEVEL_DRIFT := 1

## How far a substitution may differ in size from the slot it fills, as a fraction, with
## an absolute floor so that small numbers are not pinned exact by rounding. Applied to
## direct damage and to the card's total magnitude separately — damage because it is the
## number fights are lost to, total because it stops a 6-Block Guard becoming a 24-Block
## Doctoral Sigil on the grounds that both are "a block card".
const SIZE_TOLERANCE := 0.25
const SIZE_FLOOR := 2

## Statuses whose surplus is a documented pathology rather than just a bigger number, and
## which a roll therefore may not inflate. Burn is absent deliberately: it decrements every
## tick and is bounded by the size tolerance like any other stat line.
const CEILINGED: Array[int] = [Statuses.Kind.CHILL, Statuses.Kind.BLOT, Statuses.Kind.DECAY]

var _variants := {}  ## enemy_name -> EnemyData
var _order: Array[String] = []

## Measurement, not gameplay. A generator whose every slot falls back to its authored card
## ships the authored decks with new plumbing over the top, and passes every test while
## having generated nothing — the same trap as a probe policy that never fires. Reported by
## tools/simulate.gd so the substitution rate cannot quietly go to zero.
var slots_filled := 0
var slots_substituted := 0


## `content` may be null — that is what a suite constructing a bare Run gets, and it leaves
## the faculty empty and every examiner on its authored schools and deck.
func _init(content: ContentLibrary, content_seed: int, rolls: Rolls = Rolls.GENERATIVE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = content_seed

	var roster: Array = []
	var starting_schools: Array[int] = []
	var pool: CardPool = null
	var tier_of := {}
	var syllabus_of := {}
	if content != null:
		for base in content.enemies:
			if base != null:
				roster.append(base)
		starting_schools = content.opening_schools()
		pool = CardPool.new(content.cards)
		tier_of = _earliest_tiers(content.courses)
		syllabus_of = _syllabus_schools(content.courses)
	var opening_offence := _offensive_schools(content)

	# Dealt from a stratified bag rather than rolled independently. Uniform rolls cluster:
	# with nine examiners and five schools, worlds where one school is nobody's ward are
	# common rather than a tail case. Dealing a full shuffled set of schools before
	# repeating any keeps each run's spread even, and close to the authored roster's, which
	# ran 3 Cinder / 2 Frost / 2 Rot / 1 Ink / 1 Ward on weaknesses.
	var dealt_weak := _deal(roster.size(), rng)
	var dealt_wards := _deal(roster.size(), rng)

	for i in roster.size():
		var base: EnemyData = roster[i]

		# Deck first, and the ward rules are then evaluated against the deck the examiner
		# ACTUALLY holds. Reading "is this examiner defensive?" off the authored deck would
		# constrain the ward for a deck it never plays.
		var deck := _roll_deck(base, pool, rng, rolls)
		var defensive := _is_defensive(deck)
		var tier := int(tier_of.get(base.enemy_name, 99))

		# Both schools resolve as ONE constrained pick each, not as sequential patches.
		# Applied in sequence they fight: an earlier version's "never weak and warded alike"
		# fix-up ran after the defensive rule and could hand the ward straight back to a
		# starting school, which test_faculty caught at 5 seeds in 60. The weakness is
		# settled first so the ward can be constrained against its final value.
		var teaches := _teaches(deck, syllabus_of.get(base.enemy_name, []))

		var weak := base.weak_school
		if rolls == Rolls.GENERATIVE or rolls == Rolls.SCHOOLS:
			weak = _weak_candidates(teaches, tier, starting_schools, rng, dealt_weak[i])

		var ward := base.warded_school
		if rolls == Rolls.GENERATIVE or rolls == Rolls.SCHOOLS or rolls == Rolls.WARDS:
			ward = _resolve_ward(
				dealt_wards[i],
				weak,
				defensive,
				tier,
				starting_schools,
				opening_offence,
				teaches,
				rng
			)

		var variant: EnemyData = base.duplicate()
		# duplicate() copies the exported properties, but the deck array is shared with the
		# library's resource. Assigning a freshly built array is what keeps the roll off it.
		variant.deck = deck
		# The name is the Bestiary's key and must survive untouched, or knowledge learned
		# about "Glass Tutor" stops applying to the Glass Tutor.
		variant.enemy_name = base.enemy_name
		variant.weak_school = weak
		variant.warded_school = ward

		_variants[variant.enemy_name] = variant
		_order.append(variant.enemy_name)


# --- decks ---------------------------------------------------------------------------


## The authored deck, slot by slot, with each card swapped for another the library already
## holds that fills the same slot. Falls back to the authored card whenever nothing else
## fits, which is a legitimate outcome for a narrow slot — Ward is the only school with a
## 1-cost Block card, so a Guard slot is always going to be a Ward card.
func _roll_deck(
	base: EnemyData, pool: CardPool, rng: RandomNumberGenerator, rolls: Rolls
) -> Array[CardData]:
	var out: Array[CardData] = []
	out.assign(base.deck)
	if pool == null or not (rolls == Rolls.GENERATIVE or rolls == Rolls.DECKS):
		return out

	var built: Array[CardData] = []
	for authored in base.deck:
		slots_filled += 1
		var eligible := _eligible(authored, pool)
		# _fits accepts the authored card unconditionally, so this is only empty when the
		# card is not in the library's index at all — which the game's own content never
		# does, but a suite handing over a roster without an index does. Falling back is the
		# correct answer either way; crashing on it would make the index a load-bearing
		# invariant that nothing declares.
		var chosen: CardData = authored
		if not eligible.is_empty():
			chosen = eligible[rng.randi_range(0, eligible.size() - 1)]
		if chosen != authored:
			slots_substituted += 1
		built.append(chosen)
	return built


func _eligible(authored: CardData, pool: CardPool) -> Array:
	var out: Array = []
	for candidate in pool.candidates(CardPool.role_of(authored), authored.cost):
		if _fits(authored, candidate):
			out.append(candidate)
	return out


static func _fits(authored: CardData, candidate: CardData) -> bool:
	# The authored card always fills its own slot. Stated rather than left to fall out of
	# the rules below, so that the fallback stays a real option even if a later rule would
	# have excluded it — an empty candidate list is a bug, not a content state.
	if candidate == authored:
		return true

	if absi(CardPool.level_of(candidate) - CardPool.level_of(authored)) > LEVEL_DRIFT:
		return false
	# Exhaust is a combat difference for the examiner too: an exhausted card does not come
	# back, so a five-card deck quietly shrinks. `retain` is NOT checked, because the
	# examiner never discards its hand (Battle.end_turn discards the player's only), so
	# retain is a property of the card as a draft prize rather than as a threat.
	if candidate.exhaust != authored.exhaust:
		return false
	if CardPool.has_self_damage(candidate) and not CardPool.has_self_damage(authored):
		return false
	# An effect that does nothing on an examiner's turn is not a like-for-like trade in
	# either direction: swapping Marginalia's draw for All-Nighter's mana hands the examiner
	# a card that costs it a mana and does literally nothing, and swapping the other way
	# hands it a live card it was never tuned with.
	for kind in CardPool.INERT_FOR_EXAMINER:
		if CardPool.has_kind(candidate, kind) != CardPool.has_kind(authored, kind):
			return false
	if not _within(CardPool.direct_damage(candidate), CardPool.direct_damage(authored)):
		return false
	if not _within(CardPool.unconditional_damage(candidate), CardPool.unconditional_damage(authored)):
		return false
	if not _within(CardPool.weight(candidate), CardPool.weight(authored)):
		return false

	# THE STATUSES A SLOT APPLIES ARE PART OF THE SLOT, and this is the rule the first
	# measured version of this generator was missing. With statuses free to come and go
	# inside the size tolerance, a roll quietly eroded them — over 40 seeds the roster lost
	# 34% of its Chill and 15% of its Blot while direct damage and cost came out exactly
	# even, and graduation went from 17.5% to 34.2%. Chill cuts the PLAYER's damage, so
	# dropping it is a straight buff to them that no damage total shows.
	#
	# Pinning the set (not the amount) also makes two other guarantees structural rather
	# than policed: an examiner can never acquire a Decay it was not authored with, so it
	# can never become the Decay-plus-sustain deck that heals into an unbounded stack, and
	# the count of Chill sources per deck is exactly what was measured.
	var applied := CardPool.statuses_applied(candidate)
	var authored_applied := CardPool.statuses_applied(authored)
	if applied.size() != authored_applied.size():
		return false
	for kind in applied:
		if not authored_applied.has(kind):
			return false
		# CHILL, BLOT and DECAY are matched to the STACK, not merely capped, because none of
		# them is linear in its own number and the size tolerance cannot see that. Blot cuts
		# every number on the player's next card by 40% a stack: two stacks is an 80%
		# reduction and one is 40%, so "one less Blot" halves the mitigation while reading as
		# a one-point trade. Measured, letting these drift down inside the tolerance took the
		# two gates and the final from 42/60% loss rates to 24/41% and graduation from 17.5%
		# to 36.7% — with total damage, cost and Decay all coming out exactly even.
		if kind in CEILINGED:
			if int(applied[kind]) != int(authored_applied[kind]):
				return false
		elif not _within(int(applied[kind]), int(authored_applied[kind])):
			return false
	return true


static func _within(got: int, want: int) -> bool:
	var slack := maxi(SIZE_FLOOR, int(roundf(absf(float(want)) * SIZE_TOLERANCE)))
	return absi(got - want) <= slack


# --- schools -------------------------------------------------------------------------


## AN EXAMINER IS WEAK TO SOMETHING IT TEACHES: its weak school is drawn from the schools
## in the deck it plays and in the syllabus cards of the courses it sets.
##
## This is the rule that makes a rolled weakness survivable, and it took three measured
## attempts to find. A weakness is only worth anything if the player HAS that school, and
## what they have is almost entirely downstream of the examiners: Registration offers them
## the cards the examiner just played, and every course hands them its syllabus card.
## Rolling the weakness free of that — even constrained to the schools the player opens
## with — put the ×1.5 on a school their deck barely contains, which is why an
## unconstrained roll measured 6.7% against 17.5% on the authored table, and why this
## generator measured 5.8% before this rule. The authored weaknesses were not arbitrary;
## they were correlated with the roster's own Cinder-and-Ward decks by hand.
##
## It is also the better game. The examiner's cards are face-up as it plays them, so the
## player can now REASON about the weakness — it is one of the two or three schools they
## just watched it cast — instead of probing five schools blind. Discovery becomes
## deduction, which is what the Bestiary is for.
##
## Tier 1 narrows it further, to something the player opens with, so the first courses
## still teach the mechanic against the deck they actually hold.
static func _weak_candidates(
	teaches: Array, tier: int, starting_schools: Array, rng: RandomNumberGenerator, dealt: int
) -> int:
	# Preference order, most constrained first. Each falls through only when the previous
	# leaves nothing, which a narrow rolled deck can do.
	var ladders: Array = []
	if tier <= 1 and not starting_schools.is_empty():
		var opening: Array[int] = []
		for school in teaches:
			if starting_schools.has(school):
				opening.append(school)
		ladders.append(opening)
	ladders.append(teaches)
	ladders.append(Schools.ALL)

	for allowed in ladders:
		if allowed.is_empty():
			continue
		# The stratified deal still decides whenever it lands inside the allowed set, so the
		# roster keeps an even spread of weaknesses across schools rather than collapsing
		# onto whichever school the decks happen to favour.
		if allowed.has(dealt):
			return dealt
		return allowed[rng.randi_range(0, allowed.size() - 1)]
	return dealt


## The schools an examiner puts in front of the player: the ones in the deck it plays, plus
## the syllabus card every course it sets hands out whatever the grade.
static func _teaches(deck: Array[CardData], syllabus: Array) -> Array[int]:
	var out: Array[int] = []
	for card in deck:
		if card != null and not out.has(card.school):
			out.append(card.school)
	for school in syllabus:
		if not out.has(school):
			out.append(school)
	return out


## The ward rules, hardest first. Rule A is spec section 5 and is absolute; the other two
## are preferences, and the relaxation order below is what stops them deadlocking a roll.
##
## A. Never weak and warded to the same school.
## B. A defensive examiner is never warded against a school the player opens with. Halving
##    the player's damage against a deck that is mostly Block does not make a hard fight,
##    it makes an unbreakable one — unconstrained, Proctor's Inspection measured a 43% loss
##    over 11.1 turns, the stalemate its own roster entry warns about.
## C. An examiner met in a tier-1 course is never warded against a school the player opens
##    with DAMAGE in. At tier 1 that is Cinder alone, and the deck is still four Spark, four
##    Guard and two Ink Blot: there is no second damage school to fall back on and no draft
##    has happened yet. On main this was measurably the worst thing a random ward did —
##    Basic Arcana 101, the first course in the game, lost 28% of runs over 10.8 turns.
## D. An examiner is not warded against a school it teaches. The weakness is drawn FROM
##    what it teaches, so this is the other half of one idea: what an examiner hands you is
##    what beats it, and what it resists is what it never showed you. Without it, an
##    examiner could hand the player a school over two courses and halve it on the rematch.
static func _ward_allowed(
	school: int,
	weak: int,
	defensive: bool,
	tier: int,
	starting_schools: Array,
	opening_offence: Array,
	teaches: Array
) -> bool:
	if school == weak:
		return false
	if defensive and starting_schools.has(school):
		return false
	if tier <= 1 and opening_offence.has(school):
		return false
	if teaches.has(school):
		return false
	return true


static func _resolve_ward(
	dealt: int,
	weak: int,
	defensive: bool,
	tier: int,
	starting_schools: Array,
	opening_offence: Array,
	teaches: Array,
	rng: RandomNumberGenerator
) -> int:
	if _ward_allowed(dealt, weak, defensive, tier, starting_schools, opening_offence, teaches):
		return dealt
	# Relaxed one preference at a time, rule A last and never: it is the spec's, where the
	# rest are difficulty guards that a narrow school set may make unsatisfiable together.
	# Rule D goes first because it is the most likely to leave nothing — an examiner playing
	# three schools has only two it does not teach.
	for relax in [0, 1, 2, 3]:
		var allowed: Array[int] = []
		for school in Schools.ALL:
			var soft_teaches: Array = teaches if relax < 1 else []
			var soft_defensive: bool = defensive and relax < 2
			var soft_tier: int = 99 if relax >= 3 else tier
			if _ward_allowed(
				school,
				weak,
				soft_defensive,
				soft_tier,
				starting_schools,
				opening_offence,
				soft_teaches
			):
				allowed.append(school)
		if not allowed.is_empty():
			return allowed[rng.randi_range(0, allowed.size() - 1)]
	return dealt


## Whether an examiner wins by outlasting rather than by hitting. Measured off the deck it
## actually holds, so a rolled deck moves this with it rather than leaving a hardcoded name
## list behind.
static func _is_defensive(deck: Array[CardData]) -> bool:
	if deck.is_empty():
		return false
	var defensive := 0
	for card in deck:
		var role := CardPool.role_of(card)
		if role == CardPool.Role.BLOCK or role == CardPool.Role.SUSTAIN:
			defensive += 1
	return float(defensive) / float(deck.size()) >= 0.4


## The schools the player opens with a DAMAGE card in — Cinder alone, from the starting
## deck's Sparks. Their Guards are Block and their Ink Blots are a status, so neither is
## something a ward can take away from them.
static func _offensive_schools(content: ContentLibrary) -> Array[int]:
	var out: Array[int] = []
	if content == null:
		return out
	for card in content.starting_deck:
		if card != null and CardPool.direct_damage(card) > 0 and not out.has(card.school):
			out.append(card.school)
	return out


## examiner name -> the lowest course tier it is ever met at. An examiner fought twice at
## two tiers is constrained by the earlier one, since that is where the player is least
## equipped to cope with it.
static func _earliest_tiers(courses: Array) -> Dictionary:
	var out := {}
	for course in courses:
		if course == null or course.examiner == null:
			continue
		var name: String = course.examiner.enemy_name
		out[name] = mini(int(out.get(name, 99)), int(course.tier))
	return out


## examiner name -> the schools of the syllabus cards its courses hand out. Part of what an
## examiner "teaches", and the half the player is guaranteed to receive: Draft always offers
## the syllabus card whatever the grade, where the examiner's own cards are rationed by it.
static func _syllabus_schools(courses: Array) -> Dictionary:
	var out := {}
	for course in courses:
		if course == null or course.examiner == null or course.guaranteed_card_drop == null:
			continue
		var name: String = course.examiner.enemy_name
		if not out.has(name):
			out[name] = []
		var school: int = course.guaranteed_card_drop.school
		if not out[name].has(school):
			out[name].append(school)
	return out


## `count` schools, drawn so every school appears before any repeats. Fisher-Yates against
## the run's own generator, so the result is a pure function of the seed.
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


## This run's version of an examiner. Falls back to the base resource when the faculty has
## no entry for it, so a caller built without a library (most suites) keeps the authored
## content instead of crashing.
func examiner(base: EnemyData) -> EnemyData:
	if base == null:
		return null
	return _variants.get(base.enemy_name, base)


## Every variant, in library order — what the Bestiary screen should list, so it shows this
## run's schools rather than the authored ones.
func all() -> Array:
	var out: Array = []
	for enemy_name in _order:
		out.append(_variants[enemy_name])
	return out


func is_empty() -> bool:
	return _order.is_empty()
