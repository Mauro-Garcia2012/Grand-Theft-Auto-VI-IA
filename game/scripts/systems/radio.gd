class_name Radio
extends Node
## Procedurally synthesized car radio (no copyrighted music):
##  - VICE FM 80.6: synthwave (bass, pads, arpeggio, gated drums)
##  - RADIO LEONIDA: latin/dembow rhythm with plucks
##  - Apagada

const RATE := 22050.0
const STATIONS := ["VICE FM 80.6  ·  Synthwave", "RADIO LEONIDA 104.2  ·  Ritmo latino", "Radio apagada"]

var station := 0
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var t := 0.0
var bpm := 108.0
var _rng := RandomNumberGenerator.new()
var _lp_noise := 0.0
var _pad_ph := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _bass_ph := 0.0
var _arp_ph := 0.0
var _song_seed := 0
var _prog := []
var _active := false
var volume := 0.55


func _ready() -> void:
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -9.0
	add_child(player)
	_new_song()


func _new_song() -> void:
	_song_seed = randi()
	_rng.seed = _song_seed
	var progs := [[57, 53, 48, 55], [50, 46, 53, 48], [52, 48, 55, 50], [45, 41, 48, 43], [53, 55, 52, 57]]
	_prog = progs[_rng.randi() % progs.size()]
	bpm = [100.0, 108.0, 112.0, 118.0][_rng.randi() % 4] if station == 0 else [92.0, 96.0, 100.0][_rng.randi() % 3]


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("radio") and Game.player and Game.player.vehicle:
		station = (station + 1) % STATIONS.size()
		_new_song()
		if Game.hud:
			Game.hud.radio_name(STATIONS[station])


func _process(_delta: float) -> void:
	var in_car := Game.player != null and Game.player.vehicle != null and not Game.paused and station != 2
	if in_car and not _active:
		_active = true
		player.play()
		playback = player.get_stream_playback()
		if Game.hud:
			Game.hud.radio_name(STATIONS[station])
	elif not in_car and _active:
		_active = false
		player.stop()
		playback = null
	if _active and playback:
		_fill()


static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _fill() -> void:
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	var beat_len := 60.0 / bpm
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var s := 0.0
		var beat := t / beat_len
		var bar := int(beat / 4.0)
		var chord_root: float = _prog[bar % _prog.size()]
		var b16 := fmod(beat * 4.0, 1.0)          # position inside a 16th note
		var step16 := int(beat * 4.0) % 16
		var bpos := fmod(beat, 1.0)
		if station == 0:
			# --- synthwave
			# kick on every beat
			var kt := bpos * beat_len
			s += sin(TAU * (50.0 + 90.0 * exp(-kt * 30.0)) * kt) * exp(-kt * 9.0) * 0.8
			# snare on 2 & 4 (gated noise)
			var bi := int(beat) % 4
			if bi == 1 or bi == 3:
				_lp_noise += (_rng.randf_range(-1, 1) - _lp_noise) * 0.6
				s += _lp_noise * exp(-kt * 14.0) * 0.45
			# hats 16ths
			var ht := b16 * beat_len * 0.25
			s += _rng.randf_range(-1, 1) * exp(-ht * 120.0) * 0.07
			# bass: 8th notes, root
			var bf := _midi(chord_root - 24.0 + (12.0 if step16 % 4 == 2 else 0.0))
			_bass_ph = fmod(_bass_ph + bf / RATE, 1.0)
			var bass := (_bass_ph * 2.0 - 1.0) * 0.28 * (1.0 - fmod(beat * 2.0, 1.0) * 0.6)
			s += bass
			# pad: minor/major triad detuned saws
			var chord := [0.0, 3.0 if int(chord_root) % 2 == 1 else 4.0, 7.0]
			for k in 3:
				var f := _midi(chord_root + chord[k])
				_pad_ph[k] = fmod(_pad_ph[k] + f / RATE, 1.0)
				_pad_ph[k + 3] = fmod(_pad_ph[k + 3] + f * 1.006 / RATE, 1.0)
				s += ((_pad_ph[k] * 2.0 - 1.0) + (_pad_ph[k + 3] * 2.0 - 1.0)) * 0.035
			# arpeggio 16ths
			var arp_notes := [0.0, 7.0, 12.0, chord[1] + 12.0]
			var af := _midi(chord_root + 12.0 + arp_notes[step16 % 4])
			_arp_ph = fmod(_arp_ph + af / RATE, 1.0)
			s += (1.0 if _arp_ph < 0.5 else -1.0) * 0.06 * exp(-b16 * 3.0)
		else:
			# --- latin dembow: kick 1 & 3-ish, snare on the "and-a"
			var kt := bpos * beat_len
			var bi := int(beat) % 4
			s += sin(TAU * (55.0 + 70.0 * exp(-kt * 35.0)) * kt) * exp(-kt * 10.0) * 0.8
			var pat := [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0]
			if pat[step16] == 1:
				var st := b16 * beat_len * 0.25
				_lp_noise += (_rng.randf_range(-1, 1) - _lp_noise) * 0.7
				s += _lp_noise * exp(-st * 40.0) * 0.5
			s += _rng.randf_range(-1, 1) * exp(-b16 * beat_len * 0.25 * 150.0) * 0.05 * (1.0 if step16 % 2 == 0 else 0.5)
			# bass
			var bf := _midi(chord_root - 24.0)
			_bass_ph = fmod(_bass_ph + bf / RATE, 1.0)
			s += sin(TAU * _bass_ph) * 0.35 * (1.0 if bi != 1 else 0.6)
			# plucked marimba-ish melody on selected 16ths
			_rng.seed = _song_seed + bar * 16 + step16
			var play_note := _rng.randf() < 0.45
			if play_note:
				var scale := [0.0, 2.0, 3.0, 5.0, 7.0, 8.0, 10.0, 12.0]
				var nf := _midi(chord_root + 12.0 + scale[_rng.randi() % scale.size()])
				var nt := b16 * beat_len * 0.25
				s += sin(TAU * nf * nt) * exp(-nt * 18.0) * 0.18
			_rng.seed = int(t * 1000.0) + i
		# song change every ~3 minutes
		t += 1.0 / RATE
		if t > 180.0:
			t = 0.0
			_new_song()
		s = clampf(s * volume, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	playback.push_buffer(buf)
