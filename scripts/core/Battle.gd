class_name Battle
extends RefCounted

## One battle. Pure logic: every method returns an array of event dictionaries for
## the presentation layer to replay, and nothing here touches the scene tree.
##
## The examiner plays exactly one card per turn, telegraphed as `examiner_intent` at
## the end of the player's turn, so the player is never hit by untelegraphed damage.

const CHILL_REDUCTION := 0.3  # per stack, applied to damage
const BLOT_REDUCTION := 0.4  # per stack, applied to every number on the card

var player: Combatant
var examiner: Combatant
var player_deck: Deck
var examiner_deck: Deck
var examiner_intent: CardInstance = null
var turns := 0
var xp_banked := 0
var finished := false
var player_won := false

## Untyped: Bestiary and Battle referring to each other by type would be cyclic.
var _bestiary
var _enemy_data: EnemyData
var _schools_played := {}
var _mana_bonus_next := 0
var _ward_played_this_turn := false


func _init(
	player_cards: Array, enemy: EnemyData, bestiary, rng: RandomNumberGenerator = null
) -> void:
	_enemy_data = enemy
	_bestiary = bestiary
	player = Combatant.new("Student", 60, 3)
	examiner = enemy.to_combatant()
	player_deck = Deck.new(player_cards, rng)
	var examiner_instances := []
	for card in enemy.deck:
		examiner_instances.append(CardInstance.new(card))
	examiner_deck = Deck.new(examiner_instances, rng)


func schools_played() -> int:
	return _schools_played.size()


## "" when there is no enemy data, so the UI never has to null-check its own read.
func examiner_art_id() -> String:
	if _enemy_data == null:
		return ""
	return _enemy_data.art_id


func examiner_data() -> EnemyData:
	return _enemy_data


func start() -> Array:
	turns = 1
	player.refill_mana()
	var events: Array = [{"type": "turn_start", "turn": turns, "text": "Turn 1"}]
	for card in player_deck.draw(Deck.HAND_SIZE):
		events.append({"type": "draw", "card": card, "text": "Drew %s" % card.data.card_name})
	events.append_array(_choose_intent())
	return events


func can_play(card) -> bool:
	if finished or card == null:
		return false
	if not player_deck.hand.has(card):
		return false
	return card.data.cost <= player.mana


func play_card(card) -> Array:
	if not can_play(card):
		return [{"type": "illegal", "text": "That card cannot be played."}]

	player.spend_mana(card.data.cost)
	var events: Array = [
		{"type": "card_played", "card": card, "text": "Played %s" % card.data.card_name}
	]

	# One scale for the whole card: the school multiplier, reduced by Blot. Blot is
	# consumed once per card, not once per effect.
	var scale := float(_bestiary.multiplier(_enemy_data, card.data.school))
	var blot := player.statuses.consume(Statuses.Kind.BLOT)
	if blot > 0:
		scale *= maxf(0.0, 1.0 - BLOT_REDUCTION * float(blot))

	# Chill likewise: consumed once, and only if this card actually attacks.
	var chill_scale := 1.0
	if _deals_damage(card.data):
		var chill := player.statuses.consume(Statuses.Kind.CHILL)
		if chill > 0:
			chill_scale = maxf(0.0, 1.0 - CHILL_REDUCTION * float(chill))

	if card.data.school == Schools.School.WARD:
		_ward_played_this_turn = true

	for effect in card.data.effects:
		events.append_array(_apply(effect, scale, chill_scale, player, examiner))

	# Learning: XP is banked on the instance, never on the CardData.
	if card.gain_xp(1):
		events.append(
			{"type": "evolved", "card": card, "text": "%s evolved!" % card.data.card_name}
		)
	xp_banked += 1
	_schools_played[card.data.school] = true

	var revealed: String = _bestiary.record_hit(_enemy_data, card.data.school)
	if revealed != "":
		events.append(
			{
				"type": "revealed",
				"kind": revealed,
				"school": card.data.school,
				"text": (
					"%s is %s %s!"
					% [
						_enemy_data.enemy_name,
						"weak to" if revealed == "weakness" else "warded against",
						Schools.display_name(card.data.school),
					]
				),
			}
		)

	player_deck.play(card)
	events.append_array(_check_end())
	return events


func end_turn() -> Array:
	if finished:
		return [{"type": "illegal", "text": "The battle is over."}]

	var events: Array = []
	for card in player_deck.discard_hand():
		events.append({"type": "discard", "card": card, "text": ""})
	_ward_played_this_turn = false

	# Player's Decay resolves at the end of the player's turn.
	events.append_array(_tick_decay(player, "You"))
	events.append_array(_check_end())
	if finished:
		return events

	events.append_array(_examiner_turn())
	events.append_array(_check_end())
	if finished:
		return events

	# Back to the player.
	turns += 1
	player.expire_block()
	player.refill_mana(_mana_bonus_next)
	_mana_bonus_next = 0
	events.append({"type": "turn_start", "turn": turns, "text": "Turn %d" % turns})
	var burn := player.statuses.tick_start_of_turn()
	if burn > 0:
		player.take_damage(burn)
		events.append({"type": "damage", "target": "player", "amount": burn, "text": "Burn"})
	for card in player_deck.draw(Deck.HAND_SIZE):
		events.append({"type": "draw", "card": card, "text": ""})
	events.append_array(_check_end())
	return events


func _examiner_turn() -> Array:
	var events: Array = []
	examiner.expire_block()
	examiner.refill_mana()

	var burn := examiner.statuses.tick_start_of_turn()
	if burn > 0:
		examiner.take_damage(burn)
		events.append(
			{"type": "damage", "target": "examiner", "amount": burn, "text": "Burn"}
		)
	if examiner.is_down():
		return events

	if examiner_intent != null:
		var card: CardInstance = examiner_intent
		examiner.spend_mana(card.data.cost)
		events.append(
			{
				"type": "card_played",
				"card": card,
				"by": "examiner",
				"text": "%s casts %s" % [_enemy_data.enemy_name, card.data.card_name],
			}
		)
		var scale := 1.0
		var blot := examiner.statuses.consume(Statuses.Kind.BLOT)
		if blot > 0:
			scale *= maxf(0.0, 1.0 - BLOT_REDUCTION * float(blot))
		var chill_scale := 1.0
		if _deals_damage(card.data):
			var chill := examiner.statuses.consume(Statuses.Kind.CHILL)
			if chill > 0:
				chill_scale = maxf(0.0, 1.0 - CHILL_REDUCTION * float(chill))
		for effect in card.data.effects:
			events.append_array(_apply(effect, scale, chill_scale, examiner, player))
		examiner_deck.play(card)
		examiner_intent = null

		# The intent may have just killed the player. Do not tick the examiner's
		# own Decay or pick a new intent on top of a battle that is already
		# over — that is how a dead player was getting credited with the win:
		# the examiner's own Decay tick would then kill the examiner too, and
		# _check_end (before its fix below) asked "is the examiner down?" first.
		if player.is_down():
			return events

	events.append_array(_tick_decay(examiner, _enemy_data.enemy_name))
	if not examiner.is_down():
		events.append_array(_choose_intent())
	return events


## Picks the most expensive card the examiner can afford, and telegraphs it.
func _choose_intent() -> Array:
	_refill_examiner_hand()
	var best := _best_affordable_in_hand()
	if best == null and not examiner_deck.hand.is_empty():
		# Nothing currently in hand is affordable. Rather than hold the same
		# unaffordable hand forever (hand.size() stays >= 3, so it would never
		# be topped up again and the examiner would hesitate every turn for the
		# rest of the battle), cycle the whole hand into the discard and try
		# once more with a fresh draw. This does not guarantee an affordable
		# card exists anywhere in the deck, but it stops a merely unlucky draw
		# from making a battle un-loseable.
		for card in examiner_deck.hand.duplicate():
			examiner_deck.hand.erase(card)
			examiner_deck.discard_pile.append(card)
		_refill_examiner_hand()
		best = _best_affordable_in_hand()
	examiner_intent = best
	if best == null:
		return [{"type": "intent", "card": null, "text": "%s hesitates." % _enemy_data.enemy_name}]
	return [
		{
			"type": "intent",
			"card": best,
			"text": "%s will cast %s" % [_enemy_data.enemy_name, best.data.card_name],
		}
	]


func _refill_examiner_hand() -> void:
	if examiner_deck.hand.size() < 3:
		examiner_deck.draw(3 - examiner_deck.hand.size())


func _best_affordable_in_hand() -> CardInstance:
	var best: CardInstance = null
	for card in examiner_deck.hand:
		if card.data.cost > examiner.mana_per_turn:
			continue
		if best == null or card.data.cost > best.data.cost:
			best = card
	return best


func _tick_decay(who: Combatant, label: String) -> Array:
	var decay := who.statuses.tick_end_of_turn()
	if decay <= 0:
		return []
	who.take_damage(decay)
	return [
		{
			"type": "damage",
			"target": "player" if who == player else "examiner",
			"amount": decay,
			"text": "%s take %d from Decay" % [label, decay],
		}
	]


func _deals_damage(data: CardData) -> bool:
	for effect in data.effects:
		if effect.get("kind", "") in [CardData.DAMAGE, CardData.BONUS_IF_CHILLED]:
			return true
	return false


## Applies one effect. `scale` covers the school multiplier and Blot; `chill_scale`
## applies to damage only, and is combined with `scale` and rounded ONCE — rounding
## the school/Blot portion separately from Chill would make 10 x 0.5 x 0.7 come out
## wrong (round(7.5)=8, then round(8*0.7)=6, instead of round(5.25)=5).
func _apply(
	effect: Dictionary, scale: float, chill_scale: float, source: Combatant, target: Combatant
) -> Array:
	var kind: String = effect.get("kind", "")
	var raw: int = int(effect.get("amount", 0))
	var target_label := "player" if target == player else "examiner"

	match kind:
		CardData.DAMAGE:
			var dealt := int(roundf(float(raw) * scale * chill_scale))
			target.take_damage(dealt)
			return [
				{"type": "damage", "target": target_label, "amount": dealt, "text": "%d damage" % dealt}
			]
		CardData.BONUS_IF_CHILLED:
			if target.statuses.amount(Statuses.Kind.CHILL) <= 0:
				return []
			var bonus := int(roundf(float(raw) * scale * chill_scale))
			target.take_damage(bonus)
			return [
				{"type": "damage", "target": target_label, "amount": bonus, "text": "+%d, chilled" % bonus}
			]
		CardData.BLOCK:
			var scaled := int(roundf(float(raw) * scale))
			source.gain_block(scaled)
			return [{"type": "block", "amount": scaled, "text": "+%d block" % scaled}]
		CardData.BONUS_IF_WARD_PLAYED:
			if not _ward_played_this_turn:
				return []
			var scaled := int(roundf(float(raw) * scale))
			source.gain_block(scaled)
			return [{"type": "block", "amount": scaled, "text": "+%d block" % scaled}]
		CardData.HEAL:
			var scaled := int(roundf(float(raw) * scale))
			source.heal(scaled)
			return [{"type": "heal", "amount": scaled, "text": "Healed %d" % scaled}]
		CardData.SELF_DAMAGE:
			# Paying, not being hit: bypasses block. Unlike BLOCK/HEAL (which also
			# land on `source` but ARE scaled), this is a fixed price the card
			# charges its own caster, not scaled by the enemy's weakness/ward
			# multiplier or by Blot — the examiner's own vulnerabilities should
			# not make the player's Rot cards cheaper or more expensive to cast.
			source.pay_hp(raw)
			return [{"type": "pay_hp", "amount": raw, "text": "Paid %d hp" % raw}]
		CardData.STATUS:
			var status_kind = effect.get("status", Statuses.Kind.BURN)
			var scaled := int(roundf(float(raw) * scale))
			target.statuses.add(status_kind, scaled)
			return [
				{
					"type": "status",
					"target": target_label,
					"status": status_kind,
					"amount": scaled,
					"text": "+%d" % scaled,
				}
			]
		CardData.DOUBLE_DECAY:
			target.statuses.double_decay()
			return [{"type": "status", "target": target_label, "text": "Decay doubled"}]
		CardData.DRAW:
			var events: Array = []
			var deck := player_deck if source == player else examiner_deck
			for card in deck.draw(raw):
				events.append({"type": "draw", "card": card, "text": ""})
			return events
		CardData.MANA_NEXT:
			if source == player:
				_mana_bonus_next += raw
			return [{"type": "mana", "amount": raw, "text": "+%d mana next turn" % raw}]
		_:
			return []


func _check_end() -> Array:
	if finished:
		return []
	# Player checked first: a dead player is always a loss, even if the
	# examiner also went down in the same exchange (e.g. the examiner's own
	# Decay or a self-costing spell kills it in the same turn it kills the
	# player). Simultaneous death must not be scored as a win.
	if player.is_down():
		finished = true
		player_won = false
		return [{"type": "battle_end", "won": false, "text": "You fail the examination."}]
	if examiner.is_down():
		finished = true
		player_won = true
		return [{"type": "battle_end", "won": true, "text": "You pass the examination."}]
	return []
