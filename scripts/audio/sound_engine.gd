class_name SoundEngine
extends Node
## 程序化音效引擎：不需要任何音檔，聲音直接由物理參數合成，所以「聲音就是回饋」：
##  - 鋒利的刨刀是清脆的「唰」，鈍刀聲音悶、夾雜撕裂的劈啪聲
##  - 鋸聲的嗡嗡頻率 = 鋸齒通過速度（拉得越快音越高），鋸齒選錯會更粗糙
##  - 木槌聲依木材硬度變化，榫眼越深聲音越悶
##
## 兩種聲音：
##  1. 連續聲（摩擦類：刨、鋸、砂、磨刀）——工具每次移動呼叫 drive()，停手就自然淡出
##  2. 單發聲（敲擊、斷裂、夾具…）——oneshot()，首次合成後快取
## 若想換成真實錄音：把 assets/sfx/<名稱>.wav 或 .ogg 放進去，會自動優先使用。

const SR := 22050.0

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}

# ---- 連續聲參數（drive() 設定）
var _target := 0.0
var _gain := 0.0
var _hold := 0.0
var _cutoff := 0.3      ## 低通係數 0~1：越大越明亮
var _crackle := 0.0     ## 每秒劈啪脈衝數（撕裂、粗砂紙）
var _mod_freq := 0.0    ## 振幅調變頻率：鋸齒通過頻率
var _mod_depth := 0.0
var _tone_freq := 0.0   ## 共鳴音（鋸身、刨刀身）
var _tone_mix := 0.0
var _lp := 0.0
var _lp2 := 0.0
var _imp := 0.0
var _mod_ph := 0.0
var _tone_ph := 0.0

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SR
	gen.buffer_length = 0.12
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

# ================================================================ 連續聲
## intensity 0~1。params：gain, cutoff, crackle, mod_freq, mod_depth, tone_freq, tone_mix
func drive(intensity: float, params: Dictionary) -> void:
	_target = clampf(intensity, 0.0, 1.0) * float(params.get("gain", 0.5))
	_cutoff = clampf(float(params.get("cutoff", 0.3)), 0.01, 0.95)
	_crackle = float(params.get("crackle", 0.0))
	_mod_freq = float(params.get("mod_freq", 0.0))
	_mod_depth = float(params.get("mod_depth", 0.0))
	_tone_freq = float(params.get("tone_freq", 0.0))
	_tone_mix = float(params.get("tone_mix", 0.0))
	_hold = 0.07

func _process(delta: float) -> void:
	_hold -= delta
	if _hold <= 0.0:
		_target = 0.0
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	for i in n:
		var s := _next_sample()
		_pb.push_frame(Vector2(s, s))

func _next_sample() -> float:
	_gain += (_target - _gain) * 0.003
	if _gain <= 0.0003:
		return 0.0
	var w := randf() * 2.0 - 1.0
	_lp += _cutoff * (w - _lp)
	_lp2 += 0.03 * (_lp - _lp2)
	var s := _lp - _lp2
	if _crackle > 0.0 and randf() < _crackle / SR:
		_imp = randf_range(0.6, 1.2)
	s += _imp * (randf() * 2.0 - 1.0)
	_imp *= 0.94
	if _mod_depth > 0.0:
		_mod_ph = fmod(_mod_ph + _mod_freq / SR, 1.0)
		s *= 1.0 - _mod_depth * (0.5 + 0.5 * sin(TAU * _mod_ph))
	if _tone_mix > 0.0:
		_tone_ph = fmod(_tone_ph + _tone_freq / SR, 1.0)
		s += sin(TAU * _tone_ph) * _tone_mix * 0.25
	return clampf(s * _gain * 1.1, -1.0, 1.0)

## 離線算出連續聲（測試、試聽用）。strokes：[{"dur","call"}]，call 是設定 drive 的 Callable
func render_offline(segments: Array) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for seg in segments:
		var n := int(float(seg["dur"]) * SR)
		for i in n:
			if i % 512 == 0:
				(seg["call"] as Callable).call()
				if seg.get("silent", false):
					_target = 0.0
			out.append(_next_sample())
	return _wav(out)

## 單發聲直接取得串流（測試、試聽用）
func synth_stream(name: String, params: Dictionary = {}) -> AudioStreamWAV:
	return _synth(name, params)

# ---- 各工具的連續聲配方
func plane(intensity: float, sharpness: float, tear: float) -> void:
	drive(intensity, {"gain": 0.8, "cutoff": lerpf(0.18, 0.75, sharpness), "crackle": tear * 120.0 + (1.0 - sharpness) * 25.0,
		"tone_freq": 1400.0 + sharpness * 900.0, "tone_mix": 0.05})

func saw(intensity: float, speed_px: float, rip_teeth: bool, eff: float, cutting: bool) -> void:
	var pitch_mm := 3.0 if rip_teeth else 1.5
	var tooth_hz := clampf(speed_px * 60.0 / pitch_mm * 0.6, 60.0, 1600.0)
	drive(intensity, {"gain": 0.75 if cutting else 0.25, "cutoff": 0.45 if rip_teeth else 0.6,
		"crackle": (1.0 - eff) * 160.0 + 10.0, "mod_freq": tooth_hz, "mod_depth": 0.75 if cutting else 0.3,
		"tone_freq": 2600.0, "tone_mix": 0.04})

func sand(intensity: float, grit: int) -> void:
	var coarse := clampf((320.0 - grit) / 240.0, 0.0, 1.0)
	drive(intensity, {"gain": 0.45, "cutoff": lerpf(0.75, 0.25, coarse), "crackle": coarse * 250.0})

func stone(intensity: float, grit: int) -> void:
	drive(intensity, {"gain": 0.4, "cutoff": 0.12 if grit < 3000 else 0.3, "crackle": 6.0 if grit < 3000 else 0.0,
		"mod_freq": 4.0, "mod_depth": 0.3})

# ================================================================ 單發聲
## 有 params 的聲音會依量化後的參數快取多個版本
func oneshot(name: String, params: Dictionary = {}, volume_db := 0.0) -> void:
	var stream: AudioStream = null
	for ext in ["wav", "ogg"]:
		var path := "res://assets/sfx/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		var key := name
		for k in params.keys():
			key += "|%s=%.1f" % [k, snappedf(float(params[k]), 0.1)]
		if not _cache.has(key):
			_cache[key] = _synth(name, params)
		stream = _cache[key]
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]

func _synth(name: String, prm: Dictionary) -> AudioStreamWAV:
	var h: float = prm.get("hardness", 1.0)
	var f: float = prm.get("force", 0.7)
	match name:
		"mallet":
			# 低頻撞擊 + 木材本體共振（硬木音高較高）+ 起音的「喀」。榫眼越深越悶。
			var depth: float = prm.get("depth", 0.0)
			var f0 := (380.0 + 220.0 * h) * (1.0 - depth * 0.012)
			return _modal(0.4, [110.0 + 40.0 * h, f0, f0 * 2.32, f0 * 4.1], [18.0, 26.0, 40.0, 65.0],
				[0.42 * f, 0.32 * f, 0.18 * f, 0.09 * f], 0.25 * f, 0.004)
		"clunk":
			return _modal(0.5, [220.0 + 100.0 * h, (220.0 + 100.0 * h) * 2.7, (220.0 + 100.0 * h) * 5.2], [12.0, 20.0, 35.0],
				[0.5, 0.3, 0.15], 0.3, 0.003)
		"offcut":
			return _modal(0.3, [700.0 + 300.0 * h, 1650.0 + 500.0 * h, 3100.0], [30.0, 45.0, 70.0], [0.4, 0.25, 0.1], 0.3, 0.002)
		"tap":
			return _modal(0.25, [500.0 + 200.0 * h, 1200.0 + 450.0 * h], [35.0, 55.0], [0.35, 0.18], 0.15, 0.002)
		"pickup":
			return _modal(0.25, [620.0, 1850.0, 2930.0], [30.0, 40.0, 60.0], [0.25, 0.12, 0.08], 0.08, 0.002)
		"clamp":
			var out := PackedFloat32Array()
			for i in 3:
				out.append_array(_modal(0.07, [3200.0, 5100.0], [90.0, 120.0], [0.3, 0.15], 0.4, 0.001, true))
			out.append_array(_modal(0.3, [180.0, 420.0], [20.0, 30.0], [0.3, 0.15], 0.2, 0.003, true))
			return _wav(out)
		"crack":
			return _crack(0.6, 14)
		"chatter":
			return _chatter(0.35, 42.0)
		"saw_jump":
			return _modal(0.25, [2800.0, 4100.0, 900.0], [25.0, 35.0, 30.0], [0.25, 0.15, 0.2], 0.5, 0.012)
		"squeeze":
			return _noise_env(0.45, 0.06, 0.4, 16.0, 0.5)
		"wipe":
			return _noise_env(0.7, 0.15, 0.25, 2.0, 0.2)
		"scribe":
			return _noise_env(0.25, 0.6, 0.25, 0.0, 0.0)
		"pare":
			return _noise_env(0.18, 0.7, 0.35, 0.0, 0.0, 80.0)
		"lever":
			var a: PackedFloat32Array = _modal(0.3, [300.0, 760.0], [10.0, 18.0], [0.2, 0.1], 0.0, 0.001, true)
			var b: PackedFloat32Array = _crack(0.3, 4, true)
			for i in mini(a.size(), b.size()):
				a[i] = a[i] + b[i] * 0.5
			return _wav(a)
		"sweep":
			return _noise_env(0.9, 0.2, 0.3, 3.0, 0.6)
	return _modal(0.1, [1000.0], [40.0], [0.2], 0.0, 0.0)

# ---- 合成積木
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = data
	return w

## 模態合成：一組指數衰減的正弦波（木頭、金屬的共振）+ 起音雜訊
func _modal(dur: float, freqs: Array, decays: Array, amps: Array, click: float, click_len: float, raw := false):
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phases := []
	for k in freqs.size():
		phases.append(randf() * TAU)
	for i in n:
		var t := float(i) / SR
		var s := 0.0
		for k in freqs.size():
			s += sin(TAU * float(freqs[k]) * t + float(phases[k])) * float(amps[k]) * exp(-float(decays[k]) * t)
		if t < click_len:
			s += (randf() * 2.0 - 1.0) * click * (1.0 - t / click_len)
		out[i] = s
	return out if raw else _wav(out)

## 斷裂：一串密集、大小不一的破裂脈衝
func _crack(dur: float, count: int, raw := false):
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var hits := []
	for k in count:
		hits.append(int(pow(randf(), 1.8) * n * 0.5))
	var lp := 0.0
	for i in n:
		var s := 0.0
		for st in hits:
			var d: int = i - int(st)
			if d >= 0 and d < 900:
				s += (randf() * 2.0 - 1.0) * exp(-float(d) / 120.0)
		lp += 0.6 * (s - lp)
		var t := float(i) / SR
		out[i] = lp * 0.6 + sin(TAU * 170.0 * t) * 0.25 * exp(-6.0 * t)
	return out if raw else _wav(out)

## 顫刀：刀刃在木頭上高頻彈跳的「嗒嗒嗒」
func _chatter(dur: float, rate: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var period := int(SR / rate)
	for i in n:
		var d := i % period
		var t := float(i) / SR
		var env := 1.0 - t / dur
		out[i] = ((randf() * 2.0 - 1.0) * exp(-float(d) / 60.0) * 0.6 + sin(TAU * 900.0 * t) * exp(-float(d) / 200.0) * 0.3) * env
	return _wav(out)

## 濾波雜訊 + 包絡（擠膠、擦拭、劃線刀、修削）
func _noise_env(dur: float, cutoff: float, amp: float, am_hz: float, am_depth: float, crackle := 0.0) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var imp := 0.0
	for i in n:
		var t := float(i) / SR
		lp += cutoff * ((randf() * 2.0 - 1.0) - lp)
		lp2 += 0.03 * (lp - lp2)
		var s := lp - lp2
		if crackle > 0.0 and randf() < crackle / SR:
			imp = 1.0
		s += imp * (randf() * 2.0 - 1.0)
		imp *= 0.9
		var env := sin(PI * t / dur)
		if am_depth > 0.0:
			env *= 1.0 - am_depth * (0.5 + 0.5 * sin(TAU * am_hz * t))
		out[i] = s * amp * env * 2.0
	return _wav(out)
