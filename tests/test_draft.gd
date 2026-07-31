extends TestCase

## Registration: rebuilding the run deck to a fixed cap from the player's own cards
## plus whatever the grade lets them copy off the defeated examiner's deck.


func suite_name() -> String:
	return "draft"


func _data(name: String) -> CardData:
	var d := CardData.new()
	d.card_name = name
	return d


func _own(n: int) -> Array:
	var out := []
	for i in n:
		out.append(CardInstance.new(_data("own%d" % i)))
	return out


func _pool(n: int) -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		out.append(_data("theirs%d" % i))
	return out


func run() -> void:
	# The cap grows per COURSE, not per tier, so the very first Registration can
	# already add a card rather than only swapping.
	eq(Draft.cap_for(0), 10, "starting cap is ten")
	eq(Draft.cap_for(1), 11, "grows after one course")
	eq(Draft.cap_for(5), 15, "grows to fifteen")
	eq(Draft.cap_for(6), 16, "saturates at sixteen")
	eq(Draft.cap_for(99), 16, "never exceeds sixteen")

	# Grade gates how much of their deck is offered.
	var syllabus := _data("syllabus")
	var s_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.S)
	eq(s_draft.offered.size(), 9, "S offers the whole deck plus the syllabus card")
	var a_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.A)
	eq(a_draft.offered.size(), 6, "A offers five plus the syllabus card")
	var b_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.B)
	eq(b_draft.offered.size(), 4, "B offers three plus the syllabus card")
	var c_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.C)
	eq(c_draft.offered.size(), 2, "C offers one plus the syllabus card")
	var f_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.F)
	eq(f_draft.offered.size(), 1, "F still offers the syllabus card")

	# An F offers only the syllabus card, and it is the syllabus card.
	eq(f_draft.offered[0].data.card_name, "syllabus", "the syllabus card is always there")

	# You cannot copy more cards than the examiner had, nor more copies of one card
	# than it owned. The shipped tier-1 decks are 4-5 cards with repeats, so this is
	# the real shape of the input, not an edge case. An earlier draft of this plan
	# built the offer order as "distinct cards, then the whole deck again", which let
	# a 4-card deck offer 5 (more copies of one card than the examiner ever owned).
	# The correct approach partitions into distinct-first plus leftover duplicates and
	# clamps to the ordered list's own size, which never exceeds the real deck size.
	var dup := _data("dup")
	var other := _data("other")
	var thin := Draft.new(_own(10), [dup, dup, dup, other], syllabus, Grading.Grade.A)
	eq(thin.offered.size(), 5, "four of theirs plus the syllabus, not the full allowance")
	var dup_count := 0
	var other_count := 0
	var dup_instances: Array = []
	for card in thin.offered:
		if card.data.card_name == "dup":
			dup_count += 1
			dup_instances.append(card)
		elif card.data.card_name == "other":
			other_count += 1
	eq(dup_count, 3, "offered exactly the three copies they owned")
	eq(other_count, 1, "the fourth distinct card is offered exactly once")

	# The syllabus card is always offered — not just when it's the only card (F,
	# checked above), but alongside a full allowance too. Presence, not just count,
	# since a broken _init could drop it silently while everything else still adds up.
	var syllabus_in_s := 0
	for card in s_draft.offered:
		if card.data.card_name == "syllabus":
			syllabus_in_s += 1
	eq(syllabus_in_s, 1, "the syllabus card is offered even at a full allowance")

	# The single most important rule in this task: distinct cards must be offered
	# before duplicates, so a small allowance against a repetitive deck reaches the
	# one interesting card rather than exhausting itself on repeats of the first
	# thing seen. Grade B (allowance 3) against [dup, dup, dup, other]: naive
	# in-order iteration offers only [dup, dup, dup] and "other" never appears.
	# Distinct-first partitioning offers [dup, other, dup] instead.
	var thin_b := Draft.new(_own(10), [dup, dup, dup, other], syllabus, Grading.Grade.B)
	eq(thin_b.offered.size(), 4, "three of theirs plus the syllabus, at grade B")
	var b_dup_count := 0
	var b_other_count := 0
	for card in thin_b.offered:
		if card.data.card_name == "dup":
			b_dup_count += 1
		elif card.data.card_name == "other":
			b_other_count += 1
	eq(b_other_count, 1, "the distinct card is reached before the allowance runs out")
	eq(b_dup_count, 2, "only two of the three duplicates fit in the remaining allowance")

	# Each copy is its own CardInstance, not one instance listed three times — sharing
	# one instance across "copies" would mean training one dup trains all of them.
	neq(dup_instances[0], dup_instances[1], "first and second dup copies are distinct objects")
	neq(dup_instances[0], dup_instances[2], "first and third dup copies are distinct objects")
	dup_instances[0].xp = 1
	eq(dup_instances[1].xp, 0, "training one copy leaves its siblings untouched")

	# Offered cards arrive untrained — both the syllabus card and copies from the
	# examiner's deck.
	eq(s_draft.offered[0].xp, 0, "the syllabus copy starts at zero xp")
	eq(dup_instances[2].xp, 0, "a copy from the examiner's deck starts at zero xp")

	# Asking for a deck of exactly the cap succeeds.
	var draft := Draft.new(_own(10), _pool(4), syllabus, Grading.Grade.S)
	draft.cap = 11
	var selection := draft.own.duplicate()
	selection.append(draft.offered[0])
	var kept := draft.keep(selection)
	eq(kept.size(), 11, "kept eleven")

	# Too many or too few is refused rather than silently truncated.
	eq(draft.keep(draft.own.duplicate()).size(), 0, "ten is not eleven")
	var too_many := draft.own.duplicate()
	too_many.append_array(draft.offered)
	eq(draft.keep(too_many).size(), 0, "more than the cap is refused")

	# A card that came from neither list is refused. The selection is built at
	# exactly cap size (own + one offered card, same shape as the accepted selection
	# above) so a broken membership check is what fails this, not a size mismatch —
	# a smuggled card slipped into a same-size selection is the real threat.
	var smuggled := draft.own.duplicate()
	smuggled.append(draft.offered[0])
	smuggled[0] = CardInstance.new(_data("smuggled"))
	eq(draft.keep(smuggled).size(), 0, "cards must come from the pool")

	# Picking the same instance twice to pad out the cap is refused, even though the
	# selection is the right size and every card in it is individually legal.
	var doubled := draft.own.duplicate()
	doubled.append(draft.own[0])
	eq(doubled.size(), 11, "still eleven slots")
	eq(draft.keep(doubled).size(), 0, "the same instance cannot fill two slots")

	# Cutting a trained card destroys its XP — the point of the whole screen. XP is
	# set directly rather than via gain_xp(), which requires an evolve target
	# (CardData.evolved_card) the plain test fixtures don't set up; test_deck.gd
	# uses the same direct-assignment convention.
	var trained := Draft.new(_own(2), _pool(1), syllabus, Grading.Grade.S)
	trained.cap = 2
	trained.own[0].xp = 2
	eq(trained.own[0].xp, 2, "trained to two")
	var cut := trained.keep([trained.own[1], trained.offered[0]])
	eq(cut.size(), 2, "kept two")
	for card in cut:
		neq(card.data.card_name, "own0", "the trained card is gone")
	check(not cut.has(trained.own[0]), "the specific trained instance, xp and all, did not survive")

	# Kept cards keep their XP.
	var retained := Draft.new(_own(2), _pool(0), syllabus, Grading.Grade.F)
	retained.cap = 2
	retained.own[0].xp = 1
	var kept_trained := retained.keep([retained.own[0], retained.own[1]])
	eq(kept_trained.size(), 2, "kept both")
	var found_xp := 0
	for card in kept_trained:
		found_xp += card.xp
	eq(found_xp, 1, "the earned xp survived")
