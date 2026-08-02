class_name SaveGame
extends RefCounted

## Single-slot autosave. A CardInstance serialises as its CardData's resource path
## plus its own integer XP, so an already-evolved card serialises as the *evolved*
## resource's path and reloads still evolved rather than reverting to its base form.
## The rest of the payload is plain data pulled straight off Run/Bestiary.
##
## All methods are static; this class holds no state of its own.

const PATH := "user://run.json"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if not has_save():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# globalize_path does not resolve user:// consistently on every platform, so
	# confirm removal actually happened rather than assuming it did; fall back to a
	# relative remove through the user:// directory if the file is still there.
	if FileAccess.file_exists(PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("run.json")


static func save(run: Run) -> bool:
	var cards: Array = []
	for card in run.deck:
		cards.append({"path": card.data.resource_path, "xp": card.xp})

	var grades := {}
	for course_name in run.grades:
		grades[course_name] = int(run.grades[course_name])

	var payload := {
		"hp": run.hp,
		"max_hp": run.max_hp,
		"strikes": run.strikes,
		"courses_passed": run.courses_passed,
		"expelled": run.expelled,
		"won": run.won,
		"grades": grades,
		"deck": cards,
		"bestiary": run.bestiary.to_dict(),
		# One integer instead of nine serialised examiners: the faculty is a pure
		# function of (roster, seed), so replaying the seed rebuilds it exactly.
		"content_seed": run.content_seed,
	}

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


## `content` is the content library, needed to rebuild this run's examiners from the
## saved seed. Defaulted so suites can round-trip a Run without one; the examiners then
## fall back to their authored schools.
static func load_run(content: ContentLibrary = null) -> Run:
	if not has_save():
		return null
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null

	var cards: Array = []
	for entry in parsed.get("deck", []):
		var path: String = str(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var data: CardData = load(path)
		if data == null:
			continue
		cards.append(CardInstance.new(data, int(entry.get("xp", 0))))

	# A save written before per-run faculties has no seed. Passing 0 rolls a fresh one
	# rather than failing the load; that run simply gets a new set of weaknesses, which
	# is the least-bad outcome for a save that never had them recorded.
	var run := Run.new(cards, content, int(parsed.get("content_seed", 0)))
	run.hp = int(parsed.get("hp", Run.STARTING_HP))
	run.max_hp = int(parsed.get("max_hp", Run.STARTING_HP))
	run.strikes = int(parsed.get("strikes", 0))
	run.courses_passed = int(parsed.get("courses_passed", 0))
	run.expelled = bool(parsed.get("expelled", false))
	run.won = bool(parsed.get("won", false))

	var grades: Dictionary = parsed.get("grades", {})
	for course_name in grades:
		run.grades[course_name] = int(grades[course_name])

	run.bestiary = Bestiary.from_dict(parsed.get("bestiary", {}))
	return run
