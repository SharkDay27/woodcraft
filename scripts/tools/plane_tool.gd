class_name PlaneTool
extends WorkTool
## 手刨。物理重點：
##  - 刨底（鉋台）架在高點上，刀片只削到「最高點 - 吃刀深」以上的木料 -> 長刨會把料刨直
##  - 逆紋刨削會撕裂；刃口越鈍、吃刀越深越嚴重
##  - 吃刀過深會卡刀
##  - 每一刨都會磨耗刃口，硬木磨耗更快

const SOLES := [{"name": "長台鉋 (360mm)", "len": 360.0}, {"name": "平鉋 (230mm)", "len": 230.0}, {"name": "小鉋 (140mm)", "len": 140.0}]

var depth: float = 0.10
var _last_x: float = 0.0
var _start_x: float = 0.0
var _snapshot := PackedFloat32Array()
var _cut_done := {}
var _stalled := false
var _stroke_removed := 0.0
var _stroke_tear := 0
var _shaving := false

func _init(p_ws) -> void:
	super(p_ws)
	id = "plane"
	display = "手刨"
	sharpenable = true

func help() -> String:
	return "按住左鍵沿木料長度方向拖曳 = 一刨。Ctrl+滾輪：吃刀深度。R：切換鉋台長度。\n注意木紋方向（看「纖維傾斜」），逆紋刨會撕裂。"

func status() -> String:
	var p: WoodPiece = ws.active_piece()
	var s := "%s　吃刀 [b]%.2f mm[/b]　%s" % [SOLES[mode]["name"], depth, sharp_text()]
	if p:
		var md := WoodPhysics.plane_max_depth(p.hardness(), sharpness)
		s += "\n此木料最大可刨深度約 %.2f mm" % md
		s += "\n順紋方向：往 [b]%s[/b] 刨" % ("右 →" if p.grain_runout > 0 else "← 左")
	return s

func cycle_mode() -> void:
	mode = (mode + 1) % SOLES.size()
	ws.say("換成 %s" % SOLES[mode]["name"])

func wheel(dir: int, _shift: bool) -> void:
	depth = clampf(snappedf(depth + dir * 0.02, 0.01), 0.02, 0.6)

func press(hit: Dictionary) -> void:
	var p: WoodPiece = ws.active_piece()
	if p == null:
		return
	if not p.mortise.is_empty() or not p.tenon.is_empty():
		ws.say("已開始做接合，不能再刨厚度（會破壞劃線基準）。")
		return
	pressed = true
	_start_x = hit["top"].x
	_last_x = _start_x
	_snapshot = p.profile.duplicate()
	_cut_done = {}
	_stalled = false
	_stroke_removed = 0.0
	_stroke_tear = 0
	_shaving = false

func motion(_rel: Vector2, hit: Dictionary) -> void:
	if not pressed or _stalled:
		return
	var p: WoodPiece = ws.active_piece()
	var x: float = hit["top"].x
	if absf(x - _last_x) < 0.5:
		return
	var dir := signf(x - _last_x)
	var h := p.hardness()
	if depth > WoodPhysics.plane_max_depth(h, sharpness):
		_stalled = true
		ws.sfx.oneshot("chatter")
		ws.say("[color=orange]卡刀／顫刀！吃刀 %.2fmm 對 %s 太深了。[/color]" % [depth, p.sp()["name"]])
		return
	var uphill := dir * p.grain_runout < 0.0
	var half_sole: float = SOLES[mode]["len"] * 0.5
	var a := minf(_last_x, x)
	var b := maxf(_last_x, x)
	var seg_removed := 0.0
	var seg_n := 0
	var seg_tear := 0
	for i in WoodPiece.PROFILE_N:
		if _cut_done.has(i):
			continue
		var xi := p.x_of(i)
		if xi < a or xi > b:
			continue
		_cut_done[i] = true
		# 鉋台架在窗口內的最高點
		var ref := -1e9
		for k in WoodPiece.PROFILE_N:
			if absf(p.x_of(k) - xi) <= half_sole:
				ref = maxf(ref, _snapshot[k])
		var target := ref - depth * WoodPhysics.speed_half()
		if p.profile[i] > target:
			var removed := p.profile[i] - target
			p.profile[i] = target
			_stroke_removed += removed
			seg_removed += removed
			seg_n += 1
			p.tearout[i] = maxf(0.0, p.tearout[i] - removed)
			var chance := WoodPhysics.tearout_chance(p.sp()["tearout"], p.grain_runout, removed / WoodPhysics.speed_half(), sharpness, uphill)
			if randf() < chance:
				p.tearout[i] = maxf(p.tearout[i], removed * randf_range(1.0, 3.0) + 0.05)
				_stroke_tear += 1
				seg_tear += 1
	# ---- 聲音與刨花
	var on_board := absf(x) < p.length * 0.5
	var world := p.to_global(Vector3(clampf(x, -p.length * 0.5, p.length * 0.5), p.mean_thickness() * 0.5, 0) * 0.001)
	if seg_n > 0:
		var thick := seg_removed / seg_n
		if not _shaving:
			_shaving = true
			ws.fx.begin_shaving(world, p.sp()["early"], p.width, dir)
		ws.fx.grow_shaving(world, absf(x - _last_x), thick)
		ws.sfx.plane(clampf(0.35 + thick * 3.0, 0.0, 1.0), sharpness, float(seg_tear))
	elif on_board:
		ws.sfx.plane(0.12, sharpness, 0.0)   # 鉋台在木面上滑過、沒有吃到木頭
	_last_x = x
	p.mark_dirty()

func release(_hit: Dictionary) -> void:
	if not pressed:
		return
	pressed = false
	var p: WoodPiece = ws.active_piece()
	if p == null:
		return
	var stroke_len := absf(_last_x - _start_x)
	ws.fx.end_shaving(_stroke_tear > 0 or sharpness < 0.4)
	if stroke_len < 20.0:
		return
	if _stroke_removed > 0.0:
		p.worked = true
		p.cup = maxf(0.0, p.cup - depth * 0.5)
		p.scratch = minf(p.scratch, lerpf(0.12, 0.02, sharpness))
		p.marks_visible = true
	wear(0.006 * p.hardness() * stroke_len / 400.0)
	ws.advance_time(0.15)
	if _stroke_tear > 0:
		ws.say("[color=orange]逆紋撕裂 %d 處！[/color] 試試反方向刨、調淺吃刀或研磨刀刃。" % _stroke_tear)
	elif _stroke_removed <= 0.0 and not _stalled:
		ws.say("刨刀沒有吃到木頭（刨在低處，鉋台被高點架住）。")
