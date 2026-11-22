extends SceneTree
## Migration unique : écrit `mission.tres` (`MissionInfo`) à côté de chaque
## scène de `LevelCatalog.LEVELS`.
## Lancement : godot --headless --path . -s res://tools/godot/migrate_missions.gd

func _init() -> void:
	var levels: Array = load("res://scripts/levels/level_catalog.gd").LEVELS
	for i in levels.size():
		var level: Dictionary = levels[i]
		var info := MissionInfo.new()
		info.title = level["title"]
		info.description = level["description"]
		info.camo = level.get("camo", "woodland")
		info.map = level.get("map", "")
		info.order = (i + 1) * 10
		for objective: Dictionary in level.get("objectives", []):
			info.objectives.append(MissionObjective.make(objective["id"], objective["text"]))
		var path := MissionInfo.path_for(level["scene"])
		assert(MissionInfo.scene_for(path) == level["scene"])
		var error := ResourceSaver.save(info, path)
		print("%s %s" % [path, "ok" if error == OK else "ERREUR %d" % error])
	quit()
