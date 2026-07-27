extends SceneTree

## Writes the input actions into project.godot. Keyboard shortcuts mirror the
## touch action bar so the game can be driven without a mouse.
##   godot --headless --path . --script tools/generate_input_map.gd

const ACTIONS := {
	"turn_end": [KEY_SPACE, KEY_ENTER],
	"action_confirm": [KEY_ENTER, KEY_KP_ENTER],
	"action_cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"action_dash": [KEY_D],
	"action_loot": [KEY_F],
	"action_door": [KEY_G],
	"action_descend": [KEY_PERIOD],
	"panel_spells": [KEY_Q],
	"panel_items": [KEY_E],
	"camera_zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"camera_zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
}

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	for action: String in ACTIONS:
		var events: Array = []
		for code: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			events.append(event)
		ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("wrote %d input actions (err %d)" % [ACTIONS.size(), err])
	quit(0 if err == OK else 1)
	return true
