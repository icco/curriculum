class_name CourseData
extends Resource

## One node on the Course Catalog: a university course whose examiner is fought as a
## battle. Self-referential via `prerequisites`, which is legal for a Resource -- a
## mutual typed reference between two different core classes is not.

@export var course_name: String = ""
@export var tier: int = 1
@export var prerequisites: Array[CourseData] = []
## How many of `prerequisites` are required to open this course. 0 means all of them.
@export var prerequisites_required: int = 0
@export var examiner: EnemyData
@export var par_turns: int = 5
## Cards a player can expect to play in a par-length battle; the Learning term scores
## against this rather than against deck size.
@export var xp_par: int = 15
@export var guaranteed_card_drop: CardData
## Honors nodes need an A or better on a prerequisite to open, instead of a plain pass.
@export var is_honors: bool = false
## The course this honors node branches from, for map rendering. Availability itself
## is driven by `prerequisites`, not this field.
@export var honors_of: CourseData
