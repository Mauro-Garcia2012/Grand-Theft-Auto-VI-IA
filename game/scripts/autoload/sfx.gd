extends Node
## Sound manager. Gunshots / explosions / engines / sirens are synthesized at startup
## (no copyrighted audio); footsteps and impacts are CC0 Kenney samples.

const RATE := 22050
var streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _pi := 0
var _pi2 := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	for i in 40:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 220.0
		p.unit_size = 8.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	for i in 10:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_pool2d.append(p2)
	_build()


func _build() -> void:
	streams["pistol"] = [_gunshot(0.28, 0.9, 110.0, 0.55)]
	streams["smg"] = [_gunshot(0.14, 0.75, 140.0, 0.4)]
	streams["rifle"] = [_gunshot(0.32, 1.0, 90.0, 0.6)]
	streams["shotgun"] = [_gunshot(0.55, 1.0, 60.0, 0.9)]
	streams["sniper"] = [_gunshot(1.1, 1.0, 55.0, 1.0, true)]
	streams["rpg"] = [_whoosh(0.8)]
	streams["explosion"] = [_explosion(2.4)]
	streams["engine"] = [_engine_loop()]
	streams["siren"] = [_siren_loop()]
	streams["horn"] = [_horn()]
	streams["swing"] = [_whoosh(0.18, 0.4)]
	streams["dry"] = [_click(0.05, 2400.0)]
	streams["reload"] = [_click(0.08, 1200.0)]
	streams["impact"] = [_click(0.06, 900.0, 0.5)]
	streams["beep"] = [_tone(0.12, 880.0)]
	streams["wanted"] = [_tone(0.35, 440.0, 660.0)]
	streams["splash"] = [_splash()]
	streams["skid"] = [_skid_loop()]
	streams["step"] = _load_many(["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003"])
	streams["step_grass"] = _load_many(["footstep_grass_000", "footstep_grass_001"])
	streams["punch"] = _load_many(["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002", "impactPunch_medium_000"])
	streams["crash"] = _load_many(["impactMetal_heavy_000", "impactMetal_heavy_001", "impactMetal_heavy_002", "impactPlate_heavy_000"])
	streams["ricochet"] = _load_many(["impactMetal_light_000", "impactMetal_light_001"])
	streams["glass"] = _load_many(["impactGlass_heavy_000", "impactGlass_heavy_001"])
	streams["thud"] = _load_many(["impactSoft_heavy_000", "impactGeneric_light_000"])
	streams["pickup"] = _load_many(["powerUp2"])
	streams["money"] = _load_many(["pepSound1"])
	streams["ui"] = _load_many(["click1"])
	streams["ui_move"] = _load_many(["rollover2"])


func _load_many(names: Array) -> Array:
	var out := []
	for n in names:
		var s = load("res://assets/audio/%s.ogg" % n)
		if s:
			out.append(s)
	return out


func get_stream(name: String) -> AudioStream:
	var a: Array = streams.get(name, [])
	if a.is_empty():
		return null
	return a[_rng.randi() % a.size()]


func play_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	var s := get_stream(name)
	if s == null:
		return
	var p := _pool[_pi]
	_pi = (_pi + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()


func play(name: String, db := 0.0, pitch := 1.0) -> void:
	var s := get_stream(name)
	if s == null:
		return
	var p := _pool2d[_pi2]
	_pi2 = (_pi2 + 1) % _pool2d.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


# --------------------------------------------------------------- synthesis
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _gunshot(dur: float, vol: float, thump_hz: float, body: float, echo := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		lp = lp + (noise - lp) * 0.45
		lp2 = lp2 + (noise - lp2) * 0.08
		var crack := noise * exp(-t * 90.0)
		var boom := lp2 * exp(-t * (14.0 / body)) * 1.4
		var thump := sin(TAU * thump_hz * t * (1.0 - t * 1.5)) * exp(-t * 18.0) * 0.9
		var v := crack * 0.7 + boom + thump + lp * exp(-t * 30.0) * 0.4
		if echo and t > 0.18:
			v += lp2 * exp(-(t - 0.18) * 5.0) * 0.35
		s[i] = v * vol * 0.8
	return _wav(s)


func _whoosh(dur: float, vol := 0.8) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var a := 0.05 + 0.4 * t
		lp += (_rng.randf_range(-1, 1) - lp) * a
		s[i] = lp * sin(PI * t) * vol * 2.0
	return _wav(s)


func _explosion(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1, 1)
		lp += (noise - lp) * 0.06
		lp2 += (noise - lp2) * 0.015
		var env := exp(-t * 2.2) * (1.0 - exp(-t * 200.0))
		var v := (lp * 1.6 + lp2 * 4.0) * env + noise * exp(-t * 40.0) * 0.5
		v += sin(TAU * 45.0 * t) * exp(-t * 4.0) * 0.6
		s[i] = clampf(v, -1, 1)
	return _wav(s)


func _engine_loop() -> AudioStreamWAV:
	# 1 second loop, base 50 Hz with harmonics (pitch_scale changes RPM)
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 50.0
		var ph := fmod(t * f, 1.0)
		var saw := ph * 2.0 - 1.0
		var v := saw * 0.35 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.0 * t) * 0.12 + sin(TAU * f * 0.5 * t) * 0.2
		lp += (_rng.randf_range(-1, 1) - lp) * 0.2
		v += lp * 0.12
		v *= 0.8 + 0.2 * sin(TAU * f * 0.25 * t)
		s[i] = v * 0.6
	return _wav(s, true)


func _siren_loop() -> AudioStreamWAV:
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := 650.0 + 550.0 * (0.5 - 0.5 * cos(TAU * t))
		ph += f / RATE
		var v := sin(TAU * ph) * 0.6 + sin(TAU * ph * 2.0) * 0.15
		s[i] = v * 0.5
	return _wav(s, true)


func _horn() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := signf(sin(TAU * 400.0 * t)) * 0.3 + signf(sin(TAU * 505.0 * t)) * 0.3
		var env := minf(1.0, t * 60.0) * minf(1.0, (0.5 - t) * 30.0)
		s[i] = v * env * 0.5
	return _wav(s, true)


func _click(dur: float, hz: float, vol := 0.6) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * hz * t) * 0.5 + _rng.randf_range(-1, 1) * 0.5) * exp(-t * 60.0) * vol
	return _wav(s)


func _tone(dur: float, hz: float, hz2 := -1.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := hz if hz2 < 0.0 or t < dur * 0.5 else hz2
		s[i] = sin(TAU * f * t) * 0.4 * minf(1.0, (dur - t) * 20.0)
	return _wav(s)


func _splash() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.3
		s[i] = lp * exp(-t * 5.0) * 1.2
	return _wav(s)


func _skid_loop() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.5
		s[i] = (lp * 0.5 + sin(TAU * 1100.0 * t) * 0.1 * (0.6 + 0.4 * sin(TAU * 13.0 * t))) * 0.5
	return _wav(s, true)
