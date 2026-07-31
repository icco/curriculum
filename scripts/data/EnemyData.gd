class_name EnemyData
extends Resource

## An examiner. Its deck is drawn from the same CardData pool the player uses, which
## is what makes copying its cards after a win cost no extra content.

@export var enemy_name: String = ""
@export var max_hp: int = 30
@export var mana_per_turn: int = 2
@export var deck: Array[CardData] = []
@export var weak_school: Schools.School = Schools.School.CINDER
@export var warded_school: Schools.School = Schools.School.FROST
@export var art_id: String = ""
## Gates and the final are exempt from the "appears in >= 2 courses" rule.
@export var is_gate: bool = false


func to_combatant() -> Combatant:
	return Combatant.new(enemy_name, max_hp, mana_per_turn)
