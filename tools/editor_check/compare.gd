extends SceneTree
## Compare deux lots de scènes nœud par nœud, propriété par propriété
## (valeurs enregistrées), sans tenir compte du format du fichier.
## Usage : godot --headless --path <copie> -s res://compare.gd -- <dossier A> <dossier B> <noms…>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var a_dir := args[0]
	var b_dir := args[1]
	for name in args.slice(2):
		var a := (load(a_dir.path_join(name)) as PackedScene).instantiate()
		var b := (load(b_dir.path_join(name)) as PackedScene).instantiate()
		var diffs: Array[String] = []
		_compare_nodes(a, b, a, b, diffs)
		print("COMPARE %s : %s" % [name, "identique" if diffs.is_empty() else "%d écart(s)" % diffs.size()])
		for line in diffs.slice(0, 12):
			print("   ", line)
		a.free()
		b.free()
	quit()


func _compare_nodes(a_root: Node, b_root: Node, a: Node, b: Node, diffs: Array[String]) -> void:
	var path := str(a_root.get_path_to(a))
	_compare_objects(path, a, b, diffs, 0)
	var a_names := a.get_children().map(func(n: Node) -> String: return n.name)
	var b_names := b.get_children().map(func(n: Node) -> String: return n.name)
	for child_name in a_names:
		if not b_names.has(child_name):
			diffs.append("%s/%s : nœud absent après" % [path, child_name])
	for child_name in b_names:
		if not a_names.has(child_name):
			diffs.append("%s/%s : nœud en plus après" % [path, child_name])
		else:
			_compare_nodes(a_root, b_root, a.get_node(NodePath(child_name)), b.get_node(NodePath(child_name)), diffs)


func _compare_objects(path: String, a: Object, b: Object, diffs: Array[String], depth: int) -> void:
	for property in a.get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var key: String = property["name"]
		if key in ["owner", "unique_id", "resource_path", "resource_local_to_scene", "scene_file_path"]:
			continue
		var va: Variant = a.get(key)
		var vb: Variant = b.get(key)
		if va is Resource and vb is Resource and depth < 3:
			var pa := (va as Resource).resource_path
			var pb := (vb as Resource).resource_path
			# Ressource d'un autre fichier : même chemin attendu ; ressource
			# intégrée à la scène (« scène::id ») : comparée par son contenu.
			if (pa != "" and not pa.contains("::")) or (pb != "" and not pb.contains("::")):
				if pa != pb:
					diffs.append("%s.%s : %s → %s" % [path, key, va.resource_path, vb.resource_path])
				continue
			_compare_objects("%s.%s" % [path, key], va, vb, diffs, depth + 1)
		elif typeof(va) != typeof(vb) or (not (va is Object) and va != vb and str(va) != str(vb)):
			diffs.append("%s.%s : %s → %s" % [path, key, str(va).left(80), str(vb).left(80)])
