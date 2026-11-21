class_name MeshFade
extends RefCounted
## Fondu d'un maillage par ses matériaux (canal alpha), à la place de
## `GeometryInstance3D.transparency`, que le rendu Compatibility (export web)
## ignore : la coque du convertible et le haut des bâtiments restaient alors
## opaques.
##
## Au premier appel, chaque surface reçoit sa propre copie du matériau (en
## surcharge de surface), pour ne pas estomper les autres maillages qui
## partagent l'original.

const META := &"mesh_fade"


## Estompe `mesh` : 0 opaque (matériaux d'origine), 1 invisible.
static func apply(mesh: MeshInstance3D, fade: float) -> void:
	var entries := _entries(mesh)
	for entry: Dictionary in entries:
		var material := entry["material"] as BaseMaterial3D
		var faded := fade > 0.001
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if faded else entry["transparency"]
		var color := material.albedo_color
		color.a = float(entry["alpha"]) * (1.0 - fade)
		material.albedo_color = color


## Copies des matériaux de `mesh` (créées au premier appel) : matériau,
## transparence et alpha d'origine.
static func _entries(mesh: MeshInstance3D) -> Array:
	if mesh.has_meta(META):
		return mesh.get_meta(META)
	var entries: Array = []
	var override := mesh.material_override
	mesh.material_override = null
	for surface in mesh.mesh.get_surface_count():
		var source := override
		if source == null:
			source = mesh.get_surface_override_material(surface)
		if source == null:
			source = mesh.mesh.surface_get_material(surface)
		var base := source as BaseMaterial3D
		if base == null:
			# Matériau à shader ou absent : on laisse la surface telle quelle.
			if override:
				mesh.set_surface_override_material(surface, override)
			continue
		var copy := base.duplicate() as BaseMaterial3D
		mesh.set_surface_override_material(surface, copy)
		entries.append({"material": copy, "transparency": base.transparency, "alpha": base.albedo_color.a})
	mesh.set_meta(META, entries)
	return entries
