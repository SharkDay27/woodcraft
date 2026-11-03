class_name SandTool
extends WorkTool
## 砂紙 + 砂磨木塊。按住左鍵來回移動砂磨。
##  - 依序換號 (80→120→180→240→320)。跳號時細砂紙要很久才能磨掉粗砂紙的刮痕
##  - 沿纖維方向（左右）砂磨；橫向（上下）砂磨會留下橫紋刮痕，上油後特別明顯
##  - 也能磨掉逆紋撕裂坑、擠出的膠痕與鉛筆線

var grit_index: int = 1

func _init(p_ws) -> void:
	super(p_ws)
	id = "sand"
	display = "砂紙"

func grit() -> int:
	return WoodPhysics.GRITS[grit_index]

func help() -> String:
	return "按住左鍵左右來回砂磨（順纖維方向）。Ctrl+滾輪：換砂紙號數。\n依序換號，不要跳號；避免上下（橫紋）砂磨。"

func status() -> String:
	var s := "砂紙 [b]#%d[/b]" % grit()
	var p: WoodPiece = ws.active_piece()
	if p:
		s += "\n表面：%s" % _surface_word(p.scratch)
		if p.cross_scratch > 0.01:
			s += "　[color=orange]有橫紋刮痕[/color]"
		if p.max_tearout() > 0.05:
			s += "　[color=orange]有逆紋撕裂坑[/color]"
		if p.glue_squeeze > 0.02:
			s += "　[color=orange]有膠痕[/color]"
	return s

static func _surface_word(sc: float) -> String:
	if sc > 0.3: return "粗鋸面"
	if sc > 0.15: return "粗糙 (80 號程度)"
	if sc > 0.09: return "120 號程度"
	if sc > 0.055: return "180 號程度"
	if sc > 0.035: return "240 號程度"
	return "[color=lime]細緻[/color]"

func wheel(dir: int, _shift: bool) -> void:
	grit_index = clampi(grit_index + dir, 0, WoodPhysics.GRITS.size() - 1)
	ws.say("換成 #%d 砂紙" % grit())

func press(hit: Dictionary) -> void:
	if not hit.get("on_piece", false):
		return
	pressed = true

func motion(rel: Vector2, hit: Dictionary) -> void:
	if not pressed:
		return
	var p: WoodPiece = ws.active_piece()
	if p == null:
		return
	if p.finish_wet > 0.0:
		ws.say("塗裝還沒乾，不能砂磨。")
		pressed = false
		return
	var along := absf(rel.x)
	var across := absf(rel.y)
	var total := along + across
	if total < 1.0:
		return
	ws.sfx.sand(clampf(total / 40.0, 0.0, 1.0), grit())
	var hp: Vector3 = hit.get("local", Vector3.ZERO)
	ws.fx.sand_dust(p.to_global(Vector3(hp.x, p.mean_thickness() * 0.5, hp.z) * 0.001), p.sp()["early"])
	var level := WoodPhysics.grit_scratch(grit())
	var power := WoodPhysics.grit_power(grit())
	var work := total * 0.0009 / sqrt(maxf(p.hardness(), 0.2)) * WoodPhysics.speed_full()
	var removal := work * power
	if p.scratch > level:
		p.scratch = maxf(level, p.scratch - removal)
	else:
		p.scratch = maxf(p.scratch, level * 0.98)
	var cross_frac := across / total
	if cross_frac > 0.35:
		p.cross_scratch = maxf(p.cross_scratch, level * cross_frac)
	else:
		p.cross_scratch = maxf(0.0, p.cross_scratch - removal * 0.8)
	for i in WoodPiece.PROFILE_N:
		if p.tearout[i] > 0.0:
			var r := minf(p.tearout[i], removal * 0.3)
			p.tearout[i] -= r
			p.profile[i] -= r * 0.5
	p.glue_squeeze = maxf(0.0, p.glue_squeeze - removal * 2.0)
	p.sanded_since_coat = true
	if p.marks_visible and p.scratch < 0.1:
		p.marks_visible = false
		ws.say("鉛筆線被砂掉了。")
	ws.advance_time(total * 0.0012)
	p.mark_dirty()

func release(_hit: Dictionary) -> void:
	pressed = false
