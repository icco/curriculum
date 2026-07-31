extends Node

## Stateless. Exists because the brief names it; forwards to Grading.


func score(params: Dictionary) -> Dictionary:
	return Grading.score(params)


func letter(grade) -> String:
	return Grading.letter(grade)


func draft_allowance(grade) -> int:
	return Grading.draft_allowance(grade)
