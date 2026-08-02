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


## The schools the player opens every run with — Cinder, Ward and Ink, from the spec's
## 4 Spark / 4 Guard / 2 Ink Blot.
##
## Read off the AUTHORED starting deck, never off a run's current deck, and that
## distinction is load-bearing rather than stylistic. Faculty's rolls are constrained by
## what the player opens with, and a mid-run save restores a *drafted* deck: deriving
## the constraint from `run.deck` would feed the generator five schools on load where it
## saw three at the start, rebuild a different faculty from the same seed, and turn every
## Bestiary entry into a lie. Derived from content, the constraint is a constant, which
## is what makes generation pure in (library, seed).
func opening_schools() -> Array[int]:
	var seen := {}
	var out: Array[int] = []
	for card in starting_deck:
		if card != null and not seen.has(card.school):
			seen[card.school] = true
			out.append(card.school)
	return out


## Fresh CardInstances for a new run.
func new_starting_deck() -> Array:
	var out: Array = []
	for card in starting_deck:
		out.append(CardInstance.new(card))
	return out
