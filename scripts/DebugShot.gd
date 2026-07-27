class_name DebugShot
extends Node

## Development harness: lets the game be driven from the command line so a
## screenshot can be taken without a human at the keyboard.
##
##   LOOPWOOD_SEED=42 LOOPWOOD_SHOT=/tmp/a.png LOOPWOOD_SHOT_AFTER=1.5 \
##       godot --path . scenes/Main.tscn
##
## LOOPWOOD_SCRIPT names a comma separated list of actions run before the
## screenshot, e.g. "wait:0.5,tap_cell:12:9,confirm,end_turn".

signal action_requested(action: String, args: Array)

var shot_path: String = ""
var shot_after: float = 1.2
var quit_after_shot: bool = true
## Optional Callable returning true while the game is animating, so captures
## land on a settled frame instead of mid-tween.
var busy_probe: Callable = Callable()
var _script_steps: Array = []

func _ready() -> void:
	shot_path = OS.get_environment("LOOPWOOD_SHOT")
	var after := OS.get_environment("LOOPWOOD_SHOT_AFTER")
	if after != "":
		shot_after = float(after)
	var steps := OS.get_environment("LOOPWOOD_SCRIPT")
	if steps != "":
		_script_steps = steps.split(",", false)
	if shot_path == "" and _script_steps.is_empty():
		set_process(false)
		return
	_run.call_deferred()

static func seed_from_env() -> int:
	var s := OS.get_environment("LOOPWOOD_SEED")
	if s == "":
		return Dice.randomize_seed()
	Dice.seed_with(int(s))
	return int(s)

func _run() -> void:
	for step: String in _script_steps:
		var parts: PackedStringArray = step.split(":")
		var action: String = parts[0].strip_edges()
		var args: Array = []
		for i in range(1, parts.size()):
			args.append(parts[i])
		if action == "wait":
			await get_tree().create_timer(float(args[0])).timeout
			continue
		action_requested.emit(action, args)
		await _settle()
	if shot_path == "":
		return
	await get_tree().create_timer(shot_after).timeout
	await _settle()
	await capture(shot_path)
	if quit_after_shot:
		get_tree().quit(0)

## Waits out any running animation so scripted steps and captures are stable.
func _settle(timeout: float = 12.0) -> void:
	await get_tree().process_frame
	var waited := 0.0
	while busy_probe.is_valid() and bool(busy_probe.call()) and waited < timeout:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05

func capture(path: String) -> void:
	# A frame must actually be drawn before the backbuffer holds anything.
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		push_error("screenshot failed: %d" % err)
	else:
		print("[shot] ", path, " ", image.get_size())
