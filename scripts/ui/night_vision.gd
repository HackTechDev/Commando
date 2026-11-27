class_name NightVision
extends CanvasLayer
## Jumelles de vision nocturne (JVN) abaissées : un filtre plein écran
## simule l'image intensifiée (luminance amplifiée en vert phosphore, grain,
## lignes, vignettage). Les couleurs vives (cônes de vision, marqueurs)
## gardent leur teinte pour rester lisibles.
##
## `toggle_nvg` abaisse ou relève les jumelles de tous les opérateurs qui en
## portent (`OperatorProfile.wears_nvg`), et affiche ou retire la vue verte.
## La nuit (`LevelRoot.night`), elles sont abaissées d'office et
## l'amplification est forte (`NIGHT_GAIN`) ; de jour, elles restent
## relevées, et abaissées l'image n'est que faiblement amplifiée
## (`DAY_GAIN`, sinon tout serait blanc). Sans JVN, rien ne change.
##
## Lunette thermique (`OperatorProfile.thermal_scope`) : le même appui passe
## ensuite à la vue thermique, en niveaux de gris « blanc chaud » : gardes,
## chiens et opérateurs ressortent en blanc (un matériau de repérage à la
## place du leur, `HOT_COLOR`, que le filtre change en blanc), et la
## fumée et le gaz deviennent transparents.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Amplification de la lumière, grain, lignes, vignettage.
uniform float gain = 6.0;
uniform float grain = 0.09;
uniform float lines = 0.07;
uniform float vignette = 0.62;
// Vue thermique : niveaux de gris, corps chauds en blanc.
uniform bool thermal = false;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	// Amplification qui sature en douceur (les lampes éblouissent).
	l = 1.0 - exp(-l * gain);
	l += (noise(FRAGCOORD.xy + fract(TIME * 7.13) * 311.0) - 0.5) * grain;
	l *= 1.0 - lines * (0.5 + 0.5 * sin(FRAGCOORD.y * 1.6));
	vec3 phosphor = vec3(0.32, 1.0, 0.42) * l;
	if (thermal) {
		// Corps chauds : repérés par leur teinte magenta (`HOT_COLOR`).
		float heat = smoothstep(0.25, 0.5, min(c.r, c.b) - c.g);
		float cold = 0.1 + 0.28 * (1.0 - exp(-dot(c, vec3(0.3, 0.59, 0.11)) * gain * 0.6));
		cold += (noise(FRAGCOORD.xy + fract(TIME * 5.31) * 173.0) - 0.5) * grain * 0.5;
		phosphor = vec3(mix(cold, 0.97, heat));
	}
	// Couleurs vives (cônes, marqueurs d'équipe) : leur teinte reste lisible.
	float top = max(max(c.r, c.g), c.b);
	float saturation = (top - min(min(c.r, c.g), c.b)) / max(top, 0.001);
	float vivid = smoothstep(0.55, 0.8, saturation) * smoothstep(0.25, 0.45, top);
	float keep = thermal ? 0.0 : vivid * 0.8;
	vec3 color = mix(phosphor, clamp(c * gain * 0.5, 0.0, 1.0), keep);
	if (thermal) {
		// Cônes et marqueurs : leur teinte reste lisible, sans les corps.
		float body = smoothstep(0.25, 0.5, min(c.r, c.b) - c.g);
		color = mix(color, clamp(c * 1.2, 0.0, 1.0), vivid * 0.7 * (1.0 - body));
	}
	// Vignettage circulaire (champ des jumelles).
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float edge = 1.0 - smoothstep(vignette * 0.7, vignette, length(d));
	COLOR = vec4(color * (0.25 + 0.75 * edge), 1.0);
}
"""

## Teinte de repérage des corps chauds (vue thermique).
const HOT_COLOR := Color(1.0, 0.0, 1.0)
## Groupes des corps chauds.
const HOT_GROUPS: Array[StringName] = [&"enemies", &"commandos"]
## Intervalle (s) entre deux mises à jour des corps et des nuages repérés
## (modèles reconstruits, nouveaux nuages).
const THERMAL_REFRESH := 0.4
const SAVED_META := &"thermal_saved_material"

## Amplification de la lumière la nuit et le jour.
const NIGHT_GAIN := 6.0
const DAY_GAIN := 1.3

## Carte de nuit : jumelles abaissées d'office, forte amplification.
var night: bool = true
## Vrai quand le filtre est affiché.
var active: bool = false
## Vrai quand la vue thermique est affichée.
var thermal: bool = false
var _hot_material: StandardMaterial3D
var _refresh_left: float = 0.0
## Vision nocturne affichée dans la partie en cours (stroboscopes
## infrarouges visibles, `Tiltrotor`).
static var viewing: bool = false
var _filter: ColorRect


func _init(at_night: bool = true) -> void:
	night = at_night


func _ready() -> void:
	name = "NightVision"
	# Sous le HUD (couche 1) : l'interface reste en couleurs.
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	_filter = ColorRect.new()
	_filter.name = "Filter"
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	material.set_shader_parameter(&"gain", NIGHT_GAIN if night else DAY_GAIN)
	_filter.material = material
	add_child(_filter)
	set_active.call_deferred(night and is_available())


## La nuit tombe ou le jour se lève (`DayCycle`) : jumelles abaissées ou
## relevées d'office, gain du filtre adapté.
func set_night(value: bool) -> void:
	night = value
	(_filter.material as ShaderMaterial).set_shader_parameter(&"gain", NIGHT_GAIN if night else DAY_GAIN)
	if night != active:
		set_active(night)


## Vrai si un opérateur vivant porte des JVN.
func is_available() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and unit.profile and unit.profile.wears_nvg():
			return true
	return false


## Vrai si un opérateur vivant a une lunette thermique.
func thermal_available() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and unit.has_thermal_scope():
			return true
	return false


## Affiche ou retire la vue thermique (refusé sans lunette thermique).
func set_thermal(value: bool) -> void:
	thermal = value and thermal_available()
	if thermal and active:
		set_active(false)
	(_filter.material as ShaderMaterial).set_shader_parameter(&"thermal", thermal)
	(_filter.material as ShaderMaterial).set_shader_parameter(&"gain", NIGHT_GAIN if night else DAY_GAIN)
	_filter.visible = active or thermal
	_refresh_left = 0.0
	_mark_heat()


## Allume ou éteint les JVN (refusé sans opérateur qui en porte).
func set_active(value: bool) -> void:
	active = value and is_available()
	if active and thermal:
		set_thermal(false)
	viewing = active
	(_filter.material as ShaderMaterial).set_shader_parameter(&"thermal", false)
	_filter.visible = active or thermal
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and unit.profile and unit.profile.wears_nvg():
			unit.set_nvg_lowered(active)


func _exit_tree() -> void:
	viewing = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_nvg") and not get_tree().paused:
		# Jumelles, puis vue thermique, puis rien (selon l'équipement).
		if active:
			set_active(false)
			set_thermal(true)
		elif thermal:
			set_thermal(false)
		else:
			set_active(true)
			if not active:
				set_thermal(true)
		Sfx.play_ui(&"clink" if active or thermal else &"select")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Le dernier porteur de JVN tombé : retour à la nuit noire.
	if active and not is_available():
		set_active(false)
	if thermal and not thermal_available():
		set_thermal(false)
	if thermal:
		_refresh_left -= delta
		if _refresh_left <= 0.0:
			_refresh_left = THERMAL_REFRESH
			_mark_heat()


## Pose (`hot`) ou retire (null) le matériau de repérage d'un maillage : il
## remplace le sien, gardé à part (méta `SAVED_META`) pour être rendu.
func _heat(mesh: GeometryInstance3D, hot: Material) -> void:
	if hot:
		if not mesh.has_meta(SAVED_META):
			mesh.set_meta(SAVED_META, mesh.material_override)
			mesh.material_override = hot
	elif mesh.has_meta(SAVED_META):
		mesh.material_override = mesh.get_meta(SAVED_META)
		mesh.remove_meta(SAVED_META)


## Vue thermique : repère les corps chauds (matériau qui remplace celui de
## leurs maillages) et rend la fumée transparente ; hors vue thermique, défait
## tout.
func _mark_heat() -> void:
	if _hot_material == null:
		_hot_material = StandardMaterial3D.new()
		_hot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hot_material.albedo_color = HOT_COLOR
	var overlay: Material = _hot_material if thermal else null
	for group in HOT_GROUPS:
		for body in get_tree().get_nodes_in_group(group):
			var hot := overlay
			if body is Enemy and (body as Enemy).is_dead:
				hot = null
			# Seulement le corps (modèle d'homme ou de chien), pas le cône de
			# vision ni les jauges et marques.
			for model in (body as Node).get_children():
				if not (model is SoldierModel or model is DogModel):
					continue
				for mesh in model.find_children("*", "GeometryInstance3D", true, false):
					_heat(mesh as GeometryInstance3D, hot)
	for group: StringName in [SmokeCloud.GROUP, GasCloud.GAS_GROUP]:
		for cloud in get_tree().get_nodes_in_group(group):
			(cloud as SmokeCloud)._particles.visible = not thermal
