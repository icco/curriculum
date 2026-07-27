class_name EntityView
extends Node2D

## Visual for one combatant: a small isometric figure with a health pip bar,
## turn marker and condition icons. Movement between tiles is tweened by the
## board, which also owns the entity data.

signal move_finished

var entity: Entity
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var active_turn: bool = false:
	set(value):
		active_turn = value
		queue_redraw()
var dimmed: bool = false:
	set(value):
		if dimmed != value:
			dimmed = value
			modulate = Color(0.5, 0.55, 0.7) if dimmed else Color.WHITE

var _bob: float = 0.0
var _flash: float = 0.0
var _tween: Tween

func setup(e: Entity) -> void:
	entity = e
	queue_redraw()

func _process(delta: float) -> void:
	if active_turn:
		_bob = fmod(_bob + delta * 3.0, TAU)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()

func flash() -> void:
	_flash = 1.0
	queue_redraw()

## Walks the sprite through a list of world positions.
func animate_path(points: Array, step_time: float = 0.11) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if points.is_empty():
		move_finished.emit()
		return
	_tween = create_tween()
	for p: Vector2 in points:
		_tween.tween_property(self, "position", p, step_time)
	_tween.finished.connect(func() -> void: move_finished.emit())

func _draw() -> void:
	if entity == null:
		return
	var height: float = 30.0
	match entity.rank:
		Entity.Rank.ELITE: height = 34.0
		Entity.Rank.BOSS: height = 40.0
		Entity.Rank.HERO: height = 33.0

	var lift: float = sin(_bob) * 2.0 if active_turn else 0.0
	var base := Vector2(0, lift)

	IsoDraw.shadow(self, 0.5, 0.34)

	var art := ArtLibrary.texture(ArtLibrary.entity_key(entity.art_id))
	if art != null:
		if selected or active_turn:
			var art_ring: Color = ArtFactory.UI_ACCENT if entity.team == Entity.Team.PLAYER \
				else ArtFactory.UI_DANGER
			art_ring.a = 0.9
			IsoDraw.tile_outline(self, art_ring, 2.5, 0.86)
		ArtLibrary.draw_standing(self, art, IsoDraw.HALF_H + lift)
		_draw_health(art.get_height() - IsoDraw.HALF_H)
		_draw_conditions(art.get_height() - IsoDraw.HALF_H)
		return

	if selected or active_turn:
		var ring: Color = ArtFactory.UI_ACCENT if entity.team == Entity.Team.PLAYER else ArtFactory.UI_DANGER
		ring.a = 0.9
		IsoDraw.tile_outline(self, ring, 2.5, 0.86)

	var body_col: Color = entity.tint
	if _flash > 0.0:
		body_col = body_col.lerp(Color.WHITE, _flash)

	# Legs, torso, head — deliberately chunky so they read at mobile zoom.
	var torso_h: float = height * 0.52
	var head_r: float = height * 0.19
	draw_rect(Rect2(base + Vector2(-5, -height * 0.34), Vector2(4, height * 0.34)), Color(body_col.r * 0.55, body_col.g * 0.55, body_col.b * 0.6))
	draw_rect(Rect2(base + Vector2(1, -height * 0.34), Vector2(4, height * 0.34)), Color(body_col.r * 0.55, body_col.g * 0.55, body_col.b * 0.6))
	var torso := Rect2(base + Vector2(-7, -height * 0.34 - torso_h), Vector2(14, torso_h))
	draw_rect(torso, body_col)
	draw_rect(Rect2(torso.position, Vector2(5, torso.size.y)), Color(1, 1, 1, 0.10))
	draw_rect(torso, Color(0, 0, 0, 0.35), false, 1.0)
	var head_c: Vector2 = base + Vector2(0, -height * 0.34 - torso_h - head_r + 1)
	draw_circle(head_c, head_r, Color("e8c39e"))
	draw_circle(head_c, head_r, Color(0, 0, 0, 0.35), false, 1.0)
	# Hair cap in the team tint keeps silhouettes distinct.
	draw_arc(head_c, head_r - 0.5, PI, TAU, 10, Color(body_col.r * 0.5, body_col.g * 0.5, body_col.b * 0.55), 3.0)

	match entity.rank:
		Entity.Rank.ELITE:
			# Sash for hall monitors.
			draw_line(torso.position + Vector2(0, 3), torso.position + Vector2(14, torso_h - 3), ArtFactory.ELITE_TRIM, 3.0)
		Entity.Rank.BOSS:
			# Mortarboard for teachers.
			draw_rect(Rect2(head_c + Vector2(-9, -head_r - 4), Vector2(18, 3)), ArtFactory.BOSS_TRIM)
			draw_line(head_c + Vector2(8, -head_r - 3), head_c + Vector2(11, -head_r + 4), ArtFactory.BOSS_TRIM, 1.5)
		Entity.Rank.HERO:
			draw_rect(Rect2(base + Vector2(-8, -height - 9), Vector2(16, 3)), ArtFactory.UI_ACCENT)

	_draw_health(height)
	_draw_conditions(height)

func _draw_health(height: float) -> void:
	var w := 26.0
	var y := -height - 16.0
	var frac: float = clampf(float(entity.current_hp) / maxf(1.0, float(entity.max_hp)), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-w / 2 - 1, y - 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.65))
	var col: Color = ArtFactory.UI_GOOD
	if frac < 0.6:
		col = Color("ffb300")
	if frac < 0.3:
		col = ArtFactory.UI_DANGER
	draw_rect(Rect2(Vector2(-w / 2, y), Vector2(w * frac, 4)), col)

func _draw_conditions(height: float) -> void:
	var icons: Array = []
	if entity.has_condition("stunned"):
		icons.append(Color("ffd54f"))
	if entity.has_condition("shielded"):
		icons.append(ArtFactory.UI_ACCENT)
	if entity.has_condition("burning"):
		icons.append(Color("ff7043"))
	if entity.has_condition("slowed"):
		icons.append(Color("90a4ae"))
	var x: float = -float(icons.size() - 1) * 4.0
	for c: Color in icons:
		draw_circle(Vector2(x, -height - 22), 3.0, c)
		x += 8.0
