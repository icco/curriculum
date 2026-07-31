class_name Statuses
extends RefCounted

## The four stacking statuses. Block is deliberately absent: it belongs to
## Combatant, because it modifies incoming damage rather than ticking.

enum Kind { BURN, CHILL, BLOT, DECAY }

## How much Decay grows each time it ticks. Growing rather than decaying is what
## makes Rot lose short fights and win long ones.
const DECAY_GROWTH := 2

var _stacks := {
	Kind.BURN: 0,
	Kind.CHILL: 0,
	Kind.BLOT: 0,
	Kind.DECAY: 0,
}


func amount(kind: Kind) -> int:
	return _stacks.get(kind, 0)


func add(kind: Kind, n: int) -> void:
	_stacks[kind] = maxi(0, amount(kind) + n)


## Returns the stack and zeroes it. Chill and Blot are spent whole by one card.
func consume(kind: Kind) -> int:
	var value := amount(kind)
	_stacks[kind] = 0
	return value


func clear_all() -> void:
	for kind in _stacks:
		_stacks[kind] = 0


## Burn damage, then Burn decrements. Returns the damage dealt.
func tick_start_of_turn() -> int:
	var burn := amount(Kind.BURN)
	if burn > 0:
		_stacks[Kind.BURN] = burn - 1
	return burn


## Decay damage, then Decay grows. Returns the damage dealt.
func tick_end_of_turn() -> int:
	var decay := amount(Kind.DECAY)
	if decay > 0:
		_stacks[Kind.DECAY] = decay + DECAY_GROWTH
	return decay


func double_decay() -> void:
	_stacks[Kind.DECAY] = amount(Kind.DECAY) * 2


func to_dict() -> Dictionary:
	return {
		"burn": amount(Kind.BURN),
		"chill": amount(Kind.CHILL),
		"blot": amount(Kind.BLOT),
		"decay": amount(Kind.DECAY),
	}


static func from_dict(d: Dictionary) -> Statuses:
	var s := Statuses.new()
	s.add(Kind.BURN, int(d.get("burn", 0)))
	s.add(Kind.CHILL, int(d.get("chill", 0)))
	s.add(Kind.BLOT, int(d.get("blot", 0)))
	s.add(Kind.DECAY, int(d.get("decay", 0)))
	return s
