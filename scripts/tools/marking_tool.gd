class_name MarkingTool
extends WorkTool
## 劃線工具：
##  模式 0：鋼尺 + 直角尺 + 鉛筆 -> 橫切線（鉛筆線寬造成 ±0.25mm 誤差）
##  模式 1：劃線規 -> 榫眼（以劃線刀劃，誤差 ±0.05mm）
##  模式 2：劃線規 -> 榫頭（點擊靠近的端部）
## 真實技巧：劃線規直接對準鑿子寬度設定（K 鍵），而不是用尺量。

const MODES := ["橫切線（鉛筆+直角尺）", "榫眼劃線（劃線規）", "榫頭劃線（劃線規）"]

var gauge: float = 8.0          ## 劃線規設定：榫眼寬 / 榫頭厚
var mortise_len: float = 60.0
var tenon_len: float = 17.0
var mortise_depth: float = 18.0

func _init(p_ws) -> void:
	super(p_ws)
	id = "marking"
	display = "劃線工具"

func help() -> String:
	return "R：切換劃線模式。左鍵：在木料上劃線。\n滾輪：調整劃線規（榫眼寬／榫頭厚），Shift+滾輪：榫眼長／榫頭長。K：劃線規對準目前鑿子寬度。"

func status() -> String:
	var s := "模式：[b]%s[/b]\n劃線規 %.1f mm" % [MODES[mode], gauge]
	match mode:
		1: s += "　榫眼長 %.0f mm　深 %.0f mm" % [mortise_len, mortise_depth]
		2: s += "　榫頭長 %.0f mm" % tenon_len
	var p: WoodPiece = ws.active_piece()
	if p and ws.last_hit.get("on_piece", false):
		var x: float = ws.last_hit["local"].x
		s += "\n游標位置：距左端 [b]%.1f mm[/b]　距右端 %.1f mm" % [x + p.length * 0.5, p.length * 0.5 - x]
	return s

func cycle_mode() -> void:
	mode = (mode + 1) % MODES.size()
	ws.say("劃線模式：" + MODES[mode])

func wheel(dir: int, shift: bool) -> void:
	if shift:
		if mode == 2:
			tenon_len = clampf(tenon_len + dir, 5.0, 60.0)
		else:
			mortise_len = clampf(mortise_len + dir, 10.0, 150.0)
	else:
		gauge = clampf(snappedf(gauge + dir * 0.5, 0.5), 3.0, 30.0)

func set_gauge_from_chisel(w: float) -> void:
	gauge = w
	ws.say("劃線規已直接對準 %.0f mm 鑿子設定。" % w)

func press(hit: Dictionary) -> void:
	var p: WoodPiece = ws.active_piece()
	if p == null or not hit.get("on_piece", false):
		ws.say("請在木料上點擊劃線。")
		return
	var x: float = hit["local"].x
	match mode:
		0:
			x = snappedf(x, 0.5) + randf_range(-0.25, 0.25)
			p.marks.append({"type": "cross", "x": x})
			p.cut_jobs.append({"id": "cross_%d" % p.cut_jobs.size(), "kind": "cross", "kind_id": "cross_full",
				"x": x, "required": p.mean_thickness(), "progress": 0.0, "dev": 0.0, "angle": 0.0, "done": false, "side": 1,
				"label": "橫切斷料 @ %.1f mm" % (x + p.length * 0.5)})
			ws.say("劃下橫切線：距左端 %.1f mm" % (x + p.length * 0.5))
		1:
			if not p.mortise.is_empty():
				ws.say("這塊料已經有榫眼劃線了。")
				return
			if mortise_depth >= p.mean_thickness() - 2.0:
				ws.say("榫眼太深，會鑿穿底部。")
			var mw := gauge + randf_range(-0.05, 0.05)
			p.marks.append({"type": "mortise", "x": x, "length": mortise_len, "width": mw})
			p.mortise = {"x": x, "length": mortise_len, "mark_width": mw, "width": 0.0, "chisel": 0.0,
				"depth": 0.0, "target_depth": mortise_depth, "chips": 0, "bruise": 0.0}
			var end_dist := p.length * 0.5 - absf(x) - mortise_len * 0.5
			if end_dist < 30.0:
				ws.say("[color=orange]榫眼離端部只有 %.0f mm，鑿的時候很容易劈裂！[/color]" % end_dist)
			ws.say("劃好榫眼：寬 %.2f、長 %.0f mm" % [mw, mortise_len])
		2:
			if not p.tenon.is_empty():
				ws.say("這塊料已經有榫頭劃線了。")
				return
			var e := 1 if x > 0.0 else -1
			var tt := gauge + randf_range(-0.05, 0.05)
			var T := p.mean_thickness()
			if tt >= T - 2.0:
				ws.say("榫頭厚度不能接近板厚。")
				return
			p.marks.append({"type": "tenon", "end": e, "length": tenon_len, "thickness": tt})
			p.tenon = {"end": e, "length": tenon_len, "target": tt, "overcut": 0.0}
			var sh_depth := (T - tt) * 0.5
			p.cut_jobs.append({"id": "cheek_top", "kind": "rip", "kind_id": "cheek", "side": 1, "required": tenon_len,
				"progress": 0.0, "dev": 0.0, "angle": 0.0, "done": false, "label": "榫頭上頰面（縱切）"})
			p.cut_jobs.append({"id": "cheek_bot", "kind": "rip", "kind_id": "cheek", "side": -1, "required": tenon_len,
				"progress": 0.0, "dev": 0.0, "angle": 0.0, "done": false, "label": "榫頭下頰面（縱切）"})
			p.cut_jobs.append({"id": "shoulder_top", "kind": "cross", "kind_id": "shoulder", "side": 1, "required": sh_depth,
				"progress": 0.0, "dev": 0.0, "angle": 0.0, "done": false, "label": "榫肩上側（橫切 %.1f mm 深）" % sh_depth})
			p.cut_jobs.append({"id": "shoulder_bot", "kind": "cross", "kind_id": "shoulder", "side": -1, "required": sh_depth,
				"progress": 0.0, "dev": 0.0, "angle": 0.0, "done": false, "label": "榫肩下側（橫切 %.1f mm 深）" % sh_depth})
			ws.say("劃好榫頭：厚 %.2f、長 %.0f mm（%s端）" % [tt, tenon_len, "右" if e == 1 else "左"])
	p.marks_visible = true
	p.mark_dirty()
	ws.sfx.oneshot("scribe", {}, -3.0)
	ws.advance_time(1.0)
