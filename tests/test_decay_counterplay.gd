extends TestCase

## Does the player have any answer to Decay?
##
## Written to settle a claim made in the audit — "Decay has no player counterplay at
## all" — which is wrong, and this suite is the proof. Decay ticks at the END of the
## player's turn, while Block does not expire until the START of their next one, so
## Block gained on the turn Decay lands DOES absorb it.
##
## What is genuinely absent is any way to remove or shrink a Decay stack:
## Statuses.clear_all() exists and nothing in battle calls it. So Block mitigates
## each tick but never stops the growth, which is the real shape of the problem.


func suite_name() -> String:
	return "decay_counterplay"


func _enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = "Dummy"
	e.max_hp = 200
	e.mana_per_turn = 0  # never acts, so only Decay moves the player's hit points
	e.weak_school = Schools.School.FROST
	e.warded_school = Schools.School.INK
	e.deck = []
	return e


func _card(name: String, school: int, cost: int, effects: Array) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = school
	d.cost = cost
	var typed: Array[Dictionary] = []
	for effect in effects:
		typed.append(effect)
	d.effects = typed
	return d


func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	var guard := _card("Guard", Schools.School.WARD, 1, [{"kind": CardData.BLOCK, "amount": 20}])
	var idle := _card("Idle", Schools.School.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 0}])

	# Ten Decay on the player, and a hand that can block it.
	var blocking := Battle.new(
		[CardInstance.new(guard), CardInstance.new(guard), CardInstance.new(guard)],
		_enemy(), Bestiary.new(), rng
	)
	blocking.start()
	blocking.player.statuses.add(Statuses.Kind.DECAY, 10)
	var hp_before: int = blocking.player.hp
	# Block first, then end the turn so Decay ticks into it.
	for card in blocking.player_deck.hand.duplicate():
		if blocking.can_play(card):
			blocking.play_card(card)
			break
	check(blocking.player.block >= 10, "the player is holding enough block to eat the tick")
	blocking.end_turn()
	eq(blocking.player.hp, hp_before, "block absorbs the whole Decay tick")

	# The same tick with no block on: this is the control, and without it the case
	# above could pass simply because Decay never fired.
	var naked := Battle.new(
		[CardInstance.new(idle), CardInstance.new(idle), CardInstance.new(idle)],
		_enemy(), Bestiary.new(), rng
	)
	naked.start()
	naked.player.statuses.add(Statuses.Kind.DECAY, 10)
	var naked_before: int = naked.player.hp
	naked.end_turn()
	eq(naked.player.hp, naked_before - 10, "the same tick with no block costs full hit points")

	# But blocking does NOT shrink the stack — it grows regardless, by DECAY_GROWTH.
	# This is the real gap: mitigation exists, removal does not, so a long fight
	# eventually outgrows any block the player can put up.
	eq(
		blocking.player.statuses.amount(Statuses.Kind.DECAY),
		10 + Statuses.DECAY_GROWTH,
		"blocking the damage does not stop the stack growing"
	)
	check(
		blocking.player.statuses.amount(Statuses.Kind.DECAY) > 10,
		"Decay is strictly worse next turn even when fully blocked"
	)
