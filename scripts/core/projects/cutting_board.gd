extends Workflow
## 砧板：實務上初學者的第一件作品。
## 工序：選料 → 適應濕度 → 刨到厚度 → 兩端鋸齊到長度 → 砂磨 → 食品級油兩道以上
## 寫實重點：木料行的料兩端是粗鋸端、不直角，要各鋸掉一點；砧板只能用食品級塗料。

func _define() -> void:
	id = "cutting_board"
	sellable = true
	var L: float = params.get("length", 300.0)
	var T: float = params.get("thickness", 20.0)
	title = "砧板 %.0f mm" % L
	steps = [
		{"id": "select", "title": "選料", "detail": "從木料架拿一塊寬板（L）"},
		{"id": "acclimate", "title": "適應工坊濕度", "detail": "含水率與工坊相差 ≤ 2%（M 量測；等待或先做別的事）"},
		{"id": "plane", "title": "刨到 %.0f mm 厚" % T, "detail": "厚 %.0f±0.4、平整度 ≤ 0.3 mm、沒有逆紋撕裂坑" % T},
		{"id": "trim", "title": "兩端鋸齊、長度 %.0f mm" % L, "detail": "粗鋸端要各鋸掉一點；成品長 %.0f±3 mm" % L},
		{"id": "sand", "title": "砂磨", "detail": "依序換號砂到 #180 以上，清掉鉛筆線"},
		{"id": "finish", "title": "上食品級油", "detail": "塗料選「食品級礦物油」，至少 2 道並等乾"},
	]

func setup_tools(tools: Array) -> void:
	(tools[6] as FinishTool).mode = 0

## 成品：長度最接近目標、兩端都鋸過的那一塊
func product_piece() -> WoodPiece:
	var best: WoodPiece = null
	var L: float = params.get("length", 300.0)
	for p: WoodPiece in ws.pieces:
		if best == null or absf(p.length - L) < absf(best.length - L):
			best = p
	return best

func check(step_id: String) -> bool:
	var p := product_piece()
	if p == null:
		return false
	var L: float = params.get("length", 300.0)
	var T: float = params.get("thickness", 20.0)
	match step_id:
		"select":
			return true
		"acclimate":
			return _all_acclimated()
		"plane":
			return absf(p.mean_thickness() - T) <= 0.4 and p.flatness() <= 0.3
		"trim":
			return not p.end_rough[1] and not p.end_rough[-1] and absf(p.length - L) <= 3.0
		"sand":
			return check("trim") and _surface_ok(p)
		"finish":
			return check("sand") and _finished(p)
	return false

func evaluate() -> Dictionary:
	var p := product_piece()
	var lines: Array[String] = []
	if p == null:
		return {"text": "工作台上沒有木料。", "score": 0.0}
	var L: float = params.get("length", 300.0)
	var T: float = params.get("thickness", 20.0)
	var sp := p.sp()
	lines.append("[font_size=26][b]作品評鑑：%s 砧板[/b][/font_size]\n" % sp["name"])
	var total := 0.0
	# 尺寸 (30)
	var t_err := absf(p.mean_thickness() - T)
	var l_err := absf(p.length - L)
	var s1 := clampf(15.0 - t_err * 20.0, 0.0, 15.0) + clampf(15.0 - l_err * 2.5, 0.0, 15.0)
	if p.end_rough[1] or p.end_rough[-1]:
		s1 -= 10.0
	s1 = maxf(s1, 0.0)
	total += s1
	lines.append("尺　　寸　%4.1f / 30　（厚 %.2f mm、長 %.1f mm%s）" % [s1, p.mean_thickness(), p.length, "；[color=orange]還有粗鋸端[/color]" if p.end_rough[1] or p.end_rough[-1] else ""])
	# 平整與方正 (20)
	var sq := (absf(float(p.end_angle[1])) + absf(float(p.end_angle[-1]))) * 0.5
	var s2 := clampf(12.0 - p.flatness() * 20.0, 0.0, 12.0) + clampf(8.0 - sq * 2.5, 0.0, 8.0)
	total += s2
	lines.append("平整方正　%4.1f / 20　（平整度 %.2f mm、端面直角誤差 %.1f°）" % [s2, p.flatness(), sq])
	# 表面 (25)
	var s3 := 25.0
	var notes: Array[String] = []
	if p.max_tearout() > 0.05:
		s3 -= 8.0
		notes.append("逆紋撕裂")
	if p.scratch > 0.075:
		s3 -= 8.0
		notes.append("砂磨不足")
	elif p.scratch > 0.05:
		s3 -= 3.0
	if p.cross_scratch > 0.02:
		s3 -= 5.0
		notes.append("橫紋刮痕")
	if p.marks_visible:
		s3 -= 4.0
		notes.append("鉛筆線沒清")
	s3 = maxf(s3, 0.0)
	total += s3
	lines.append("表面處理　%4.1f / 25　%s" % [s3, "、".join(notes)])
	# 塗裝 (25)
	var s4 := clampf(p.finish_coats * 7.0, 0.0, 21.0)
	if p.finish_coats >= 2 and p.finish_wet <= 0.0:
		s4 += 4.0
	var defects: Array[String] = []
	for d in p.defects:
		if not defects.has(d):
			defects.append(d)
	if p.finish_kind != "" and p.finish_kind != "food_oil":
		defects.append("砧板用了非食品級塗料")
	if p.finish_wet > 0.0:
		defects.append("塗裝未乾")
	s4 = maxf(0.0, s4 - defects.size() * 4.0)
	total += s4
	lines.append("塗　　裝　%4.1f / 25　（%d 道）%s" % [s4, p.finish_coats, ("　瑕疵：" + "、".join(defects)) if defects.size() > 0 else ""])
	if p.split:
		total -= 30.0
		lines.append("[color=red]木料劈裂　-30[/color]")
	if absf(p.moisture - Game.BUYER_EMC) > 3.5:
		lines.append("[color=orange]⚠ 含水率 %.1f%% 與台灣一般家庭（約 %.0f%%）差距大，出貨後可能變形。[/color]" % [p.moisture, Game.BUYER_EMC])
	total = clampf(total, 0.0, 100.0)
	lines.append("\n[font_size=30][b]總分 %.0f / 100　評等：%s[/b][/font_size]" % [total, rank_text(total)])
	var product := {"type": "cutting_board", "name": "%s砧板 %.0f×%.0f" % [sp["name"], p.length / 10.0, p.width / 10.0],
		"species": p.species_id, "score": total, "length": p.length, "width": p.width, "thickness": p.mean_thickness(),
		"finish": p.finish_kind, "defects": defects, "built_mc": p.moisture}
	return {"text": "\n".join(lines), "score": total, "product": product}
