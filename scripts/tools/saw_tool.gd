class_name SawTool
extends WorkTool
## 日式雙刃鋸（兩刃鋸）：一側縱切齒、一側橫切齒，拉鋸時切削。
## 操作：按住左鍵，滑鼠「往下拉」= 拉鋸切削；往上推 = 回程。左右晃動 = 鋸子偏斜。
## 物理重點：
##  - 鋸齒種類要配合纖維方向（縱切 vs 橫切），否則慢又粗糙
##  - 起鋸前 2mm 鋸路未建立，很容易跑偏
##  - 拉太快會跳鋸、偏移
##  - 鋸路寬 0.6mm：要鋸在線的「廢料側」(留線)，否則榫頭會薄掉一個鋸路

const SIDES := ["縱切齒", "橫切齒"]

var job_index: int = 0
var _strokes_fast := 0

func _init(p_ws) -> void:
	super(p_ws)
	id = "saw"
	display = "兩刃鋸"
	sharpness = 1.0

func help() -> String:
	return "按住左鍵，滑鼠往下拉 = 拉鋸（切削），往上推 = 回程。左右移動可修正偏移。\nR：翻面（縱切齒／橫切齒）。滾輪：選擇要鋸的線。要訣：鋸在線的廢料側。"

func _jobs() -> Array:
	var p: WoodPiece = ws.active_piece()
	return p.pending_jobs() if p else []

func current_job() -> Dictionary:
	var js := _jobs()
	if js.is_empty():
		return {}
	job_index = clampi(job_index, 0, js.size() - 1)
	return js[job_index]

func status() -> String:
	var s := "使用：[b]%s[/b]　%s" % [SIDES[mode], sharp_text()]
	var j := current_job()
	if j.is_empty():
		s += "\n沒有待鋸的劃線。先用劃線工具 (2) 劃線。"
		return s
	var eff := WoodPhysics.saw_efficiency(mode, j["kind"])
	s += "\n目標：[b]%s[/b]（%d/%d）" % [j["label"], job_index + 1, _jobs().size()]
	s += "\n進度 %.1f / %.1f mm　效率 %s" % [j["progress"], j["required"],
		"[color=lime]佳[/color]" if eff > 0.9 else "[color=red]鋸齒不對[/color]"]
	var dev: float = j["dev"]
	var side_txt := ""
	if j["kind_id"] == "cheek":
		side_txt = "偏向廢料側" if dev > 0 else "吃進榫頭"
	else:
		side_txt = "偏右" if dev > 0 else "偏左"
	var col := "lime" if absf(dev - (0.3 if j["kind_id"] == "cheek" else 0.0)) < 0.2 else "orange"
	s += "\n鋸路偏離劃線 [color=%s]%+.2f mm[/color]（%s）　垂直誤差 %.1f°" % [col, dev, side_txt, j["angle"]]
	return s

func cycle_mode() -> void:
	mode = (mode + 1) % 2
	ws.say("鋸子翻面：" + SIDES[mode])

func wheel(dir: int, _shift: bool) -> void:
	var n := _jobs().size()
	if n > 0:
		job_index = posmod(job_index + dir, n)

func press(_hit: Dictionary) -> void:
	if current_job().is_empty():
		ws.say("沒有劃線可以鋸。")
		return
	pressed = true
	_strokes_fast = 0

func motion(rel: Vector2, _hit: Dictionary) -> void:
	if not pressed:
		return
	var p: WoodPiece = ws.active_piece()
	var j := current_job()
	if j.is_empty() or p == null:
		pressed = false
		return
	var steer := WoodPhysics.saw_steer(j["progress"])
	j["dev"] = float(j["dev"]) + rel.x * steer
	j["angle"] = float(j["angle"]) + rel.x * steer * 0.8
	var eff0 := WoodPhysics.saw_efficiency(mode, j["kind"])
	if rel.y <= 0.0:
		ws.sfx.saw(clampf(-rel.y / 40.0, 0.0, 1.0), -rel.y, mode == 0, eff0, false)  # 回程：鋸身摩擦聲
		return  # 回程不切削
	var stroke := rel.y
	if stroke > 60.0:
		_strokes_fast += 1
		j["dev"] = float(j["dev"]) + randf_range(-0.15, 0.15)
		if _strokes_fast % 6 == 1:
			ws.sfx.oneshot("saw_jump")
			ws.say("[color=orange]拉太快，鋸子在跳！[/color] 放慢、用鋸子自身重量。")
		stroke *= 0.6
	var eff := WoodPhysics.saw_efficiency(mode, j["kind"])
	var rate := WoodPhysics.saw_rate(p.hardness(), eff, sharpness, p.width)
	j["progress"] = float(j["progress"]) + stroke * rate
	ws.sfx.saw(clampf(stroke / 40.0, 0.0, 1.0), rel.y, mode == 0, eff, true)
	_emit_dust(p, j, stroke * rate)
	wear(stroke * 0.000004 * p.hardness())
	ws.advance_time(stroke * 0.002)
	if eff < 0.9 and randf() < 0.02:
		ws.say("鋸得很慢，而且%s。換另一面鋸齒 (R)。" % ("纖維被扯毛" if mode == 0 else "鋸屑排不出來"))
	if float(j["progress"]) >= float(j["required"]):
		var over: float = float(j["progress"]) - float(j["required"])
		j["progress"] = j["required"]
		j["done"] = true
		pressed = false
		_finish(p, j, over)
	p.mark_dirty()

func release(_hit: Dictionary) -> void:
	pressed = false

## 鋸屑：從鋸路噴出，在料旁堆積。體積 = 鋸路寬 × 前進深度 × 鋸路長
func _emit_dust(p: WoodPiece, j: Dictionary, advance: float) -> void:
	var T := p.mean_thickness()
	var pos := Vector3.ZERO
	match String(j["kind_id"]):
		"cross_full":
			pos = Vector3(float(j["x"]) + float(j["dev"]), T * 0.5 - float(j["progress"]), p.width * 0.5)
		"shoulder":
			pos = Vector3(p.shoulder_x(), float(j["side"]) * (T * 0.5 - float(j["progress"])), p.width * 0.5)
		"cheek":
			pos = Vector3(float(p.tenon["end"]) * (p.length * 0.5 - float(j["progress"])), float(j["side"]) * float(p.tenon["target"]) * 0.5, p.width * 0.5)
	var world := p.to_global(pos * 0.001)
	var pile := p.to_global(Vector3(pos.x, 0, p.width * 0.5 + 12.0) * 0.001)
	ws.fx.sawdust(world, pile, WoodPhysics.KERF * advance * p.width, j["kind"] == "rip", p.sp()["early"])

func _finish(p: WoodPiece, j: Dictionary, over: float) -> void:
	match String(j["kind_id"]):
		"cross_full":
			ws.sfx.oneshot("clunk", {"hardness": p.hardness()})
			ws.say("鋸斷了！實際鋸路偏離 %+.2f mm，端面直角誤差 %.1f°" % [j["dev"], j["angle"]])
			ws.split_piece(p, float(j["x"]) + float(j["dev"]), float(j["angle"]))
		"shoulder":
			# 肩部鋸過頭會在榫頭根部留下鋸痕，削弱強度
			var overcut := over * 0.4 + randf_range(0.0, 0.3)
			p.tenon["overcut"] = float(p.tenon["overcut"]) + overcut
			p.end_angle[int(p.tenon["end"])] = float(j["angle"])
			if overcut > 0.4:
				ws.say("[color=orange]肩部鋸過頭 %.1f mm，榫頭根部被鋸傷。[/color]" % overcut)
			else:
				ws.say("榫肩鋸好了。")
		"cheek":
			ws.say("頰面鋸好了（偏離 %+.2f mm）。" % j["dev"])
	_drop_waste(p)
	if p.tenon_complete() and not p.tenon.has("thickness"):
		var t: float = float(p.tenon["target"]) - WoodPhysics.KERF + float(p.job("cheek_top")["dev"]) + float(p.job("cheek_bot")["dev"])
		p.tenon["thickness"] = t
		ws.say("[b]榫頭完成！[/b]廢料掉下來了。用卡尺 (M) 量量看厚度。")
	job_index = 0

## 頰面 + 肩部都鋸完的那一側，廢料真的掉下來
func _drop_waste(p: WoodPiece) -> void:
	if p.tenon.is_empty():
		return
	for side in [1, -1]:
		var key := "waste_%d" % side
		if p.tenon.has(key):
			continue
		var cheek := p.job("cheek_top" if side == 1 else "cheek_bot")
		var sh := p.job("shoulder_top" if side == 1 else "shoulder_bot")
		if cheek.is_empty() or sh.is_empty() or not cheek["done"] or not sh["done"]:
			continue
		p.tenon[key] = true
		var T := p.mean_thickness()
		var tl: float = p.tenon["length"]
		var e: float = p.tenon["end"]
		var face: float = float(p.tenon["target"]) * 0.5 - WoodPhysics.KERF * 0.5 + float(cheek["dev"])
		var th := T * 0.5 - face
		var center := Vector3(e * (p.length * 0.5 - tl * 0.5), side * (face + th * 0.5), 0)
		var xf := p.global_transform * Transform3D(Basis.IDENTITY, center * 0.001)
		ws.fx.offcut(xf, Vector3(tl, th, p.width), p.sp()["early"])
		ws.sfx.oneshot("offcut", {"hardness": p.hardness()})
