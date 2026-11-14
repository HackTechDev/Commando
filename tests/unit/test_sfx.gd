extends GutTest
## Sons synthétisés (`Sfx`) : bibliothèque complète, sans saturation.

const SOUNDS: Array[StringName] = [&"shot", &"shot_suppressed", &"step", &"crawl", &"hit", &"punch", &"fall", &"knife", &"block", &"whoosh", &"clink", &"reload", &"scrape", &"alert", &"suspicious", &"select", &"order", &"arm", &"denied"]


func test_library_is_complete() -> void:
	for sound in SOUNDS:
		assert_true(Sfx.has_sound(sound), sound)


func test_streams_are_short_16_bit_and_not_clipped() -> void:
	for sound in SOUNDS:
		var stream: AudioStreamWAV = Sfx._streams[sound]
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, sound)
		var samples := stream.data.size() / 2
		assert_between(samples, 100, Sfx.MIX_RATE * 2, "%s : durée" % sound)
		var peak := 0
		for i in samples:
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		assert_lte(peak, int(0.9 * 32767.0) + 1, "%s : crête ≤ 0,9" % sound)
