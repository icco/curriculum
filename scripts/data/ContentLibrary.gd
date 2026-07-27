class_name ContentLibrary
extends Resource

## Single index of every content resource. Loading one resource beats scanning
## directories, which is unreliable in exported builds.

@export var spells: Array[SpellData] = []
@export var enemies: Array[EnemyData] = []
@export var loot: Array[LootItemData] = []
@export var skills: Array[SkillNodeData] = []
