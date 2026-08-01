extends SceneTree

## Runs the same headless runs as simulate.gd under several deliberately different
## play policies, and reports the grade each earns. Where simulate.gd answers "how
## hard is the game?", this answers "does playing well matter?" — if a policy that
## throws away a real resource scores the same as the greedy one, that resource is
## not a decision. Balance work only; the gate is check.sh.
##   godot --headless --path . --script tools/policy_probe.gd -- 30

var _policy := "greedy"

## The hp at or below which the throwlow policy stops fighting and takes the F.
## Must sit ABOVE the hp the player typically enters a course with, or the policy
## simply never engages and measures greedy under another name. The per-course
## "hp in" column from tools/simulate.gd is the number to check it against.
const _THROW_BELOW := 40

## How many battles throwlow actually diverged on. Without this the policy can report
## a near-greedy score simply by never having fired, which reads as "the exploit does
## not pay" when nothing was tested at all.
var _thrown := 0


## Any card that spends itself on staying alive: Block, healing, or retain. Not a
## school test -- see the nodefence policy.
func _is_defensive(data: CardData) -> bool:
	if data.retain:
		return true
	for effect in data.effects:
		if effect.get("kind", "") in [CardData.BLOCK, CardData.HEAL, CardData.BONUS_IF_WARD_PLAYED]:
			return true
	return false


## Returns true if it played something.
func _take_actions(battle: Battle) -> bool:
	var played := false
	match _policy:
		"greedy":
			for card in battle.player_deck.hand.duplicate():
				if battle.can_play(card):
					battle.play_card(card)
					played = true
					if battle.finished:
						break
		"onecard":
			# Deliberately bad: play exactly one affordable card per turn, wasting
			# the rest of the mana.
			for card in battle.player_deck.hand.duplicate():
				if battle.can_play(card):
					battle.play_card(card)
					played = true
					break
		"nodefence":
			# Deliberately bad: all-in on offence, never spending a card on staying
			# alive. Filtered on what the card DOES, not on its school: Block is not
			# exclusive to Ward (the Numb the Hall line is Frost and grants 6-10
			# Block), so filtering on Schools.School.WARD would measure "never plays a
			# Ward card" while quietly leaving the policy still defending.
			for card in battle.player_deck.hand.duplicate():
				if _is_defensive(card.data):
					continue
				if battle.can_play(card):
					battle.play_card(card)
					played = true
					if battle.finished:
						break
		"throwlow":
			# Is deliberately failing an exam a free full heal? A pass restores a
			# fraction of max scaled by grade, but an F restores ALL of it (spec 6.1)
			# and the first of two strikes is survivable -- so at low hp, throwing a
			# fight may beat winning it. If this policy outscores greedy, that
			# exploit is real rather than theoretical.
			if battle.player_starting_hp > _THROW_BELOW:
				for card in battle.player_deck.hand.duplicate():
					if battle.can_play(card):
						battle.play_card(card)
						played = true
						if battle.finished:
							break
		"onlydefence":
			# Deliberately bad: turtle forever.
			for card in battle.player_deck.hand.duplicate():
				if not _is_defensive(card.data):
					continue
				if battle.can_play(card):
					battle.play_card(card)
					played = true
	return played


func run_policy(count: int) -> Dictionary:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var wins := 0
	var grade_counts := {}
	var total_courses := 0
	var total_score := 0.0
	var scored_battles := 0
	var terms := {"efficiency": 0.0, "survival": 0.0, "learning": 0.0, "discovery": 0.0}
	var eff_clamped := 0
	var learn_clamped := 0

	for i in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var game := Run.new(library.new_starting_deck(), library, 500 + i)
		var catalog := library.catalog()
		var guard := 0
		while not game.is_over() and guard < 30:
			guard += 1
			var open := catalog.available(game.grades)
			if open.is_empty():
				break
			var course = open[0]
			var battle := Battle.new(
				game.deck, game.examiner_for(course.examiner), game.bestiary, rng, game.hp
			)
			battle.start()
			var turn_guard := 0
			while not battle.finished and turn_guard < 200:
				turn_guard += 1
				# One full turn per iteration: the policy takes every action it
				# wants, then the turn always ends. (An earlier version ended the
				# turn only when the policy played nothing, which let the
				# "one card per turn" policy loop and play its whole hand anyway.)
				_take_actions(battle)
				if battle.finished:
					break
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
			if _policy == "throwlow" and battle.player_starting_hp <= _THROW_BELOW:
				_thrown += 1
			total_score += float(scored["total"])
			scored_battles += 1
			for t in terms:
				terms[t] = float(terms[t]) + float(scored[t])
			if float(scored["efficiency"]) >= Grading.TERM_MAX:
				eff_clamped += 1
			if float(scored["learning"]) >= Grading.TERM_MAX:
				learn_clamped += 1
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
		if game.won:
			wins += 1
		total_courses += game.courses_passed

	return {
		"wins": wins,
		"courses": float(total_courses) / float(count),
		"grades": grade_counts,
		"mean_score": total_score / maxf(1.0, float(scored_battles)),
		"terms": terms,
		"battles": scored_battles,
		"eff_clamped": eff_clamped,
		"learn_clamped": learn_clamped,
	}


func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var count := 30
	if args.size() > 0 and args[0].is_valid_int():
		count = args[0].to_int()

	for policy in ["greedy", "onecard", "nodefence", "onlydefence", "throwlow"]:
		_policy = policy
		_thrown = 0
		var r := run_policy(count)
		print(
			"%-9s wins %2d/%d  courses/run %5.1f  mean score %5.1f  grades %s"
			% [policy, r["wins"], count, r["courses"], r["mean_score"], r["grades"]]
		)
		if policy == "throwlow":
			print(
				"          diverged from greedy on %d of %d battles (threshold %d hp)"
				% [_thrown, int(r["battles"]), _THROW_BELOW]
			)
		var n := maxf(1.0, float(r["battles"]))
		var t: Dictionary = r["terms"]
		print(
			"          terms/battle: eff %4.1f (maxed %d%%)  surv %4.1f  learn %4.1f (maxed %d%%)  disc %4.1f"
			% [
				float(t["efficiency"]) / n,
				int(round(100.0 * float(r["eff_clamped"]) / n)),
				float(t["survival"]) / n,
				float(t["learning"]) / n,
				int(round(100.0 * float(r["learn_clamped"]) / n)),
				float(t["discovery"]) / n,
			]
		)
	quit(0)
	return true
