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


func progress() -> String:
	if not can_evolve():
		return "mastered"
	return "%d/%d" % [xp, data.xp_to_evolve]
