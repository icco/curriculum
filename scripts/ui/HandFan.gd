class_name HandFan
extends Control

## The curved hand. The layout maths is a static function so it can be tested without
## instantiating a scene.

signal card_play_requested(card)
signal card_inspect_requested(card)

## Tuned so five cards in a hand never overlap enough to clip each other's name —
## the fanned/tilted bounding box of each card, not just its flat width, has to clear
## its neighbour (see the half-extent maths below). At the old 200x300 / 0.22 rad,
## adjacent outer cards overlapped by ~40px and their names read as fragments.
const MAX_SPREAD := 440.0
const MAX_TILT := 0.14  # radians at the outermost card
const ARC_DROP := 40.0  # how far the outer cards hang below the middle
## How far below its slot a newly drawn card starts, so it is dealt in rather than
## appearing. Small: this is a readability cue, not a flourish.
const DEAL_IN_DROP := 90.0


## Where card `index` of `count` sits across a screen `width` wide.
static func fan_transform(index: int, count: int, width: float) -> Dictionary:
	if count <= 1:
		return {"position": Vector2(width * 0.5, 0.0), "rotation": 0.0}

	# -1 at the far left, +1 at the far right.
	var t := (float(index) / float(count - 1)) * 2.0 - 1.0

	# The outermost cards are rotated by MAX_TILT about their own centre, so their
	# axis-aligned bounding box reaches further outward than CARD_SIZE.x / 2 alone
	# would suggest -- clamping the centre to just [0, width] left the last sliver of
	# a tilted card hanging off the edge of the screen. Half-extent of a w x h
	# rectangle rotated by `angle` is (w * cos(angle) + h * sin(angle)) / 2.
	var half_extent := (
		(CardView.CARD_SIZE.x * cos(MAX_TILT) + CardView.CARD_SIZE.y * sin(MAX_TILT)) * 0.5
	)
	# Narrow the spread as the hand grows so it never leaves the screen.
	var spread := minf(minf(MAX_SPREAD, width * 0.42), maxf(0.0, width * 0.5 - half_extent))
	var x := width * 0.5 + t * spread
	var y := absf(t) * ARC_DROP
	return {
		"position": Vector2(clampf(x, half_extent, width - half_extent), y),
		"rotation": t * MAX_TILT,
	}


## CardInstance -> CardView, so a refresh can REUSE the view a card already has.
##
## This used to free every view and build a fresh set on each refresh, which runs
## after every card played and every End Turn. Two costs: it re-ran ArtLibrary lookups
## and built five or six nodes per card on every tap, and — the reason it mattered —
## it left nothing to animate. A card that should slide to the discard simply blinked
## out of existence, so the battle had no motion or feedback of any kind. With no
## examiner telegraph, the fight is already short on information; it cannot also be
## short on feedback.
var _views := {}


func _init() -> void:
	# The fan itself must not eat taps; only the CardViews inside it do.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# set_hand() runs before the parent container has sorted its children, so the first
	# layout() sees size.x == 0 and falls back to the full 1080. Re-fanning on resize is
	# what makes the fan honour the width it is actually given -- without it, the cards
	# stay spread for a screen wider than the one they are on and hang over the gutter.
	resized.connect(layout)


func set_hand(cards: Array) -> void:
	# Drop the views for cards that have left the hand. remove_child is NOT redundant
	# with queue_free: queue_free is deferred to the end of the frame, so without the
	# explicit removal this control keeps reporting played cards as children for the
	# rest of the tick — and layout(), get_child_count() and the order the fan indexes
	# by all read that immediately.
	for card in _views.keys():
		if cards.has(card):
			continue
		var stale: CardView = _views[card]
		_views.erase(card)
		if is_instance_valid(stale):
			remove_child(stale)
			stale.queue_free()

	# Reuse what is still held; build only what is genuinely new.
	var dealt := {}
	for card in cards:
		var view: CardView = _views.get(card)
		if view == null:
			view = CardView.new()
			view.setup(card)
			view.play_requested.connect(func(c): card_play_requested.emit(c))
			view.inspect_requested.connect(func(c): card_inspect_requested.emit(c))
			add_child(view)
			_views[card] = view
			dealt[view] = true
		else:
			view.sync()

	# Children have to sit in hand order: fan_transform indexes by child position, and
	# reusing views means insertion order no longer matches the hand on its own.
	for i in cards.size():
		move_child(_views[cards[i]], i)

	layout(dealt)


## fan_transform's y is 0 at the middle card and grows toward the edges (see
## ARC_DROP), so the middle card's centre sits at the very top of local (0,0) — its
## top edge is CARD_SIZE.y / 2 ABOVE that origin. Left uncorrected, the middle of the
## hand renders outside HandFan's own rect and bleeds into whatever is laid out above
## it (this is what made the block/mana row look corrupted once the dead gap above
## the hand was closed up). Shifting every card down by half the card height, plus a
## little for the rotated corners of the outer cards, keeps the whole fan inside the
## control it belongs to.
func _vertical_offset() -> float:
	return CardView.CARD_SIZE.y * 0.5 + 12.0


## `dealt` holds the views created by this refresh. They are placed below their slot
## and slid up, because a card being dealt has no previous position worth travelling
## from; everything else slides from wherever it already was.
func layout(dealt: Dictionary = {}) -> void:
	var width := size.x if size.x > 0.0 else 1080.0
	var views := get_children()
	var y_offset := _vertical_offset()
	for i in views.size():
		var view: CardView = views[i]
		var t := fan_transform(i, views.size(), width)
		var centre: Vector2 = t["position"] + Vector2(0, y_offset)
		var target: Vector2 = centre - CardView.CARD_SIZE * 0.5
		var target_rotation: float = t["rotation"]
		if dealt.has(view):
			view.position = target + Vector2(0.0, DEAL_IN_DROP)
			view.rotation = target_rotation
		view.settle_at(target, target_rotation, true)


func set_playable(predicate: Callable) -> void:
	for child in get_children():
		var view: CardView = child
		view.set_playable(predicate.call(view.card))


## Which CardView a card is currently drawn by, or null. Exists so a caller can find a
## specific card's view without reaching through get_children() and matching by hand.
func view_for(card) -> CardView:
	var view = _views.get(card)
	return view if is_instance_valid(view) else null
