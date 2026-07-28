class_name PropSprite
extends Node2D

## One piece of academy furniture, drawn procedurally in isometric.

var prop_type: int = MapData.Prop.NONE
var is_container: bool = false
var looted: bool = false
var dimmed: bool = false:
	set(value):
		if dimmed != value:
			dimmed = value
			modulate = Color(0.42, 0.46, 0.62) if dimmed else Color.WHITE

func setup(type: int, container: bool = false) -> void:
	prop_type = type
	is_container = container
	queue_redraw()

func _draw() -> void:
	var art := ArtLibrary.texture(ArtLibrary.prop_key(prop_type, looted))
	if art != null:
		IsoDraw.shadow(self, 0.6, 0.3)
		ArtLibrary.draw_standing(self, art, IsoDraw.HALF_H)
		if is_container and not looted:
			_draw_seal()
		return
	match prop_type:
		MapData.Prop.DESK:
			IsoDraw.shadow(self, 0.66, 0.28)
			IsoDraw.box(self, 0.62, 6, Color("6d5637"), Vector2(0, -12))
			IsoDraw.box(self, 0.18, 12, Color("53412a"), Vector2(-8, 2))
			IsoDraw.box(self, 0.18, 12, Color("53412a"), Vector2(8, 2))
		MapData.Prop.CHAIR:
			IsoDraw.shadow(self, 0.4, 0.24)
			IsoDraw.box(self, 0.36, 9, Color("4a5a76"), Vector2(0, -2))
			IsoDraw.slab(self, 14, 14, Color("3d4c64"), Vector2(4, -11))
		MapData.Prop.BRAZIER:
			IsoDraw.shadow(self, 0.36, 0.3)
			IsoDraw.box(self, 0.16, 14, Color("4a4038"))          # tripod stem
			IsoDraw.box(self, 0.44, 6, Color("6b5b45"), Vector2(0, -14))
			# Flame, brightest at the core.
			draw_circle(Vector2(0, -24), 7.0, Color(1.0, 0.45, 0.12, 0.55))
			draw_circle(Vector2(0, -25), 4.5, Color(1.0, 0.72, 0.25, 0.85))
			draw_circle(Vector2(0, -26), 2.2, Color(1.0, 0.95, 0.75))
		MapData.Prop.PODIUM:
			IsoDraw.shadow(self, 0.4, 0.26)
			IsoDraw.box(self, 0.36, 20, Color("6b4a2f"))
			IsoDraw.box(self, 0.5, 3, Color("8a6440"), Vector2(0, -20))
		MapData.Prop.CHEST:
			IsoDraw.shadow(self, 0.6, 0.32)
			var body: Color = Color("6a4f38") if not looted else Color("4a392b")
			IsoDraw.box(self, 0.62, 38, body)
			# Iron banding and a keyhole plate.
			for i in 2:
				draw_rect(Rect2(-11, -32 + i * 14, 22, 3), Color("3a3128"))
			draw_rect(Rect2(-3, -20, 6, 8), Color("c9a227"))
			if is_container and not looted:
				_draw_seal()
		MapData.Prop.BOOKSHELF:
			IsoDraw.shadow(self, 0.6, 0.3)
			IsoDraw.box(self, 0.6, 34, Color("5b4029"))
			for row in 3:
				var y: float = -30.0 + row * 10.0
				for i in 6:
					var hue: float = fposmod(float(row * 6 + i) * 0.17, 1.0)
					draw_rect(Rect2(-14 + i * 5, y, 4, 8), Color.from_hsv(hue, 0.45, 0.72))
		MapData.Prop.RUNE_SLATE:
			IsoDraw.shadow(self, 0.5, 0.24)
			IsoDraw.box(self, 0.5, 8, Color("3f3a33"))
			IsoDraw.slab(self, 46, 32, Color("22242e"), Vector2(0, -8))
			# Glyphs still burning on the slate.
			var glyph := Color(0.45, 0.78, 1.0, 0.85)
			for row in 3:
				var y: float = -32.0 + row * 8.0
				draw_line(Vector2(-16, y), Vector2(-16 + 8 + row * 6, y), glyph, 1.5)
			draw_arc(Vector2(10, -20), 5.0, 0, TAU, 10, Color(0.55, 0.85, 1.0, 0.7), 1.5)
		_:
			pass

## Warded seal: this chest still holds something.
func _draw_seal() -> void:
	draw_circle(Vector2(0, -45), 5.0, Color(1.0, 0.84, 0.35, 0.35))
	draw_arc(Vector2(0, -45), 4.0, 0, TAU, 12, Color("ffd54f"), 1.6)
	draw_line(Vector2(-3, -45), Vector2(3, -45), Color("ffd54f"), 1.4)
	draw_line(Vector2(0, -48), Vector2(0, -42), Color("ffd54f"), 1.4)
