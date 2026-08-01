extends TestCase

## The hand REUSES a card's view across refreshes instead of rebuilding all of them.
##
## HandFan used to free every CardView and construct a fresh set on every refresh —
## which runs after each card played and each End Turn. Besides the churn, it left
## nothing to animate: a card had no continuous identity, so it could only blink in
## and out. These assertions are what stop that regressing, and they check object
## identity rather than child counts, because a rebuild-everything implementation
## passes every count-based check identically.


func suite_name() -> String:
	return "handfan_reuse"


func _data(name: String) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = Schools.School.CINDER
	d.cost = 1
	d.effects = [{"kind": CardData.DAMAGE, "amount": 5}] as Array[Dictionary]
	return d


func _card(name: String) -> CardInstance:
	return CardInstance.new(_data(name))


func _names(view: CardView) -> Array:
	var out: Array = []
	for child in view.find_children("*", "Label", true, false):
		out.append(child.text)
	return out


func run() -> void:
	var fan := HandFan.new()
	var a := _card("Alpha")
	var b := _card("Beta")
	var c := _card("Gamma")

	fan.set_hand([a, b, c])
	eq(fan.get_child_count(), 3, "one view per card")
	var view_a: CardView = fan.view_for(a)
	var view_c: CardView = fan.view_for(c)
	check(view_a != null and view_c != null, "every card has a view")
	var id_a := view_a.get_instance_id()
	var id_c := view_c.get_instance_id()

	# Beta is played. The other two must be the SAME objects, not equal-looking
	# replacements — that is the whole point of the change.
	fan.set_hand([a, c])
	eq(fan.get_child_count(), 2, "the played card's view is gone immediately")
	eq(fan.view_for(b), null, "the played card no longer has a view")
	eq(fan.view_for(a).get_instance_id(), id_a, "the kept card kept its view object")
	eq(fan.view_for(c).get_instance_id(), id_c, "the other kept card kept its view too")

	# A draw adds one view without disturbing the survivors.
	var d := _card("Delta")
	fan.set_hand([a, c, d])
	eq(fan.get_child_count(), 3, "the drawn card got a view")
	eq(fan.view_for(a).get_instance_id(), id_a, "drawing does not rebuild the held cards")

	# Children must sit in hand order. Reusing views means insertion order stops
	# matching the hand on its own, and fan_transform indexes by child position — so
	# without the reorder the cards would fan in the wrong places.
	fan.set_hand([d, a, c])
	var ordered: Array = []
	for child in fan.get_children():
		ordered.append((child as CardView).card)
	eq(ordered, [d, a, c], "children follow the hand's order")

	# A reused view has to notice its card EVOLVING underneath it. The instance keeps
	# its identity while swapping CardData, so a view that only checks identity would
	# happily keep showing the old face for the rest of the battle.
	var base := _data("Sprout")
	var grown := _data("Bloom")
	base.evolved_card = grown
	base.xp_to_evolve = 1
	var evolving := CardInstance.new(base)

	var evo_fan := HandFan.new()
	evo_fan.set_hand([evolving])
	var evo_view: CardView = evo_fan.view_for(evolving)
	check(_names(evo_view).has("Sprout"), "the view starts on the base card")

	eq(evolving.gain_xp(1), true, "the card evolved")
	evo_fan.set_hand([evolving])
	eq(evo_fan.view_for(evolving).get_instance_id(), evo_view.get_instance_id(),
		"evolving does not throw the view away")
	check(_names(evo_fan.view_for(evolving)).has("Bloom"), "the reused view redrew the new face")
	check(
		not _names(evo_fan.view_for(evolving)).has("Sprout"),
		"and the old face is gone rather than layered underneath"
	)

	evo_fan.free()
	fan.free()
