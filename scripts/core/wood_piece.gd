class_name WoodPiece
extends Node3D
## 一塊木料。座標：原點在中心，x = 長度（纖維方向），y = 厚度，z = 寬度。
## 邏輯單位為 mm，場景單位為 m。
## 厚度不是單一數字，而是沿長度的「厚度剖面」：刨刀只削高點，平整度會自然浮現。

const PROFILE_N := 48
const WOOD_SHADER := preload("res://shaders/wood.gdshader")

var species_id: String = "white_pine"
var label_name: String = "木料"
var length: float = 520.0
var width: float = 60.0
var moisture: float = 9.0
var grain_runout: float = 3.0   ## 纖維傾斜角（度）。>0：往 +x 方向刨是順紋
var profile := PackedFloat32Array()   ## 每段厚度 (mm)
var tearout := PackedFloat32Array()   ## 每段逆紋撕裂坑深度 (mm)
var cup: float = 0.0                  ## 橫向翹曲 (mm)，含水率變化造成
var worked: bool = false              ## 是否已被刨過（之後的含水率變化會造成翹曲）
var scratch: float = 0.5              ## 表面刮痕深度（粗鋸面 0.5）
var cross_scratch: float = 0.0        ## 橫紋刮痕
var glue_squeeze: float = 0.0
var finish_kind: String = ""
var finish_coats: int = 0
var finish_wet: float = 0.0           ## 剩餘乾燥時間（分鐘）
var sanded_since_coat: bool = true
var defects: Array[String] = []
var split: bool = false
var end_angle := {1: 0.0, -1: 0.0}   ## 端面直角誤差（度）
var end_rough := {1: false, -1: false} ## 端面是否還是木料行的粗鋸端（需要鋸齊）
var inv_uid: int = 0                   ## 來自哪一筆庫存
var marks: Array = []
var marks_visible: bool = true
var cut_jobs: Array = []
var mortise: Dictionary = {}
var tenon: Dictionary = {}
var measured: Dictionary = {}
var pith := Vector3(0, -0.15, 0.02)

var _mat: ShaderMaterial
var _dirty := true
var _rebuild_cooldown := 0.0

# ================================================================ 建立
func setup(p_species: String, p_length: float, p_width: float, p_thick: float, p_mc: float, rough: bool) -> void:
	species_id = p_species
	length = p_length
	width = p_width
	moisture = p_mc
	profile.resize(PROFILE_N)
	tearout.resize(PROFILE_N)
	var bow := randf_range(0.6, 1.6) if rough else 0.0
	var twist_phase := randf() * TAU
	for i in PROFILE_N:
		var t := float(i) / float(PROFILE_N - 1)
		var b := bow * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var wav := 0.25 * sin(t * 7.0 + twist_phase) if rough else 0.0
		profile[i] = p_thick + b + wav + randf_range(-0.08, 0.08)
		tearout[i] = 0.0
	grain_runout = randf_range(1.5, 6.0) * (1.0 if randf() < 0.5 else -1.0)
	scratch = 0.5 if rough else 0.05
	end_rough = {1: rough, -1: rough}
	if rough:
		end_angle = {1: randf_range(1.0, 4.0), -1: randf_range(1.0, 4.0)}
	pith = Vector3(randf_range(-0.2, 0.2), -randf_range(0.08, 0.25), randf_range(-0.04, 0.04))
	_make_material()
	_dirty = true

func _make_material() -> void:
	var sp := WoodSpecies.get_data(species_id)
	_mat = ShaderMaterial.new()
	_mat.shader = WOOD_SHADER
	_mat.set_shader_parameter("early_color", sp["early"])
	_mat.set_shader_parameter("late_color", sp["late"])
	_mat.set_shader_parameter("ring_freq", sp["ring_freq"])
	_mat.set_shader_parameter("pith_offset", pith)
	var tex_path: String = sp["texture"]
	if ResourceLoader.exists(tex_path):
		_mat.set_shader_parameter("albedo_tex", load(tex_path))
		_mat.set_shader_parameter("use_tex", true)

func sp() -> Dictionary:
	return WoodSpecies.get_data(species_id)

func hardness() -> float:
	return WoodSpecies.hardness(species_id)

# ================================================================ 量測
func x_of(i: int) -> float:
	return -length * 0.5 + (float(i) + 0.5) * length / PROFILE_N

func index_of(x: float) -> int:
	return clampi(int((x + length * 0.5) / length * PROFILE_N), 0, PROFILE_N - 1)

func thickness_at(x: float) -> float:
	var f := (x + length * 0.5) / length * PROFILE_N - 0.5
	var i0 := clampi(int(floor(f)), 0, PROFILE_N - 1)
	var i1 := clampi(i0 + 1, 0, PROFILE_N - 1)
	return lerpf(profile[i0], profile[i1], clampf(f - floor(f), 0.0, 1.0))

func mean_thickness() -> float:
	var s := 0.0
	for v in profile:
		s += v
	return s / PROFILE_N

func min_thickness() -> float:
	var m := 1e9
	for v in profile:
		m = minf(m, v)
	return m

## 平整度：直尺量到的最大光隙（長度方向起伏 + 橫向翹曲）
func flatness() -> float:
	var lo := 1e9
	var hi := -1e9
	for v in profile:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return (hi - lo) + cup

func max_tearout() -> float:
	var m := 0.0
	for v in tearout:
		m = maxf(m, v)
	return m

func half_extents_m() -> Vector3:
	return Vector3(length, mean_thickness(), width) * 0.0005

func job(id: String) -> Dictionary:
	for j in cut_jobs:
		if j["id"] == id:
			return j
	return {}

func pending_jobs() -> Array:
	var out := []
	for j in cut_jobs:
		if not j["done"]:
			out.append(j)
	return out

func tenon_complete() -> bool:
	if tenon.is_empty():
		return false
	for id in ["cheek_top", "cheek_bot", "shoulder_top", "shoulder_bot"]:
		var j := job(id)
		if j.is_empty() or not j["done"]:
			return false
	return true

func shoulder_x() -> float:
	return float(tenon["end"]) * (length * 0.5 - float(tenon["length"]))

# ================================================================ 含水率與木材形變
func set_moisture(new_mc: float) -> void:
	var s := sp()
	var ft := WoodPhysics.movement_factor(s["shrink_t"], moisture, new_mc)  # 弦向：板寬
	var fr := WoodPhysics.movement_factor(s["shrink_r"], moisture, new_mc)  # 徑向：板厚
	if is_equal_approx(ft, 1.0) and is_equal_approx(fr, 1.0):
		moisture = new_mc
		return
	width *= ft
	for i in PROFILE_N:
		profile[i] *= fr
	if not mortise.is_empty():
		mortise["width"] = float(mortise["width"]) * ft
	if not tenon.is_empty() and tenon.has("thickness"):
		tenon["thickness"] = float(tenon["thickness"]) * fr
	# 弦切板兩面收縮不同 -> 杯形翹曲。已刨平的料變形才有意義。
	if worked:
		cup += absf(minf(new_mc, WoodPhysics.FSP) - minf(moisture, WoodPhysics.FSP)) * 0.06 * width / 60.0
	moisture = new_mc
	_dirty = true

# ================================================================ 視覺
func mark_dirty() -> void:
	_dirty = true

func _process(delta: float) -> void:
	_rebuild_cooldown -= delta
	if _dirty and _rebuild_cooldown <= 0.0:
		rebuild()

func rebuild() -> void:
	_dirty = false
	_rebuild_cooldown = 0.08
	for c in get_children():
		c.queue_free()
	if _mat == null:
		_make_material()
	_update_material()
	var T := mean_thickness()
	var L := length
	var W := width
	var comb := CSGCombiner3D.new()
	add_child(comb)
	var body := CSGBox3D.new()
	body.size = Vector3(L, T, W) * 0.001
	body.material = _mat
	comb.add_child(body)

	# 榫眼
	if not mortise.is_empty() and float(mortise["depth"]) > 0.05:
		var d: float = mortise["depth"]
		var mw: float = maxf(float(mortise["width"]), float(mortise["chisel"]))
		_sub(comb, Vector3(mortise["x"], T * 0.5 - d * 0.5 + 0.5, 0), Vector3(mortise["length"], d + 1.0, mw))

	# 榫頭：頰面 + 肩部都鋸完的那一側，廢料掉落
	if not tenon.is_empty():
		var e: float = tenon["end"]
		var xs := shoulder_x()
		var tl: float = tenon["length"]
		var cx := xs + e * (tl * 0.5 + 1.0)
		var t_target: float = tenon["target"]
		for side in [1, -1]:
			var cheek := job("cheek_top" if side == 1 else "cheek_bot")
			var sh := job("shoulder_top" if side == 1 else "shoulder_bot")
			if cheek.is_empty() or sh.is_empty():
				continue
			var face_y: float = side * (t_target * 0.5 - WoodPhysics.KERF * 0.5 + float(cheek["dev"]))
			if cheek["done"] and sh["done"]:
				var top: float = side * (T * 0.5 + 1.0)
				_sub(comb, Vector3(cx, (face_y + top) * 0.5, 0), Vector3(tl + 2.0, absf(top - face_y), W + 2.0))

	# 進行中的鋸路
	for j in cut_jobs:
		if j["done"] or float(j["progress"]) <= 0.01:
			continue
		var p: float = j["progress"]
		var k := WoodPhysics.KERF
		match String(j["kind_id"]):
			"cross_full":
				_sub(comb, Vector3(float(j["x"]) + float(j["dev"]), T * 0.5 - p * 0.5 + 0.5, 0), Vector3(k, p + 1.0, W + 2.0))
			"shoulder":
				var s: float = j["side"]
				_sub(comb, Vector3(shoulder_x() + float(j["dev"]), s * (T * 0.5 - p * 0.5 + 0.5), 0), Vector3(k, p + 1.0, W + 2.0))
			"cheek":
				var s2: float = j["side"]
				var e2: float = tenon["end"]
				var fy: float = s2 * (float(tenon["target"]) * 0.5 + float(j["dev"]))
				_sub(comb, Vector3(e2 * (L * 0.5 - p * 0.5 + 0.5), fy, 0), Vector3(p + 1.0, k, W + 2.0))

	if marks_visible:
		_build_marks(T)

func _sub(comb: CSGCombiner3D, center_mm: Vector3, size_mm: Vector3) -> void:
	var b := CSGBox3D.new()
	b.operation = CSGShape3D.OPERATION_SUBTRACTION
	b.size = size_mm * 0.001
	b.position = center_mm * 0.001
	b.material = _mat
	comb.add_child(b)

func _line(center_mm: Vector3, size_mm: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size_mm * 0.001
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.12, 0.14)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	mi.mesh = bm
	mi.position = center_mm * 0.001
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_marks(T: float) -> void:
	var W := width
	var lw := 0.35
	for m in marks:
		match String(m["type"]):
			"cross":
				var x: float = m["x"]
				_line(Vector3(x, T * 0.5 + 0.05, 0), Vector3(lw, 0.1, W))
				_line(Vector3(x, 0, W * 0.5 + 0.05), Vector3(lw, T, 0.1))
			"mortise":
				var mx: float = m["x"]
				var ml: float = m["length"]
				var mw: float = m["width"]
				for s in [1, -1]:
					_line(Vector3(mx, T * 0.5 + 0.05, s * mw * 0.5), Vector3(ml, 0.1, lw))
					_line(Vector3(mx + s * ml * 0.5, T * 0.5 + 0.05, 0), Vector3(lw, 0.1, mw))
			"tenon":
				var e: float = m["end"]
				var tl: float = m["length"]
				var tt: float = m["thickness"]
				var xs := e * (length * 0.5 - tl)
				_line(Vector3(xs, T * 0.5 + 0.05, 0), Vector3(lw, 0.1, W))
				_line(Vector3(xs, -T * 0.5 - 0.05, 0), Vector3(lw, 0.1, W))
				_line(Vector3(xs, 0, W * 0.5 + 0.05), Vector3(lw, T, 0.1))
				for s in [1, -1]:
					_line(Vector3(xs + e * tl * 0.5, s * tt * 0.5, W * 0.5 + 0.05), Vector3(tl, lw, 0.1))
					_line(Vector3(e * (length * 0.5 + 0.05), s * tt * 0.5, 0), Vector3(0.1, lw, W))

func _update_material() -> void:
	var rough := clampf(0.45 + scratch * 0.9, 0.35, 0.95)
	_mat.set_shader_parameter("roughness_amt", rough)
	_mat.set_shader_parameter("tear_dark", clampf(max_tearout() * 4.0 + cross_scratch * 8.0, 0.0, 1.0))
	var g := 0.0
	var dark := 0.0
	if finish_coats > 0:
		dark = clampf(0.35 + 0.1 * finish_coats, 0.0, 0.6)
		g = clampf(finish_coats * (0.3 if finish_kind == "varnish" else 0.15), 0.0, 0.9)
	_mat.set_shader_parameter("gloss", g)
	_mat.set_shader_parameter("oil_darken", dark)

# ================================================================ 鋸斷後產生兩塊新料
## 回傳 [左料, 右料]。kerf_center 為實際鋸路中心 x。
func split_at(kerf_center: float, angle_deg: float) -> Array:
	var kerf := WoodPhysics.KERF
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var ranges := [[x0, kerf_center - kerf * 0.5], [kerf_center + kerf * 0.5, x1]]
	var out := []
	for r_i in 2:
		var a: float = ranges[r_i][0]
		var b: float = ranges[r_i][1]
		var p := WoodPiece.new()
		p.species_id = species_id
		p.length = b - a
		p.width = width
		p.moisture = moisture
		p.grain_runout = grain_runout
		p.cup = cup
		p.worked = worked
		p.scratch = scratch
		p.cross_scratch = cross_scratch
		p.pith = pith + Vector3((a + b) * 0.0005, 0, 0)
		p.split = false
		p.profile.resize(PROFILE_N)
		p.tearout.resize(PROFILE_N)
		var mid := (a + b) * 0.5
		for i in PROFILE_N:
			var xx := a + (float(i) + 0.5) * (b - a) / PROFILE_N
			p.profile[i] = thickness_at(xx)
			p.tearout[i] = tearout[index_of(xx)]
		p.end_angle = {1: end_angle[1] if r_i == 1 else angle_deg, -1: end_angle[-1] if r_i == 0 else angle_deg}
		p.end_rough = {1: end_rough[1] if r_i == 1 else false, -1: end_rough[-1] if r_i == 0 else false}
		p.label_name = label_name
		p.inv_uid = inv_uid
		p.defects = defects.duplicate()
		# 轉移劃線、榫眼、榫頭與尚未完成的鋸切
		for m in marks:
			if m["type"] == "cross" or m["type"] == "mortise":
				if float(m["x"]) > a and float(m["x"]) < b:
					var nm: Dictionary = m.duplicate()
					nm["x"] = float(m["x"]) - mid
					p.marks.append(nm)
			elif m["type"] == "tenon":
				if (int(m["end"]) == 1 and r_i == 1) or (int(m["end"]) == -1 and r_i == 0):
					p.marks.append(m.duplicate())
		for j in cut_jobs:
			if j["kind_id"] == "cross_full":
				if not j["done"] and float(j["x"]) > a and float(j["x"]) < b:
					var nj: Dictionary = j.duplicate()
					nj["x"] = float(j["x"]) - mid
					p.cut_jobs.append(nj)
			elif not tenon.is_empty() and ((int(tenon["end"]) == 1 and r_i == 1) or (int(tenon["end"]) == -1 and r_i == 0)):
				p.cut_jobs.append(j.duplicate())
		if not mortise.is_empty() and float(mortise["x"]) > a and float(mortise["x"]) < b:
			p.mortise = mortise.duplicate()
			p.mortise["x"] = float(mortise["x"]) - mid
		if not tenon.is_empty() and ((int(tenon["end"]) == 1 and r_i == 1) or (int(tenon["end"]) == -1 and r_i == 0)):
			p.tenon = tenon.duplicate()
		p._make_material()
		out.append(p)
	return out

# ================================================================ 存檔
const SAVE_FIELDS := ["species_id", "label_name", "length", "width", "moisture", "grain_runout", "cup", "worked", "scratch",
	"cross_scratch", "glue_squeeze", "finish_kind", "finish_coats", "finish_wet", "sanded_since_coat", "split",
	"marks", "marks_visible", "cut_jobs", "mortise", "tenon", "measured", "inv_uid"]

func to_dict() -> Dictionary:
	var d := {}
	for f in SAVE_FIELDS:
		d[f] = get(f)
	d["profile"] = Array(profile)
	d["tearout"] = Array(tearout)
	d["defects"] = Array(defects)
	d["end_angle"] = [end_angle[1], end_angle[-1]]
	d["end_rough"] = [end_rough[1], end_rough[-1]]
	d["pith"] = [pith.x, pith.y, pith.z]
	return d

static func from_dict(d: Dictionary) -> WoodPiece:
	var p := WoodPiece.new()
	for f in SAVE_FIELDS:
		if d.has(f):
			p.set(f, d[f])
	p.profile = PackedFloat32Array(d["profile"])
	p.tearout = PackedFloat32Array(d["tearout"])
	for x in d.get("defects", []):
		p.defects.append(String(x))
	p.end_angle = {1: float(d["end_angle"][0]), -1: float(d["end_angle"][1])}
	p.end_rough = {1: bool(d["end_rough"][0]), -1: bool(d["end_rough"][1])}
	p.pith = Vector3(d["pith"][0], d["pith"][1], d["pith"][2])
	# JSON 會把整數變成浮點數，把關鍵的整數欄位修回來
	if not p.tenon.is_empty():
		p.tenon["end"] = int(p.tenon["end"])
	if not p.mortise.is_empty():
		p.mortise["chips"] = int(p.mortise["chips"])
	for m in p.marks:
		if m.has("end"):
			m["end"] = int(m["end"])
	p._make_material()
	return p
