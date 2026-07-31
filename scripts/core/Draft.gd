class_name Draft
extends RefCounted

## Registration. Pools the player's surviving deck with what their grade lets them
## copy off the defeated examiner, then keeps exactly `cap` cards. Cutting a card
## discards its CardInstance — and with it the XP it earned — which is the decision
## the whole screen exists to pose.

const BASE_CAP := 10
const MAX_CAP := 16

var own: Array = []  ## Array[CardInstance] — the surviving run deck
var offered: Array = []  ## Array[CardInstance] — fresh copies, XP 0
var cap := BASE_CAP


## Grows per course passed, not per tier: a per-tier cap would equal the starting
## deck size when the first Registration screen opens, leaving nothing to do on five
## of the fifteen courses.
static func cap_for(courses_passed: int) -> int:
	return mini(BASE_CAP + maxi(0, courses_passed), MAX_CAP)


func _init(
	own_cards: Array, examiner_deck: Array[CardData], syllabus_card: CardData, grade
) -> void:
	own = own_cards.duplicate()

	# The syllabus card is always offered, whatever the grade, so a course always
	# teaches something.
	if syllabus_card != null:
		offered.append(CardInstance.new(syllabus_card))

	var allowance: int = Grading.draft_allowance(grade)
	if allowance == 0:
		return

	# Distinct cards first, so a generous allowance against a repetitive deck does not
	# spend itself on duplicates before the player sees the interesting card — but the
	# ordering must PRESERVE THE MULTISET. Appending the whole deck again after the
	# distinct pass would let a 4-card deck offer 5, including more copies of a card
	# than the examiner ever owned. Partitioning into distinct-first plus the leftover
	# duplicates keeps `ordered` the same size as `examiner_deck`, so clamping the
	# take to min(allowance, ordered.size()) can never over-offer.
	var seen := {}
	var ordered: Array[CardData] = []
	var duplicates: Array[CardData] = []
	for card in examiner_deck:
		if seen.has(card):
			duplicates.append(card)
		else:
			seen[card] = true
			ordered.append(card)
	ordered.append_array(duplicates)

	# -1 is the "whole deck" sentinel (Grading.draft_allowance for grade S); every
	# other grade clamps to its fixed allowance or the deck's own size, whichever is
	# smaller.
	var limit := ordered.size() if allowance < 0 else mini(allowance, ordered.size())
	for i in limit:
		offered.append(CardInstance.new(ordered[i]))


## Returns the new run deck, or an empty array if the selection is not exactly `cap`
## cards drawn from own + offered with no card repeated. A wrong-size or illegal
## selection is refused rather than silently truncated or padded — corrupting the
## run deck is worse than making the player choose again.
func keep(selection: Array) -> Array:
	if selection.size() != cap:
		return []

	var legal := {}
	for card in own:
		legal[card] = true
	for card in offered:
		legal[card] = true

	var chosen := {}
	for card in selection:
		if not legal.has(card) or chosen.has(card):
			return []
		chosen[card] = true

	return selection.duplicate()
