class_name Combatant
extends RefCounted

## The shared shape of the player and an examiner: hit points, block, mana and
## statuses. Knows nothing about cards or turns.

var display_name := ""
var hp := 0
var max_hp := 0
var block := 0
var mana := 0
var mana_per_turn := 0
var statuses: Statuses = Statuses.new()


func _init(name_in: String, max_hp_in: int, mana_per_turn_in: int) -> void:
	display_name = name_in
	max_hp = max_hp_in
	hp = max_hp_in
	mana_per_turn = mana_per_turn_in


## Block absorbs first. Returns the hit points actually lost.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var absorbed := mini(block, amount)
	block -= absorbed
	var lost := mini(amount - absorbed, hp)
	hp -= lost
	return lost


func gain_block(n: int) -> void:
	block = maxi(0, block + n)


func heal(n: int) -> void:
	hp = clampi(hp + n, 0, max_hp)


## Self-damage from Rot cards bypasses block — you are paying, not being hit.
func pay_hp(n: int) -> void:
	hp = maxi(0, hp - n)


func spend_mana(n: int) -> bool:
	if n > mana:
		return false
	mana -= n
	return true


func refill_mana(bonus: int = 0) -> void:
	mana = mana_per_turn + bonus


## Block expires at the start of its owner's turn.
func expire_block() -> void:
	block = 0


func is_down() -> bool:
	return hp <= 0


func hp_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
