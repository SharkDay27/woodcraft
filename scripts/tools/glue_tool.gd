class_name GlueTool
extends WorkTool
## 木工白膠 (PVA) 與 F 夾。
##  模式 0 上膠：按住左鍵擠膠（越久越多）。上膠後開放時間 10 分鐘內要組裝 (F)。
##  模式 1 夾具：滾輪調整夾持壓力，左鍵 夾上／拆下。至少夾 45 分鐘 (T 等待)。

const MODES := ["上膠（白膠 PVA）", "F 夾"]

var _squeezing := false
var pressure: float = 0.5

func _init(p_ws) -> void:
	super(p_ws)
	id = "glue"
	display = "膠與夾具"

func help() -> String:
	return "R：切換 上膠／夾具。上膠：按住左鍵擠膠，然後按 F 組裝。\n夾具：滾輪調壓力，左鍵夾上／拆下。T：等待 10 分鐘（Shift+T：1 小時）。"

func status() -> String:
	var a: Dictionary = ws.assembly
	var s := "模式：[b]%s[/b]" % MODES[mode]
	s += "\n上膠量 %s" % _amount_word(a["glue"])
	if float(a["glue"]) > 0.0 and not a["assembled"]:
		var left: float = 10.0 - (ws.game_minutes - float(a["glue_time"]))
		s += "　開放時間剩 [color=%s]%.0f 分[/color]" % ["lime" if left > 3 else "red", maxf(left, 0.0)]
	s += "\n夾持壓力 %d%%" % int(pressure * 100.0)
	if a["clamped"]:
		s += "　[b]已夾持 %.0f 分鐘[/b]" % (ws.game_minutes - float(a["clamp_time"]))
	return s

static func _amount_word(v: float) -> String:
	if v <= 0.0: return "無"
	if v < 0.3: return "[color=orange]太少 (%d%%)[/color]" % int(v * 100)
	if v <= 0.8: return "[color=lime]適量 (%d%%)[/color]" % int(v * 100)
	return "[color=orange]太多 (%d%%)[/color]" % int(v * 100)

func cycle_mode() -> void:
	mode = (mode + 1) % 2
	ws.say("切換：" + MODES[mode])

func wheel(dir: int, _shift: bool) -> void:
	pressure = clampf(pressure + dir * 0.05, 0.0, 1.0)

func press(_hit: Dictionary) -> void:
	var a: Dictionary = ws.assembly
	if mode == 0:
		if a["assembled"]:
			ws.say("已經組裝了。")
			return
		if not a["dry_fit"]:
			ws.say("[color=orange]先乾試裝 (F) 確認配合，再上膠！[/color]")
			return
		if float(a["glue"]) == 0.0:
			a["glue_time"] = ws.game_minutes
		pressed = true
		_squeezing = true
		ws.sfx.oneshot("squeeze")
	else:
		if not a["assembled"]:
			ws.say("還沒組裝，沒有東西可以夾。")
			return
		if a["clamped"]:
			a["clamp_minutes"] = ws.game_minutes - float(a["clamp_time"])
			a["clamped"] = false
			ws.sfx.oneshot("clamp")
			ws.say("拆下夾具（夾了 %.0f 分鐘）。" % a["clamp_minutes"])
			ws.finalize_glue()
		else:
			a["clamped"] = true
			ws.sfx.oneshot("clamp")
			a["clamp_time"] = ws.game_minutes
			a["pressure"] = pressure
			var leg: WoodPiece = ws.mortise_piece()
			if leg and float(a["glue"]) > 0.6:
				leg.glue_squeeze = (float(a["glue"]) - 0.5) * (0.5 + pressure)
				ws.say("膠從接縫擠出來了。可以等它半乾再刮掉，或之後砂掉。")
			ws.say("夾上 F 夾，壓力 %d%%。" % int(pressure * 100))

func process(delta: float) -> void:
	if _squeezing:
		ws.assembly["glue"] = minf(1.5, float(ws.assembly["glue"]) + delta * 0.35)

func release(_hit: Dictionary) -> void:
	if _squeezing:
		_squeezing = false
		ws.say("上膠量：%s" % _amount_word(ws.assembly["glue"]))
	pressed = false
