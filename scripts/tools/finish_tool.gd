class_name FinishTool
extends WorkTool
## 塗裝。
##  模式 0：食品級礦物油＋蜂蠟（砧板、餐具；每道 30 分鐘）
##  模式 1：木蠟油（擦拭，每道乾燥 60 分鐘）
##  模式 2：亮光漆（每道乾燥 120 分鐘，道與道之間要用 #320 輕砂打毛）
## 塗裝會讓表面缺陷「浮現」：刮痕、橫紋、膠痕、撕裂都會被記錄為瑕疵。

const MODES := [{"id": "food_oil", "name": "食品級礦物油＋蜂蠟（砧板用）", "dry": 30.0},
	{"id": "oil", "name": "木蠟油（擦拭）", "dry": 60.0}, {"id": "varnish", "name": "亮光漆", "dry": 120.0}]

func _init(p_ws) -> void:
	super(p_ws)
	id = "finish"
	display = "塗裝"

func help() -> String:
	return "R：切換塗料。左鍵：在木料上塗一道（套用到整個組件）。\n每道要等乾 (T)。上漆前表面要砂到 #180 以上，膠痕要清乾淨。"

func status() -> String:
	var s := "塗料：[b]%s[/b]（乾燥 %.0f 分鐘）" % [MODES[mode]["name"], MODES[mode]["dry"]]
	var p: WoodPiece = ws.active_piece()
	if p:
		s += "\n已塗 %d 道" % p.finish_coats
		if p.finish_wet > 0.0:
			s += "　[color=orange]未乾，還要 %.0f 分鐘[/color]" % p.finish_wet
	return s

func cycle_mode() -> void:
	mode = (mode + 1) % MODES.size()
	ws.say("塗料：" + MODES[mode]["name"])

func press(hit: Dictionary) -> void:
	if not hit.get("on_piece", false):
		return
	var targets: Array = ws.finish_targets()
	var kind: String = MODES[mode]["id"]
	for p: WoodPiece in targets:
		if p.finish_kind != "" and p.finish_kind != kind:
			ws.say("[color=orange]%s 已經用了別種塗料，混用會不相容。[/color]" % p.label_name)
			p.defects.append("塗料混用，附著不良")
		if p.finish_wet > 0.0:
			p.defects.append("前一道未乾就上下一道，表面發黏起皺")
			ws.say("[color=red]%s 上一道還沒乾！[/color]" % p.label_name)
		if p.finish_coats == 0:
			_reveal_defects(p)
		elif kind == "varnish" and not p.sanded_since_coat:
			p.defects.append("漆層之間沒有打磨，層間附著差")
		p.finish_kind = kind
		p.finish_coats += 1
		p.finish_wet = MODES[mode]["dry"]
		p.sanded_since_coat = false
		p.mark_dirty()
	ws.sfx.oneshot("wipe")
	ws.advance_time(5.0)
	ws.say("塗上第 %d 道%s。" % [targets[0].finish_coats if targets.size() > 0 else 0, MODES[mode]["name"]])

func _reveal_defects(p: WoodPiece) -> void:
	if p.scratch > 0.08:
		p.defects.append("砂磨不足，塗裝後砂痕明顯")
		ws.say("[color=orange]上了油，%s 表面的砂痕全都浮現出來了。[/color]" % p.label_name)
	if p.cross_scratch > 0.02:
		p.defects.append("橫紋刮痕在塗裝後浮現")
	if p.glue_squeeze > 0.03:
		p.defects.append("膠痕處吃不進塗料，出現白斑")
		ws.say("[color=orange]膠痕處吃不進油，出現淺色斑塊。[/color]")
	if p.max_tearout() > 0.08:
		p.defects.append("逆紋撕裂坑在塗裝後變深色")
	if p.marks_visible:
		p.defects.append("鉛筆線沒有清掉，被封在塗層下")
