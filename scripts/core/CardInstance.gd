class_name CardInstance
extends RefCounted

## One copy of a card inside one run. Holds its own XP and a pointer to the shared
## CardData. Evolution swaps the pointer; the CardData is never written to.

var data: CardData
var xp: int = 0


func _init(card_data: CardData, starting_xp: int = 0) -> void:
	data = card_data
	xp = starting_xp


func can_evolve() -> bool:
	return data != null and not data.is_fully_evolved()


## Returns true when this call evolved the card.
func gain_xp(amount: int = 1) -> bool:
	if not can_evolve():
		return false
	xp += amount
	if xp < data.xp_to_evolve:
		return false
	data = data.evolved_card
	xp = 0
	return true


## 1-5. Every line is exactly five CardData deep (spec section 11), so counting the
## hops from here to the terminal card via evolved_card and subtracting from 5 gives
## the current level without CardData needing to export its own level number.
func level() -> int:
	if data == null:
		return 0
	var hops := 0
	var node := data
	while node.evolved_card != null:
		hops += 1
		node = node.evolved_card
	return 5 - hops


## "L2 3/9" mid-line, "L5 mastered" at the terminal card. The level prefix is new:
## with five tiers instead of two, a bare "3/9" no longer says which tier's XP bar
## it is.
func progress() -> String:
	if not can_evolve():
		return "L%d mastered" % level()
	return "L%d %d/%d" % [level(), xp, data.xp_to_evolve]
