extends SceneTree

## Writes resources/enemies/*.tres from spec section 11's roster. Gate and final decks
## hold EVOLVED cards, so a boss visibly plays cards the player does not have yet.

const OUT_DIR := "res://resources/enemies"
const CARDS := "res://resources/cards"

const CINDER := Schools.School.CINDER
const FROST := Schools.School.FROST
const INK := Schools.School.INK
const ROT := Schools.School.ROT
const WARD := Schools.School.WARD


## [name, hp, mana, weak, warded, art, is_gate, deck card slugs]
##
## Tuned against hit points that CARRY between courses. Before that landed, every
## fight started at a full 60 and an examiner only had to be survivable in isolation;
## now a deck's job is to cost the right amount of a resource the player keeps, and
## the measured shape (tools/simulate.gd, per-course table) is the gate rather than
## any one fight feeling right.
##
## Two rules the numbers below follow:
##
## 1. A deck's DAMAGE DENSITY matters more than its hit points. A fight is lost to
##    what the examiner lands per turn, not to how long it takes to kill; raising hp
##    lengthens a fight without making it more dangerous, which is how Cryomancy 201
##    became a thirteen-turn slog at a 0% loss rate. Prefer editing the deck.
## 2. Six of the nine examiners are fought TWICE, at two different tiers, from one
##    stat block (spec 8.1). So each regular has to be a real cost at its early
##    course without being free at its late one — which means a flat, reliable deck
##    rather than a bursty one. Burst is reserved for the two gates and the final,
##    each of which is fought exactly once.
func roster() -> Array:
	return [
		# --- Regulars. Fought twice each, tiers 1-3. ---
		# Slightly above their old hit points across the board: the first seven
		# courses measured at a 0% loss rate, so tier 1 was costing nothing at all.
		["Novice", 32, 2, INK, FROST, "novice", false,
			["spark", "spark", "kindle", "guard"]],
		# A second Ink Blot gave it two debuff cards and almost no damage: Cantrips 101
		# cost the player 0.6 hit points on average, which is not a fight.
		["Glass Tutor", 36, 2, CINDER, INK, "glass_tutor", false,
			["ink_blot", "cite_source", "marginalia", "guard", "scorch_notes"]],
		# Was two Guards plus Study Break and a single Spark — almost no offence at
		# all, which made Applied Wardcraft 301 a 0%-loss punching bag. It keeps its
		# defensive identity but now threatens something.
		["Hall Monitor", 40, 2, ROT, WARD, "hall_monitor", false,
			["guard", "warded_bracers", "spark", "study_break", "scorch_notes"]],
		# Chill reduces the BEARER's next attack, so every Chill the Drillmaster lands
		# lengthens the fight by cutting the player's damage — and a longer fight is
		# more Chill. Three sources made this the longest fight in the game (13.3
		# turns) at a 0% loss rate: safe and tedious at once. Exactly one source now,
		# with the freed slots spent on damage.
		["Drillmaster", 40, 2, CINDER, FROST, "drillmaster", false,
			["frost_lance", "glass_shard", "glass_shard", "guard", "guard"]],
		# The hardest examiner in the game to tune, because it is fought at both
		# Necrology 201 and Thesis 301 and its school punishes fight LENGTH.
		#
		# Three Decay sources in five cards was the original problem: Decay grows +2
		# every tick and the player has no way to clear it, so one Rot Seed left
		# running seven turns is 4+6+8+10+12+14+16 = 70 damage on its own. One source
		# now. Decay's growth itself is untouched — the spec argues for it explicitly
		# (3.1), and the deck was what made it unfair.
		#
		# The cost curve is load-bearing and cost the tuning pass one full iteration.
		# This examiner has 2 mana, so a deck of ALL 1-cost cards lets it play two
		# cards every turn: dropping its one 2-cost card to shorten fights took
		# Necrology 201 from a 37% loss to 53%, because Bitter Recall plus Spark is 18
		# damage a turn where a single 2-cost card is 11. Keep at least one 2-cost
		# card here to hold the per-turn output down.
		# Bitter Recall is 12 damage for 1 mana, so pairing it with Spark gave this
		# examiner an 18-damage turn on 2 mana — which is why Necrology 201 stayed a
		# 34% loss, harder than the tier-2 GATE, long after its Decay was cut. Two
		# Sparks cap the same turn at 12.
		["Alchemy Master", 42, 2, WARD, ROT, "alchemy_master", false,
			["rot_seed", "spark", "guard", "scorch_notes", "spark"]],
		["Battle Chanter", 44, 2, FROST, CINDER, "battle_chanter", false,
			["cinder_burst", "spark", "scorch_notes", "kindle", "guard"]],
		# --- Gates and the final. Fought once each, so burst is allowed here. ---
		# Each gate still clearly out-stats its tier's regulars, and the final
		# out-stats both gates. Full mana spending made three of these decks
		# degenerate — Proctor could combo block with itself every turn into a
		# stalemate, Vice-Chancellor's two Decay sources stacked into an unbounded
		# snowball, Rector's Immolate Notes + Bitter Mastery was a one-combo kill —
		# so each was fixed for that specific problem rather than compensated for
		# with lower hit points.
		["Proctor", 40, 3, CINDER, WARD, "proctor", true,
			["bulwark", "guard", "rime_lance", "glass_shard", "still_the_hall"]],
		["Vice-Chancellor", 46, 3, FROST, INK, "vice_chancellor", true,
			["spilled_ledger", "frost_lance", "cite_chapter_and_verse", "scorch_notes", "bulwark"]],
		# Was a 92% loss that ended in 2.8 turns: an all-evolved deck at 3 mana, led
		# by Valedictory Blaze (30 damage for 3) and Immolate Notes (17 for 2), against
		# a player arriving at ~34 hit points. It killed before the fight became one.
		# The hit points stay — a final should be a wall of a fight — but the burst
		# comes down to its un-evolved forms, so the Rector wins by grinding a
		# depleted student down rather than by deleting them from full.
		["Rector", 68, 3, ROT, WARD, "rector", false,
			["glass_shard", "winter_term", "defended_thesis", "spark",
			 "honours_sigil", "scorch_notes"]],
	]


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var enemies: Array[EnemyData] = []
	for row in roster():
		var enemy := EnemyData.new()
		enemy.enemy_name = row[0]
		enemy.max_hp = row[1]
		enemy.mana_per_turn = row[2]
		enemy.weak_school = row[3]
		enemy.warded_school = row[4]
		enemy.art_id = "entities/%s" % row[5]
		enemy.is_gate = row[6]
		var deck: Array[CardData] = []
		for slug in row[7]:
			var path := "%s/%s.tres" % [CARDS, slug]
			var card: CardData = load(path)
			if card == null:
				printerr("missing card %s for %s" % [path, enemy.enemy_name])
				quit(1)
				return true
			deck.append(card)
		enemy.deck = deck
		var out := "%s/%s.tres" % [OUT_DIR, row[5]]
		if ResourceSaver.save(enemy, out) != OK:
			printerr("failed to write %s" % out)
			quit(1)
			return true
		enemies.append(load(out))

	var library: ContentLibrary = load("res://resources/content_library.tres")
	library.enemies = enemies
	ResourceSaver.save(library, "res://resources/content_library.tres")
	print("wrote %d examiners" % enemies.size())
	quit(0)
	return true
