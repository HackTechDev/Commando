@tool
extends EditorPlugin
## Greffon « Éditeur de mission » (voir MISSION_EDITOR.md).
##
## Aperçu des textures externes sur la scène de mission ouverte
## (`TexturePreview`), retirées le temps de chaque enregistrement.

const TexturePreview := preload("res://addons/mission_editor/texture_preview.gd")

var _textures := TexturePreview.new()


func _enter_tree() -> void:
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	_on_scene_changed.call_deferred(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	scene_changed.disconnect(_on_scene_changed)
	scene_saved.disconnect(_on_scene_saved)
	_textures.revert()


## Avant tout enregistrement (et changement d'onglet, perte du focus…),
## les textures quittent les matériaux ; elles reviennent juste après,
## une fois l'enregistrement fait.
func _apply_changes() -> void:
	_textures.revert()
	_reapply.call_deferred()


func _save_external_data() -> void:
	_textures.revert()
	_reapply.call_deferred()


func _reapply() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root is LevelRoot:
		_textures.apply(root)


func _on_scene_saved(_path: String) -> void:
	_reapply.call_deferred()


func _on_scene_changed(root: Node) -> void:
	_textures.revert()
	if root is LevelRoot:
		_textures.apply(root)
