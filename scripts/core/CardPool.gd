class_name CardPool
extends RefCounted

## The library's cards, indexed by the shape of the deck slot each one can fill. This is
## what lets Faculty assemble a per-run examiner deck instead of reading an authored one
## off a .tres.
##
## LIBRARY CARDS ONLY — generation picks from what exists and never invents a stat line,
## and that is a correctness constraint rather than a stylistic one. An examiner's deck
## is exactly what Registration offers the player to copy (Draft takes `examiner_deck`
## and wraps each entry in a CardInstance), and SaveGame serialises a CardInstance as its
## CardData's `resource_path`. A freshly-constructed CardData has no resource path, so the
## first card drafted off a generated examiner would silently vanish on the next load.
## Whatever a slot needs, it has to be something already on disk.
##
## Nothing here mutates a CardData. The index holds references to the library's shared
## resources and only ever reads them.

## What a card is FOR, which is the part of a deck slot that has to survive substitution.
## Ordered by precedence in role_of(): a card that attacks is an attacking card whatever
## else it carries, because damage density is the number every tuning rule in
## tools/generate_enemies.gd is written against.
enum Role { STRIKE, BLOCK, SUSTAIN, DOT, CONTROL, UTILITY }

## Every line in tools/generate_content.gd is five levels deep.
const LEVELS := 5

var _slots := {}  ## "role:cost" -> Array[CardData], sorted by name


func _init(cards: Array) -> void:
	var keyed := {}
	for card in cards:
		if card == null:
			continue
		var key := _key(role_of(card), card.cost)
		if not keyed.has(key):
			keyed[key] = []
		keyed[key].append(card)
	# Sorted by name, not left in library order. The pick is a seeded index into this
	# array, so its order is part of what generation is pure in — and library order is
	# whatever the generator's directory walk produced, which would make the world a
	# player is mid-run in depend on a filename.
	for key in keyed:
		var list: Array = keyed[key]
		list.sort_custom(func(a: CardData, b: CardData) -> bool: return a.card_name < b.card_name)
		_slots[key] = list


static func _key(role: int, cost: int) -> String:
	return "%d:%d" % [role, cost]


## Every card that could fill a slot of this shape, in a stable order. Empty when the
## library has nothing of that role at that cost — Ward, for instance, has no card that
## deals damage at any cost, so there is no STRIKE candidate in it at all.
func candidates(role: int, cost: int) -> Array:
	return _slots.get(_key(role, cost), [])


static func role_of(card: CardData) -> Role:
	if card == null:
		return Role.UTILITY
	var kinds := {}
	var statuses := {}
	for effect in card.effects:
		var kind: String = effect.get("kind", "")
		kinds[kind] = true
		if kind == CardData.STATUS:
			statuses[int(effect.get("status", -1))] = true

	if kinds.has(CardData.DAMAGE) or kinds.has(CardData.BONUS_IF_CHILLED):
		return Role.STRIKE
	if kinds.has(CardData.BLOCK) or kinds.has(CardData.BONUS_IF_WARD_PLAYED):
		return Role.BLOCK
	if kinds.has(CardData.HEAL):
		return Role.SUSTAIN
	# Damage over time, including the card that doubles someone else's Decay.
	if (
		kinds.has(CardData.DOUBLE_DECAY)
		or statuses.has(Statuses.Kind.BURN)
		or statuses.has(Statuses.Kind.DECAY)
	):
		return Role.DOT
	if statuses.has(Statuses.Kind.CHILL) or statuses.has(Statuses.Kind.BLOT):
		return Role.CONTROL
	return Role.UTILITY


## 1 for a base card, 5 for a fully evolved one. Counted by walking the evolution chain
## rather than stored, because nothing on CardData records it. The bound on the walk is a
## guard against a malformed cycle, not an expected case.
static func level_of(card: CardData) -> int:
	if card == null:
		return 1
	var remaining := 0
	var walk := card
	while walk.evolved_card != null and remaining < LEVELS:
		walk = walk.evolved_card
		remaining += 1
	return LEVELS - remaining


## Same-turn damage only, matching tools/generate_content.gd's own definition: Burn and
## Decay pay out over several turns, which is a different balance question.
static func direct_damage(card: CardData) -> int:
	if card == null:
		return 0
	var total := 0
	for effect in card.effects:
		var kind: String = effect.get("kind", "")
		if kind == CardData.DAMAGE or kind == CardData.BONUS_IF_CHILLED:
			total += int(effect.get("amount", 0))
	return total


## Damage that lands whatever the target's state — direct_damage minus the conditional
## part. Checked separately from the total because the two are not the same threat: Glass
## Shard is 9 plus 4 more only against a chilled target, and swapping it for a flat 13
## reads as a like-for-like trade on the total while being a straight buff in practice.
static func unconditional_damage(card: CardData) -> int:
	if card == null:
		return 0
	var total := 0
	for effect in card.effects:
		if effect.get("kind", "") == CardData.DAMAGE:
			total += int(effect.get("amount", 0))
	return total


## Every number the card puts on the table, added up — damage, block, healing, status
## stacks, cards drawn, hit points paid. A crude measure of how big a card is, used to
## keep a substitution in the same weight class as the slot it fills. Damage is checked
## separately and more tightly; this catches the rest, so that a 6-Block Guard cannot
## quietly become a 24-Block Doctoral Sigil just because both are "a block card".
static func weight(card: CardData) -> int:
	if card == null:
		return 0
	var total := 0
	for effect in card.effects:
		total += absi(int(effect.get("amount", 0)))
	return total


## kind -> amount, for the statuses this card applies.
static func statuses_applied(card: CardData) -> Dictionary:
	var out := {}
	if card == null:
		return out
	for effect in card.effects:
		if effect.get("kind", "") != CardData.STATUS:
			continue
		var kind := int(effect.get("status", -1))
		out[kind] = int(out.get(kind, 0)) + int(effect.get("amount", 0))
	return out


## Effect kinds that do nothing at all when an EXAMINER plays the card, so a slot cannot
## trade one for a live effect without changing what the fight costs. Both are live for the
## player, which is why the cards exist:
##
## - MANA_NEXT is banked into Battle._mana_bonus_next only `if source == player`; an
##   examiner playing Cram spends a card and a mana on nothing.
## - BONUS_IF_WARD_PLAYED reads _ward_played_this_turn, which Battle.end_turn clears before
##   handing over, so it is always false by the time the examiner casts. Hall Monitor's
##   Warded Bracers has been granting its 10 Block and never its conditional 4.
const INERT_FOR_EXAMINER: Array[String] = [CardData.MANA_NEXT, CardData.BONUS_IF_WARD_PLAYED]


static func has_kind(card: CardData, kind: String) -> bool:
	if card == null:
		return false
	for effect in card.effects:
		if effect.get("kind", "") == kind:
			return true
	return false


static func has_self_damage(card: CardData) -> bool:
	if card == null:
		return false
	for effect in card.effects:
		if effect.get("kind", "") == CardData.SELF_DAMAGE:
			return true
	return false


static func heals(card: CardData) -> bool:
	if card == null:
		return false
	for effect in card.effects:
		if effect.get("kind", "") == CardData.HEAL:
			return true
	return false
