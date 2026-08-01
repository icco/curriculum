extends TestCase
func suite_name() -> String:
	return "burnlog"
func run() -> void:
	var S := Schools.School
	var kindle := CardData.new()
	kindle.card_name = "Kindle"; kindle.school = S.CINDER; kindle.cost = 1
	kindle.effects = [{"kind": CardData.STATUS, "status": Statuses.Kind.BURN, "amount": 4}] as Array[Dictionary]
	var jab := CardData.new()
	jab.card_name = "Jab"; jab.school = S.CINDER; jab.cost = 1
	jab.effects = [{"kind": CardData.DAMAGE, "amount": 1}] as Array[Dictionary]
	var e := EnemyData.new()
	e.enemy_name = "Dummy"; e.max_hp = 80; e.mana_per_turn = 1
	e.deck = [jab] as Array[CardData]
	e.weak_school = S.ROT; e.warded_school = S.FROST
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var b := Battle.new([CardInstance.new(kindle)], e, Bestiary.new(), rng)
	b.start()
	b.play_card(b.player_deck.hand[0])
	var events := b.end_turn()
	var burn_text := ""
	for ev in events:
		var t := str(ev.get("text", ""))
		if t.to_lower().contains("burn"):
			burn_text = t
			break
	check(burn_text != "", "a burn tick was logged")
	# The number is the point: the event carries `amount`, and the log must not drop it.
	check(burn_text.contains("4"), "burn log names its damage, got '%s'" % burn_text)
