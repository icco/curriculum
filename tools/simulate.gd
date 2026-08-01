extends SceneTree

## Plays N headless runs with the greedy policy and reports how far they got. Balance
## work only; the gate is check.sh.
##   godot --headless --path . --script tools/simulate.gd -- 20


func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var count := 10
	if args.size() > 0 and args[0].is_valid_int():
		count = args[0].to_int()
	# How many distinct GENERATED WORLDS the runs are spread over. Examiner weaknesses
	# are rolled per run now, so an aggregate across N runs is an average over N
	# different games — and a generator producing half-trivial and half-impossible
	# worlds averages to a perfectly respectable number while being useless. Runs are
	# grouped onto a few worlds so the spread BETWEEN them is visible.
	var worlds := 10
	if args.size() > 1 and args[1].is_valid_int():
		worlds = maxi(1, args[1].to_int())

	var library: ContentLibrary = load("res://resources/content_library.tres")
	var wins := 0
	var total_courses := 0
	var grade_counts := {}
	var courses_passed_counts := {}  ## int -> run count, for the distribution
	var ended_expelled := 0
	var ended_final_loss := 0  ## reached the final course and lost it
	var ended_stuck := 0  ## is_over() never became true (ran out of open courses)
	var course_loss_counts := {}  ## course_name -> number of runs that lost there
	## course_name -> {attempts, hp_in, hp_out, turns}. Hit points carry between
	## courses now, so WHERE a run dies is much less informative than what it walked
	## in with: a course with a 60% loss rate that is only ever entered at 20 hp is
	## a symptom of the two courses before it, not a mis-tuned examiner.
	var course_stats := {}
	var course_order: Array = []
	var world_runs := {}  ## world index -> runs played
	var world_wins := {}  ## world index -> runs graduated

	for i in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		# Content seed and shuffle seed vary independently: several runs share a world
		# and differ only in their draws.
		var world := i % worlds
		rng.seed = 1000 + i
		var game := Run.new(library.new_starting_deck(), library.enemies, 500 + world)
		var catalog := library.catalog()
		var guard := 0
		var last_course_lost: String = ""
		while not game.is_over() and guard < 30:
			guard += 1
			var open := catalog.available(game.grades)
			if open.is_empty():
				break
			var course = open[0]
			if not course_stats.has(course.course_name):
				course_stats[course.course_name] = {"a": 0, "hp_in": 0, "hp_out": 0, "turns": 0}
				course_order.append(course.course_name)
			var hp_in: int = game.hp
			var battle := Battle.new(
				game.deck, game.examiner_for(course.examiner), game.bestiary, rng, game.hp
			)
			battle.start()
			var turn_guard := 0
			while not battle.finished and turn_guard < 200:
				turn_guard += 1
				var played := false
				for card in battle.player_deck.hand.duplicate():
					if battle.can_play(card):
						battle.play_card(card)
						played = true
						if battle.finished:
							break
				if battle.finished:
					break
				if not played or battle.player.mana <= 0:
					battle.end_turn()
			var scored: Dictionary = Grading.score(
				{
					"won": battle.player_won,
					"turns_taken": battle.turns,
					"par_turns": course.par_turns,
					"hp_end": battle.player.hp,
					"hp_start": battle.player_starting_hp,
					"xp_banked": battle.xp_banked,
					"xp_par": course.xp_par,
					"weakness_known": game.bestiary.knows_weakness(course.examiner.enemy_name),
					"distinct_schools": battle.schools_played(),
				}
			)
			var letter := Grading.letter(scored["grade"])
			grade_counts[letter] = int(grade_counts.get(letter, 0)) + 1
			var cs: Dictionary = course_stats[course.course_name]
			cs["a"] = int(cs["a"]) + 1
			cs["hp_in"] = int(cs["hp_in"]) + hp_in
			cs["hp_out"] = int(cs["hp_out"]) + maxi(0, battle.player.hp)
			cs["turns"] = int(cs["turns"]) + battle.turns
			if not battle.player_won:
				last_course_lost = course.course_name
				course_loss_counts[course.course_name] = int(course_loss_counts.get(course.course_name, 0)) + 1
			game.record_result(course, scored["grade"], battle.player.hp)
			if battle.player_won and not game.is_over():
				var draft := Draft.new(
					game.deck,
					game.examiner_for(course.examiner).deck,
					course.guaranteed_card_drop,
					scored["grade"]
				)
				draft.cap = game.deck_cap()
				var selection: Array = []
				for card in draft.offered:
					if selection.size() < draft.cap:
						selection.append(card)
				for card in draft.own:
					if selection.size() < draft.cap:
						selection.append(card)
				var kept := draft.keep(selection)
				if kept.size() == draft.cap:
					game.deck = kept
		world_runs[world] = int(world_runs.get(world, 0)) + 1
		if game.won:
			wins += 1
			world_wins[world] = int(world_wins.get(world, 0)) + 1
		elif game.expelled:
			ended_expelled += 1
			if last_course_lost != "":
				pass  # already tallied above
		elif not last_course_lost.is_empty() and catalog.available(game.grades).is_empty():
			# Not expelled (fewer than 2 strikes), but ran out of open courses —
			# most often because the run lost the final course itself.
			ended_final_loss += 1
		else:
			ended_stuck += 1
		total_courses += game.courses_passed
		courses_passed_counts[game.courses_passed] = int(courses_passed_counts.get(game.courses_passed, 0)) + 1

	print("%d runs: %d wins, %.1f courses passed on average" % [count, wins, float(total_courses) / float(count)])
	print("grades: %s" % grade_counts)
	print(
		"endings: %d graduated, %d expelled (2 strikes), %d lost the final/ran dry, %d other"
		% [wins, ended_expelled, ended_final_loss, ended_stuck]
	)
	print("courses passed distribution: %s" % courses_passed_counts)
	print("losses by course: %s" % course_loss_counts)

	# Per-world graduation, so a generator that makes some worlds unplayable cannot
	# hide behind a healthy average.
	var rates: Array[float] = []
	for world in world_runs:
		rates.append(100.0 * float(world_wins.get(world, 0)) / float(world_runs[world]))
	rates.sort()
	if rates.size() > 1:
		var spread := ""
		for r in rates:
			spread += "%.0f%% " % r
		print(
			"graduation by world (%d worlds, %d runs each): %s-- lowest %.0f%%, highest %.0f%%"
			% [
				rates.size(),
				int(world_runs[world_runs.keys()[0]]),
				spread,
				rates[0],
				rates[rates.size() - 1],
			]
		)
	print("")
	print("%-24s %5s %6s %7s %7s %6s" % ["course", "att", "loss%", "hp in", "hp out", "turns"])
	for name in course_order:
		var cs: Dictionary = course_stats[name]
		var attempts := maxf(1.0, float(cs["a"]))
		print(
			"%-24s %5d %5.0f%% %7.1f %7.1f %6.1f"
			% [
				name,
				int(cs["a"]),
				100.0 * float(course_loss_counts.get(name, 0)) / attempts,
				float(cs["hp_in"]) / attempts,
				float(cs["hp_out"]) / attempts,
				float(cs["turns"]) / attempts,
			]
		)
	quit(0)
	return true
