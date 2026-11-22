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

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Amplification de la lumière, grain, lignes, vignettage.
uniform float gain = 6.0;
uniform float grain = 0.09;
uniform float lines = 0.07;
uniform float vignette = 0.62;

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
	// Couleurs vives (cônes, marqueurs d'équipe) : leur teinte reste lisible.
	float top = max(max(c.r, c.g), c.b);
	float saturation = (top - min(min(c.r, c.g), c.b)) / max(top, 0.001);
	float vivid = smoothstep(0.55, 0.8, saturation) * smoothstep(0.25, 0.45, top);
	vec3 color = mix(phosphor, clamp(c * gain * 0.5, 0.0, 1.0), vivid * 0.8);
	// Vignettage circulaire (champ des jumelles).
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float edge = 1.0 - smoothstep(vignette * 0.7, vignette, length(d));
	COLOR = vec4(color * (0.25 + 0.75 * edge), 1.0);
}
"""

## Amplification de la lumière la nuit et le jour.
const NIGHT_GAIN := 6.0
const DAY_GAIN := 1.3

## Carte de nuit : jumelles abaissées d'office, forte amplification.
var night: bool = true
## Vrai quand le filtre est affiché.
var active: bool = false
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


## Vrai si un opérateur vivant porte des JVN.
func is_available() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and unit.profile and unit.profile.wears_nvg():
			return true
	return false


## Allume ou éteint les JVN (refusé sans opérateur qui en porte).
func set_active(value: bool) -> void:
	active = value and is_available()
	viewing = active
	_filter.visible = active
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and unit.profile and unit.profile.wears_nvg():
			unit.set_nvg_lowered(active)


func _exit_tree() -> void:
	viewing = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_nvg") and not get_tree().paused:
		set_active(not active)
		Sfx.play_ui(&"clink" if active else &"select")
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Le dernier porteur de JVN tombé : retour à la nuit noire.
	if active and not is_available():
		set_active(false)
