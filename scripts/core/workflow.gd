class_name Workflow
extends RefCounted
## 作品專案的基底類別。每個作品 = 工序清單 + 完成條件 + 評分 + 產出的商品資料。
## 新增作品：在 scripts/core/projects/ 新增一個繼承 Workflow 的腳本，並加到 PROJECTS。

const PROJECTS := [
	{"id": "cutting_board", "name": "砧板", "script": "res://scripts/core/projects/cutting_board.gd", "sellable": true,
		"desc": "初學者的第一件作品：選料、刨平、兩端鋸齊、砂磨、上食品級油。需要寬板。",
		"sizes": [{"name": "小 250 × 20", "length": 250.0, "thickness": 20.0}, {"name": "中 300 × 20", "length": 300.0, "thickness": 20.0},
			{"name": "大 350 × 22", "length": 350.0, "thickness": 22.0}, {"name": "薄 300 × 18", "length": 300.0, "thickness": 18.0}]},
	{"id": "mortise_tenon", "name": "T 字方榫接合（練習）", "script": "res://scripts/core/projects/mortise_tenon.gd", "sellable": false,
		"desc": "榫卯基本功練習件，不能販售。需要角料。", "sizes": [{"name": "標準 24mm 厚", "thickness": 24.0}]},
]

var ws
var id: String = ""
var title: String = ""
var sellable: bool = false
var params: Dictionary = {}
var steps: Array = []

static func create(p_id: String, p_ws, p_params: Dictionary) -> Workflow:
	for pr in PROJECTS:
		if pr["id"] == p_id:
			return (load(pr["script"]) as GDScript).new(p_ws, p_params)
	return null

func _init(p_ws, p_params: Dictionary = {}) -> void:
	ws = p_ws
	params = p_params
	_define()

func _define() -> void:
	pass

func setup_tools(_tools: Array) -> void:
	pass

func check(_step_id: String) -> bool:
	return false

func current_step() -> int:
	for i in steps.size():
		if not check(steps[i]["id"]):
			return i
	return steps.size()

func is_complete() -> bool:
	return current_step() >= steps.size()

## 回傳 {"text": 評鑑文字, "score": 0~100, "product": 商品資料（可販售作品才有）}
func evaluate() -> Dictionary:
	return {"text": "", "score": 0.0}

# ---------------------------------------------------------------- 共用檢查
func _all_acclimated() -> bool:
	for p: WoodPiece in ws.pieces:
		if absf(p.moisture - ws.emc) > 2.0:
			return false
	return ws.pieces.size() > 0

func _surface_ok(p: WoodPiece) -> bool:
	return p.scratch <= 0.075 and p.glue_squeeze <= 0.03 and not p.marks_visible and p.max_tearout() <= 0.05

func _finished(p: WoodPiece, kind := "") -> bool:
	return p.finish_coats >= 2 and p.finish_wet <= 0.0 and (kind == "" or p.finish_kind == kind)

static func rank_text(total: float) -> String:
	return "S 名匠" if total >= 90 else ("A 熟手" if total >= 75 else ("B 學徒" if total >= 55 else ("C 新手" if total >= 35 else "D 再接再厲")))
