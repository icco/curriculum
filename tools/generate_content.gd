extends SceneTree

## Writes resources/cards/*.tres from the table below, which is spec section 11.
## Re-runnable: it overwrites. Run with
##   godot --headless --path . --script tools/generate_content.gd

const OUT_DIR := "res://resources/cards"

# These read Schools.School and Statuses.Kind directly rather than mirroring
# them as hardcoded ints (the previous CINDER := 0 ... WARD := 4, BURN := 0
# ... DECAY := 3). A hardcoded mirror is exactly how a reordered enum could
# silently reassign every card's school or status without anything noticing —
# a bare int keeps matching whatever the enum reorders to. Aliasing the real
# enum members keeps the table short while making a reorder correct by
# construction instead of relying on a test to catch it after the fact.
const CINDER := Schools.School.CINDER
const FROST := Schools.School.FROST
const INK := Schools.School.INK
const ROT := Schools.School.ROT
const WARD := Schools.School.WARD

const BURN := Statuses.Kind.BURN
const CHILL := Statuses.Kind.CHILL
const BLOT := Statuses.Kind.BLOT
const DECAY := Statuses.Kind.DECAY


static func dmg(n: int) -> Dictionary:
	return {"kind": "damage", "amount": n}


static func blk(n: int) -> Dictionary:
	return {"kind": "block", "amount": n}


static func heal(n: int) -> Dictionary:
	return {"kind": "heal", "amount": n}


static func status(kind: int, n: int) -> Dictionary:
	return {"kind": "status", "status": kind, "amount": n}


static func draw(n: int) -> Dictionary:
	return {"kind": "draw", "amount": n}


static func mana(n: int) -> Dictionary:
	return {"kind": "mana_next", "amount": n}


static func pay(n: int) -> Dictionary:
	return {"kind": "self_damage", "amount": n}


static func chilled(n: int) -> Dictionary:
	return {"kind": "bonus_if_chilled", "amount": n}


static func warded(n: int) -> Dictionary:
	return {"kind": "bonus_if_ward_played", "amount": n}


static func doubling() -> Dictionary:
	return {"kind": "double_decay"}


## [base_name, evolved_name, school, art, base_cost, base_effects, evo_cost,
##  evo_effects, exhaust, retain]
func table() -> Array:
	return [
		# Cinder
		["Spark", "Ember Lance", CINDER, "spark", 1, [dmg(6)], 1, [dmg(10)], false, false],
		["Kindle", "Conflagration", CINDER, "kindle", 1, [status(BURN, 3)], 1, [status(BURN, 6)], false, false],
		["Scorch Notes", "Immolate Notes", CINDER, "scorch_notes", 2, [dmg(11)], 2, [dmg(17)], false, false],
		["Cinder Burst", "Pyre Burst", CINDER, "cinder_burst", 2, [dmg(5), status(BURN, 3)], 2, [dmg(8), status(BURN, 5)], false, false],
		["Final Recitation", "Valedictory Blaze", CINDER, "final_recitation", 3, [dmg(20)], 3, [dmg(30)], true, false],
		# Frost
		["Frost Lance", "Rime Lance", FROST, "frost_lance", 1, [dmg(5), status(CHILL, 1)], 1, [dmg(8), status(CHILL, 1)], false, false],
		["Hoarfrost", "Deep Hoarfrost", FROST, "hoarfrost", 1, [status(CHILL, 2)], 1, [status(CHILL, 3), dmg(3)], false, false],
		["Glass Shard", "Mirror Shard", FROST, "glass_shard", 2, [dmg(9), chilled(4)], 2, [dmg(13), chilled(6)], false, false],
		["Numb the Hall", "Still the Hall", FROST, "numb_the_hall", 2, [status(CHILL, 2), blk(6)], 2, [status(CHILL, 3), blk(10)], false, false],
		["Winter Term", "Long Winter", FROST, "winter_term", 3, [dmg(12), status(CHILL, 4)], 3, [dmg(18), status(CHILL, 5)], false, false],
		# Ink
		["Ink Blot", "Spilled Ledger", INK, "ink_blot", 1, [status(BLOT, 1)], 1, [status(BLOT, 2)], false, false],
		["Marginalia", "Copious Marginalia", INK, "marginalia", 1, [draw(2)], 0, [draw(2)], false, false],
		["Cite Source", "Cite Chapter & Verse", INK, "cite_source", 1, [dmg(4), draw(1)], 1, [dmg(6), draw(2)], false, false],
		["Cram", "All-Nighter", INK, "cram", 2, [mana(2)], 1, [mana(2)], false, false],
		["Thesis Statement", "Defended Thesis", INK, "thesis_statement", 3, [dmg(8), draw(3)], 2, [dmg(12), draw(3)], false, false],
		# Rot
		["Rot Seed", "Blightseed", ROT, "rot_seed", 1, [status(DECAY, 4)], 1, [status(DECAY, 6)], false, false],
		["Bitter Recall", "Bitter Mastery", ROT, "bitter_recall", 1, [pay(3), dmg(12)], 1, [pay(2), dmg(18)], false, false],
		["Necrology Note", "Necrology Thesis", ROT, "necrology_note", 2, [dmg(5), status(DECAY, 5)], 2, [dmg(8), status(DECAY, 8)], false, false],
		["Feed the Curriculum", "Feed the Faculty", ROT, "feed_the_curriculum", 2, [pay(5), doubling()], 2, [pay(3), doubling(), draw(1)], false, false],
		# Ward
		["Guard", "Bulwark", WARD, "guard", 1, [blk(6)], 1, [blk(10)], false, false],
		["Rimeward", "Aegis Ward", WARD, "rimeward", 1, [blk(5)], 1, [blk(8)], false, true],
		["Study Break", "Restorative Study", WARD, "study_break", 2, [heal(8)], 2, [heal(14)], false, false],
		["Warded Bracers", "Sigil Bracers", WARD, "warded_bracers", 2, [blk(10), warded(4)], 2, [blk(14), warded(6)], false, false],
		["Honours Sigil", "Valedictory Sigil", WARD, "honours_sigil", 3, [blk(18), heal(6)], 3, [blk(24), heal(10)], false, false],
	]


static func slug(name: String) -> String:
	var out := name.to_lower()
	out = out.replace("&", "and")
	out = out.replace("-", "_")
	var cleaned := ""
	for i in out.length():
		var c := out[i]
		if c.is_valid_identifier() or c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			cleaned += c
		elif c == " ":
			cleaned += "_"
	while cleaned.contains("__"):
		cleaned = cleaned.replace("__", "_")
	return cleaned


func make_card(name: String, school: int, cost: int, effects: Array, art: String, exhaust: bool, retain: bool) -> CardData:
	var card := CardData.new()
	card.card_name = name
	card.school = school
	card.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	card.effects = typed
	card.art_id = "cards/%s" % art
	card.exhaust = exhaust
	card.retain = retain
	card.xp_to_evolve = 5
	return card


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var written := 0
	for row in table():
		var base_name: String = row[0]
		var evo_name: String = row[1]
		var school: int = row[2]
		var art: String = row[3]

		# The evolved form is written first, so the base card can reference it.
		var evolved := make_card(evo_name, school, row[6], row[7], art, row[8], row[9])
		var evo_path := "%s/%s.tres" % [OUT_DIR, slug(evo_name)]
		var evo_err := ResourceSaver.save(evolved, evo_path)
		if evo_err != OK:
			printerr("failed to write %s: %d" % [evo_path, evo_err])
			quit(1)
			return true
		written += 1

		var base := make_card(base_name, school, row[4], row[5], art, row[8], row[9])
		base.evolved_card = load(evo_path)
		var base_path := "%s/%s.tres" % [OUT_DIR, slug(base_name)]
		var base_err := ResourceSaver.save(base, base_path)
		if base_err != OK:
			printerr("failed to write %s: %d" % [base_path, base_err])
			quit(1)
			return true
		written += 1

	print("wrote %d card resources to %s" % [written, OUT_DIR])

	# Index everything just written, plus the starting deck the spec names.
	var library := ContentLibrary.new()
	var all: Array[CardData] = []
	for row in table():
		all.append(load("%s/%s.tres" % [OUT_DIR, slug(row[0])]))
		all.append(load("%s/%s.tres" % [OUT_DIR, slug(row[1])]))
	library.cards = all
	var start: Array[CardData] = []
	for i in 4:
		start.append(load("%s/spark.tres" % OUT_DIR))
	for i in 4:
		start.append(load("%s/guard.tres" % OUT_DIR))
	for i in 2:
		start.append(load("%s/ink_blot.tres" % OUT_DIR))
	library.starting_deck = start
	# Enemies and courses are filled in by Tasks 17 and 18; preserve them if present.
	var existing = load("res://resources/content_library.tres")
	if existing != null:
		library.enemies = existing.enemies
		library.courses = existing.courses
	ResourceSaver.save(library, "res://resources/content_library.tres")
	print("indexed %d cards, %d starting" % [library.cards.size(), library.starting_deck.size()])

	quit(0)
	return true
