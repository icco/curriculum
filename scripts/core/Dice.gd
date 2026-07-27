class_name Dice
extends RefCounted

## Central dice + randomness helper. Everything random in the game funnels
## through here so a run can be reproduced from a single seed.

static var rng := RandomNumberGenerator.new()

static func seed_with(s: int) -> void:
	rng.seed = s

static func randomize_seed() -> int:
	rng.randomize()
	return rng.seed

static func d(sides: int) -> int:
	return rng.randi_range(1, sides)

static func d20() -> int:
	return rng.randi_range(1, 20)

static func roll(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += rng.randi_range(1, sides)
	return total

## Parses and rolls an expression like "2d6+3", "1d10", "d4-1" or a flat "5".
static func roll_expr(expr: String) -> int:
	var parsed := parse_expr(expr)
	return roll(parsed.count, parsed.sides) + parsed.flat if parsed.sides > 0 else parsed.flat

## Returns {count, sides, flat}. Flat-only expressions come back with sides == 0.
static func parse_expr(expr: String) -> Dictionary:
	var clean := expr.strip_edges().to_lower().replace(" ", "")
	if clean == "":
		return {"count": 0, "sides": 0, "flat": 0}
	var flat := 0
	var dice_part := clean
	var sign_idx := maxi(clean.rfind("+"), clean.rfind("-"))
	if sign_idx > 0:
		flat = int(clean.substr(sign_idx))
		dice_part = clean.substr(0, sign_idx)
	if not dice_part.contains("d"):
		return {"count": 0, "sides": 0, "flat": int(dice_part) + flat}
	var halves := dice_part.split("d")
	var count := 1 if halves[0] == "" else int(halves[0])
	var sides := int(halves[1])
	return {"count": count, "sides": sides, "flat": flat}

## Average result of an expression, used by the AI to compare options.
static func average(expr: String) -> float:
	var p := parse_expr(expr)
	return p.count * (p.sides + 1) / 2.0 + p.flat

static func chance(probability: float) -> bool:
	return rng.randf() < probability

static func range_i(low: int, high: int) -> int:
	return rng.randi_range(low, high)

static func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]

static func shuffled(arr: Array) -> Array:
	var copy := arr.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy

## Weighted pick. `weights` maps key -> relative weight.
static func weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for k: Variant in weights:
		total += float(weights[k])
	if total <= 0.0:
		return null
	var pin := rng.randf() * total
	for k: Variant in weights:
		pin -= float(weights[k])
		if pin <= 0.0:
			return k
	return weights.keys().back()
