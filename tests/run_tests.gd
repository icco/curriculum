extends SceneTree

## Headless suite runner. Add every new suite to SUITES.
##
## A SceneTree script's _init() has no tree — Engine.get_main_loop() is null and the
## root window is not live — so everything runs from _process(), which quits by
## returning true.

const SUITES := [
	"res://tests/test_schools.gd",
	"res://tests/test_tooling.gd",
]


func _process(_delta: float) -> bool:
	var total_checks := 0
	var total_failures := 0

	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL  could not load suite %s" % path)
			total_failures += 1
			continue
		var suite: TestCase = script.new()
		suite.run()
		total_checks += suite.checks
		for failure in suite.failures:
			printerr("FAIL  %s: %s" % [suite.suite_name(), failure])
			total_failures += 1
		print(
			"  %-16s %d checks, %d failures"
			% [suite.suite_name(), suite.checks, suite.failures.size()]
		)

	print("%d checks, %d failures" % [total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)
	return true
