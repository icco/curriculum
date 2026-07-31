extends TestCase

## Burn decays, Decay grows. That asymmetry is the whole identity of the two
## damage-over-time schools, so it is pinned here.


func suite_name() -> String:
	return "statuses"


func run() -> void:
	var s := Statuses.new()
	eq(s.amount(Statuses.Kind.BURN), 0, "starts empty")

	# Burn: ticks at the start of the turn, then decrements.
	s.add(Statuses.Kind.BURN, 3)
	eq(s.tick_start_of_turn(), 3, "burn deals its value")
	eq(s.amount(Statuses.Kind.BURN), 2, "burn decremented")
	eq(s.tick_start_of_turn(), 2, "burn deals less")
	eq(s.tick_start_of_turn(), 1, "burn deals one")
	eq(s.tick_start_of_turn(), 0, "burn is spent")
	eq(s.amount(Statuses.Kind.BURN), 0, "burn cannot go negative")

	# Decay: ticks at the end of the turn, then GROWS by two.
	var d := Statuses.new()
	d.add(Statuses.Kind.DECAY, 4)
	eq(d.tick_end_of_turn(), 4, "decay deals its value")
	eq(d.amount(Statuses.Kind.DECAY), 6, "decay grew by two")
	eq(d.tick_end_of_turn(), 6, "decay deals more")
	eq(d.amount(Statuses.Kind.DECAY), 8, "decay grew again")

	# Doubling is what Feed the Curriculum does.
	d.double_decay()
	eq(d.amount(Statuses.Kind.DECAY), 16, "decay doubled")

	# Decay with no stacks does nothing and does not start growing from zero.
	var empty := Statuses.new()
	eq(empty.tick_end_of_turn(), 0, "no decay, no damage")
	eq(empty.amount(Statuses.Kind.DECAY), 0, "decay stays at zero")

	# Chill and Blot are consumed whole by the next card, not ticked.
	var c := Statuses.new()
	c.add(Statuses.Kind.CHILL, 2)
	eq(c.consume(Statuses.Kind.CHILL), 2, "consume returns the stack")
	eq(c.amount(Statuses.Kind.CHILL), 0, "consume zeroes it")
	eq(c.consume(Statuses.Kind.CHILL), 0, "consuming nothing is zero")
	eq(c.tick_start_of_turn(), 0, "chill is not burn")

	# Stacks accumulate.
	var stack := Statuses.new()
	stack.add(Statuses.Kind.BLOT, 1)
	stack.add(Statuses.Kind.BLOT, 2)
	eq(stack.amount(Statuses.Kind.BLOT), 3, "blot stacks")

	# Round-trips for the save file with all four statuses.
	var all := Statuses.new()
	all.add(Statuses.Kind.BURN, 5)
	all.add(Statuses.Kind.CHILL, 3)
	all.add(Statuses.Kind.BLOT, 7)
	all.add(Statuses.Kind.DECAY, 11)
	var round := Statuses.from_dict(all.to_dict())
	eq(round.amount(Statuses.Kind.BURN), 5, "burn survives round trip")
	eq(round.amount(Statuses.Kind.CHILL), 3, "chill survives round trip")
	eq(round.amount(Statuses.Kind.BLOT), 7, "blot survives round trip")
	eq(round.amount(Statuses.Kind.DECAY), 11, "decay survives round trip")

	# add() clamps to zero and does not go negative.
	var clamp := Statuses.new()
	clamp.add(Statuses.Kind.BURN, -5)
	eq(clamp.amount(Statuses.Kind.BURN), 0, "negative add on empty clamps to zero")
	clamp.add(Statuses.Kind.BURN, 10)
	clamp.add(Statuses.Kind.BURN, -3)
	eq(clamp.amount(Statuses.Kind.BURN), 7, "negative add reduces but does not go below zero")
