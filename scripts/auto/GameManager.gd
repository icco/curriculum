extends Node

## Holds the current Run and forwards to it. No rules live here: keeping state out of
## the singletons is what lets every suite construct a Run directly.
##
## Run, ContentLibrary and SaveGame are referenced here through `load()` rather than
## as bare class_name identifiers, and none of this file's declarations are typed
## `Run` / `ContentLibrary`. Godot 4.7.1 resolves a bare reference to any of those
## three (directly, or transitively through Run -> CourseData via record_result, or
## ContentLibrary -> CourseData via courses) eagerly while building autoload
## singletons during `--import`, and CourseData's self-referential
## `Array[CourseData]` export leaks a GDScript resource when that happens — which
## `tools/check.sh` treats as a hard failure since it greps the import output for
## "ERROR". `load()` sidesteps the eager class-name resolution; the runtime object
## it produces is identical either way.

const _RUN_SCRIPT := "res://scripts/core/Run.gd"
const _SAVE_SCRIPT := "res://scripts/core/SaveGame.gd"

var run = null  ## Run


func start_new_run(library):
	run = load(_RUN_SCRIPT).new(library.new_starting_deck())
	return run


func load_existing():
	run = load(_SAVE_SCRIPT).load_run()
	return run


func save() -> bool:
	if run == null:
		return false
	return load(_SAVE_SCRIPT).save(run)


func abandon() -> void:
	run = null
	load(_SAVE_SCRIPT).delete()


func strikes() -> int:
	return 0 if run == null else run.strikes


func deck_cap() -> int:
	return Draft.BASE_CAP if run == null else run.deck_cap()
