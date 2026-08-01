extends SceneTree

## Prints one generated world: every examiner's rolled schools and deck, next to the
## authored ones it replaced. Balance work only; the gate is check.sh.
##   godot --headless --path . --script tools/inspect_world.gd -- 504
##
## This exists because tools/simulate.gd can tell you a world measured badly but not why.
## A world at a 0% graduation rate is the one measurement worth chasing, and chasing it
## means reading the content the seed produced rather than inferring it from a loss table.


func _describe(card: CardData) -> String:
	var bits: Array = []
	for effect in card.effects:
		var kind: String = effect.get("kind", "")
		if kind == CardData.STATUS:
			var names := ["burn", "chill", "blot", "decay"]
			var status := int(effect.get("status", -1))
			var label: String = names[status] if status >= 0 and status < names.size() else "?"
			bits.append("%s %d" % [label, int(effect.get("amount", 0))])
		elif effect.has("amount"):
			bits.append("%s %d" % [kind, int(effect.get("amount", 0))])
		else:
			bits.append(kind)
	return "%s [%s] %d/%s" % [card.card_name, Schools.display_name(card.school), card.cost, ", ".join(bits)]


func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var content_seed := 504
	if args.size() > 0 and args[0].is_valid_int():
		content_seed = args[0].to_int()

	var library: ContentLibrary = load("res://resources/content_library.tres")
	var faculty := Faculty.new(library, content_seed)
	print("world seed %d — %d of %d deck slots substituted" % [
		content_seed, faculty.slots_substituted, faculty.slots_filled
	])
	print("opening schools: %s" % [library.opening_schools().map(Schools.display_name)])

	for base in library.enemies:
		var rolled: EnemyData = faculty.examiner(base)
		var courses: Array = []
		for course in library.courses:
			if course.examiner != null and course.examiner.enemy_name == base.enemy_name:
				courses.append("%s (t%d)" % [course.course_name, course.tier])
		print("")
		print("%s — %d hp, %d mana — %s" % [rolled.enemy_name, rolled.max_hp, rolled.mana_per_turn, ", ".join(courses)])
		print(
			"  weak %-6s (was %-6s)   warded %-6s (was %s)"
			% [
				Schools.display_name(rolled.weak_school),
				Schools.display_name(base.weak_school),
				Schools.display_name(rolled.warded_school),
				Schools.display_name(base.warded_school),
			]
		)
		for i in rolled.deck.size():
			var mark := "  " if rolled.deck[i] == base.deck[i] else "->"
			print("   %s %-52s (was %s)" % [mark, _describe(rolled.deck[i]), base.deck[i].card_name])
	quit(0)
	return true
