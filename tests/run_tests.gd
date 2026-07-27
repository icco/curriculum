extends SceneTree

## Headless test runner:  godot --headless --path . --script tests/run_tests.gd
## Exits non-zero when anything fails so CI/agent loops can trust the code.

const TEST_DIR := "res://tests"

var _ran: bool = false

## Runs on the first frame, not in _init: there the main loop is unregistered
## and the root window is not live, so tree-dependent tests silently no-op.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	return true

func _run_all() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)

	var files := _test_files()
	var total_checks := 0
	var all_failures: Array = []
	var suites := 0

	for path: String in files:
		if only != "" and not path.contains(only):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			all_failures.append("%s: failed to parse (see SCRIPT ERROR above)" % path)
			print("  [FAIL] %-28s parse error" % path.get_file())
			continue
		suites += 1
		var instance: Object = script.new()
		var names: Array = []
		for m: Dictionary in instance.get_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		names.sort()
		for n: String in names:
			instance.set_current("%s::%s" % [path.get_file(), n])
			if instance.has_method("before_each"):
				instance.call("before_each")
			instance.call(n)
			if instance.has_method("after_each"):
				instance.call("after_each")
		total_checks += int(instance.get("checks"))
		var fails: Array = instance.get("failures")
		all_failures.append_array(fails)
		var mark := "ok  " if fails.is_empty() else "FAIL"
		print("  [%s] %-28s %d tests" % [mark, path.get_file(), names.size()])

	print("")
	print("%d suites, %d assertions, %d failures" % [suites, total_checks, all_failures.size()])
	if not all_failures.is_empty():
		print("")
		for f: String in all_failures:
			print("  x ", f)
		quit(1)
		return
	print("ALL TESTS PASSED")
	quit(0)

func _test_files() -> Array:
	var out: Array = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("test_") and name.ends_with(".gd"):
			out.append(TEST_DIR + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
