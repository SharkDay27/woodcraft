class_name WhetstoneTool
extends WorkTool
## 磨刀石。研磨刨刀與鑿子的刃口。
## 操作：按住左鍵上下來回推磨。左右晃動 = 研磨角度不穩，會把刃口磨圓，效果打折。
## 依序：#1000 中砥（最多 85%）→ #6000 仕上砥（到 100%）。未經中砥直接仕上，效果很差。
## 硬鋼刃口在硬木上磨耗較快，這就是為什麼真實木工常常在磨刀。

const STONES := [{"grit": 1000, "cap": 0.85}, {"grit": 6000, "cap": 1.0}]

var target_index: int = 0

func _init(p_ws) -> void:
	super(p_ws)
	id = "whetstone"
	display = "磨刀石"

func _target() -> WorkTool:
	var list: Array = ws.sharpenable_tools()
	target_index = posmod(target_index, list.size())
	return list[target_index]

func help() -> String:
	return "按住左鍵上下推磨，保持左右穩定（角度一致）。R：換磨刀石號數。滾輪：換要研磨的刀具。"

func status() -> String:
	var t := _target()
	return "研磨：[b]%s[/b]　%s\n磨刀石：[b]#%d[/b]（最多磨到 %d%%）" % [t.display, t.sharp_text(), STONES[mode]["grit"], int(STONES[mode]["cap"] * 100)]

func cycle_mode() -> void:
	mode = (mode + 1) % STONES.size()
	ws.say("換成 #%d 磨刀石" % STONES[mode]["grit"])

func wheel(dir: int, _shift: bool) -> void:
	target_index += dir
	ws.say("研磨對象：" + _target().display)

func press(_hit: Dictionary) -> void:
	pressed = true

func motion(rel: Vector2, _hit: Dictionary) -> void:
	if not pressed:
		return
	var t := _target()
	var stroke := absf(rel.y)
	if stroke < 1.0:
		return
	ws.sfx.stone(clampf(stroke / 40.0, 0.0, 1.0), STONES[mode]["grit"])
	var stability := 1.0 - clampf(absf(rel.x) / (stroke + 1.0), 0.0, 0.85)
	var gain := stroke * 0.00035 * stability
	var cap: float = STONES[mode]["cap"]
	if mode == 1 and t.sharpness < 0.78:
		gain *= 0.15
	if t.sharpness < cap:
		t.sharpness = minf(cap, t.sharpness + gain)
	elif stability < 0.5:
		t.sharpness = maxf(0.3, t.sharpness - stroke * 0.0001)   # 角度亂晃把刃口磨圓
	ws.advance_time(stroke * 0.003)

func release(_hit: Dictionary) -> void:
	pressed = false
	var t := _target()
	if mode == 1 and t.sharpness < 0.8:
		ws.say("仕上砥的效果很有限——先用 #1000 中砥把刃口磨出來。")
