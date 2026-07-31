class_name HandFan
extends Control

## The curved hand. The layout maths is a static function so it can be tested without
## instantiating a scene.

signal card_play_requested(card)
signal card_inspect_requested(card)

const MAX_SPREAD := 420.0
const MAX_TILT := 0.22  # radians at the outermost card
const ARC_DROP := 46.0  # how far the outer cards hang below the middle


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


func _init() -> void:
	# The fan itself must not eat taps; only the CardViews inside it do.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hand(cards: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for card in cards:
		var view := CardView.new()
		view.setup(card)
		view.play_requested.connect(func(c): card_play_requested.emit(c))
		view.inspect_requested.connect(func(c): card_inspect_requested.emit(c))
		add_child(view)
	layout()


func layout() -> void:
	var width := size.x if size.x > 0.0 else 1080.0
	var views := get_children()
	for i in views.size():
		var view: CardView = views[i]
		var t := fan_transform(i, views.size(), width)
		view.position = t["position"] - CardView.CARD_SIZE * 0.5
		view.rotation = t["rotation"]
		view.remember_home()


func set_playable(predicate: Callable) -> void:
	for child in get_children():
		var view: CardView = child
		view.set_playable(predicate.call(view.card))
