extends SceneTree

## Headless suite runner. Discovers every tests/test_*.gd automatically — there is no
## list to keep in step, so a new suite cannot be silently left unregistered, and
## parallel branches adding suites never collide on a shared constant.
##
## A SceneTree script's _init() has no tree — Engine.get_main_loop() is null and the
## root window is not live — so everything runs from _process(), which quits by
## returning true.

const TESTS_DIR := "res://tests"


func _discover() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		printerr("FAIL  cannot open %s" % TESTS_DIR)
		return found
	for file in dir.get_files():
		# .gd in a source checkout, .gdc once exported.
		var name := file.trim_suffix(".remap").trim_suffix("c")
		if name.begins_with("test_") and name.ends_with(".gd"):
			found.append("%s/%s" % [TESTS_DIR, name])
	found.sort()
	return found


func _process(_delta: float) -> bool:
	var suites := _discover()
	if suites.is_empty():
		printerr("FAIL  no test suites found in %s" % TESTS_DIR)
		quit(1)
		return true

	var total_checks := 0
	var total_failures := 0

	for path in suites:
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL  could not load suite %s" % path)
			total_failures += 1
			continue
		# A suite that fails to compile loads as a GDScript that cannot be
		# instantiated; calling new() on it returns null and every later call on the
		# result errors once per frame without ever reaching quit().
		if not script.can_instantiate():
			printerr("FAIL  suite %s did not compile" % path)
			total_failures += 1
			continue
		var suite: TestCase = script.new()
		if suite == null:
			printerr("FAIL  could not instantiate suite %s" % path)
			total_failures += 1
			continue
		suite.run()
		total_checks += suite.checks
		for failure in suite.failures:
			printerr("FAIL  %s: %s" % [suite.suite_name(), failure])
			total_failures += 1
		print(
			"  %-16s %d checks, %d failures"
			% [suite.suite_name(), suite.checks, suite.failures.size()]
		)

	print("%d suites, %d checks, %d failures" % [suites.size(), total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)
	return true
