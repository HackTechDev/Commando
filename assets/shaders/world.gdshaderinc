// Décor des cartes UFO:AI. Inclus par les variantes générées par
// `WorldMaterial` (opaque, découpé, transparent), qui fixent `render_mode`
// et définissent ALPHA_SCISSOR ou ALPHA_BLEND.
//
// Deux effacements, en pointillé (le décor reste dans la passe opaque) :
// - autour de chaque opérateur (`see_through_1` à `_6`, xyz : torse, w : 1
//   si actif), ce qui est entre la caméra et lui ;
// - sur un toit (`reveal` de 0 à 1), seulement la partie au-dessus de
//   l'intérieur qu'il couvre (`reveal_mask`, posé sur `reveal_rect` :
//   x, z du coin, largeur, profondeur).

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_emission = false;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float reveal = 0.0;
uniform sampler2D reveal_mask : filter_linear, repeat_disable;
uniform vec4 reveal_rect = vec4(0.0, 0.0, 1.0, 1.0);

global uniform vec4 see_through_1;
global uniform vec4 see_through_2;
global uniform vec4 see_through_3;
global uniform vec4 see_through_4;
global uniform vec4 see_through_5;
global uniform vec4 see_through_6;

// Rayon (à l'écran, en mètres) de la découpe pleine, puis du fondu.
const float SEE_RADIUS = 1.0;
const float SEE_FADE = 0.5;
// Marge devant l'opérateur, et hauteur au-dessus de ses pieds, en deçà
// desquelles rien n'est découpé (le sol qu'il foule, son abri bas).
const float SEE_DEPTH = 0.6;
const float SEE_FEET = 0.35;
// Hauteur du torse au-dessus des pieds (voir `UfoMapLevel`).
const float TORSO = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Seuil de pointillé (matrice de Bayer 4 × 4), dans ]0, 1[.
float dither(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	int index = x + y * 4;
	const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (BAYER[index] + 0.5) / 16.0;
}

float see_through(vec4 op, vec3 view_pos, mat4 view, float height) {
	if (op.w <= 0.0 || height < op.y - TORSO + SEE_FEET) {
		return 0.0;
	}
	vec3 op_view = (view * vec4(op.xyz, 1.0)).xyz;
	if (view_pos.z < op_view.z + SEE_DEPTH) {
		return 0.0;
	}
	float d = length(view_pos.xy - op_view.xy);
	return 1.0 - smoothstep(SEE_RADIUS, SEE_RADIUS + SEE_FADE, d);
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.9;
	if (use_normal) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
	if (use_emission) {
		EMISSION = texture(emission_texture, UV).rgb;
	}
	float hide = 0.0;
	if (reveal > 0.0) {
		vec2 at = (world_pos.xz - reveal_rect.xy) / reveal_rect.zw;
		if (at.x >= 0.0 && at.y >= 0.0 && at.x <= 1.0 && at.y <= 1.0) {
			hide = reveal * texture(reveal_mask, at).r;
		}
	}
	// La découpe ne vaut que vue de la caméra : les ombres restent entières.
	if (!IN_SHADOW_PASS) {
		hide = max(hide, see_through(see_through_1, VERTEX, VIEW_MATRIX, world_pos.y));
		hide = max(hide, see_through(see_through_2, VERTEX, VIEW_MATRIX, world_pos.y));
		hide = max(hide, see_through(see_through_3, VERTEX, VIEW_MATRIX, world_pos.y));
		hide = max(hide, see_through(see_through_4, VERTEX, VIEW_MATRIX, world_pos.y));
		hide = max(hide, see_through(see_through_5, VERTEX, VIEW_MATRIX, world_pos.y));
		hide = max(hide, see_through(see_through_6, VERTEX, VIEW_MATRIX, world_pos.y));
	}
	if (hide > dither(FRAGCOORD.xy)) {
		discard;
	}
#if defined(ALPHA_SCISSOR)
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#elif defined(ALPHA_BLEND)
	ALPHA = albedo.a;
#endif
}
