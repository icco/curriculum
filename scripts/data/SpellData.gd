class_name SpellData
extends Resource

## One spell. Fixed-value fields are enums so callers get exhaustive `match`
## instead of string comparisons.

enum Action { ACTION, BONUS, REACTION }
enum Kind { ATTACK, AUTO, SAVE, HEAL, BUFF, TELEPORT }
enum Target { ENEMY, ALLY, SELF, TILE }
enum SaveEffect { NONE, HALF }

@export var id: StringName = &""
@export var display_name: String = "Spell"
## 0 is a cantrip: always available, and its dice scale with level.
@export_range(0, 9) var level: int = 0
@export var action: Action = Action.ACTION
@export var kind: Kind = Kind.ATTACK
@export var target: Target = Target.ENEMY
@export_range(0, 30) var range_tiles: int = 0
## Radius in tiles; 0 is a single target.
@export_range(0, 6) var aoe: int = 0

@export_group("Damage")
@export var damage: String = ""
@export var damage_type: String = "force"
## Auto-hit spells fire this many independent packets.
@export_range(1, 12) var darts: int = 1
@export var save_ability: Entity.Ability = Entity.Ability.DEX
@export var save_effect: SaveEffect = SaveEffect.HALF

@export_group("Effect")
@export var condition: StringName = &""
@export_range(0, 10) var condition_rounds: int = 0

@export_group("Presentation")
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var icon_name: StringName = &""

@export_group("Progression")
@export_range(0, 20) var unlock_cost: int = 0
## Known from the very first loop, without a skill node.
@export var starting: bool = false

func is_cantrip() -> bool:
	return level == 0

func uses_bonus_action() -> bool:
	return action == Action.BONUS

func has_condition() -> bool:
	return condition != &"" and condition_rounds > 0

func save_ability_key() -> String:
	return Entity.ability_key(save_ability)
