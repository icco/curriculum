extends Node

## Holds the current Run and forwards to it. No rules live here: keeping state out of the
## singletons is what lets every suite construct a Run directly instead of resetting
## globals between tests.

var run: Run = null


## The whole library reaches the Run, not just its starting deck: examiners are
## generated from it per run, so dropping it here left the faculty empty and every
## examiner on its authored schools. Same defect as the one Main.start_new_run carried.
func start_new_run(library: ContentLibrary) -> Run:
	run = Run.new(library.new_starting_deck(), library)
	return run


func load_existing(library: ContentLibrary = null) -> Run:
	run = SaveGame.load_run(library)
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
