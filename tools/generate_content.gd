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

## The XP each level demands before it evolves. Index 0 is level 1's threshold, etc.
## Level 5 is terminal and never consults its own entry.
const XP_THRESHOLDS := [5, 9, 15, 24, 5]

## Levels 3-5 don't get hand-authored stat lines. Each is the previous level's
## amount plus a shrinking share (80%, 60%, 40%) of the raw level1->level2 delta,
## cumulative — repeating that delta outright would let a card that merely
## doubled once double three further times by level 5. See scale_line_effects().
const GROWTH_MULT := [0.8, 0.6, 0.4]

## A maxed deck's whole turn (3 mana) should land in the neighbourhood of
## 45-50 direct damage, or a properly-statted boss dies in one turn instead of
## surviving a fight. This is the per-CARD half of that budget: nothing may
## deal more than this from repeated copies of itself alone in one turn. See
## turn_ceiling() and enforce_turn_cap().
const TURN_DAMAGE_CAP := 50


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


## [name1, name2, name3, name4, name5, school, cost1, effects1, cost2,
##  effects2, exhaust, retain]
##
## Only the five names and the level1/level2 stat lines are hand-authored.
## Levels 3-5's costs and effect amounts are derived by scale_line_effects()
## and the flat-cost rule in _process(), below. There is no shared "art"
## column: every level gets its own art_id, derived from its own name by
## slug() in _process() — see the note there.
func table() -> Array:
	return [
		# Cinder
		["Spark", "Ember Lance", "Blaze Lance", "Wildfire Lance", "Supernova Lance",
			CINDER, 1, [dmg(6)], 1, [dmg(10)], false, false],
		["Kindle", "Conflagration", "Wildfire", "Firestorm", "Cataclysm",
			CINDER, 1, [status(BURN, 3)], 1, [status(BURN, 6)], false, false],
		["Scorch Notes", "Immolate Notes", "Cremate Notes", "Incinerate Notes", "Annihilate Notes",
			CINDER, 2, [dmg(11)], 2, [dmg(17)], false, false],
		["Cinder Burst", "Pyre Burst", "Bonfire Burst", "Wildblaze Burst", "Starfire Burst",
			CINDER, 2, [dmg(5), status(BURN, 3)], 2, [dmg(8), status(BURN, 5)], false, false],
		["Final Recitation", "Valedictory Blaze", "Commencement Pyre", "Convocation Inferno", "Doctoral Immolation",
			CINDER, 3, [dmg(20)], 3, [dmg(30)], true, false],
		# Frost
		["Frost Lance", "Rime Lance", "Glacier Lance", "Permafrost Lance", "Absolute Zero Lance",
			FROST, 1, [dmg(5), status(CHILL, 1)], 1, [dmg(8), status(CHILL, 1)], false, false],
		["Hoarfrost", "Deep Hoarfrost", "Killing Frost", "Black Ice", "Eternal Winter",
			FROST, 1, [status(CHILL, 2)], 1, [status(CHILL, 3), dmg(3)], false, false],
		["Glass Shard", "Mirror Shard", "Prism Shard", "Crystal Shard", "Diamond Shard",
			FROST, 2, [dmg(9), chilled(4)], 2, [dmg(13), chilled(6)], false, false],
		["Numb the Hall", "Still the Hall", "Freeze the Hall", "Silence the Hall", "Entomb the Hall",
			FROST, 2, [status(CHILL, 2), blk(6)], 2, [status(CHILL, 3), blk(10)], false, false],
		["Winter Term", "Long Winter", "Endless Winter", "Nuclear Winter", "Ice Age",
			FROST, 3, [dmg(12), status(CHILL, 4)], 3, [dmg(18), status(CHILL, 5)], false, false],
		# Ink
		["Ink Blot", "Spilled Ledger", "Smeared Archive", "Redacted Record", "Purged Transcript",
			INK, 1, [status(BLOT, 1)], 1, [status(BLOT, 2)], false, false],
		["Marginalia", "Copious Marginalia", "Exhaustive Marginalia", "Annotated Codex", "Complete Concordance",
			INK, 1, [draw(2)], 0, [draw(2)], false, false],
		["Cite Source", "Cite Chapter & Verse", "Cross Reference", "Annotated Bibliography", "Complete Works",
			INK, 1, [dmg(4), draw(1)], 1, [dmg(6), draw(2)], false, false],
		["Cram", "All-Nighter", "Caffeine Binge", "Sleepless Marathon", "Perfect Recall",
			INK, 2, [mana(2)], 1, [mana(2)], false, false],
		["Thesis Statement", "Defended Thesis", "Published Thesis", "Peer Reviewed Thesis", "Landmark Thesis",
			INK, 3, [dmg(8), draw(3)], 2, [dmg(12), draw(3)], false, false],
		# Rot
		["Rot Seed", "Blightseed", "Blightroot", "Blightvine", "Blightbloom",
			ROT, 1, [status(DECAY, 4)], 1, [status(DECAY, 6)], false, false],
		["Bitter Recall", "Bitter Mastery", "Bitter Reckoning", "Bitter Judgment", "Bitter Finality",
			ROT, 1, [pay(3), dmg(12)], 1, [pay(2), dmg(18)], false, false],
		["Necrology Note", "Necrology Thesis", "Necrology Monograph", "Necrology Codex", "Necrology Canon",
			ROT, 2, [dmg(5), status(DECAY, 5)], 2, [dmg(8), status(DECAY, 8)], false, false],
		["Feed the Curriculum", "Feed the Faculty", "Feed the Department", "Feed the Institution", "Feed the Endowment",
			ROT, 2, [pay(5), doubling()], 2, [pay(3), doubling(), draw(1)], false, false],
		# Ward
		["Guard", "Bulwark", "Rampart", "Bastion", "Citadel",
			WARD, 1, [blk(6)], 1, [blk(10)], false, false],
		["Rimeward", "Aegis Ward", "Sanctum Ward", "Bastion Ward", "Absolute Ward",
			WARD, 1, [blk(5)], 1, [blk(8)], false, true],
		["Study Break", "Restorative Study", "Restful Recess", "Sabbatical", "Full Recovery",
			WARD, 2, [heal(8)], 2, [heal(14)], false, false],
		["Warded Bracers", "Sigil Bracers", "Rune Bracers", "Glyph Bracers", "Ward Gauntlets",
			WARD, 2, [blk(10), warded(4)], 2, [blk(14), warded(6)], false, false],
		["Honours Sigil", "Valedictory Sigil", "Magisterial Sigil", "Doctoral Sigil", "Grand Chancellor Sigil",
			WARD, 3, [blk(18), heal(6)], 3, [blk(24), heal(10)], false, false],
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


## Identifies one effect slot so level1 and level2 amounts can be matched up even
## when the arrays aren't in the same order or the same length (Hoarfrost's damage
## effect, for instance, only exists from level2 onward). A plain "kind" is not
## enough for status effects, since two different Statuses.Kind values both report
## kind "status" — the status enum member is folded into the key so Burn and Chill
## are never confused for each other.
static func effect_key(effect: Dictionary) -> String:
	var kind: String = effect.get("kind", "")
	if kind == CardData.STATUS:
		return "%s:%d" % [kind, int(effect.get("status", -1))]
	return kind


static func effect_amount(effect: Dictionary) -> int:
	return int(effect.get("amount", 0))


static func lookup_amount(effects: Array, key: String) -> int:
	for e in effects:
		if effect_key(e) == key:
			return effect_amount(e)
	return 0


## Derives levels 3, 4 and 5's effects from levels 1 and 2. Templates on level2's
## effect list (order and set of kinds), looking up each one's level1 counterpart
## (treated as 0 if the effect doesn't exist yet at level1). Returns
## [level3_effects, level4_effects, level5_effects].
static func scale_line_effects(level1: Array, level2: Array) -> Array:
	var order: Array[String] = []
	var kind_of := {}
	var status_of := {}
	var has_amount := {}
	var cur := {}
	var delta := {}

	for effect in level2:
		var key: String = effect_key(effect)
		order.append(key)
		kind_of[key] = effect.get("kind", "")
		if effect.has("status"):
			status_of[key] = effect["status"]
		if effect.has("amount"):
			has_amount[key] = true
			var level2_amount := effect_amount(effect)
			var level1_amount := lookup_amount(level1, key)
			cur[key] = level2_amount
			var d: int = level2_amount - level1_amount
			# Self-damage is the drawback, not the payoff, so a shrinking delta
			# (Bitter Recall's pay 3 -> 2) is backwards: it would keep shrinking
			# right as the payoff peaks, making the card strictly better in every
			# dimension by level 5. Flip the sign so the risk grows alongside the
			# reward instead; a delta that's already growing (or flat) is left as-is.
			if kind_of[key] == CardData.SELF_DAMAGE and d < 0:
				d = -d
			delta[key] = d
		else:
			has_amount[key] = false

	var levels := []
	for mult in GROWTH_MULT:
		var effects: Array = []
		for key in order:
			if not has_amount[key]:
				effects.append({"kind": kind_of[key]})
				continue
			var d: int = delta[key]
			if d != 0:
				var inc := int(round(d * mult))
				if d >= 1:
					inc = maxi(inc, 1)
				elif d <= -1:
					inc = mini(inc, -1)
				cur[key] = int(cur[key]) + inc
			# Draw is card advantage, not a stat line — uncapped, Cite Source's
			# draw would reach 5 by level 5 on a one-cost damage card. Hold it to
			# one better than its level2 self.
			if kind_of[key] == CardData.DRAW:
				var cap: int = lookup_amount(level2, key) + 1
				cur[key] = mini(int(cur[key]), cap)
			var built := {"kind": kind_of[key], "amount": cur[key]}
			if status_of.has(key):
				built["status"] = status_of[key]
			effects.append(built)
		levels.append(effects)
	return levels


## How many times one copy of a card can be cast in a single 3-mana turn.
static func casts_per_turn(cost: int, exhaust: bool) -> int:
	if exhaust or cost <= 0:
		return 1
	return maxi(1, int(floor(3.0 / cost)))


## Direct, same-turn damage only (DAMAGE, and BONUS_IF_CHILLED since it lands
## in the same hit). Burn and Decay are excluded: they pay out over several
## turns, which is a different balance question from a single turn's burst.
static func direct_damage_total(effects: Array) -> int:
	var total := 0
	for e in effects:
		var kind: String = e.get("kind", "")
		if kind == CardData.DAMAGE or kind == CardData.BONUS_IF_CHILLED:
			total += int(e.get("amount", 0))
	return total


static func turn_ceiling(effects: Array, cost: int, exhaust: bool) -> int:
	return direct_damage_total(effects) * casts_per_turn(cost, exhaust)


## Blunt safety net for every level of every line: trims the single largest
## direct-damage effect until turn_ceiling() fits TURN_DAMAGE_CAP. Not a
## substitute for picking the right cost/exhaust on a line that's breaching by
## a lot (see the Bitter Recall override in _process()) — this only catches
## the case where an otherwise-fine line's growth overshoots by a little.
static func enforce_turn_cap(effects: Array, cost: int, exhaust: bool) -> Array:
	var casts := casts_per_turn(cost, exhaust)
	var ceiling := turn_ceiling(effects, cost, exhaust)
	if ceiling <= TURN_DAMAGE_CAP:
		return effects
	var best_idx := -1
	var best_amt := -1
	for i in effects.size():
		var e = effects[i]
		var kind: String = e.get("kind", "")
		if kind == CardData.DAMAGE or kind == CardData.BONUS_IF_CHILLED:
			var amt := int(e.get("amount", 0))
			if amt > best_amt:
				best_amt = amt
				best_idx = i
	if best_idx == -1:
		return effects
	var reduction := int(ceil(float(ceiling - TURN_DAMAGE_CAP) / casts))
	var out := effects.duplicate(true)
	var trimmed: Dictionary = out[best_idx].duplicate()
	trimmed["amount"] = maxi(1, best_amt - reduction)
	out[best_idx] = trimmed
	return out


static func _with_self_damage(effects: Array, amount: int) -> Array:
	var out: Array = []
	for e in effects:
		if e.get("kind", "") == CardData.SELF_DAMAGE:
			var ne: Dictionary = e.duplicate()
			ne["amount"] = amount
			out.append(ne)
		else:
			out.append(e)
	return out


func make_card(
	card_name: String,
	school: int,
	cost: int,
	effects: Array,
	art_id: String,
	exhaust: bool,
	retain: bool,
	xp_threshold: int
) -> CardData:
	var card := CardData.new()
	card.card_name = card_name
	card.school = school
	card.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	card.effects = typed
	card.art_id = art_id
	card.exhaust = exhaust
	card.retain = retain
	card.xp_to_evolve = xp_threshold
	return card


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Any level3-5 name changed on a previous run leaves its old .tres behind —
	# ResourceSaver only ever writes, never deletes. A stale file would still load
	# (test_content's directory walk would find it) and inflate the count past
	# 120, so every run starts from a clean slate for cards this generator owns:
	# everything, since the whole set is regenerated from the table every time.
	var stale_dir := DirAccess.open(OUT_DIR)
	if stale_dir != null:
		for file in stale_dir.get_files():
			if file.ends_with(".tres") or file.ends_with(".tres.import"):
				stale_dir.remove(file)

	var written := 0
	var all: Array[CardData] = []
	var path_by_name := {}

	for row in table():
		var names: Array = [row[0], row[1], row[2], row[3], row[4]]
		var school: int = row[5]
		var cost1: int = row[6]
		var effects1: Array = row[7]
		var cost2: int = row[8]
		var effects2: Array = row[9]
		var exhaust: bool = row[10]
		var retain: bool = row[11]

		var scaled := scale_line_effects(effects1, effects2)
		var effects_by_level := [effects1, effects2, scaled[0], scaled[1], scaled[2]]
		# Cost stays flat at the level2 value for levels 3-5. A line that gets
		# cheaper from level1 to level2 (Marginalia 1 -> 0, Cram 2 -> 1, Thesis
		# Statement 3 -> 2) keeps that identity rather than continuing to drop.
		var costs := [cost1, cost2, cost2, cost2, cost2]

		# Bitter Recall was already the best damage-per-mana card in the game
		# pre-levelling (12 damage for 1 mana vs. Spark's 6); the generic growth
		# rule compounded that into 3 casts x 29 damage = 87 in one turn. No amount
		# of trimming the damage number fixes a cost-1 card that can be cast 3
		# times, so this line alone rises in cost as it masters (1/2/2/3/3) —
		# every other line's cost is meant to stay flat, which is why this can't
		# be a generic rule.
		if names[0] == "Bitter Recall":
			costs = [1, 2, 2, 3, 3]
			var self_damage_by_level := [3, 4, 5, 6, 7]
			for lvl in range(5):
				effects_by_level[lvl] = _with_self_damage(effects_by_level[lvl], self_damage_by_level[lvl])

		for lvl in range(5):
			effects_by_level[lvl] = enforce_turn_cap(effects_by_level[lvl], costs[lvl], exhaust)

		# Every level gets its own art_id, derived from its own name the same way
		# its filename is: "cards/<slug(name)>". Levels used to share the line's
		# art (one illustration, five frame treatments); the art pipeline now
		# generates a distinct illustration per level, so the id has to be
		# distinct and predictable per level rather than per line. School still
		# is shared across the line — only art_id became per-level.
		var art_ids: Array = []
		for lvl_name in names:
			art_ids.append("cards/%s" % slug(lvl_name))

		# Written level5 first, then 4 down to 1, so each level's evolved_card can
		# point at the already-saved resource for the next one — the same reason
		# the original two-level generator wrote the evolved form before the base.
		var paths := ["", "", "", "", ""]
		var next_path := ""
		for lvl in range(4, -1, -1):
			var card := make_card(
				names[lvl], school, costs[lvl], effects_by_level[lvl], art_ids[lvl], exhaust,
				retain, XP_THRESHOLDS[lvl]
			)
			if lvl < 4:
				card.evolved_card = load(next_path)
			var path := "%s/%s.tres" % [OUT_DIR, slug(names[lvl])]
			var err := ResourceSaver.save(card, path)
			if err != OK:
				printerr("failed to write %s: %d" % [path, err])
				quit(1)
				return true
			written += 1
			paths[lvl] = path
			next_path = path

		for lvl in range(5):
			all.append(load(paths[lvl]))
			path_by_name[names[lvl]] = paths[lvl]

	print("wrote %d card resources to %s" % [written, OUT_DIR])

	# The starting deck the spec names: 4 Spark, 4 Guard, 2 Ink Blot — always the
	# level1 form, looked up by name rather than gathered mid-loop so the order
	# here matches the spec's order regardless of the table's row order.
	var start: Array[CardData] = []
	for i in 4:
		start.append(load(path_by_name["Spark"]))
	for i in 4:
		start.append(load(path_by_name["Guard"]))
	for i in 2:
		start.append(load(path_by_name["Ink Blot"]))

	# Index everything just written, plus the starting deck the spec names.
	var library := ContentLibrary.new()
	library.cards = all
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
