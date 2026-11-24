@tool
class_name Rainfall
extends WeatherParticles
## Pluie (cartes urbaines) : gouttes en traits fins qui tombent vite, un peu
## inclinées par le vent, et le bruit de l'averse (boucle de bruit filtré,
## synthétisée au démarrage, non spatialisée, bus « SFX »).

const MIX_RATE := 22050
## Durée de la boucle sonore et du fondu qui en raccorde les bouts (s).
const LOOP_TIME := 3.0
const LOOP_FADE := 0.25

## Nombre de gouttes.
@export var drops: int = 2400:
	set(value):
		drops = value
		_reconfigure()
## Vent (m/s) : inclinaison des gouttes.
@export var wind := Vector3(1.2, 0.0, 0.5):
	set(value):
		wind = value
		_reconfigure()
## Volume du bruit de la pluie (dB).
@export var volume_db: float = -14.0

var _sound: AudioStreamPlayer


func _configure(particles: GPUParticles3D) -> void:
	var motion := falling_motion(14.0, 17.0, -4.0, wind)
	motion.spread = 2.0
	motion.scale_min = 0.8
	motion.scale_max = 1.2
	particles.process_material = motion
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Trait vertical tourné vers la caméra autour de son axe.
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.albedo_color = Color(0.78, 0.84, 0.92, 0.3)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = look
	particles.draw_pass_1 = drop
	_setup(particles, drops, 1.4)
	# Le bruit de l'averse : en jeu seulement.
	if not Engine.is_editor_hint() and _sound == null:
		_sound = AudioStreamPlayer.new()
		_sound.name = "RainSound"
		_sound.bus = &"SFX"
		_sound.volume_db = volume_db
		_sound.stream = rain_loop()
		add_child(_sound, false, Node.INTERNAL_MODE_FRONT)
		_sound.play()


func _exit_tree() -> void:
	if _sound:
		_sound.stop()


## Bruit d'averse en boucle : bruit blanc adouci (passe-bas à un pôle),
## dont la fin est fondue dans le début pour un raccord sans clic.
static func rain_loop() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var total := int(MIX_RATE * (LOOP_TIME + LOOP_FADE))
	var fade := int(MIX_RATE * LOOP_FADE)
	var raw := PackedFloat32Array()
	raw.resize(total)
	var low := 0.0
	for i in total:
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.35
		raw[i] = low
	var count := total - fade
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value := raw[i]
		if i < fade:
			var t := float(i) / fade
			value = value * t + raw[count + i] * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(value * 1.4, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	stream.data = data
	return stream
