class_name LootItemData
extends Resource

## A piece of gear or a consumable. Runs store the id and re-resolve through
## Roster, so saves stay small and content stays editable.

enum Slot { WEAPON, ARMOUR, TRINKET, CONSUMABLE }
enum Effect { NONE, HEAL, DASH, CLEANSE }

@export var id: StringName = &""
@export var display_name: String = "Oddment"
@export var slot: Slot = Slot.TRINKET

@export_group("Gear")
@export var damage_dice: String = ""
@export_range(0, 12) var attack_bonus: int = 0
@export_range(0, 12) var damage_bonus: int = 0
@export_range(0, 12) var ac_bonus: int = 0
@export_range(1, 12) var range_tiles: int = 1

@export_group("Consumable")
@export var effect: Effect = Effect.NONE
@export var power: String = ""

@export_group("Drop table")
@export_range(0.0, 10.0, 0.5) var weight: float = 1.0
@export_range(1, 12) var min_depth: int = 1

func slot_key() -> String:
	match slot:
		Slot.WEAPON: return "weapon"
		Slot.ARMOUR: return "armour"
		Slot.CONSUMABLE: return "consumable"
		_: return "trinket"

func is_consumable() -> bool:
	return slot == Slot.CONSUMABLE

## Rough desirability, used to decide whether a find is an upgrade.
func score() -> float:
	return Dice.average(damage_dice) + attack_bonus * 2.0 + damage_bonus * 1.5 + ac_bonus * 3.0
