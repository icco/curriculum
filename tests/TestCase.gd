extends RefCounted

## Minimal xUnit-ish base. Subclasses define `test_*` methods; the runner
## instantiates them, calls each test, and reports collected failures.

var failures: Array = []
var checks: int = 0
var _current: String = ""

func set_current(name: String) -> void:
	_current = name

func fail(msg: String) -> void:
	failures.append("%s: %s" % [_current, msg])

func check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		fail(msg)
	return cond

func eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	checks += 1
	if actual != expected:
		fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])
		return false
	return true

func ne(actual: Variant, unexpected: Variant, msg: String = "") -> bool:
	checks += 1
	if actual == unexpected:
		fail("%s expected value other than %s" % [msg, str(unexpected)])
		return false
	return true

func between(actual: float, low: float, high: float, msg: String = "") -> bool:
	checks += 1
	if actual < low or actual > high:
		fail("%s expected %s..%s, got %s" % [msg, str(low), str(high), str(actual)])
		return false
	return true

func truthy(value: Variant, msg: String = "") -> bool:
	return check(bool(value), msg + " (expected truthy, got %s)" % str(value))

func falsy(value: Variant, msg: String = "") -> bool:
	return check(not bool(value), msg + " (expected falsy, got %s)" % str(value))
