extends Node
## Effets sonores provisoires, synthétisés au démarrage (bruit filtré,
## bips), en attendant de vrais sons CC0 (M10).
##
## `play_at` joue un son positionnel 3D (bus « SFX ») ; `play_ui` un son
## d'interface non spatialisé (bus « UI »). Les sons sont générés une fois et
## mis en cache.

## Émis à chaque son joué (tests, futurs sous-titres d'accessibilité).
signal played(sound: StringName, position: Vector3)

const MIX_RATE := 22050
## Portée et atténuation des sons 3D (voir l'écouteur de `CameraRig`).
const UNIT_SIZE := 10.0
const MAX_DISTANCE := 60.0
## Nombre maximal de sons 3D simultanés (les plus anciens sont coupés).
const MAX_VOICES := 32

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 12345
	_build_library()


## À la fermeture du jeu, coupe les sons en cours : sinon le serveur audio
## garde leurs flux et Godot signale des fuites.
func _exit_tree() -> void:
	for player in _voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_voices.clear()


## Joue `sound` à `position` (monde). `pitch_jitter` varie la hauteur pour
## éviter l'effet mitraillette des sons répétés.
func play_at(sound: StringName, position: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var stream: AudioStream = _streams.get(sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null or not scene.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	scene.add_child(player)
	player.global_position = position
	player.finished.connect(_on_voice_finished.bind(player))
	player.play()
	played.emit(sound, position)
	_voices.append(player)
	if _voices.size() > MAX_VOICES:
		var oldest: AudioStreamPlayer3D = _voices.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Joue un son d'interface (bips de sélection, d'ordre…), non spatialisé.
func play_ui(sound: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"UI"
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	played.emit(sound, Vector3.INF)


## Vrai si le son `sound` existe.
func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


func _on_voice_finished(player: AudioStreamPlayer3D) -> void:
	_voices.erase(player)
	player.queue_free()


# --- Synthèse ---------------------------------------------------------------

func _build_library() -> void:
	# Tir à silencieux (opérateurs) : claquement sourd et bref.
	_streams[&"shot_suppressed"] = _wav(_mix([
		_noise(0.09, 0.001, 0.05, 0.35, 0.9),
		_tone([180.0, 70.0], 0.08, 0.6, 0.002, 0.06),
	]))
	# Tir ennemi (sans silencieux) : détonation et queue.
	_streams[&"shot"] = _wav(_mix([
		_noise(0.35, 0.001, 0.12, 0.8, 1.0),
		_tone([140.0, 45.0], 0.25, 0.8, 0.001, 0.15),
	]))
	# Pas : petit frottement grave ; reptation : bruissement plus long.
	_streams[&"step"] = _wav(_noise(0.06, 0.002, 0.03, 0.12, 0.7))
	_streams[&"crawl"] = _wav(_noise(0.22, 0.05, 0.1, 0.18, 0.4))
	# Impact sur un corps, coup de poing ou de crosse, chute d'un corps.
	_streams[&"hit"] = _wav(_mix([
		_noise(0.08, 0.001, 0.04, 0.25, 0.8),
		_tone([110.0, 60.0], 0.1, 0.7, 0.001, 0.06),
	]))
	_streams[&"punch"] = _wav(_mix([
		_noise(0.07, 0.001, 0.03, 0.3, 0.7),
		_tone([150.0, 80.0], 0.08, 0.8, 0.001, 0.05),
	]))
	_streams[&"fall"] = _wav(_mix([
		_noise(0.25, 0.005, 0.12, 0.08, 1.0),
		_tone([70.0, 40.0], 0.3, 0.9, 0.003, 0.15),
	]))
	# Couteau : lame qui tranche (souffle aigu bref).
	_streams[&"knife"] = _wav(_sweep_noise(0.16, 0.6, 0.95, 0.5))
	# Parade : choc sec ; esquive, lancer : souffle.
	_streams[&"block"] = _wav(_mix([
		_noise(0.05, 0.001, 0.02, 0.7, 0.8),
		_tone([900.0, 700.0], 0.06, 0.25, 0.001, 0.03),
	]))
	_streams[&"whoosh"] = _wav(_sweep_noise(0.22, 0.1, 0.5, 0.5))
	# Couteau qui tombe au sol : tintement métallique.
	_streams[&"clink"] = _wav(_mix([
		_tone([2400.0, 2300.0], 0.25, 0.35, 0.001, 0.08),
		_tone([3700.0, 3600.0], 0.18, 0.2, 0.001, 0.05),
	]))
	# Rechargement : deux déclics.
	_streams[&"reload"] = _wav(_concat([
		_noise(0.03, 0.001, 0.01, 0.9, 0.7),
		_silence(0.35),
		_noise(0.04, 0.001, 0.015, 0.9, 0.9),
	]))
	# Explosion : souffle grave et long, grondement.
	_streams[&"explosion"] = _wav(_mix([
		_noise(1.3, 0.002, 0.45, 0.45, 1.0),
		_tone([95.0, 28.0], 1.0, 1.0, 0.002, 0.4),
	]))
	# Trousse de soins : bande qu'on déchire.
	_streams[&"bandage"] = _wav(_sweep_noise(0.35, 0.3, 0.8, 0.35))
	# Caisse qui frotte au sol.
	_streams[&"scrape"] = _wav(_noise(0.5, 0.05, 0.35, 0.1, 0.6))
	# Alerte : deux bips montants ; méfiance : un bip interrogatif.
	_streams[&"alert"] = _wav(_concat([
		_tone([880.0, 880.0], 0.1, 0.5, 0.005, 0.02),
		_tone([1320.0, 1320.0], 0.16, 0.5, 0.005, 0.05),
	]))
	_streams[&"suspicious"] = _wav(_tone([600.0, 900.0], 0.18, 0.35, 0.01, 0.05))
	# Interface : sélection, ordre, action armée.
	_streams[&"select"] = _wav(_tone([1000.0, 1000.0], 0.05, 0.3, 0.003, 0.02))
	_streams[&"order"] = _wav(_concat([
		_tone([700.0, 700.0], 0.045, 0.3, 0.003, 0.015),
		_tone([1050.0, 1050.0], 0.06, 0.3, 0.003, 0.02),
	]))
	_streams[&"arm"] = _wav(_tone([1400.0, 1600.0], 0.05, 0.25, 0.002, 0.02))
	_streams[&"denied"] = _wav(_tone([300.0, 220.0], 0.15, 0.35, 0.005, 0.05))


## Bruit blanc filtré passe-bas (`brightness` de 0, sourd, à 1, clair),
## avec attaque et décroissance exponentielle (`decay` en secondes).
func _noise(duration: float, attack: float, decay: float, brightness: float, gain: float) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var alpha := clampf(brightness, 0.01, 1.0)
	var low := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		low += alpha * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * _envelope(t, attack, decay) * gain / sqrt(alpha)
	return samples


## Bruit dont le filtre s'ouvre de `from` à `to` (souffle, lame).
func _sweep_noise(duration: float, from: float, to: float, gain: float) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var u := float(i) / count
		var alpha := lerpf(from, to, u)
		low += alpha * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * sin(PI * u) * gain
	return samples


## Sinus glissant de `freqs[0]` à `freqs[1]` Hz.
func _tone(freqs: Array, duration: float, gain: float, attack: float, decay: float) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var freq := lerpf(freqs[0], freqs[1], float(i) / count)
		phase += TAU * freq / MIX_RATE
		samples[i] = sin(phase) * _envelope(t, attack, decay) * gain
	return samples


func _silence(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(duration * MIX_RATE))
	return samples


func _envelope(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / maxf(decay, 0.001))


func _mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for part: PackedFloat32Array in parts:
		length = maxi(length, part.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for part: PackedFloat32Array in parts:
		for i in part.size():
			out[i] += part[i]
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		out.append_array(part)
	return out


## Convertit en flux 16 bits mono, avec un court fondu de fin ; un son trop
## fort est ramené à une crête de 0,9 au lieu d'être écrêté.
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	if peak > 0.9:
		for i in samples.size():
			samples[i] *= 0.9 / peak
	var fade := mini(64, samples.size())
	for i in fade:
		samples[samples.size() - 1 - i] *= float(i) / fade
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
