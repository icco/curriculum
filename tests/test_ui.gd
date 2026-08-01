extends TestCase

## Layout maths and the mouse-filter discipline. Control nodes eat board taps: every
## container must be MOUSE_FILTER_IGNORE with only buttons set to STOP, or the screen
## goes silently unresponsive.


func suite_name() -> String:
	return "ui"


func _card(name: String, cost := 1) -> CardInstance:
	var d := CardData.new()
	d.card_name = name
	d.cost = cost
	d.school = Schools.School.CINDER
	d.effects = [{"kind": CardData.DAMAGE, "amount": 6}] as Array[Dictionary]
	d.art_id = "cards/spark"
	return CardInstance.new(d)


func run() -> void:
	# A single card sits centred and upright.
	var solo := HandFan.fan_transform(0, 1, 1080.0)
	almost(solo["rotation"], 0.0, "one card is upright")
	almost(solo["position"].x, 540.0, "one card is centred")

	# Five cards fan symmetrically about the centre.
	var first := HandFan.fan_transform(0, 5, 1080.0)
	var last := HandFan.fan_transform(4, 5, 1080.0)
	var middle := HandFan.fan_transform(2, 5, 1080.0)
	check(first["position"].x < middle["position"].x, "cards run left to right")
	check(middle["position"].x < last["position"].x, "cards run left to right")
	almost(middle["rotation"], 0.0, "the middle card is upright")
	almost(first["rotation"], -last["rotation"], "the fan is symmetric")
	check(first["rotation"] < 0.0, "the left card tilts left")
	# Outer cards sit lower, which is what makes a fan read as a fan.
	check(first["position"].y > middle["position"].y, "outer cards hang lower")
	almost(first["position"].y, last["position"].y, "the fan is level")

	# The fan never runs off a 1080-wide screen, however many cards are held.
	for count in [1, 3, 5, 8, 12]:
		for i in count:
			var t := HandFan.fan_transform(i, count, 1080.0)
			check(t["position"].x >= 0.0, "card %d/%d is on screen" % [i, count])
			check(t["position"].x <= 1080.0, "card %d/%d is on screen" % [i, count])

	# A card's effects must render as short, plain-English text — without this, a
	# player can only tell cards apart by memorising all 48 of them.
	eq(
		CardView.effect_summary([{"kind": CardData.DAMAGE, "amount": 6}] as Array[Dictionary]),
		"6 damage",
		"plain damage reads as N damage"
	)
	eq(
		CardView.effect_summary([{"kind": CardData.BLOCK, "amount": 6}] as Array[Dictionary]),
		"+6 block",
		"block reads as +N block"
	)
	eq(
		CardView.effect_summary(
			[{"kind": CardData.STATUS, "status": Statuses.Kind.BURN, "amount": 3}] as Array[Dictionary]
		),
		"3 Burn",
		"a status effect names the status"
	)
	eq(
		CardView.effect_summary([{"kind": CardData.DRAW, "amount": 2}] as Array[Dictionary]),
		"Draw 2",
		"draw reads as Draw N"
	)
	eq(
		CardView.effect_summary(
			[
				{"kind": CardData.DAMAGE, "amount": 12},
				{"kind": CardData.SELF_DAMAGE, "amount": 3},
			] as Array[Dictionary]
		),
		"12 damage, lose 3 hp",
		"multiple effects join into one line, in card order"
	)
	eq(
		CardView.effect_summary(
			[{"kind": CardData.BONUS_IF_CHILLED, "amount": 4}] as Array[Dictionary]
		),
		"+4 if chilled",
		"a conditional bonus says its condition"
	)

	# A CardView reports the card it was given and its XP progress.
	var view := CardView.new()
	var card := _card("Spark")
	view.setup(card)
	eq(view.card, card, "view holds its card")
	check(view.get_child_count() > 0, "view built its children")
	view.set_playable(false)
	eq(view.modulate.a < 1.0, true, "unplayable cards are dimmed")
	view.set_playable(true)
	almost(view.modulate.a, 1.0, "playable cards are opaque")

	# The card itself takes taps; its illustration/rim/label chrome must not, or the
	# chrome on top silently eats the drag/tap the card depends on.
	eq(view.mouse_filter, Control.MOUSE_FILTER_STOP, "the card itself takes taps")
	for child in view.get_children():
		var chrome: Control = child
		eq(chrome.mouse_filter, Control.MOUSE_FILTER_IGNORE, "card chrome ignores the mouse")

	# Containers must not swallow taps.
	var fan := HandFan.new()
	fan.set_hand([_card("a"), _card("b")])
	eq(fan.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the fan itself ignores the mouse")
	eq(fan.get_child_count(), 2, "one view per card")

	var box := UIKit.transparent(VBoxContainer.new())
	eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UIKit containers ignore the mouse")

	var tap := UIKit.button("Tap")
	eq(tap.mouse_filter, Control.MOUSE_FILTER_STOP, "buttons stop it")
	# 48dp thumb targets at 1080 wide.
	check(tap.custom_minimum_size.y >= 96.0, "buttons are thumb-sized")

	view.free()
	fan.free()
	box.free()
	tap.free()
