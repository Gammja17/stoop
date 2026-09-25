extends Node
## 효과음/음악/바람 소리. 새 울음·타격음 일부는 코드로 합성한다.

const MIX := 22050

const FILES := {
	"hit": ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002", "impactPunch_heavy_003"],
	"hit_med": ["impactPunch_medium_000", "impactPunch_medium_001"],
	"crash": ["impactSoft_heavy_000", "impactSoft_heavy_001"],
	"thud": ["impactSoft_medium_000"],
	"tap": ["impactGeneric_light_000", "impactGeneric_light_001"],
	"wood": ["impactWood_heavy_000"],
	"step": ["footstep_grass_000", "footstep_grass_001"],
	"ui_click": ["click_002"],
	"ui_select": ["select_001"],
	"ui_hover": ["select_004"],
	"ui_confirm": ["confirmation_001"],
	"ui_good": ["confirmation_002"],
	"ui_back": ["back_001"],
	"ui_open": ["open_001"],
	"ui_close": ["close_001"],
	"ui_error": ["error_004"],
	"notify": ["maximize_006"],
	"pluck": ["pluck_001"],
	"drop": ["drop_002"],
	"bong": ["bong_001"],
}

const MUSIC := {
	"title": "res://assets/audio/music/music_contemplation.mp3",
	"calm": "res://assets/audio/music/music_aurora.mp3",
	"hunt": "res://assets/audio/music/music_pursuit.ogg",
	"danger": "res://assets/audio/music/music_battle.mp3",
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next3d := 0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur := ""
var music_gain := 0.0            # 지금 곡에만 더하는 음량(dB). 다이나믹 음악이 쓴다
var _fade := [-80.0, -80.0]      # 두 음악 플레이어의 크로스페이드 음량(dB)
var _cur_idx := 0
var _waves: AudioStreamPlayer

# 바람(절차적)
var _wind_player: AudioStreamPlayer
var _wind_pb: AudioStreamGeneratorPlayback
var wind_speed := 0.0      # 0..1
var wind_tuck := 0.0
var wind_muffle := 0.0     # 슬로모션 때 먹먹하게
var wind_enabled := false
var rain_level := 0.0
var _r_prev := 0.0
var _w_amp := 0.0
var _w_lp1 := 0.0
var _w_lp2 := 0.0
var _w_lp3 := 0.0
var _w_svf_low := 0.0
var _w_svf_band := 0.0
var _w_gust := 0.0
var _w_gust_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in FILES:
		var arr := []
		for fname in FILES[key]:
			var path := "res://assets/audio/sfx/%s.ogg" % fname
			if ResourceLoader.exists(path):
				arr.append(load(path))
		_streams[key] = arr
	_build_synth()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 24:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = 18.0
		p3.max_distance = 600.0
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p3)
		_players3d.append(p3)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	_waves = AudioStreamPlayer.new()
	_waves.bus = "Ambience"
	_waves.volume_db = -80.0
	var ws = load("res://assets/audio/ambience/waves_vistula.mp3")
	if ws:
		ws.loop = true
		_waves.stream = ws
	add_child(_waves)
	_wind_player = AudioStreamPlayer.new()
	_wind_player.bus = "Ambience"
	# 웹은 기본이 '샘플' 재생이라 실시간 생성 소리가 안 난다 → 스트림으로 재생
	_wind_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX
	gen.buffer_length = 0.12
	_wind_player.stream = gen
	add_child(_wind_player)


# ---------- 재생 ----------

func _pick(key: String) -> AudioStream:
	var arr: Array = _streams.get(key, [])
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


func play(key: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _pick(key)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = maxf(pitch, 0.05)
	p.play()


func play_at(key: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 500.0) -> void:
	var s := _pick(key)
	if s == null:
		return
	var p := _players3d[_next3d]
	_next3d = (_next3d + 1) % _players3d.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = maxf(pitch, 0.05)
	p.max_distance = max_dist
	p.global_position = pos
	p.play()


func music(key: String, fade: float = 2.5) -> void:
	if key == _music_cur:
		return
	_music_cur = key
	# 음량은 _fade로 섞고 _process에서 플레이어에 반영한다 (웹에서도 동작하도록 버스 효과 대신)
	var inc_i := 1 if (_music_a.playing and float(_fade[0]) > -40.0) else 0
	var out_i := 1 - inc_i
	var incoming: AudioStreamPlayer = _music_b if inc_i == 1 else _music_a
	var tw := create_tween().set_parallel(true)
	if key != "" and MUSIC.has(key):
		var st = load(MUSIC[key])
		st.loop = true
		incoming.stream = st
		_fade[inc_i] = -40.0
		incoming.play()
		tw.tween_method(func(v): _fade[inc_i] = v, -40.0, 0.0, fade)
	_cur_idx = inc_i
	tw.tween_method(func(v): _fade[out_i] = v, float(_fade[out_i]), -80.0, fade)


func _update_music_volume() -> void:
	if _music_a == null:
		return
	var i := 0
	for m: AudioStreamPlayer in [_music_a, _music_b]:
		m.volume_db = float(_fade[i]) + (music_gain if i == _cur_idx else 0.0)
		if i != _cur_idx and float(_fade[i]) < -79.0 and m.playing:
			m.stop()
		i += 1


func set_waves(level: float) -> void:
	if _waves.stream == null:
		return
	if level > 0.01 and not _waves.playing:
		_waves.play()
	_waves.volume_db = lerpf(_waves.volume_db, linear_to_db(maxf(level, 0.0001)) - 4.0, 0.05)


func set_wind_active(on: bool) -> void:
	wind_enabled = on
	if on and not _wind_player.playing:
		_wind_player.play()
		_wind_pb = _wind_player.get_stream_playback()


# ---------- 바람 합성 ----------

func _process(delta: float) -> void:
	_update_music_volume()
	if not wind_enabled or _wind_pb == null:
		return
	var target_amp := 0.03 + 0.95 * pow(clampf(wind_speed, 0.0, 1.0), 1.5)
	var frames := _wind_pb.get_frames_available()
	if frames <= 0:
		return
	var sp := clampf(wind_speed, 0.0, 1.0)
	var bright := lerpf(0.04, 0.42, sp) * (1.0 - 0.75 * wind_muffle)
	var fc := lerpf(500.0, 2600.0, sp) * (1.0 - 0.5 * wind_muffle)
	var f := 2.0 * sin(PI * fc / MIX)
	var q := lerpf(0.55, 0.18, wind_tuck)
	var whistle_mix := (0.08 + 0.35 * wind_tuck) * sp
	for i in frames:
		_w_gust_t -= 1.0 / MIX
		if _w_gust_t <= 0.0:
			_w_gust_t = randf_range(0.3, 1.2)
			_w_gust = randf_range(0.75, 1.15)
		_w_amp += (target_amp * _w_gust - _w_amp) * 0.0004
		var w := randf() * 2.0 - 1.0
		_w_lp1 += (w - _w_lp1) * 0.015
		_w_lp2 += (w - _w_lp2) * bright
		_w_lp3 += (_w_lp2 - _w_lp3) * 0.03
		var band := _w_lp2 - _w_lp3
		var hi := w - _w_svf_low - q * _w_svf_band
		_w_svf_band += f * hi
		_w_svf_low += f * _w_svf_band
		var o := (_w_lp1 * 3.2 + band * 1.3 + _w_svf_band * whistle_mix) * _w_amp
		# 빗소리: 잘게 튀는 고역 잡음
		if rain_level > 0.01:
			var hp := w - _r_prev
			_r_prev = w
			o += hp * rain_level * (0.05 + (0.12 if randf() < 0.02 else 0.0))
		o = clampf(o, -1.0, 1.0)
		_wind_pb.push_frame(Vector2(o, o * 0.96))


# ---------- 합성 효과음 ----------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX
	st.stereo = false
	st.data = bytes
	return st


func _add(key: String, s: PackedFloat32Array) -> void:
	if not _streams.has(key):
		_streams[key] = []
	_streams[key].append(_wav(s))


func _build_synth() -> void:
	seed(1234)
	# 타격 '쿵': 낮게 떨어지는 사인 + 짧은 노이즈 어택
	for v in 2:
		var n := int(MIX * 0.75)
		var s := PackedFloat32Array()
		s.resize(n)
		var ph := 0.0
		var lp := 0.0
		for i in n:
			var t := float(i) / MIX
			var fr := lerpf(120.0 + v * 15.0, 34.0, 1.0 - exp(-t * 7.0))
			ph += TAU * fr / MIX
			var env := exp(-t * 5.5)
			lp += ((randf() * 2.0 - 1.0) - lp) * 0.35
			var click := lp * exp(-t * 60.0) * 0.9
			s[i] = sin(ph) * env * 0.95 + click
		_add("boom", s)
	# 휙: 대역 노이즈 스윕
	for v in 3:
		var n := int(MIX * 0.5)
		var s := PackedFloat32Array()
		s.resize(n)
		var low := 0.0
		var band := 0.0
		for i in n:
			var t := float(i) / n
			var fc := lerpf(350.0, 2400.0 - v * 400.0, sin(t * PI))
			var f := 2.0 * sin(PI * fc / MIX)
			var x := randf() * 2.0 - 1.0
			var hi := x - low - 0.6 * band
			band += f * hi
			low += f * band
			s[i] = band * sin(t * PI) * 0.8
		_add("whoosh", s)
	# 날갯짓: 짧고 낮은 퍼덕
	for v in 3:
		var n := int(MIX * 0.16)
		var s := PackedFloat32Array()
		s.resize(n)
		var lp := 0.0
		for i in n:
			var t := float(i) / n
			lp += ((randf() * 2.0 - 1.0) - lp) * (0.12 + v * 0.03)
			var env := sin(minf(t * 4.0, 1.0) * PI * 0.5) * (1.0 - t) * (1.0 - t)
			s[i] = lp * env * 2.4
		_add("flap", s)
	# 깃털 흩날림: 잘게 부서지는 고역 노이즈
	for v in 2:
		var n := int(MIX * 0.55)
		var s := PackedFloat32Array()
		s.resize(n)
		var prev := 0.0
		for i in n:
			var t := float(i) / n
			var x := randf() * 2.0 - 1.0
			var hp := x - prev
			prev = x
			var grain := 1.0 if randf() < 0.18 else 0.25
			s[i] = hp * grain * exp(-t * 4.0) * 0.5
		_add("feathers", s)
	# 물 튀김
	for v in 2:
		var n := int(MIX * 0.9)
		var s := PackedFloat32Array()
		s.resize(n)
		var lp := 0.0
		for i in n:
			var t := float(i) / n
			var a := lerpf(0.6, 0.03, t)
			lp += ((randf() * 2.0 - 1.0) - lp) * a
			s[i] = lp * exp(-t * 3.5) * 1.4
		_add("splash", s)
	# 송골매 울음: 끽-끽-끽
	_add("call", _bird_call(5, 0.075, 0.125, 2050.0, 1650.0, 0.18))
	_add("call", _bird_call(4, 0.08, 0.13, 1950.0, 1600.0, 0.2))
	# 경고 울음(침입자)
	_add("screech", _bird_call(1, 0.55, 0.6, 2500.0, 2100.0, 0.25))
	# 새끼 삐약
	_add("chick", _chirp(3, 0.07, 0.16, 3100.0, 3900.0))
	_add("chick", _chirp(4, 0.06, 0.13, 3300.0, 4100.0))
	# 수리부엉이 부엉
	_add("hoot", _hoot())
	# 갈매기
	_add("gull", _bird_call(1, 0.45, 0.5, 1500.0, 850.0, 0.1))
	_add("gull", _bird_call(2, 0.22, 0.3, 1400.0, 1000.0, 0.1))
	# 오리 꽥
	_add("quack", _bird_call(2, 0.14, 0.2, 420.0, 360.0, 0.35))
	# 까마귀 까악
	_add("caw", _bird_call(1, 0.3, 0.34, 720.0, 560.0, 0.6))
	_add("caw", _bird_call(2, 0.2, 0.28, 760.0, 600.0, 0.55))
	# 흰꼬리수리: 높고 가는 연속 울음
	_add("eagle", _bird_call(5, 0.1, 0.16, 2350.0, 2050.0, 0.08))
	# 물범: 낮은 울음
	_add("seal", _bird_call(1, 0.8, 0.85, 240.0, 170.0, 0.35))
	_add("seal", _bird_call(2, 0.35, 0.45, 300.0, 210.0, 0.3))
	# 박쥐: 아주 높은 찍찍
	_add("bat", _chirp(6, 0.025, 0.06, 5200.0, 6400.0))
	# 고래 숨 뿜기: 길고 낮은 노이즈
	var bn := int(MIX * 1.6)
	var bs := PackedFloat32Array()
	bs.resize(bn)
	var blp := 0.0
	for i in bn:
		var t := float(i) / bn
		blp += ((randf() * 2.0 - 1.0) - blp) * 0.08
		bs[i] = blp * minf(t * 10.0, 1.0) * pow(1.0 - t, 1.5) * 3.0
	_add("blow", bs)
	# 천둥: 날카로운 균열음 + 길게 구르는 저음
	for v in 2:
		var tn := int(MIX * 3.2)
		var ts := PackedFloat32Array()
		ts.resize(tn)
		var lp1 := 0.0
		var lp2 := 0.0
		for i in tn:
			var t := float(i) / MIX
			var x := randf() * 2.0 - 1.0
			lp1 += (x - lp1) * 0.03
			lp2 += (lp1 - lp2) * 0.05
			var roll := (0.6 + 0.4 * sin(t * (5.0 + v * 2.0)) * sin(t * 1.7)) * exp(-t * 0.9) * minf(t * 8.0, 1.0)
			var crack := x * exp(-t * 18.0) * 0.5
			ts[i] = lp2 * roll * 9.0 + crack
		_add("thunder", ts)
	# 목표 달성 차임
	_add("chime", _chime([880.0, 1318.5]))
	_add("chime_big", _chime([659.3, 880.0, 1318.5]))
	# 심장 박동
	var hn := int(MIX * 0.7)
	var hs := PackedFloat32Array()
	hs.resize(hn)
	for i in hn:
		var t := float(i) / MIX
		var e1 := exp(-maxf(t, 0.0) * 18.0)
		var e2 := exp(-maxf(t - 0.22, 0.0) * 18.0) * (1.0 if t > 0.22 else 0.0)
		hs[i] = sin(TAU * 52.0 * t) * (e1 + e2 * 0.8)
	_add("heart", hs)
	randomize()


func _bird_call(notes: int, dur: float, gap: float, f0: float, f1: float, noise: float) -> PackedFloat32Array:
	var n := int(MIX * (gap * notes + 0.05))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in notes:
		var start := int(k * gap * MIX)
		var ln := int(dur * MIX)
		var ph := 0.0
		for i in ln:
			if start + i >= n:
				break
			var t := float(i) / ln
			var fr := lerpf(f0, f1, t) * (1.0 + 0.02 * sin(float(i) * 0.02))
			ph += TAU * fr / MIX
			var env := minf(t * 12.0, 1.0) * pow(1.0 - t, 1.4)
			var tone := sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0) + 0.15 * sin(ph * 4.0)
			s[start + i] += (tone * 0.45 + (randf() * 2.0 - 1.0) * noise) * env * 0.7
	return s


func _chirp(notes: int, dur: float, gap: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(MIX * (gap * notes + 0.05))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in notes:
		var start := int(k * gap * MIX)
		var ln := int(dur * MIX)
		var ph := 0.0
		for i in ln:
			var t := float(i) / ln
			ph += TAU * lerpf(f0, f1, t) / MIX
			s[start + i] += sin(ph) * sin(t * PI) * 0.5
	return s


func _hoot() -> PackedFloat32Array:
	var n := int(MIX * 1.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var parts := [[0.0, 0.32, 330.0], [0.55, 0.6, 305.0]]
	for p in parts:
		var start := int(p[0] * MIX)
		var ln := int(p[1] * MIX)
		var ph := 0.0
		for i in ln:
			if start + i >= n:
				break
			var t := float(i) / ln
			ph += TAU * lerpf(p[2], p[2] * 0.9, t) / MIX
			s[start + i] += (sin(ph) + 0.2 * sin(ph * 2.0)) * sin(t * PI) * 0.6
	return s


func _chime(freqs: Array) -> PackedFloat32Array:
	var step := 0.12
	var n := int(MIX * (step * freqs.size() + 0.8))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in freqs.size():
		var start := int(k * step * MIX)
		for i in range(start, n):
			var t := float(i - start) / MIX
			s[i] += sin(TAU * freqs[k] * t) * exp(-t * 4.0) * 0.28
	return s
