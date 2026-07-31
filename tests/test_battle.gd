extends TestCase

## Turn resolution. Every test builds its cards inline so a content change cannot
## break the rules suite.


func suite_name() -> String:
	return "battle"


func _card(name: String, school, cost: int, effects: Array) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = school
	d.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	d.effects = typed
	return d


func _enemy(hp: int, weak, warded, deck: Array) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = "Dummy"
	e.max_hp = hp
	e.mana_per_turn = 2
	var typed: Array[CardData] = []
	for c in deck:
		typed.append(c)
	e.deck = typed
	e.weak_school = weak
	e.warded_school = warded
	return e


## The deck is shuffled, so with a hand of mixed card types `hand[0]` is not
## reliably the card a scenario wants to play. Find it by name instead.
func _find_in_hand(deck: Deck, name: String) -> CardInstance:
	for card in deck.hand:
		if card.data.card_name == name:
			return card
	return null


func _battle(player_cards: Array, enemy: EnemyData) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var instances := []
	for c in player_cards:
		instances.append(CardInstance.new(c))
	return Battle.new(instances, enemy, Bestiary.new(), rng)


func run() -> void:
	var S := Schools.School
	var strike := _card("Strike", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 10}])
	var guard := _card("Guard", S.WARD, 1, [{"kind": CardData.BLOCK, "amount": 6}])
	var poke := _card("Poke", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 1}])

	# A neutral card deals its face value.
	var b := _battle([strike, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [poke]))
	b.start()
	eq(b.player.hp, 60, "player starts at 60")
	eq(b.player.mana, 3, "three mana")
	eq(b.player_deck.hand.size(), 5, "drew five")
	var events := b.play_card(b.player_deck.hand[0])
	eq(b.examiner.hp, 90, "neutral card dealt 10")
	eq(b.player.mana, 2, "mana spent")
	# NOTE: play_card always emits at least a "card_played" event, so this cannot
	# fail regardless of what the effects actually did. Kept for brief-fidelity;
	# the real proof is the eq() checks around it.
	check(events.size() > 0, "play produced events")

	# Mana is enforced.
	var broke := _battle([_card("Big", S.CINDER, 9, [{"kind": CardData.DAMAGE, "amount": 5}])], _enemy(50, S.ROT, S.FROST, [poke]))
	broke.start()
	eq(broke.can_play(broke.player_deck.hand[0]), false, "cannot afford it")
	var refused := broke.play_card(broke.player_deck.hand[0])
	eq(refused[0]["type"], "illegal", "refused as illegal")
	eq(broke.examiner.hp, 50, "no damage dealt")

	# The weak school multiplies by 1.5, the warded school halves — and the very
	# first hit already gets the bonus.
	var weak := _battle([strike], _enemy(100, S.CINDER, S.WARD, [poke]))
	weak.start()
	weak.play_card(weak.player_deck.hand[0])
	eq(weak.examiner.hp, 85, "weak school dealt 15")

	var warded := _battle([strike], _enemy(100, S.ROT, S.CINDER, [poke]))
	warded.start()
	warded.play_card(warded.player_deck.hand[0])
	eq(warded.examiner.hp, 95, "warded school dealt 5")

	# The multiplier scales non-damage numbers too, which is what lets Ward be a
	# weakness at all.
	var ward_weak := _battle([guard], _enemy(100, S.WARD, S.ROT, [poke]))
	ward_weak.start()
	ward_weak.play_card(ward_weak.player_deck.hand[0])
	eq(ward_weak.player.block, 9, "block scaled by the weakness")

	# Playing a card banks XP and evolves it in place at the threshold.
	#
	# NOTE on a bug in the brief's own draft here: the original test built three
	# SEPARATE CardInstance.new(evo_base) objects and expected xp to accumulate
	# across them (first play brings the first instance to 1/2, then it expected
	# the SECOND, entirely independent, fresh instance to evolve after just one
	# play). That is impossible under the already-committed, already-tested
	# per-instance XP semantics (tests/test_evolution.gd: "two instances sharing
	# one CardData must not see each other's XP"). Battle must not — and does
	# not — change that. Fixed here by giving a single instance its 1 banked xp
	# up front, so this one Battle-mediated play is the one that crosses the
	# threshold, which is what actually exercises Battle's play_card ->
	# CardInstance.gain_xp wiring.
	var evo_base := _card("Seed", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 1}])
	var evo_top := _card("Bloom", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 9}])
	evo_base.evolved_card = evo_top
	evo_base.xp_to_evolve = 2
	var evo_rng := RandomNumberGenerator.new()
	evo_rng.seed = 99
	var seasoned := CardInstance.new(evo_base, 1)
	var evo := Battle.new([seasoned], _enemy(100, S.ROT, S.FROST, [poke]), Bestiary.new(), evo_rng)
	evo.start()
	var evo_events := evo.play_card(evo.player_deck.hand[0])
	eq(evo.xp_banked, 1, "one play recorded")
	eq(seasoned.data.card_name, "Bloom", "evolved at the threshold")
	var saw_evolution := false
	for e in evo_events:
		if e["type"] == "evolved":
			saw_evolution = true
	eq(saw_evolution, true, "emitted an evolved event")

	# A fresh instance below the threshold does not evolve early.
	var fresh_rng := RandomNumberGenerator.new()
	fresh_rng.seed = 99
	var fresh_seed := CardInstance.new(evo_base)
	var not_yet := Battle.new(
		[fresh_seed], _enemy(100, S.ROT, S.FROST, [poke]), Bestiary.new(), fresh_rng
	)
	not_yet.start()
	not_yet.play_card(not_yet.player_deck.hand[0])
	eq(fresh_seed.data.card_name, "Seed", "not yet evolved with only one xp banked")

	# A hit with the weak school reveals it and says so.
	var reveal := _battle([strike], _enemy(100, S.CINDER, S.WARD, [poke]))
	reveal.start()
	var reveal_events := reveal.play_card(reveal.player_deck.hand[0])
	var saw_reveal := false
	for e in reveal_events:
		if e["type"] == "revealed":
			saw_reveal = true
	eq(saw_reveal, true, "reveal emitted")

	# Distinct schools played is what the Discovery term counts. All three cards
	# (cost 1 + 1 + 0 = 2 mana) are affordable within the player's 3 mana, so the
	# exact count is pinned at 3, not just ">= 2".
	var variety := _battle([strike, guard, poke], _enemy(100, S.ROT, S.FROST, [poke]))
	variety.start()
	for card in variety.player_deck.hand.duplicate():
		if variety.can_play(card):
			variety.play_card(card)
	eq(variety.schools_played(), 3, "counted three distinct schools exactly")

	# schools_played() must key by school, not by card name: two different-named
	# cards in the SAME school count once.
	var ember := _card("Ember", S.CINDER, 0, [{"kind": CardData.DAMAGE, "amount": 1}])
	var spark := _card("Spark", S.CINDER, 0, [{"kind": CardData.DAMAGE, "amount": 1}])
	var keying := _battle([ember, spark], _enemy(100, S.ROT, S.FROST, [poke]))
	keying.start()
	for card in keying.player_deck.hand.duplicate():
		if keying.can_play(card):
			keying.play_card(card)
	eq(keying.schools_played(), 1, "same-school cards with different names count once")

	# Ending the turn discards, runs the examiner, and comes back with a new hand.
	var turn := _battle([strike, strike, strike, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [_card("Jab", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 4}])]))
	turn.start()
	eq(turn.turns, 1, "first turn")
	check(turn.examiner_intent != null, "intent telegraphed before the player acts")
	turn.end_turn()
	eq(turn.player.hp, 56, "examiner hit for four")
	eq(turn.turns, 2, "second turn")
	eq(turn.player_deck.hand.size(), 5, "redrew five")
	eq(turn.player.mana, 3, "mana refilled")

	# Block gained during the player's own turn must survive to absorb the
	# examiner's attack in the SAME end_turn() call — it only expires afterward,
	# at the start of the player's next turn.
	var block_survives := _battle([guard, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [_card("Jab", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 4}])]))
	block_survives.start()
	block_survives.play_card(_find_in_hand(block_survives.player_deck, "Guard"))
	eq(block_survives.player.block, 6, "gained six block")
	block_survives.end_turn()
	eq(block_survives.player.hp, 60, "block absorbed the examiner's hit before expiring")

	# Burn ticks at the start of the bearer's turn and decrements.
	var burn_card := _card("Kindle", S.CINDER, 1, [{"kind": CardData.STATUS, "status": Statuses.Kind.BURN, "amount": 3}])
	var burn := _battle([burn_card, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [poke]))
	burn.start()
	burn.play_card(_find_in_hand(burn.player_deck, "Kindle"))
	eq(burn.examiner.statuses.amount(Statuses.Kind.BURN), 3, "applied three burn")
	burn.end_turn()
	eq(burn.examiner.hp, 97, "burn ticked for three")
	eq(burn.examiner.statuses.amount(Statuses.Kind.BURN), 2, "burn decremented")

	# Rot pays in the player's own hit points, bypassing block.
	var bitter := _card("Bitter", S.ROT, 1, [{"kind": CardData.SELF_DAMAGE, "amount": 3}, {"kind": CardData.DAMAGE, "amount": 12}])
	var rot := _battle([bitter], _enemy(100, S.WARD, S.FROST, [poke]))
	rot.start()
	rot.player.gain_block(50)
	rot.play_card(rot.player_deck.hand[0])
	eq(rot.player.hp, 57, "paid three hp through block")
	eq(rot.examiner.hp, 88, "dealt twelve")

	# Blot is consumed ONCE per card, not once per effect: both hits on a
	# two-effect card must get the same reduction.
	var flurry := _card("Flurry", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 10}, {"kind": CardData.DAMAGE, "amount": 10}])
	var blotted := _battle([flurry], _enemy(100, S.ROT, S.FROST, [poke]))
	blotted.start()
	blotted.player.statuses.add(Statuses.Kind.BLOT, 1)
	blotted.play_card(blotted.player_deck.hand[0])
	eq(blotted.examiner.hp, 88, "both hits reduced by the same single Blot consumption (10*0.6 twice = 12)")

	# Chill scales damage on top of the school multiplier, and the combined scale
	# must be rounded ONCE, not once for the school/Blot portion and again for
	# Chill. 15 * 0.5 (warded) * 0.7 (one Chill stack) = 5.25 -> 5. Rounding the
	# 0.5 step first would give round(7.5)=8, then round(8*0.7)=6 — a different,
	# wrong answer.
	var frosty := _card("Frosty", S.ROT, 1, [{"kind": CardData.DAMAGE, "amount": 15}])
	var chilled := _battle([frosty], _enemy(100, S.CINDER, S.ROT, [poke]))
	chilled.start()
	chilled.player.statuses.add(Statuses.Kind.CHILL, 1)
	chilled.play_card(chilled.player_deck.hand[0])
	eq(chilled.examiner.hp, 95, "school scale and Chill combined and rounded once")

	# The examiner plays the highest-cost card it can AFFORD with its
	# mana_per_turn (2 here), not the highest-cost card in its deck.
	var nip := _card("Nip", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 1}])
	var bite := _card("Bite", S.CINDER, 2, [{"kind": CardData.DAMAGE, "amount": 2}])
	var devour := _card("Devour", S.CINDER, 3, [{"kind": CardData.DAMAGE, "amount": 3}])
	var pricing := _battle([strike], _enemy(100, S.ROT, S.FROST, [nip, bite, devour]))
	pricing.start()
	check(pricing.examiner_intent != null, "examiner has an intent")
	eq(pricing.examiner_intent.data.cost, 2, "picked the highest AFFORDABLE card, not the priciest one")

	# Player Decay ticks at the END of the player's own turn, BEFORE the examiner
	# gets to act at all. If Decay kills the player right there, the examiner's
	# turn must never run: turns must not advance, and no examiner card_played
	# event may appear.
	var decay_race := _battle([strike, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [poke]))
	decay_race.start()
	decay_race.player.statuses.add(Statuses.Kind.DECAY, 100)
	var decay_events := decay_race.end_turn()
	eq(decay_race.finished, true, "the player's own decay ended the battle")
	eq(decay_race.player_won, false, "decay defeat is not a win")
	eq(decay_race.turns, 1, "turn never advanced: the examiner never got a turn")
	var examiner_acted := false
	for e in decay_events:
		if e.get("by", "") == "examiner":
			examiner_acted = true
	eq(examiner_acted, false, "the examiner's turn did not run after the player's decay ended the battle")

	# Examiner Burn ticks at the START of the examiner's turn, BEFORE its
	# telegraphed intent resolves. If Burn alone is lethal, the intent must never
	# be played — the player must take no damage from it.
	var scorch := _card("Scorch", S.CINDER, 1, [{"kind": CardData.STATUS, "status": Statuses.Kind.BURN, "amount": 5}])
	var massive := _card("Massive", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 50}])
	var burn_kill := _battle([scorch, strike, strike, strike, strike], _enemy(2, S.ROT, S.FROST, [massive]))
	burn_kill.start()
	burn_kill.play_card(_find_in_hand(burn_kill.player_deck, "Scorch"))
	var burn_kill_events := burn_kill.end_turn()
	eq(burn_kill.finished, true, "burn alone killed the examiner")
	eq(burn_kill.player_won, true, "burn kill counts as a win")
	eq(burn_kill.player.hp, 60, "the examiner's lethal-avoided intent never got to resolve")
	var examiner_played := false
	for e in burn_kill_events:
		if e.get("by", "") == "examiner":
			examiner_played = true
	eq(examiner_played, false, "burn resolved before the intent could be played")

	# The UI needs read access to the enemy's art id and data without reaching
	# into a private field.
	var art_enemy := _enemy(10, S.ROT, S.FROST, [poke])
	art_enemy.art_id = "goblin"
	var art_battle := _battle([strike], art_enemy)
	eq(art_battle.examiner_art_id(), "goblin", "exposes the enemy's art id")
	eq(art_battle.examiner_data(), art_enemy, "exposes the enemy data object")

	# Killing the examiner ends the battle and reports a win.
	var kill := _battle([strike, strike], _enemy(5, S.ROT, S.FROST, [poke]))
	kill.start()
	var end_events := kill.play_card(kill.player_deck.hand[0])
	eq(kill.finished, true, "battle over")
	eq(kill.player_won, true, "player won")
	var saw_end := false
	for e in end_events:
		if e["type"] == "battle_end":
			saw_end = true
	eq(saw_end, true, "emitted battle_end")
	# The brief's original assertion here chained a ternary guarding an empty
	# hand, which — if the hand were empty — passed `null` into play_card and so
	# actually exercised the can_play(null) == false path, not "battle is over".
	# Use a second, real, in-hand, affordable card instead, so the refusal can
	# only be attributed to `finished`.
	check(kill.player_deck.hand.size() > 0, "a second legal-looking card remains in hand")
	var remaining: CardInstance = kill.player_deck.hand[0]
	eq(kill.can_play(remaining), false, "cannot play a legal card once the battle has ended")
	eq(kill.play_card(remaining)[0]["type"], "illegal", "refused solely because the battle is over")

	# Losing sets finished without a win. The F strike is Run's job, not Battle's.
	var doomed := _battle([guard], _enemy(100, S.ROT, S.FROST, [_card("Crush", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 999}])]))
	doomed.start()
	doomed.end_turn()
	eq(doomed.finished, true, "battle over")
	eq(doomed.player_won, false, "player lost")
	eq(doomed.player.is_down(), true, "player is down")
