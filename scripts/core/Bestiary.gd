class_name Bestiary
extends RefCounted

## What the student has learned about examiners this run. Keyed by examiner name, so
## a weakness learned in Cantrips 101 still pays in Marginalia 201.

const WEAK_MULTIPLIER := 1.5
const WARD_MULTIPLIER := 0.5

var _weaknesses_known := {}
var _wards_known := {}


## Scales every number on a card of this school. Applies whether or not the player
## has discovered the weakness: the reveal is information, not the reward.
func multiplier(enemy: EnemyData, school) -> float:
	if enemy == null:
		return 1.0
	if school == enemy.weak_school:
		return WEAK_MULTIPLIER
	if school == enemy.warded_school:
		return WARD_MULTIPLIER
	return 1.0


## Records what a hit taught. Returns "weakness", "ward", or "" for nothing new.
func record_hit(enemy: EnemyData, school) -> String:
	if enemy == null:
		return ""
	if school == enemy.weak_school and not _weaknesses_known.has(enemy.enemy_name):
		_weaknesses_known[enemy.enemy_name] = school
		return "weakness"
	if school == enemy.warded_school and not _wards_known.has(enemy.enemy_name):
		_wards_known[enemy.enemy_name] = school
		return "ward"
	return ""


func knows_weakness(enemy_name: String) -> bool:
	return _weaknesses_known.has(enemy_name)


func knows_ward(enemy_name: String) -> bool:
	return _wards_known.has(enemy_name)


func weakness_of(enemy_name: String):
	return _weaknesses_known.get(enemy_name, null)


func to_dict() -> Dictionary:
	return {"weaknesses": _weaknesses_known.duplicate(), "wards": _wards_known.duplicate()}


static func from_dict(d: Dictionary) -> Bestiary:
	var b := Bestiary.new()
	for enemy_name in d.get("weaknesses", {}):
		b._weaknesses_known[enemy_name] = d["weaknesses"][enemy_name]
	for enemy_name in d.get("wards", {}):
		b._wards_known[enemy_name] = d["wards"][enemy_name]
	return b
