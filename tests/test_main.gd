extends TestCase

## Main is the composition root: it wires every screen together without any screen
## knowing about another. boot_headless() lets this suite drive it without a live
## scene tree, exactly as the brief calls out.


func suite_name() -> String:
	return "main"


func run() -> void:
	# Leave no save behind from an earlier suite's run, or "boots to the menu" could
	# secretly boot to a leftover Continue button instead.
	SaveGame.delete()

	var main := Main.new()
	main.boot_headless()
	eq(main.current_screen_name(), "menu", "boots to the menu")

	main.start_new_run()
	eq(main.current_screen_name(), "catalog", "a new run opens the catalog")
	check(main.run != null, "root owns the run")
	eq(main.run.deck.size(), 10, "dealt the starting deck")
	check(SaveGame.has_save(), "starting a run autosaves")

	# Choosing a course opens a battle.
	var lib2: ContentLibrary = load("res://resources/content_library.tres")
	var course: CourseData = lib2.course_named("Basic Arcana 101")
	main.enter_course(course)
	eq(main.current_screen_name(), "battle", "entering a course opens the battle")
	check(main.battle != null, "root owns the battle")

	# Expulsion ends the run and clears the save.
	main.run.strikes = Run.MAX_STRIKES
	main.run.expelled = true
	main.finish_battle_headless(false)
	eq(main.current_screen_name(), "gameover", "expulsion ends the run")
	eq(SaveGame.has_save(), false, "expulsion cleared the save")
	main.free()

	# A loss skips registration entirely -- there is nothing to draft from a defeat --
	# and lands straight back on the catalog once the report card is dismissed.
	var lossy := Main.new()
	lossy.boot_headless()
	lossy.start_new_run()
	lossy.enter_course(course)
	lossy.battle.player_won = false
	lossy._show_registration({})
	eq(lossy.current_screen_name(), "catalog", "a loss skips the draft and returns to the catalog")
	check(SaveGame.has_save(), "returning to the catalog autosaves")
	lossy.free()

	# A win opens the registration screen instead, built from the run's own deck and
	# the course's examiner -- proof the draft is actually wired to the run, not just
	# that the screen swap happens.
	var winner := Main.new()
	winner.boot_headless()
	winner.start_new_run()
	winner.enter_course(course)
	winner.battle.player_won = true
	winner._show_registration({"grade": Grading.Grade.C})
	eq(winner.current_screen_name(), "registration", "a win opens the registration screen")
	var registration: RegistrationScreen = winner._screen
	check(registration.draft != null, "the registration screen received a draft")
	eq(registration.draft.own, winner.run.deck, "the draft pools the run's own deck")
	eq(registration.draft.cap, winner.run.deck_cap(), "the draft cap matches the run's deck cap")

	# Confirming registration hands the kept deck back to the run and returns to the
	# catalog, autosaving along the way.
	var kept: Array = registration.draft.own.slice(0, registration.draft.cap)
	registration.registration_complete.emit(kept)
	eq(winner.current_screen_name(), "catalog", "confirming registration returns to the catalog")
	eq(winner.run.deck, kept, "the kept selection became the run's deck")
	check(SaveGame.has_save(), "confirming registration autosaves")
	winner.free()

	DeckManager.end_battle()
	SaveGame.delete()
