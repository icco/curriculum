extends TestCase

## ReportCard and RegistrationScreen: the post-battle grade breakdown and the deck-cap
## decision. The report must show all four terms (not just the letter), because
## Learning and Discovery are why the grade isn't pure speed. Registration must show
## every card's XP progress and must refuse any selection that is not exactly the
## cap — silently swapping or truncating would corrupt the run deck.


func suite_name() -> String:
	return "registration"


func _data(name: String) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = Schools.School.CINDER
	d.effects = [{"kind": CardData.DAMAGE, "amount": 6}] as Array[Dictionary]
	d.art_id = "cards/spark"
	# Give every fixture an evolve target so gain_xp() actually banks XP instead of
	# being a no-op on an already-terminal card — otherwise progress() always reports
	# "mastered" and the XP-visibility assertions below could never go red.
	d.evolved_card = CardData.new()
	d.evolved_card.card_name = name + " (evolved)"
	return d


func _card(name: String) -> CardInstance:
	return CardInstance.new(_data(name))


func _labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	for child in root.find_children("*", "Label", true, false):
		out.append(child)
	return out


func _test_report_card() -> void:
	var report := ReportCard.new()
	var course := CourseData.new()
	course.course_name = "Basic Arcana 101"
	var scored := Grading.score({
		"won": true, "turns_taken": 5, "par_turns": 5, "hp_end": 60, "hp_start": 60,
		"xp_banked": 15, "xp_par": 15, "weakness_known": true, "distinct_schools": 5,
	})
	eq(scored["grade"], Grading.Grade.S, "this fixture scores an S")

	report.show_result(scored, {"strike": false, "strikes": 0, "expelled": false}, course)

	var labels := _labels(report)
	var texts: Array[String] = []
	for label in labels:
		texts.append(label.text)
	var report_text := " ".join(texts)

	# Control nodes eat taps: every container must ignore the mouse, or a full-rect
	# child silently swallows the Continue button's tap.
	eq(report.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the report card ignores the mouse")
	for box in report.find_children("*", "VBoxContainer", true, false):
		eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the report's rows ignore the mouse")
	for label in labels:
		eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "labels never eat taps")

	# The letter must be its own label with the exact text, not merely a substring
	# match — "Survival" itself contains a capital S, so a naive `contains("S")`
	# check can never go red even if the letter is never rendered at all.
	var exact_letter_hits := 0
	for text in texts:
		if text == Grading.letter(scored["grade"]):
			exact_letter_hits += 1
	check(exact_letter_hits >= 1, "some label is exactly the letter grade, not a substring hit")

	for term in ["Efficiency", "Survival", "Learning", "Discovery"]:
		check(report_text.contains(term), "showed the %s term" % term)

	# All four terms are broken out at 25 points apiece for this fixture, not folded
	# into the total alone.
	check(report_text.contains("25 / 25"), "a perfect term shows its score out of 25")
	check(report_text.contains("100 / 100"), "the total is shown out of 100")

	report.free()


func _test_report_card_strike() -> void:
	# A failing result surfaces the probation strike and the HP restore, on top of
	# the four terms — the report still has to explain what happened.
	var report := ReportCard.new()
	var course := CourseData.new()
	course.course_name = "Failed Course"
	var scored := Grading.score({"won": false})
	eq(scored["grade"], Grading.Grade.F, "a loss always grades F")
	report.show_result(scored, {"strike": true, "strikes": 1, "expelled": false}, course)
	var report_text := " ".join(_labels(report).map(func(l): return l.text))
	check(
		report_text.contains("strike 1 of %d" % Run.MAX_STRIKES),
		"shows the exact strike count and ceiling"
	)
	check(report_text.contains("restored"), "explains that hp was restored, not just lost")
	report.free()


func _own(n: int) -> Array:
	var out := []
	for i in n:
		out.append(_card("own%d" % i))
	return out


func _pool(n: int) -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		out.append(_data("theirs%d" % i))
	return out


func _build_registration() -> Dictionary:
	var own := _own(10)
	own[0].gain_xp()  # trains one card to 1/5, so entries are not all identical text
	var syllabus := _data("syllabus")
	var draft := Draft.new(own, _pool(4), syllabus, Grading.Grade.S)
	draft.cap = 11
	var registration := RegistrationScreen.new()
	registration.size = Vector2(1080, 1920)
	registration.begin(draft)
	return {"draft": draft, "registration": registration}


func _test_toggle_and_cap() -> void:
	var built := _build_registration()
	var draft: Draft = built["draft"]
	var registration: RegistrationScreen = built["registration"]

	eq(registration.selected.size(), 0, "nothing chosen yet")
	eq(registration.can_confirm(), false, "cannot confirm an empty selection")

	for card in draft.own:
		registration.toggle(card)
	eq(registration.selected.size(), 10, "chose ten")
	eq(registration.can_confirm(), false, "ten is not the cap of eleven")

	registration.toggle(draft.offered[0])
	eq(registration.selected.size(), 11, "chose eleven")
	eq(registration.can_confirm(), true, "eleven meets the cap")

	# Selecting an twelfth card past the cap must be refused outright, not accepted by
	# silently evicting one of the existing eleven to make room. Capture the selection
	# by identity before the attempt so an eviction (same size, different membership)
	# is caught, not just a size change.
	var before := registration.selected.duplicate()
	registration.toggle(draft.offered[1])
	eq(registration.selected.size(), 11, "still eleven after trying to add a twelfth")
	check(not registration.selected.has(draft.offered[1]), "the refused card was not added")
	check(registration.selected == before, "no existing pick was silently evicted to make room")

	registration.toggle(draft.offered[0])
	eq(registration.selected.size(), 10, "toggling removes")
	eq(registration.can_confirm(), false, "back below the cap")

	registration.free()


func _entry_texts(registration: RegistrationScreen) -> Array[String]:
	var out: Array[String] = []
	for button in registration.find_children("*", "Button", true, false):
		if button.has_meta("card"):
			out.append(button.text)
	return out


func _test_xp_shown_on_every_card() -> void:
	var built := _build_registration()
	var draft: Draft = built["draft"]
	var registration: RegistrationScreen = built["registration"]

	var texts := _entry_texts(registration)
	eq(texts.size(), draft.own.size() + draft.offered.size(), "one entry per card")

	var all_cards: Array = []
	all_cards.append_array(draft.own)
	all_cards.append_array(draft.offered)

	var saw_progress: Array[String] = []
	for card in all_cards:
		var progress: String = card.progress()
		var found := false
		for text in texts:
			if text.contains(card.data.card_name) and text.contains(progress):
				found = true
				break
		check(found, "%s shows its XP progress (%s)" % [card.data.card_name, progress])
		saw_progress.append(progress)

	# Confirm this isn't a coincidence where every card happens to show the same
	# string: the trained card's progress differs from an untrained one's.
	check(saw_progress.has("1/5"), "the trained card shows its actual progress, not 0/5 for everyone")
	check(saw_progress.has("0/5"), "an untrained card still shows 0/5")

	registration.free()


func _find_button_named(root: Node, label: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == label:
			return button
	return null


func _test_confirm_emits_kept_deck() -> void:
	var built := _build_registration()
	var draft: Draft = built["draft"]
	var registration: RegistrationScreen = built["registration"]

	for card in draft.own:
		registration.toggle(card)
	registration.toggle(draft.offered[0])
	eq(registration.can_confirm(), true, "eleven meets the cap before confirming")

	var received: Array = []
	registration.registration_complete.connect(func(kept): received.append(kept))

	var confirm := _find_button_named(registration, "Confirm")
	check(confirm != null, "found the confirm button")
	confirm.pressed.emit()

	eq(received.size(), 1, "confirming a legal selection emits registration_complete once")
	eq(received[0].size(), 11, "the emitted deck is exactly the cap")

	registration.free()


func _test_refuses_illegal_selection_and_keeps_screen_up() -> void:
	# Draft.keep() refuses a same-size selection that repeats one instance instead of
	# drawing eleven distinct cards. Registration must not lose the deck when that
	# happens — it must leave the screen up rather than emit a broken result.
	var built := _build_registration()
	var draft: Draft = built["draft"]
	var registration: RegistrationScreen = built["registration"]

	var illegal: Array = []
	for i in draft.cap:
		illegal.append(draft.own[0])  # the same instance, cap times over
	registration.selected = illegal
	eq(registration.can_confirm(), true, "can_confirm only checks size, not legality")

	var received: Array = []
	registration.registration_complete.connect(func(kept): received.append(kept))

	var confirm := _find_button_named(registration, "Confirm")
	confirm.pressed.emit()

	eq(received.size(), 0, "an illegal selection never emits registration_complete")
	eq(registration.selected.size(), draft.cap, "the screen's selection state is untouched, not cleared")

	registration.free()


func _test_mouse_filters() -> void:
	var built := _build_registration()
	var registration: RegistrationScreen = built["registration"]

	eq(registration.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the screen itself ignores the mouse")
	for box in registration.find_children("*", "VBoxContainer", true, false):
		eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "layout containers ignore the mouse")
	for margin in registration.find_children("*", "MarginContainer", true, false):
		eq(margin.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the outer margin ignores the mouse")
	for grid in registration.find_children("*", "GridContainer", true, false):
		eq(grid.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the card grid ignores the mouse")
	# The "NEW" ownership badge sits on top of an offered card's tap target as a child
	# Control, not beside it -- if it (or its label) ever took the mouse, it would
	# silently eat the tap instead of letting it fall through to the button beneath.
	for badge in registration.find_children("*", "PanelContainer", true, false):
		eq(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the NEW badge ignores the mouse")
	for label in registration.find_children("*", "Label", true, false):
		eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "labels never eat taps")
	for button in registration.find_children("*", "Button", true, false):
		eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, "buttons take taps")
		check(button.custom_minimum_size.y >= UIKit.TAP_MIN, "buttons are thumb-sized")
	# The one deliberate exception: a ScrollContainer that ignores the mouse cannot
	# scroll at all. It IS the tap target here, not a layout wrapper over one.
	for scroll in registration.find_children("*", "ScrollContainer", true, false):
		eq(scroll.mouse_filter, Control.MOUSE_FILTER_STOP, "the scroll container takes scroll input by design")

	registration.free()


func run() -> void:
	_test_report_card()
	_test_report_card_strike()
	_test_toggle_and_cap()
	_test_xp_shown_on_every_card()
	_test_confirm_emits_kept_deck()
	_test_refuses_illegal_selection_and_keeps_screen_up()
	_test_mouse_filters()
