class_name UIKit
extends RefCounted

## Shared widget constructors, so screens read as declarations. Also the single place
## the mouse-filter rule is applied.

const TAP_MIN := 96.0  # 48dp at portrait 2x


static func label(text: String, size := 32) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(TAP_MIN * 2.0, TAP_MIN)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


## Containers must never intercept taps meant for the board beneath them.
static func transparent(container: Control) -> Control:
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


static func spacer() -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## The single source for a status's display name, so CardView (effect text on a
## card) and BattleScreen (log lines, status readouts) can't drift into calling the
## same status by two different names.
static func status_name(kind) -> String:
	match int(kind):
		Statuses.Kind.BURN:
			return "Burn"
		Statuses.Kind.CHILL:
			return "Chill"
		Statuses.Kind.BLOT:
			return "Blot"
		Statuses.Kind.DECAY:
			return "Decay"
	return "?"
