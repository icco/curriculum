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
func roster() -> Array:
	return [
		["Novice", 28, 2, INK, FROST, "novice", false,
			["spark", "spark", "kindle", "guard"]],
		["Glass Tutor", 34, 2, CINDER, INK, "glass_tutor", false,
			["ink_blot", "cite_source", "marginalia", "guard", "ink_blot"]],
		["Hall Monitor", 38, 2, ROT, WARD, "hall_monitor", false,
			["guard", "guard", "warded_bracers", "spark", "study_break"]],
		["Drillmaster", 42, 2, CINDER, FROST, "drillmaster", false,
			["frost_lance", "frost_lance", "hoarfrost", "glass_shard", "guard"]],
		["Alchemy Master", 46, 2, WARD, ROT, "alchemy_master", false,
			["rot_seed", "necrology_note", "rot_seed", "bitter_recall", "guard"]],
		["Battle Chanter", 44, 2, FROST, CINDER, "battle_chanter", false,
			["cinder_burst", "spark", "scorch_notes", "kindle", "guard"]],
		# HP is ordered deliberately: each gate clearly out-stats that tier's
		# regulars (tier 1 tops out at 38, tier 2 at 46), and the final
		# (Rector) clearly out-stats both gates. Full mana spending made three
		# of these decks degenerate — Proctor could combo block with itself
		# every turn into a stalemate, Vice-Chancellor's two Decay sources
		# stacked into an unbounded snowball, Rector's Immolate Notes +
		# Bitter Mastery was a one-combo kill — so each deck below was fixed
		# for that specific problem rather than compensated for with lower HP.
		["Proctor", 40, 3, CINDER, WARD, "proctor", true,
			["bulwark", "guard", "rime_lance", "glass_shard", "still_the_hall"]],
		["Vice-Chancellor", 48, 3, FROST, INK, "vice_chancellor", true,
			["spilled_ledger", "frost_lance", "cite_chapter_and_verse", "scorch_notes", "bulwark"]],
		["Rector", 80, 3, ROT, WARD, "rector", false,
			["valedictory_blaze", "long_winter", "defended_thesis", "spark",
			 "valedictory_sigil", "immolate_notes"]],
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
