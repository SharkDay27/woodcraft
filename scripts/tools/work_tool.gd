class_name WorkTool
extends RefCounted
## 工具基底類別。workshop (ws) 是 main.gd，提供 active_piece()、log()、advance_time() 等。
## hit 字典：{"on_piece": bool, "local": Vector3(mm), "top": Vector3(mm, 在料頂面平面上，可超出料外)}

var ws
var id: String = ""
var display: String = ""
var sharpness: float = 1.0
var sharpenable: bool = false
var mode: int = 0
var pressed: bool = false
var anim := Vector2.ZERO   ## 按住時累積的滑鼠移動，給 3D 工具模型做動畫

func _init(p_ws) -> void:
	ws = p_ws

func help() -> String:
	return ""

func status() -> String:
	return ""

func press(_hit: Dictionary) -> void:
	pressed = true

func release(_hit: Dictionary) -> void:
	pressed = false

func motion(_rel: Vector2, _hit: Dictionary) -> void:
	pass

func wheel(_dir: int, _shift: bool) -> void:
	pass

func cycle_mode() -> void:
	pass

func process(_delta: float) -> void:
	pass

func wear(amount: float) -> void:
	var before := sharpness
	sharpness = clampf(sharpness - amount, 0.05, 1.0)
	if before >= 0.5 and sharpness < 0.5:
		ws.say("[color=orange]%s 的刃口變鈍了，切削更費力、表面更粗。按 8 到磨刀石研磨。[/color]" % display)

func sharp_text() -> String:
	var c := "lime" if sharpness > 0.75 else ("yellow" if sharpness > 0.45 else "red")
	return "刃口鋒利度 [color=%s]%d%%[/color]" % [c, int(sharpness * 100.0)]
