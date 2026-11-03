extends Workflow
## 「T 字方榫接合」練習件：榫卯基本功，不能販售。

const TARGET_T := 24.0
const MORTISE_W := 8.0
const MORTISE_L := 60.0
const MORTISE_D := 18.0
const TENON_L := 17.0

func _define() -> void:
	id = "mortise_tenon"
	title = "T 字方榫接合（練習）"
	sellable = false
	steps = [
		{"id": "select", "title": "選料", "detail": "從木料架拿一塊角料（L）"},
		{"id": "acclimate", "title": "適應工坊濕度", "detail": "含水率與工坊相差 ≤ 2%"},
		{"id": "plane", "title": "刨平到 24.0 mm", "detail": "厚 24.0±0.3、平整度 ≤ 0.3 mm（M 量測）"},
		{"id": "crosscut", "title": "劃線、鋸斷成兩段", "detail": "兩段各 ≥ 240 mm"},
		{"id": "mortise", "title": "在腳料鑿榫眼", "detail": "寬 8、長 60、深 18 mm"},
		{"id": "tenon", "title": "在橫料鋸榫頭", "detail": "厚 8、長 17 mm（比榫眼淺 1mm 留膠室）"},
		{"id": "fit", "title": "乾試裝", "detail": "F 試裝；太緊就用鑿子修頰面"},
		{"id": "glue", "title": "上膠、組裝、夾持", "detail": "10 分鐘內組裝，夾 ≥ 45 分鐘再拆"},
		{"id": "sand", "title": "砂磨", "detail": "#180 以上、清掉膠痕與鉛筆線"},
		{"id": "finish", "title": "塗裝", "detail": "至少 2 道並完全乾燥"},
	]

func setup_tools(tools: Array) -> void:
	var mk: MarkingTool = tools[1]
	mk.gauge = MORTISE_W
	mk.mortise_len = MORTISE_L
	mk.mortise_depth = MORTISE_D
	mk.tenon_len = TENON_L
	(tools[6] as FinishTool).mode = 1

func check(step_id: String) -> bool:
	var pieces: Array = ws.pieces
	var a: Dictionary = ws.assembly
	match step_id:
		"select":
			return pieces.size() > 0
		"acclimate":
			return _all_acclimated()
		"plane":
			for p: WoodPiece in pieces:
				if absf(p.mean_thickness() - TARGET_T) > 0.3 or p.flatness() > 0.3:
					return false
			return pieces.size() > 0
		"crosscut":
			if pieces.size() < 2:
				return false
			for p: WoodPiece in pieces:
				if p.length < 240.0:
					return false
			return true
		"mortise":
			var m: WoodPiece = ws.mortise_piece()
			return m != null and float(m.mortise["depth"]) >= MORTISE_D - 0.5
		"tenon":
			var t: WoodPiece = ws.tenon_piece()
			return t != null and t.tenon.has("thickness")
		"fit":
			return a["dry_fit"]
		"glue":
			return a["released"]
		"sand":
			for p: WoodPiece in pieces:
				if p.scratch > 0.075 or p.glue_squeeze > 0.03 or p.marks_visible:
					return false
			return a["released"]
		"finish":
			for p: WoodPiece in pieces:
				if not _finished(p):
					return false
			return pieces.size() > 0
	return false

func evaluate() -> Dictionary:
	var leg: WoodPiece = ws.mortise_piece()
	var rail: WoodPiece = ws.tenon_piece()
	var a: Dictionary = ws.assembly
	var lines: Array[String] = []
	var total := 0.0
	lines.append("[font_size=26][b]作品評鑑：T 字方榫接合[/b][/font_size]\n")
	if leg == null or rail == null or not a["assembled"]:
		lines.append("作品尚未組裝完成，無法評分。")
		return {"text": "\n".join(lines), "score": 0.0}
	lines.append("樹種：%s\n" % leg.sp()["name"])

	var t_err := (absf(leg.mean_thickness() - TARGET_T) + absf(rail.mean_thickness() - TARGET_T)) * 0.5
	var flat := maxf(leg.flatness(), rail.flatness())
	var s1 := clampf(10.0 - t_err * 15.0, 0.0, 10.0) + clampf(5.0 - flat * 8.0, 0.0, 5.0)
	total += s1
	lines.append("尺寸精度　%4.1f / 15　（厚度誤差 %.2f mm、平整度 %.2f mm）" % [s1, t_err, flat])

	var delta: float = a["fit_delta"]
	var fit := WoodPhysics.fit_grade(delta)
	var s2 := 22.0 * float(fit["score"])
	var shoulder_gap := maxf(0.0, float(rail.tenon["length"]) - float(leg.mortise["depth"]))
	var sq := absf(float(rail.end_angle[int(rail.tenon["end"])]))
	s2 += clampf(8.0 - shoulder_gap * 6.0 - sq * 2.0, 0.0, 8.0)
	total += s2
	lines.append("接合配合　%4.1f / 30　（%s，間隙 %+.2f mm；肩部縫隙 %.1f mm；肩部直角誤差 %.1f°）" % [s2, fit["grade"], delta, shoulder_gap, sq])

	var strength: float = a["strength"]
	var s3 := 25.0 * strength
	total += s3
	var snotes: Array = a["strength_notes"]
	lines.append("結構強度　%4.1f / 25　（%d%%）%s" % [s3, int(strength * 100), ("　" + "、".join(snotes)) if snotes.size() > 0 else ""])

	var s4 := 15.0
	var surf_notes: Array[String] = []
	for p: WoodPiece in [leg, rail]:
		if p.max_tearout() > 0.05:
			s4 -= 3.0
			surf_notes.append("%s 有逆紋撕裂" % p.label_name)
		if p.scratch > 0.075:
			s4 -= 3.0
			surf_notes.append("%s 砂磨不足" % p.label_name)
		if p.cross_scratch > 0.02:
			s4 -= 2.0
			surf_notes.append("%s 有橫紋刮痕" % p.label_name)
	s4 = maxf(s4, 0.0)
	total += s4
	lines.append("表面處理　%4.1f / 15　%s" % [s4, "、".join(surf_notes)])

	var defects: Array[String] = []
	var coats := mini(leg.finish_coats, rail.finish_coats)
	var s5 := clampf(coats * 5.0, 0.0, 15.0)
	for p: WoodPiece in [leg, rail]:
		for d in p.defects:
			if not defects.has(d):
				defects.append(d)
		if p.finish_wet > 0.0 and not defects.has("塗裝未乾就交件"):
			defects.append("塗裝未乾就交件")
	s5 = maxf(0.0, s5 - defects.size() * 3.0)
	total += s5
	lines.append("塗　　裝　%4.1f / 15　（%d 道）%s" % [s5, coats, ("　瑕疵：" + "、".join(defects)) if defects.size() > 0 else ""])

	if leg.split or rail.split:
		total -= 25.0
		lines.append("[color=red]木料劈裂　-25[/color]")
	if a.has("built_mc") and absf(float(a["built_mc"]) - ws.emc) > 2.0:
		lines.append("[color=orange]⚠ 組裝時含水率 %.1f%% 與工坊平衡含水率 %.1f%% 差太多，作品日後會收縮、接合會鬆。[/color]" % [a["built_mc"], ws.emc])
	total = clampf(total, 0.0, 100.0)
	lines.append("\n[font_size=30][b]總分 %.0f / 100　評等：%s[/b][/font_size]" % [total, rank_text(total)])
	return {"text": "\n".join(lines), "score": total}
