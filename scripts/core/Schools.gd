class_name Schools
extends RefCounted

## The five schools of magic. Every card belongs to exactly one, and examiner
## weaknesses and wards resolve against them. Depended on by everything; depends on
## nothing.

enum School { CINDER, FROST, INK, ROT, WARD }

const ALL: Array[int] = [School.CINDER, School.FROST, School.INK, School.ROT, School.WARD]


static func display_name(school: int) -> String:
	match school:
		School.CINDER:
			return "Cinder"
		School.FROST:
			return "Frost"
		School.INK:
			return "Ink"
		School.ROT:
			return "Rot"
		School.WARD:
			return "Ward"
	return "?"


## The school's ink. Five of these come straight from the art reference's own palette;
## moss is the one addition, because the reference has no green.
static func colour(school: int) -> Color:
	match school:
		School.CINDER:
			return Color("#D45C3C")
		School.FROST:
			return Color("#498BAD")
		School.INK:
			return Color("#000000")
		School.ROT:
			return Color("#6E7B3F")
		School.WARD:
			return Color("#E0A51F")
	return Color.MAGENTA

