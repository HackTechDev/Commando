class_name WorldMaterial
extends RefCounted
## Matériaux du décor des cartes UFO:AI : un `ShaderMaterial` sur
## `assets/shaders/world.gdshaderinc`, qui sait s'effacer autour des
## opérateurs et sur l'emprise d'un toit (voir le shader).
##
## Les textures sont demandées comme pour un `BaseMaterial3D`, par
## métadonnées (`albedo_source`…), et posées par `TextureLibrary`.

enum Blend { OPAQUE, SCISSOR, ALPHA }

const INCLUDE := "res://assets/shaders/world.gdshaderinc"
## Paramètres globaux des opérateurs (`see_through_1` à `_6`).
const SEE_THROUGH_SLOTS := 6
## Hauteur du torse au-dessus des pieds (`TORSO` dans le shader).
const TORSO := 1.0

static var _shaders: Dictionary = {}
## Dernières positions transmises par `set_see_through` (pieds).
static var see_through_points: Array[Vector3] = []


## Nouveau matériau du décor.
static func create(blend: Blend = Blend.OPAQUE) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader(blend)
	return material


## Shader (partagé) de la variante `blend`.
static func shader(blend: Blend) -> Shader:
	if _shaders.has(blend):
		return _shaders[blend]
	var code := "shader_type spatial;\n"
	match blend:
		Blend.OPAQUE:
			code += "render_mode depth_draw_opaque, cull_back;\n"
		Blend.SCISSOR:
			code += "render_mode depth_draw_opaque, cull_back;\n#define ALPHA_SCISSOR\n"
		Blend.ALPHA:
			code += "render_mode blend_mix, depth_draw_never, cull_back;\n#define ALPHA_BLEND\n"
	code += "#include \"%s\"\n" % INCLUDE
	var result := Shader.new()
	result.code = code
	_shaders[blend] = result
	return result


## Indique au décor où sont les opérateurs : torses de `points` (6 au plus),
## les autres emplacements sont éteints.
static func set_see_through(points: Array[Vector3]) -> void:
	see_through_points = points.slice(0, SEE_THROUGH_SLOTS)
	for i in SEE_THROUGH_SLOTS:
		var value := Vector4.ZERO
		if i < points.size():
			var at := points[i]
			value = Vector4(at.x, at.y + TORSO, at.z, 1.0)
		RenderingServer.global_shader_parameter_set(StringName("see_through_%d" % (i + 1)), value)
