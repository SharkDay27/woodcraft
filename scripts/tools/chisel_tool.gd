class_name ChiselTool
extends WorkTool
## 鑿子 + 木槌。
##  模式 0：鑿榫眼——按住左鍵蓄力（木槌舉高），放開敲擊。蓄力時滑鼠左右晃 = 鑿子歪斜，會把榫眼壁撐寬。
##          每敲幾下要按 E 撬出木屑，否則木屑塞住鑿不下去。
##          靠近端部用力敲會劈裂。
##  模式 1：修榫頭——輕推削去頰面，一次 0.05~0.3 mm，削過頭就鬆了。

const WIDTHS := [6.0, 8.0, 9.0, 10.0, 12.0, 15.0, 18.0]
const MODES := ["鑿榫眼（木槌）", "修削榫頭頰面"]

var width_index: int = 1
var force: float = 0.0
var _wobble: float = 0.0

func _init(p_ws) -> void:
	super(p_ws)
	id = "chisel"
	display = "鑿子"
	sharpenable = true

func chisel_width() -> float:
	return WIDTHS[width_index]

func help() -> String:
	return "R：切換模式。滾輪：換鑿子寬度。按住左鍵蓄力、放開敲擊（蓄力時保持滑鼠穩定）。\nE：撬出木屑。K（在劃線工具中）：劃線規對準鑿子寬度。"

func status() -> String:
	var s := "模式：[b]%s[/b]　鑿寬 [b]%.0f mm[/b]　%s" % [MODES[mode], chisel_width(), sharp_text()]
	if pressed:
		s += "\n力道 " + _bar(force) + ("　[color=orange]晃動 %.2f[/color]" % _wobble if _wobble > 0.05 else "")
	var p: WoodPiece = ws.active_piece()
	if p and mode == 0 and not p.mortise.is_empty():
		var m := p.mortise
		s += "\n榫眼深 %.1f / %.1f mm　卡屑 %d　劃線寬 %.2f" % [m["depth"], m["target_depth"], m["chips"], m["mark_width"]]
		if int(m["chips"]) >= 3:
			s += "\n[color=orange]木屑塞住了，按 E 撬出[/color]"
	if p and mode == 1 and p.tenon.has("thickness"):
		s += "\n榫頭目前厚度：用卡尺 (M) 量測"
	return s

func _bar(v: float) -> String:
	var n := int(v * 10.0)
	var c := "lime" if v < 0.7 else ("yellow" if v < 0.9 else "red")
	return "[color=%s]%s[/color]%s" % [c, "█".repeat(n), "░".repeat(10 - n)]

func cycle_mode() -> void:
	mode = (mode + 1) % 2
	ws.say("鑿子模式：" + MODES[mode])

func wheel(dir: int, _shift: bool) -> void:
	width_index = clampi(width_index + dir, 0, WIDTHS.size() - 1)

func press(_hit: Dictionary) -> void:
	pressed = true
	force = 0.0
	_wobble = 0.0

func process(delta: float) -> void:
	if pressed:
		force = minf(1.0, force + delta * (0.9 if mode == 0 else 0.6))

func motion(rel: Vector2, _hit: Dictionary) -> void:
	if pressed:
		_wobble += absf(rel.x) * 0.002

func release(hit: Dictionary) -> void:
	if not pressed:
		return
	pressed = false
	var p: WoodPiece = ws.active_piece()
	if p == null:
		return
	if mode == 0:
		_strike(p, hit)
	else:
		_pare(p)
	p.mark_dirty()

func lever_out() -> void:
	var p: WoodPiece = ws.active_piece()
	if p == null or p.mortise.is_empty():
		return
	if int(p.mortise["chips"]) == 0:
		ws.say("榫眼裡沒有木屑。")
		return
	var n_chips := int(p.mortise["chips"])
	p.mortise["chips"] = 0
	ws.sfx.oneshot("lever")
	ws.fx.chips(p.to_global(Vector3(float(p.mortise["x"]), p.mean_thickness() * 0.5, 0) * 0.001), n_chips * 2 + 2, float(p.mortise["chisel"]), p.sp()["early"])
	# 用鑿子撬屑時若撬在榫眼端壁，會壓傷端壁
	p.mortise["bruise"] = float(p.mortise["bruise"]) + 0.03 / maxf(p.hardness(), 0.3)
	ws.advance_time(0.3)
	ws.say("撬出木屑。")

func _strike(p: WoodPiece, hit: Dictionary) -> void:
	if p.mortise.is_empty():
		ws.say("先用劃線規劃好榫眼。")
		return
	var m := p.mortise
	var lx: Vector3 = hit.get("local", Vector3.ZERO)
	if not hit.get("on_piece", false) or absf(lx.x - float(m["x"])) > float(m["length"]) * 0.5 + 2.0 or absf(lx.z) > float(m["mark_width"]) * 0.5 + 3.0:
		ws.say("鑿子沒有放在榫眼劃線內。")
		return
	var cw := chisel_width()
	if float(m["chisel"]) == 0.0:
		m["chisel"] = cw
		if cw > float(m["mark_width"]) + 0.3:
			ws.say("[color=orange]鑿子比劃線還寬 %.1f mm！[/color]" % (cw - float(m["mark_width"])))
		elif cw < float(m["mark_width"]) - 0.5:
			ws.say("鑿子比劃線窄，之後要分兩次鑿，壁面不會平整。")
	var wobble_w := _wobble * (1.5 - sharpness * 0.5)
	m["width"] = maxf(float(m["width"]), cw + wobble_w + (float(m["mark_width"]) - cw if cw < float(m["mark_width"]) - 0.5 else 0.0))
	if _wobble > 0.15:
		ws.say("鑿子歪了，榫眼壁被撐寬約 %.2f mm。" % wobble_w)
	var d := WoodPhysics.chisel_depth(force, sharpness, p.hardness(), int(m["chips"]))
	m["depth"] = minf(float(m["depth"]) + d, p.mean_thickness())
	m["chips"] = int(m["chips"]) + 1
	ws.sfx.oneshot("mallet", {"force": force, "hardness": p.hardness(), "depth": float(m["depth"])}, linear_to_db(0.4 + force * 0.6))
	if randf() < 0.5:
		ws.fx.chips(p.to_global(Vector3(lx.x, p.mean_thickness() * 0.5, 0) * 0.001), 1, cw, p.sp()["early"])
	wear(0.004 * p.hardness() * force)
	ws.advance_time(0.15)
	# 劈裂判定
	var end_dist := p.length * 0.5 - absf(float(m["x"])) - float(m["length"]) * 0.5
	if end_dist < 1.5 * p.mean_thickness() and force > 0.75 and not p.split:
		if randf() < 0.25 * float(p.sp()["split"]):
			p.split = true
			ws.sfx.oneshot("crack")
			ws.say("[color=red][b]啪！木料從榫眼往端部劈裂了。[/b][/color] 鑿榫眼時端部要留長（留「角」），完成後再鋸掉。")
	if float(m["depth"]) >= p.mean_thickness() - 0.1:
		ws.say("[color=red]鑿穿了！[/color]")
	elif float(m["depth"]) > float(m["target_depth"]) + 1.0:
		ws.say("[color=orange]榫眼比預定深 %.1f mm。[/color]" % (float(m["depth"]) - float(m["target_depth"])))

func _pare(p: WoodPiece) -> void:
	if not p.tenon.has("thickness"):
		ws.say("榫頭還沒鋸好。")
		return
	var amt := force * 0.28 * sharpness / sqrt(maxf(p.hardness(), 0.2)) * randf_range(0.7, 1.3)
	amt = maxf(amt, 0.02)
	p.tenon["thickness"] = float(p.tenon["thickness"]) - amt
	ws.sfx.oneshot("pare", {}, linear_to_db(0.5 + force * 0.5))
	var e: float = p.tenon["end"]
	ws.fx.chips(p.to_global(Vector3(e * (p.length * 0.5 - 5.0), p.mean_thickness() * 0.3, 0) * 0.001), 1 + int(force * 2.0), p.width * 0.6, p.sp()["early"])
	# 削得越用力越不平整
	p.tenon["pare_rough"] = float(p.tenon.get("pare_rough", 0.0)) + force * 0.02
	wear(0.002 * p.hardness())
	ws.advance_time(0.3)
	ws.say("削去頰面約 %s。" % ("薄薄一層" if amt < 0.1 else ("一層" if amt < 0.2 else "[color=orange]厚厚一層[/color]")))
