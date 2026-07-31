class_name CardData
extends Resource

## A card's static definition. Shared by every copy of the card in every run, so it
## is immutable at play time: per-copy XP lives on CardInstance, never here.

# Effect kinds. An effect is a Dictionary: {"kind": ..., "amount": int, ...}.
const DAMAGE := "damage"
const BLOCK := "block"
const HEAL := "heal"
const STATUS := "status"  # also carries "status": Statuses.Kind
const DRAW := "draw"
const MANA_NEXT := "mana_next"
const SELF_DAMAGE := "self_damage"
const DOUBLE_DECAY := "double_decay"
const BONUS_IF_CHILLED := "bonus_if_chilled"
const BONUS_IF_WARD_PLAYED := "bonus_if_ward_played"

@export var card_name: String = ""
@export var school: Schools.School = Schools.School.CINDER
@export var cost: int = 1
@export var effects: Array[Dictionary] = []
@export var xp_to_evolve: int = 5
## The next tier, or null when this card is already the evolved form. Self-reference
## on a Resource is legal; a mutual typed reference between two core classes is not.
@export var evolved_card: CardData
@export var art_id: String = ""
## Battle-scoped: an exhausted card leaves play until the battle ends.
@export var exhaust: bool = false
## Retained cards survive the end-of-turn discard.
@export var retain: bool = false


func is_fully_evolved() -> bool:
	return evolved_card == null
