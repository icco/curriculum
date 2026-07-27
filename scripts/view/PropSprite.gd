class_name PropSprite
extends Node2D

## One piece of school furniture, drawn procedurally in isometric.

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
		MapData.Prop.TRASH:
			IsoDraw.shadow(self, 0.36, 0.26)
			IsoDraw.box(self, 0.34, 16, Color("3f6b57"))
			IsoDraw.box(self, 0.38, 2, Color("58907a"), Vector2(0, -16))
		MapData.Prop.PODIUM:
			IsoDraw.shadow(self, 0.4, 0.26)
			IsoDraw.box(self, 0.36, 20, Color("6b4a2f"))
			IsoDraw.box(self, 0.5, 3, Color("8a6440"), Vector2(0, -20))
		MapData.Prop.LOCKER:
			IsoDraw.shadow(self, 0.6, 0.32)
			var body: Color = Color("7b8595") if not looted else Color("5e6673")
			IsoDraw.box(self, 0.62, 38, body)
			# Vent slats and a handle so lockers read at a glance.
			for i in 3:
				draw_rect(Rect2(-10, -34 + i * 5, 20, 2), Color(0, 0, 0, 0.28))
			draw_rect(Rect2(6, -20, 3, 7), Color("d7dde8"))
			if is_container and not looted:
				draw_circle(Vector2(0, -44), 4.5, Color("ffd54f"))
				draw_circle(Vector2(0, -44), 2.0, Color("8d6e00"))
		MapData.Prop.BOOKSHELF:
			IsoDraw.shadow(self, 0.6, 0.3)
			IsoDraw.box(self, 0.6, 34, Color("5b4029"))
			for row in 3:
				var y: float = -30.0 + row * 10.0
				for i in 6:
					var hue: float = fposmod(float(row * 6 + i) * 0.17, 1.0)
					draw_rect(Rect2(-14 + i * 5, y, 4, 8), Color.from_hsv(hue, 0.45, 0.72))
		MapData.Prop.CHALKBOARD:
			IsoDraw.shadow(self, 0.5, 0.24)
			IsoDraw.box(self, 0.5, 8, Color("4a4034"))
			IsoDraw.slab(self, 46, 30, Color("2f4a3c"), Vector2(0, -8))
			draw_line(Vector2(-16, -26), Vector2(-2, -30), Color(1, 1, 1, 0.5), 1.5)
			draw_line(Vector2(2, -20), Vector2(16, -24), Color(1, 1, 1, 0.35), 1.5)
		_:
			pass
