class_name EnemyData
extends Resource

## An enemy archetype. Hit points are rolled per spawn from `hit_dice`.

enum Role { GRUNT, ELITE, BOSS }

@export var id: StringName = &""
@export var display_name: String = "Student"
@export var role: Role = Role.GRUNT
## Depth band this archetype appears in.
@export_range(1, 12) var min_depth: int = 1
@export_range(1, 12) var max_depth: int = 12

@export_group("Ability scores")
@export_range(1, 30) var score_str: int = 10
@export_range(1, 30) var score_dex: int = 10
@export_range(1, 30) var score_con: int = 10
@export_range(1, 30) var score_int: int = 10
@export_range(1, 30) var score_wis: int = 10
@export_range(1, 30) var score_cha: int = 10

@export_group("Defence")
## Printed AC, including its dexterity contribution.
@export_range(1, 30) var armour_class: int = 11
@export var hit_dice: String = "2d8"
@export_range(1, 12) var speed_tiles: int = 6
@export_range(1, 6) var proficiency: int = 2

@export_group("Offence")
@export var attack_ability: Entity.Ability = Entity.Ability.STR
@export var casting_ability: Entity.Ability = Entity.Ability.INT
@export var weapon_name: String = "Fists"
@export var damage_dice: String = "1d4"
@export_range(1, 12) var attack_range: int = 1

@export_group("Rewards")
@export_range(0, 1000) var xp_value: int = 5
@export var tint: Color = Color("ef5350")

func stats() -> Dictionary:
	return {
		"str": score_str, "dex": score_dex, "con": score_con,
		"int": score_int, "wis": score_wis, "cha": score_cha,
	}

func rank() -> Entity.Rank:
	match role:
		Role.ELITE: return Entity.Rank.ELITE
		Role.BOSS: return Entity.Rank.BOSS
		_: return Entity.Rank.GRUNT

func appears_at(depth: int) -> bool:
	return depth >= min_depth and depth <= max_depth
