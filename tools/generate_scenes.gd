extends SceneTree

## Packs a code-built node tree into a .tscn so the structure lives in a scene
## and the script can reference nodes instead of constructing them.
##   godot --headless --path . --script tools/generate_scenes.gd
##
## Prerequisite: every node the script needs must be given a `name` (and ideally
## `unique_name_in_owner`) in the builder first. PackedScene silently drops
## children whose owner is not the packed root, and auto-named nodes cannot be
## referenced afterwards — the verification step below exists to catch both.
##
## Currently only used for the leaf views; HUD and LoopScreen still build their
## trees in code (see the refactor(ui) commit for why).

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes"))
	var ok := true
	ok = pack(EntityView.new(), "res://scenes/EntityView.tscn", []) and ok
	ok = pack(PropSprite.new(), "res://scenes/PropSprite.tscn", []) and ok
	quit(0 if ok else 1)
	return true

## Builds `node`, claims every descendant for the scene root, packs, saves, then
## reloads and asserts the `expected` node paths survived.
func pack(node: Node, path: String, expected: Array) -> bool:
	root.add_child(node)
	_claim(node, node)
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err != OK:
		push_error("pack %s failed: %d" % [path, err])
		return false
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save %s failed: %d" % [path, err])
		return false
	node.free()

	var check: Node = (load(path) as PackedScene).instantiate()
	var missing: Array = []
	for p: String in expected:
		if check.get_node_or_null(p) == null:
			missing.append(p)
	var count := _count(check)
	check.free()
	if not missing.is_empty():
		push_error("%s lost nodes: %s — name them in the builder first" % [path, str(missing)])
		return false
	print("%-34s %2d nodes" % [path, count])
	return true

func _claim(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_claim(child, owner_node)

func _count(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
