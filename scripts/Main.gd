extends Node2D

## Presentation and input. All rules live in FloorSession/GameState; this node
## turns taps into action calls and replays the returned events as animation.

enum Mode { FREE, PREVIEW, AIMING }

const AUTO_SAVE := true

var state: GameState
var session: FloorSession
var board: BoardView
var camera: CameraRig
var hud: HUD
var screens: LoopScreen
var debug_shot: DebugShot

var mode: int = Mode.FREE
var busy: bool = false
var pending: Dictionary = {}     ## staged action awaiting a confirming tap
var aiming_spell: String = ""

func _ready() -> void:
	Roster.load_data()
	DebugShot.seed_from_env()

	state = GameState.new()
	# LOOPWOOD_FRESH=1 discards the save so scripted runs are reproducible.
	if OS.get_environment("LOOPWOOD_FRESH") != "":
		GameState.wipe()
	elif AUTO_SAVE:
		state.load_from()

	board = BoardView.new()
	board.name = "Board"
	add_child(board)

	camera = CameraRig.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	camera.tapped.connect(_on_tapped)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.action_pressed.connect(_on_action)
	hud.spell_chosen.connect(_on_spell_chosen)
	hud.item_chosen.connect(_on_item_chosen)
	hud.confirm_pressed.connect(_commit_pending)
	hud.cancel_pressed.connect(_clear_pending)

	screens = LoopScreen.new()
	screens.name = "Screens"
	add_child(screens)
	screens.continue_pressed.connect(_start_new_loop)

	debug_shot = get_node_or_null("DebugShot")
	if debug_shot != null:
		debug_shot.action_requested.connect(_on_debug_action)
		debug_shot.busy_probe = is_busy

	_start_session(state.current_depth())

func is_busy() -> bool:
	return busy

# ------------------------------------------------------------------ session

func _start_session(depth: int) -> void:
	session = FloorSession.new(state)
	var events := session.build(depth)
	board.build(session.map)
	for e: Entity in session.entities:
		board.add_entity(e)
	board.refresh_visibility(true)
	camera.set_bounds(board.board_bounds())
	camera.focus_on(board.grid_to_world(session.player.grid_pos), true)
	hud.clear_log()
	_replay(events)
	_refresh_ui()
	_advance_until_player()

func _refresh_ui() -> void:
	if session == null:
		return
	hud.set_status(state.month_name(), session.depth, state.player_level(),
		int(state.global["loops"]), int(state.global["skill_points"]))
	hud.set_vitals(session.player, session.moves_left())
	var player_turn := session.is_player_turn() and not busy
	for action: String in ["spells", "items", "dash", "loot", "door", "descend", "end_turn"]:
		hud.set_action_enabled(action, player_turn)
	if player_turn:
		hud.set_action_enabled("dash", session.has_action())
		hud.set_action_enabled("loot", session.has_action() and session.adjacent_container() != Vector2i(-1, -1))
		hud.set_action_enabled("door", session.adjacent_door() != Vector2i(-1, -1))
		hud.set_action_enabled("descend", session.on_stairs())
	_refresh_highlights()

func _refresh_highlights() -> void:
	board.clear_highlights()
	if session == null or not session.is_player_turn() or busy:
		return
	if mode == Mode.AIMING:
		var spell := Roster.spell(aiming_spell)
		var cells: Array = []
		for e: Entity in session.visible_enemies():
			if MapData.chebyshev(session.player.grid_pos, e.grid_pos) <= int(spell.get("range", 1)):
				cells.append(e.grid_pos)
		board.set_targets(cells)
		return
	var reach: Dictionary = session.reachable_cells()["cost"]
	var cells: Array = reach.keys()
	cells.erase(session.player.grid_pos)
	board.set_move_range(cells)
	board.set_targets(session.attackable_cells())

# -------------------------------------------------------------------- input

func _on_tapped(world_pos: Vector2) -> void:
	if busy or session == null or session.is_over() or screens.is_open():
		return
	if not session.is_player_turn():
		hud.set_hint("Not your turn.")
		return
	var cell := board.world_to_grid(world_pos)
	if not session.map.in_bounds(cell):
		return
	hud.close_panels()

	# Second tap on the same tile commits, per the confirm-before-commit rule.
	if not pending.is_empty() and pending.get("cell") == cell:
		_commit_pending()
		return

	if mode == Mode.AIMING:
		_stage_spell(cell)
		return
	var target := session.entity_at(cell)
	if target != null and target.is_hostile_to(session.player) and session.map.is_visible(cell):
		_stage_attack(target)
		return
	if _stage_interaction(cell):
		return
	_stage_move(cell)

## Tapping an adjacent locker or door stages opening it. Returns true if the
## tile is interactive.
func _stage_interaction(cell: Vector2i) -> bool:
	var adjacent := MapData.chebyshev(cell, session.player.grid_pos) <= 1
	if not adjacent:
		return false
	var container: Dictionary = session.map.containers.get(cell, {})
	if not container.is_empty() and not bool(container.get("looted", false)):
		if not session.has_action():
			hud.set_hint("No action left to search that locker.")
			return true
		pending = {"kind": "loot", "cell": cell}
		mode = Mode.PREVIEW
		board.set_cursor(cell)
		hud.show_confirm("Search")
		hud.set_hint("Search the locker. Tap again or Confirm.")
		return true
	if session.map.doors.has(cell):
		pending = {"kind": "door", "cell": cell}
		mode = Mode.PREVIEW
		board.set_cursor(cell)
		var open: bool = session.map.is_door_open(cell)
		hud.show_confirm("Close" if open else "Open")
		hud.set_hint("%s the door. Tap again or Confirm." % ("Close" if open else "Open"))
		return true
	return false

func _stage_move(cell: Vector2i) -> void:
	var reach := session.reachable_cells()
	if not (reach["cost"] as Dictionary).has(cell) or cell == session.player.grid_pos:
		_clear_pending()
		hud.set_hint("Out of movement range.")
		return
	var path := MapData.reconstruct_path(reach["came_from"], cell)
	pending = {"kind": "move", "cell": cell, "path": path}
	mode = Mode.PREVIEW
	board.set_path(path)
	board.set_cursor(cell)
	board.set_threat(_threatened_cells(path))
	hud.show_confirm("Move %d" % (path.size() - 1))
	hud.set_hint("Tap again or Confirm to move %d tiles." % (path.size() - 1))

func _stage_attack(target: Entity) -> void:
	pending = {"kind": "attack", "cell": target.grid_pos, "target": target}
	mode = Mode.PREVIEW
	board.set_targets([target.grid_pos])
	board.set_cursor(target.grid_pos)
	var shield := Combat.defended_ac(target, session.player.grid_pos, session.map)
	var cover_note := ""
	if int(shield["cover"]) != MapData.Cover.NONE:
		cover_note = " behind %s" % MapData.cover_name(shield["cover"])
	if not Combat.can_attack(session.player, target, session.map):
		hud.set_hint("%s is out of reach%s." % [target.display_name, cover_note])
		hud.hide_confirm()
		return
	hud.show_confirm("Attack")
	hud.set_hint("%s — AC %d%s. Tap again or Confirm." % [
		target.display_name, int(shield["ac"]), cover_note])

func _stage_spell(cell: Vector2i) -> void:
	var spell := Roster.spell(aiming_spell)
	pending = {"kind": "spell", "cell": cell, "spell_id": aiming_spell}
	board.set_cursor(cell)
	var affected: Array = [cell]
	var aoe := int(spell.get("aoe", 0))
	if aoe > 0:
		affected = []
		for y in range(cell.y - aoe, cell.y + aoe + 1):
			for x in range(cell.x - aoe, cell.x + aoe + 1):
				var c := Vector2i(x, y)
				if session.map.in_bounds(c) and session.map.has_line_of_sight(cell, c):
					affected.append(c)
	board.set_targets(affected)
	hud.show_confirm("Cast")
	var occupant := session.entity_at(cell)
	var where: String = occupant.display_name if occupant != null else "that tile"
	if aoe > 0:
		where += " and everything within %d tiles" % aoe
	hud.set_hint("%s on %s. Tap again or Confirm." % [str(spell.get("name", "Spell")), where])

## Tiles on the path where an enemy could take a swing as you leave.
func _threatened_cells(path: Array) -> Array:
	var out: Array = []
	for e: Entity in session.entities:
		if not e.is_alive() or not e.is_hostile_to(session.player):
			continue
		if not session.map.is_visible(e.grid_pos):
			continue
		for cell: Vector2i in path:
			if MapData.chebyshev(cell, e.grid_pos) <= 1 and not out.has(cell):
				out.append(cell)
	return out

func _clear_pending() -> void:
	pending = {}
	mode = Mode.FREE
	aiming_spell = ""
	hud.hide_confirm()
	hud.set_hint("")
	_refresh_highlights()

func _commit_pending() -> void:
	if busy or pending.is_empty() or session == null or not session.is_player_turn():
		return
	var action: Dictionary = pending.duplicate()
	_clear_pending()
	var events: Array = []
	match str(action["kind"]):
		"move":
			events = session.player_move(action["path"])
		"attack":
			events = session.player_attack(action["target"])
		"spell":
			events = session.player_cast(str(action["spell_id"]), action["cell"])
		"loot":
			events = session.player_loot()
		"door":
			events = session.player_toggle_door()
	await _run(events)

# ------------------------------------------------------------------ actions

func _on_action(name: String) -> void:
	if busy or session == null or session.is_over() or screens.is_open():
		return
	if not session.is_player_turn():
		return
	match name:
		"spells":
			_clear_pending()
			hud.toggle_spells(session.known_spells(), session.player, session.can_cast)
		"items":
			_clear_pending()
			hud.toggle_items(state.consumables())
		"dash":
			await _run(session.player_dash())
		"loot":
			await _run(session.player_loot())
		"door":
			await _run(session.player_toggle_door())
		"descend":
			await _run(session.descend())
		"end_turn":
			_clear_pending()
			hud.close_panels()
			await _end_turn()

func _on_spell_chosen(spell_id: String) -> void:
	var spell := Roster.spell(spell_id)
	hud.close_panels()
	if not session.can_cast(spell):
		hud.set_hint("Cannot cast %s right now." % str(spell.get("name", spell_id)))
		return
	# Self-target spells need no aiming step.
	if str(spell.get("target", "")) == "self" or int(spell.get("range", 0)) == 0:
		await _run(session.player_cast(spell_id, session.player.grid_pos))
		return
	pending = {}
	aiming_spell = spell_id
	mode = Mode.AIMING
	hud.set_hint("Tap a target for %s (range %d)." % [
		str(spell.get("name", spell_id)), int(spell.get("range", 0))])
	_refresh_highlights()

func _on_item_chosen(index: int) -> void:
	hud.close_panels()
	await _run(session.player_use_item(index))

func _end_turn() -> void:
	await _run(session.end_player_turn())

# ------------------------------------------------------------- event replay

## Plays events, then hands the turn onward until the player can act again.
func _run(events: Array) -> void:
	if busy:
		return
	busy = true
	_refresh_ui()
	await _replay(events)
	busy = false
	if session.is_over():
		_handle_end_of_run()
		return
	await _advance_until_player()

func _advance_until_player() -> void:
	if session == null or session.is_over():
		return
	var guard := 0
	while not session.is_player_turn() and not session.is_over() and guard < 400:
		guard += 1
		busy = true
		_refresh_ui()
		var actor := session.current_actor()
		if actor != null and actor != session.player and session.map.is_visible(actor.grid_pos):
			camera.focus_on(board.grid_to_world(actor.grid_pos))
		await _replay(session.run_enemy_turn())
		busy = false
	if session.is_over():
		_handle_end_of_run()
		return
	hud.set_banner("Your turn", ArtFactory.UI_ACCENT)
	camera.focus_on(board.grid_to_world(session.player.grid_pos))
	_refresh_ui()

func _replay(events: Array) -> void:
	for event: Dictionary in events:
		var type := str(event.get("type", ""))
		match type:
			"move":
				await _animate_move(event["actor"], event["path"])
			"teleport":
				board.snap_entity(event["attacker"])
			"attack", "opportunity", "spell_attack", "spell_auto", "spell_save":
				_flash(event.get("target"))
				await _beat(0.16)
			"cast":
				await _beat(0.1)
			"death":
				var victim: Entity = event["target"]
				board.remove_entity(victim)
				await _beat(0.14)
			"level_up":
				hud.set_banner("Level %d!" % int(event["level"]), ArtFactory.UI_GOOD)
				await _beat(0.2)
			"door":
				board.refresh_cell(event["cell"])
			"loot":
				board.refresh_visibility(true)
			"player_died":
				hud.set_banner("You black out…", ArtFactory.UI_DANGER)
			"escaped":
				hud.set_banner("Free.", ArtFactory.UI_GOOD)
			"descend":
				hud.set_banner("Downstairs", ArtFactory.UI_ACCENT)
		if str(event.get("text", "")) != "" and not bool(event.get("quiet", false)):
			hud.log_line(str(event["text"]), _colour_for(type))
		board.refresh_entity(session.player)
	board.refresh_visibility()
	_refresh_ui()

func _animate_move(actor: Entity, path: Array) -> void:
	if actor == null or path.is_empty():
		return
	var view := board.view_for(actor)
	if view == null:
		board.snap_entity(actor)
		return
	board.animate_entity_path(actor, path)
	if actor == session.player:
		camera.focus_on(board.grid_to_world(actor.grid_pos))
	# The signal is only ever emitted from the tween created above, so this
	# cannot miss it.
	await view.move_finished
	board.refresh_visibility()

func _flash(target: Variant) -> void:
	if target == null or not (target is Entity):
		return
	var view := board.view_for(target)
	if view != null:
		view.flash()

func _beat(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

static func _colour_for(type: String) -> Color:
	match type:
		"attack", "spell_attack", "spell_auto", "spell_save":
			return Color("ffcc80")
		"opportunity":
			return Color("ff8a65")
		"death":
			return ArtFactory.UI_DANGER
		"heal", "level_up", "escaped":
			return ArtFactory.UI_GOOD
		"buff", "cast", "descend":
			return ArtFactory.UI_ACCENT
		"player_died":
			return ArtFactory.UI_DANGER
		"info", "loot", "door":
			return ArtFactory.UI_DIM
	return ArtFactory.UI_TEXT

# ------------------------------------------------------------- end of a run

func _handle_end_of_run() -> void:
	hud.hide_confirm()
	hud.close_panels()
	board.clear_highlights()
	if session.phase == FloorSession.Phase.ESCAPED:
		var summary := state.win_run()
		if AUTO_SAVE:
			state.save()
		screens.show_victory(state, summary)
	else:
		var summary := state.fail_loop()
		if AUTO_SAVE:
			state.save()
		screens.show_loop_failed(state, summary)

func _start_new_loop() -> void:
	if AUTO_SAVE:
		state.save()
	_clear_pending()
	_start_session(1)

# -------------------------------------------------------- scripted testing

## Actions issued by DebugShot so a run can be driven from the command line.
func _on_debug_action(action: String, args: Array) -> void:
	const ARITY := {
		"tap_cell": 2, "tap_rel": 2, "tap_screen": 2, "spell": 1, "cast": 3, "zoom": 1, "warp_prop": 2,
	}
	if args.size() < int(ARITY.get(action, 0)):
		push_warning("debug action '%s' needs %d args" % [action, int(ARITY[action])])
		return
	match action:
		"tap_cell":
			_on_tapped(board.grid_to_world(Vector2i(int(args[0]), int(args[1]))))
		"tap_screen":
			# Goes through the camera's screen->world maths, unlike tap_cell.
			var screen := Vector2(float(args[0]), float(args[1]))
			_on_tapped(camera.screen_to_world(screen))
			board.set_cursor(board.world_to_grid(camera.screen_to_world(screen)))
		"tap_rel":
			var cell: Vector2i = session.player.grid_pos + Vector2i(int(args[0]), int(args[1]))
			_on_tapped(board.grid_to_world(cell))
		"tap_enemy":
			var seen := session.visible_enemies()
			if not seen.is_empty():
				_on_tapped(board.grid_to_world((seen[0] as Entity).grid_pos))
		"tap_far":
			# Furthest tile the player can actually reach: exercises pathing.
			var cost: Dictionary = session.reachable_cells()["cost"]
			var best := session.player.grid_pos
			for c: Vector2i in cost:
				if int(cost[c]) > int(cost.get(best, 0)):
					best = c
			_on_tapped(board.grid_to_world(best))
		"confirm":
			_commit_pending()
		"cancel":
			_clear_pending()
		"end_turn":
			await _end_turn()
		"dash", "loot", "door", "descend", "spells", "items":
			await _on_action(action)
		"spell":
			await _on_spell_chosen(str(args[0]))
		"cast":
			await _run(session.player_cast(str(args[0]), Vector2i(int(args[1]), int(args[2]))))
		"kill_all":
			for e: Entity in session.entities:
				if e != session.player:
					e.current_hp = 0
					board.remove_entity(e)
		"screen_loop":
			session.player.current_hp = 0
			session.phase = FloorSession.Phase.DEAD
			_handle_end_of_run()
		"screen_victory":
			screens.show_victory(state, {"insight": 12, "depth": 12, "kills": 40, "loop": 4})
		"zoom":
			camera.zoom = Vector2(float(args[0]), float(args[0]))
		"tap_locker":
			for c: Vector2i in session.map.containers:
				for d: Vector2i in MapData.DIRS_8:
					if session.map.is_walkable(c + d) and session.entity_at(c + d) == null:
						session.player.grid_pos = c + d
						board.snap_entity(session.player)
						session.update_fov()
						board.refresh_visibility(true)
						camera.focus_on(board.grid_to_world(c), true)
						_refresh_ui()
						_on_tapped(board.grid_to_world(c))
						return
		"warp_prop":
			# Stand beside a tall prop to check isometric draw order.
			var offset := Vector2i(int(args[0]), int(args[1]))
			for y in session.map.height:
				for x in session.map.width:
					var c := Vector2i(x, y)
					if not MapData.TALL_PROPS.has(session.map.prop_at(c)):
						continue
					if not session.map.is_walkable(c + offset) or session.entity_at(c + offset) != null:
						continue
					session.player.grid_pos = c + offset
					board.snap_entity(session.player)
					session.update_fov()
					board.refresh_visibility(true)
					camera.zoom = Vector2(2.4, 2.4)
					camera.focus_on(board.grid_to_world(c), true)
					_refresh_ui()
					return
