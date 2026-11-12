class_name Tracer
extends MeshInstance3D
## Trait lumineux éphémère matérialisant un tir.

const THICKNESS := 0.035
const DURATION := 0.12


## Crée un traceur entre deux points du monde, enfant de `parent`.
static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var box := BoxMesh.new()
	box.size = Vector3(THICKNESS, THICKNESS, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var tracer := Tracer.new()
	tracer.mesh = box
	tracer.material_override = material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tracer)
	tracer.look_at_from_position((from + to) * 0.5, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tween := tracer.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, DURATION)
	tween.tween_callback(tracer.queue_free)
