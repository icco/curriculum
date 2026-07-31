class_name ContentLibrary
extends Resource

## One index over all content. Adding a card means adding a .tres and listing it
## here; nothing in the rules layer changes.

@export var cards: Array[CardData] = []
@export var enemies: Array[EnemyData] = []
@export var courses: Array[CourseData] = []
@export var starting_deck: Array[CardData] = []


func card_named(name: String) -> CardData:
	for card in cards:
		if card != null and card.card_name == name:
			return card
	return null


func enemy_named(name: String) -> EnemyData:
	for enemy in enemies:
		if enemy != null and enemy.enemy_name == name:
			return enemy
	return null


func course_named(name: String) -> CourseData:
	for course in courses:
		if course != null and course.course_name == name:
			return course
	return null


func catalog() -> Catalog:
	return Catalog.new(courses)


## Fresh CardInstances for a new run.
func new_starting_deck() -> Array:
	var out: Array = []
	for card in starting_deck:
		out.append(CardInstance.new(card))
	return out
