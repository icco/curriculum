extends Node2D

## Game root: owns the board, the camera and the current floor's roster.
## Turn logic and UI are layered on top of this in later stages.

var board: BoardView
var camera: CameraRig
var debug_shot: Node

var map: MapData
var player: Entity
var entities: Array = []          ## Array[Entity], player included
var depth: int = 1
var run_seed: int = 0

const SIGHT_RADIUS := 9

func _ready() -> void:
	Roster.load_data()
	debug_shot = get_node_or_null("DebugShot")
	run_seed = DebugShot.seed_from_env()

	board = BoardView.new()
	board.name = "Board"
	add_child(board)

	camera = CameraRig.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	camera.tapped.connect(_on_tapped)

	start_floor(1)

# ------------------------------------------------------------------- floor

func start_floor(new_depth: int) -> void:
	depth = new_depth
	var gen := MapGenerator.new()
	var result := gen.generate(depth)
	map = result["map"]
	entities.clear()

	board.build(map)

	player = Roster.make_player()
	player.grid_pos = map.entry_pos
	entities.append(player)

	for spawn: Dictionary in result["spawns"]:
		var e := Roster.make_enemy(str(spawn["role"]), depth)
		e.grid_pos = spawn["pos"]
		entities.append(e)

	for e: Entity in entities:
		board.add_entity(e)

	update_fov()
	camera.set_bounds(board.board_bounds())
	camera.focus_on(board.grid_to_world(player.grid_pos), true)

func update_fov() -> void:
	map.recompute_fov(player.grid_pos, SIGHT_RADIUS)
	board.refresh_visibility()

## Tiles occupied by living combatants, used by pathing.
func occupied(exclude: Entity = null) -> Dictionary:
	var out: Dictionary = {}
	for e: Entity in entities:
		if e == exclude or not e.is_alive():
			continue
		out[e.grid_pos] = e
	return out

func entity_at(cell: Vector2i) -> Entity:
	for e: Entity in entities:
		if e.is_alive() and e.grid_pos == cell:
			return e
	return null

# ------------------------------------------------------------------- input

func _on_tapped(world_pos: Vector2) -> void:
	var cell := board.world_to_grid(world_pos)
	if not map.in_bounds(cell):
		return
	board.set_cursor(cell)
	var reach: Dictionary = map.flood_fill(player.grid_pos, player.speed_tiles, occupied(player))["cost"]
	var cells: Array = reach.keys()
	cells.erase(player.grid_pos)
	board.set_move_range(cells)
	if reach.has(cell):
		var came: Dictionary = map.flood_fill(player.grid_pos, player.speed_tiles, occupied(player))["came_from"]
		board.set_path(MapData.reconstruct_path(came, cell))
