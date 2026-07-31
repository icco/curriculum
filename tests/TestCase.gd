class_name TestCase
extends RefCounted

## Base for every suite. A suite overrides suite_name() and run(), and records outcomes
## through check()/eq() rather than asserting, so one failure does not hide the rest of
## the suite.

var failures: Array[String] = []
var checks := 0


func suite_name() -> String:
	return "unnamed"


func run() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func eq(actual, expected, message := "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func neq(actual, unexpected, message := "") -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s: expected anything but %s" % [message, unexpected])


## Float comparison within 0.001.
##
## NaN is rejected explicitly. Every comparison against NaN is false, so the tolerance
## check alone would treat NaN as a pass — meaning a division-by-zero regression would
## slip through every float assertion in the suite silently. An unguarded division is
## exactly the bug this helper is most often asked to catch.
func almost(actual: float, expected: float, message := "") -> void:
	checks += 1
	if is_nan(actual):
		failures.append("%s: expected %f, got NaN" % [message, expected])
		return
	if is_inf(actual):
		failures.append("%s: expected %f, got infinity" % [message, expected])
		return
	if absf(actual - expected) > 0.001:
		failures.append("%s: expected %f, got %f" % [message, expected, actual])
