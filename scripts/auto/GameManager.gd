extends Node

## Holds the current Run and forwards to it. No rules live here: keeping state out of the
## singletons is what lets every suite construct a Run directly instead of resetting
## globals between tests.

var run: Run = null


func start_new_run(library: ContentLibrary) -> Run:
	run = Run.new(library.new_starting_deck())
	return run


func load_existing() -> Run:
	run = SaveGame.load_run()
	return run


func save() -> bool:
	if run == null:
		return false
	return SaveGame.save(run)


func abandon() -> void:
	run = null
	SaveGame.delete()


func strikes() -> int:
	return 0 if run == null else run.strikes


func deck_cap() -> int:
	return Draft.BASE_CAP if run == null else run.deck_cap()
