class_name SkillNodeData
extends Resource

## One node of the between-loops skill tree.

enum EffectType {
	BONUS_HP, BONUS_AC, BONUS_SPEED,
	BONUS_SLOTS_1, BONUS_SLOTS_2, BONUS_SLOTS_3,
	ABILITY_SCORE, UNLOCK_SPELL,
}

@export var id: StringName = &""
@export var display_name: String = "Node"
@export_range(0, 30) var cost: int = 1
@export_multiline var description: String = ""
## Ids of nodes that must be bought first.
@export var requires: Array[StringName] = []

@export_group("Effect")
@export var effect_type: EffectType = EffectType.BONUS_HP
@export_range(0, 20) var value: int = 1
## Only for ABILITY_SCORE.
@export var ability: Entity.Ability = Entity.Ability.INT
## Only for UNLOCK_SPELL.
@export var spell_id: StringName = &""

## GlobalState key this node increments, or "" for the special cases.
func global_key() -> String:
	match effect_type:
		EffectType.BONUS_HP: return "bonus_hp"
		EffectType.BONUS_AC: return "bonus_ac"
		EffectType.BONUS_SPEED: return "bonus_speed"
		EffectType.BONUS_SLOTS_1: return "bonus_slots_1"
		EffectType.BONUS_SLOTS_2: return "bonus_slots_2"
		EffectType.BONUS_SLOTS_3: return "bonus_slots_3"
		_: return ""
