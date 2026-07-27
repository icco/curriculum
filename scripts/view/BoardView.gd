class_name BoardView
extends Node2D

## Renders a MapData as isometric tile layers plus furniture and combatant
## sprites, and owns all grid <-> screen conversion.
##
## Fog of war is done with paired "lit" and "dim" tile layers rather than an
## overlay, so the dimming follows the full height of wall blocks. Unexplored
## cells simply have no tile placed.

## Tint applied to explored-but-unseen tiles.
@export var fog_tint: Color = Color(0.44, 0.48, 0.63)

var map: MapData

var floor_lit: TileMapLayer
var floor_dim: TileMapLayer
var block_lit: TileMapLayer
var block_dim: TileMapLayer
var highlights: Node2D
var world: Node2D

var _floor_source: int
var _block_source: int
var _cell_state: PackedByteArray      ## 0 unknown, 1 explored, 2 visible
var _props: Dictionary = {}           ## Vector2i -> PropSprite
var _entity_views: Dictionary = {}    ## Entity -> EntityView

# Highlight state, drawn by the highlight child.
var move_cells: Array = []
var path_cells: Array = []
var target_cells: Array = []
var cursor_cell: Vector2i = Vector2i(-999, -999)
var threat_cells: Array = []

func _ready() -> void:
	var built := ArtFactory.build_tileset()
	var tileset: TileSet = built["tileset"]
	_floor_source = built["floor_source"]
	_block_source = built["block_source"]

	floor_lit = _make_layer(tileset, false)
	floor_dim = _make_layer(tileset, false)
	floor_dim.modulate = fog_tint
	add_child(floor_lit)
	add_child(floor_dim)

	highlights = Node2D.new()
	highlights.name = "Highlights"
	highlights.draw.connect(_draw_highlights)
	add_child(highlights)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	block_lit = _make_layer(tileset, true)
	block_dim = _make_layer(tileset, true)
	block_dim.modulate = fog_tint
	world.add_child(block_lit)
	world.add_child(block_dim)

func _make_layer(tileset: TileSet, ysort: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	layer.y_sort_enabled = ysort
	return layer

# --------------------------------------------------------------- building

func build(new_map: MapData) -> void:
	map = new_map
	clear_board()
	_cell_state = PackedByteArray()
	_cell_state.resize(map.width * map.height)
	_cell_state.fill(0)

	for p: Vector2i in map.containers:
		pass  # containers are drawn by their locker prop

	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var prop := map.prop_at(cell)
			if prop != MapData.Prop.NONE:
				var sprite := PropSprite.new()
				sprite.setup(prop, map.containers.has(cell))
				sprite.position = grid_to_world(cell)
				sprite.visible = false
				world.add_child(sprite)
				_props[cell] = sprite
	refresh_visibility(true)

func clear_board() -> void:
	for layer: TileMapLayer in [floor_lit, floor_dim, block_lit, block_dim]:
		if layer != null:
			layer.clear()
	for p: Vector2i in _props:
		(_props[p] as Node).queue_free()
	_props.clear()
	for e: Variant in _entity_views:
		(_entity_views[e] as Node).queue_free()
	_entity_views.clear()
	move_cells.clear()
	path_cells.clear()
	target_cells.clear()
	threat_cells.clear()

# ------------------------------------------------------------ conversions

func grid_to_world(cell: Vector2i) -> Vector2:
	return floor_lit.map_to_local(cell)

func world_to_grid(pos: Vector2) -> Vector2i:
	return floor_lit.local_to_map(pos)

func board_bounds() -> Rect2:
	if map == null:
		return Rect2()
	var corners: Array = [
		grid_to_world(Vector2i(0, 0)),
		grid_to_world(Vector2i(map.width - 1, 0)),
		grid_to_world(Vector2i(0, map.height - 1)),
		grid_to_world(Vector2i(map.width - 1, map.height - 1)),
	]
	var rect := Rect2(corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		rect = rect.expand(c)
	return rect

# ------------------------------------------------------------- visibility

## Repaints tiles whose fog state changed. Cheap enough to call every time the
## player moves a single step.
func refresh_visibility(force: bool = false) -> void:
	if map == null:
		return
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var i := map.idx(cell)
			var desired: int = 0
			if map.is_visible(cell):
				desired = 2
			elif map.is_explored(cell):
				desired = 1
			if not force and _cell_state[i] == desired:
				continue
			_cell_state[i] = desired
			_paint_cell(cell, desired)
	_refresh_props()
	_refresh_entity_visibility()

func _paint_cell(cell: Vector2i, state: int) -> void:
	floor_lit.erase_cell(cell)
	floor_dim.erase_cell(cell)
	block_lit.erase_cell(cell)
	block_dim.erase_cell(cell)
	if state == 0:
		return
	var tile := map.tile_at(cell)
	if tile == MapData.Tile.VOID:
		return

	var floor_layer: TileMapLayer = floor_lit if state == 2 else floor_dim
	var block_layer: TileMapLayer = block_lit if state == 2 else block_dim

	match tile:
		MapData.Tile.WALL:
			block_layer.set_cell(cell, _block_source, Vector2i(ArtFactory.Block.WALL, 0))
		MapData.Tile.DOOR:
			floor_layer.set_cell(cell, _floor_source, Vector2i(ArtFactory.Floor.HALL, 0))
			var art: int = ArtFactory.Block.DOOR_OPEN if map.is_door_open(cell) else ArtFactory.Block.DOOR_CLOSED
			block_layer.set_cell(cell, _block_source, Vector2i(art, 0))
		MapData.Tile.STAIRS:
			floor_layer.set_cell(cell, _floor_source, Vector2i(ArtFactory.Floor.STAIRS, 0))
		_:
			floor_layer.set_cell(cell, _floor_source, Vector2i(_floor_art(cell), 0))

## Redraws a single cell, e.g. after a door opens.
func refresh_cell(cell: Vector2i) -> void:
	if map == null or not map.in_bounds(cell):
		return
	_paint_cell(cell, _cell_state[map.idx(cell)])

func _floor_art(cell: Vector2i) -> int:
	var room_id := map.room_at(cell)
	if room_id == -1:
		return ArtFactory.Floor.HALL
	var kind := str(map.rooms[room_id]["kind"])
	return int(ArtFactory.ROOM_FLOOR.get(kind, ArtFactory.Floor.HALL))

func _refresh_props() -> void:
	for cell: Vector2i in _props:
		var sprite: PropSprite = _props[cell]
		var state: int = _cell_state[map.idx(cell)]
		sprite.visible = state > 0
		sprite.dimmed = state == 1
		var container: Dictionary = map.containers.get(cell, {})
		var looted: bool = bool(container.get("looted", false))
		if sprite.looted != looted:
			sprite.looted = looted
			sprite.queue_redraw()

func _refresh_entity_visibility() -> void:
	for e: Variant in _entity_views:
		var entity: Entity = e
		var view: EntityView = _entity_views[e]
		if entity.team == Entity.Team.PLAYER:
			view.visible = true
			view.dimmed = false
		else:
			view.visible = map.is_visible(entity.grid_pos)

# ---------------------------------------------------------------- entities

func add_entity(e: Entity) -> EntityView:
	var view := EntityView.new()
	view.setup(e)
	view.position = grid_to_world(e.grid_pos)
	world.add_child(view)
	_entity_views[e] = view
	_refresh_entity_visibility()
	return view

func remove_entity(e: Entity) -> void:
	if not _entity_views.has(e):
		return
	var view: EntityView = _entity_views[e]
	_entity_views.erase(e)
	var tween := view.create_tween()
	tween.tween_property(view, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(view, "scale", Vector2(0.6, 0.6), 0.35)
	tween.tween_callback(view.queue_free)

func view_for(e: Entity) -> EntityView:
	return _entity_views.get(e, null)

func snap_entity(e: Entity) -> void:
	var view: EntityView = _entity_views.get(e, null)
	if view != null:
		view.position = grid_to_world(e.grid_pos)

func refresh_entity(e: Entity) -> void:
	var view: EntityView = _entity_views.get(e, null)
	if view != null:
		view.queue_redraw()

## Slides a sprite along a grid path; returns the view so callers can await.
func animate_entity_path(e: Entity, cells: Array) -> EntityView:
	var view: EntityView = _entity_views.get(e, null)
	if view == null:
		return null
	var points: Array = []
	for c: Vector2i in cells:
		points.append(grid_to_world(c))
	view.animate_path(points)
	return view

# -------------------------------------------------------------- highlights

func set_move_range(cells: Array) -> void:
	move_cells = cells
	highlights.queue_redraw()

func set_path(cells: Array) -> void:
	path_cells = cells
	highlights.queue_redraw()

func set_targets(cells: Array) -> void:
	target_cells = cells
	highlights.queue_redraw()

func set_threat(cells: Array) -> void:
	threat_cells = cells
	highlights.queue_redraw()

func set_cursor(cell: Vector2i) -> void:
	cursor_cell = cell
	highlights.queue_redraw()

func clear_highlights() -> void:
	move_cells = []
	path_cells = []
	target_cells = []
	threat_cells = []
	cursor_cell = Vector2i(-999, -999)
	highlights.queue_redraw()

func _draw_highlights() -> void:
	for cell: Vector2i in move_cells:
		IsoDraw.tile(highlights, Color(0.36, 0.78, 0.98, 0.30), 0.94, grid_to_world(cell))
		IsoDraw.tile_outline(highlights, Color(0.45, 0.85, 1.0, 0.35), 1.0, 0.94, grid_to_world(cell))
	for cell: Vector2i in threat_cells:
		IsoDraw.tile(highlights, Color(0.94, 0.33, 0.31, 0.16), 0.96, grid_to_world(cell))
	for cell: Vector2i in target_cells:
		IsoDraw.tile(highlights, Color(0.94, 0.33, 0.31, 0.34), 0.96, grid_to_world(cell))
		IsoDraw.tile_outline(highlights, Color(1, 0.45, 0.4, 0.9), 2.0, 0.96, grid_to_world(cell))
	# Amber footsteps so the route reads clearly on top of the blue move range.
	for i in path_cells.size():
		var cell: Vector2i = path_cells[i]
		var last: bool = i == path_cells.size() - 1
		var pos := grid_to_world(cell)
		if last:
			IsoDraw.tile(highlights, Color(1.0, 0.87, 0.42, 0.62), 0.92, pos)
			IsoDraw.tile_outline(highlights, Color(1.0, 0.95, 0.7, 1.0), 3.0, 0.92, pos)
		elif i > 0:
			IsoDraw.tile(highlights, Color(1.0, 0.82, 0.35, 0.42), 0.5, pos)
	if cursor_cell.x > -900:
		IsoDraw.tile_outline(highlights, Color(1, 1, 1, 0.95), 2.5, 0.98, grid_to_world(cursor_cell))
