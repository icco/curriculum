class_name Main
extends Node

## Composition root. Owns the Run and swaps screens; no screen knows about another.
##
## The loop: menu -> catalog -> battle -> report card -> registration (draft) -> back
## to the catalog. Expulsion (two F grades) or passing the final ends the run at a
## game-over screen instead. A failed battle skips registration -- there is nothing
## to draft from a loss -- and goes straight back to the catalog after the report
## card. Autosaves on every return to the catalog; deletes the save on expulsion.

## Backed by GameManager rather than stored here. The two used to be separate fields
## assigned side by side (`run = ...` then `GameManager.run = run`, in two places),
## which is two references to one object with nothing keeping them in step — a
## reassignment that missed one line would have left the autoload pointing at a stale
## run and nothing would have failed loudly. The autoload is the single storage
## location; this is a view onto it, so `main.run` still reads naturally here and in
## the suites.
##
## The three autoloads are NOT removable, whatever their thinness suggests: the brief
## (assets/prompts/init.md, section A) names GameManager, DeckManager and GradeManager
## as required singletons, and spec 10.3 records the compromise they implement.
var run: Run:
	get:
		return GameManager.run
	set(value):
		GameManager.run = value

var battle: Battle = null

var library: ContentLibrary = null
var catalog: Catalog = null

var _screen: Control = null
var _screen_name := ""
## Every screen is mounted inside this, so the edge gutter is defined in exactly one
## place instead of seven. A screen therefore never sees the full viewport width: its
## own `size.x` is already the padded content width, which is what any screen doing
## its own layout maths (CourseCatalog's tier columns, HandFan's spread) should be
## measuring against anyway.
var _frame: MarginContainer = null
var _course = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	boot_headless()
	_handle_cmdline()


## Separated from _ready so tests can drive the root without a live scene tree.
func boot_headless() -> void:
	library = load("res://resources/content_library.tres")
	catalog = library.catalog()
	_rng.randomize()
	_show_menu()


func current_screen_name() -> String:
	return _screen_name


func _swap(screen: Control, name: String) -> void:
	if _frame == null:
		_frame = UIKit.screen_margin()
		add_child(_frame)
	# Compared against _frame, not self: screens are mounted one level down now, so a
	# `get_parent() == self` check would never match and every screen would be left
	# stacked on top of the last.
	if _screen != null and _screen.get_parent() == _frame:
		_frame.remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	_screen_name = name
	# No anchor preset: _frame is a Container, and a Container sets its children's rects
	# itself. The screen fills the gutter because Control's default size flags are FILL.
	_frame.add_child(screen)


func _show_menu() -> void:
	var menu := MainMenu.new()
	menu.build(SaveGame.has_save())
	menu.new_run_requested.connect(start_new_run)
	menu.continue_requested.connect(_continue_run)
	menu.bestiary_requested.connect(_show_bestiary)
	_swap(menu, "menu")


func start_new_run() -> void:
	# The library, not just its starting deck. Passing only the deck was a real defect
	# rather than a tidiness one: this run's examiners are GENERATED from the library, so
	# a fresh run built without it rolled an empty faculty and faced the authored schools,
	# while a continued run (which did pass the roster) faced rolled ones. Per-run content
	# was live in tools/simulate.gd and dead in the actual game.
	run = Run.new(library.new_starting_deck(), library)
	SaveGame.save(run)
	_show_catalog()


func _continue_run() -> void:
	run = SaveGame.load_run(library)
	if run == null:
		start_new_run()
		return
	_show_catalog()


func _show_catalog() -> void:
	var map := CourseCatalog.new()
	map.course_chosen.connect(enter_course)
	_swap(map, "catalog")
	map.show_catalog(catalog, run.grades)


func _show_bestiary() -> void:
	var screen := BestiaryScreen.new()
	screen.closed.connect(_show_menu if run == null else _show_catalog)
	_swap(screen, "bestiary")
	# This run's examiners, not the roster's: the screen reads weak_school straight off
	# what it is handed, so passing library.enemies would print the authored schools
	# and flatly contradict what the player discovered in a fight.
	screen.show_bestiary(
		run.bestiary if run != null else Bestiary.new(),
		run.faculty.all() if run != null and not run.faculty.is_empty() else library.enemies
	)


func enter_course(course: CourseData) -> void:
	_course = course
	battle = Battle.new(run.deck, run.examiner_for(course.examiner), run.bestiary, _rng, run.hp)
	DeckManager.deck = battle.player_deck
	var screen := BattleScreen.new()
	screen.battle_finished.connect(func(_b): _on_battle_finished())
	_swap(screen, "battle")
	screen.begin(battle)


func _on_battle_finished() -> void:
	# The battle's piles are gone the moment it is graded; leaving them on the
	# autoload means it spends the rest of the session pointing at a finished fight.
	DeckManager.end_battle()
	finish_battle_headless(battle.player_won)


## Grades the finished battle, records it, and moves on. Exposed for tests so a
## battle's outcome can be driven without playing it out through the screen.
func finish_battle_headless(_won: bool) -> void:
	var scored: Dictionary = GradeManager.score(
		{
			"won": battle.player_won,
			"turns_taken": battle.turns,
			"par_turns": _course.par_turns,
			"hp_end": battle.player.hp,
			# What the player walked in on, not their maximum: hit points carry
			# between battles, so grading against max_hp would let damage taken
			# three courses ago permanently cap every later Survival score.
			"hp_start": battle.player_starting_hp,
			"xp_banked": battle.xp_banked,
			"xp_par": _course.xp_par,
			"weakness_known": run.bestiary.knows_weakness(_course.examiner.enemy_name),
			"distinct_schools": battle.schools_played(),
		}
	)
	var result := run.record_result(_course, scored["grade"], battle.player.hp)

	if run.is_over():
		SaveGame.delete()
		var over := GameOver.new()
		over.restarted.connect(start_new_run)
		_swap(over, "gameover")
		over.show_outcome(run)
		return

	var report := ReportCard.new()
	report.continued.connect(func(): _show_registration(scored))
	_swap(report, "report")
	report.show_result(scored, result, _course)


func _show_registration(scored: Dictionary) -> void:
	# A loss has nothing to draft from -- straight back to the catalog.
	if not battle.player_won:
		SaveGame.save(run)
		_show_catalog()
		return
	# The examiner the player actually fought, not the roster entry. Drafting off
	# _course.examiner.deck would offer cards from a deck this run's examiner never
	# played once decks become generative too.
	var draft := Draft.new(
		run.deck,
		run.examiner_for(_course.examiner).deck,
		_course.guaranteed_card_drop,
		scored["grade"]
	)
	draft.cap = run.deck_cap()
	var screen := RegistrationScreen.new()
	screen.registration_complete.connect(
		func(kept):
			run.deck = kept
			SaveGame.save(run)
			_show_catalog()
	)
	_swap(screen, "registration")
	screen.begin(draft)


## tools/shot.sh passes --shot/--seed/--screen after a bare --.
func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var wanted := ""
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			out = args[i + 1]
		elif args[i] == "--seed" and i + 1 < args.size():
			_rng.seed = args[i + 1].to_int()
		elif args[i] == "--screen" and i + 1 < args.size():
			wanted = args[i + 1]
	if out == "":
		return

	match wanted:
		"catalog":
			start_new_run()
		"battle":
			start_new_run()
			enter_course(library.course_named("Basic Arcana 101"))
		"bestiary":
			_show_bestiary()
		_:
			pass
	_screenshot(out)


func _screenshot(path: String) -> void:
	# --headless does not render, so this only works from a windowed run, and the
	# frame must be drawn before the viewport texture holds anything.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("wrote %s" % path)
	get_tree().quit()  # or the process hangs forever
