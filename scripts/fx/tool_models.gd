class_name ToolModels
extends Node3D
## 手上工具的 3D 實體與動作（全部用基本形狀程式建模，之後可換成 assets/models/ 的 .glb）。
##  - 游標在木料上：工具放到木料上的作業位置，跟著動作移動
##      手刨沿著刨削行程推、鋸子在鋸路裡來回拉並隨深度下沉、
##      鑿子立在游標處，木槌蓄力時舉高、放開時敲下
##  - 游標不在木料上：工具拿在手上（畫面右下）
##  - 夾持中的 F 夾會一直留在作品上

var ws
var models := {}
var mallet: Node3D
var clamp_model: Node3D
var _saw_offset := 0.0
var _last_anim := {}
var _jiggle := Vector3.ZERO
var _sand_paper: MeshInstance3D
var _pencil: Node3D
var _square: Node3D
var _gauge: Node3D
var _stone_blade: Node3D
var _can: Node3D

var M_OAK := _mat(Color(0.70, 0.52, 0.32), 0.7)
var M_DARK := _mat(Color(0.36, 0.22, 0.13), 0.6)
var M_STEEL := _mat(Color(0.80, 0.81, 0.84), 0.35, 0.5)
var M_BLACK := _mat(Color(0.12, 0.12, 0.13), 0.5, 0.4)
var M_CORK := _mat(Color(0.66, 0.50, 0.34), 0.95)
var M_PAPER := _mat(Color(0.55, 0.45, 0.32), 1.0)
var M_RED := _mat(Color(0.75, 0.18, 0.12), 0.5)
var M_WHITE := _mat(Color(0.92, 0.91, 0.86), 0.5)
var M_ORANGE := _mat(Color(0.85, 0.45, 0.15), 0.5)
var M_STONE1 := _mat(Color(0.78, 0.42, 0.24), 0.95)
var M_STONE2 := _mat(Color(0.88, 0.86, 0.80), 0.9)
var M_CLOTH := _mat(Color(0.86, 0.80, 0.68), 1.0)
var M_CAN := _mat(Color(0.20, 0.36, 0.30), 0.4, 0.6)
var M_GRAPHITE := _mat(Color(0.15, 0.15, 0.15), 0.6)
var M_YELLOW := _mat(Color(0.95, 0.78, 0.25), 0.6)

func _ready() -> void:
	models["plane"] = _build_plane()
	models["marking"] = _build_marking()
	models["saw"] = _build_saw()
	models["chisel"] = _build_chisel()
	models["sand"] = _build_sand()
	models["glue"] = _build_glue()
	models["finish"] = _build_finish()
	models["whetstone"] = _build_whetstone()
	mallet = _build_mallet()
	clamp_model = _build_clamp()
	_can = Node3D.new()
	add_child(_can)
	_cyl(_can, 0.045, 0.085, Vector3(0, 0.0425, 0), M_CAN)
	_cyl(_can, 0.046, 0.006, Vector3(0, 0.086, 0), M_STEEL)
	for m in models.values():
		m.visible = false
	mallet.visible = false
	clamp_model.visible = false
	_can.visible = false

# ================================================================ 建模積木
static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = 16
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _root() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	return n

# ================================================================ 各工具模型（原點 = 接觸點）
## 日式鉋刀：橡木鉋台 + 斜插的鉋刃與壓鐵（原點在鉋底中心，長度沿 x）
func _build_plane() -> Node3D:
	var n := _root()
	_box(n, Vector3(0.27, 0.034, 0.075), Vector3(0, 0.017, 0), M_OAK)
	_box(n, Vector3(0.008, 0.075, 0.066), Vector3(0.01, 0.05, 0), M_STEEL, Vector3(0, 0, deg_to_rad(52)))
	_box(n, Vector3(0.005, 0.06, 0.062), Vector3(0.022, 0.048, 0), M_STEEL.duplicate(), Vector3(0, 0, deg_to_rad(52)))
	_box(n, Vector3(0.03, 0.006, 0.075), Vector3(-0.005, 0.035, 0), M_DARK)   # 刨口
	return n

## 鉛筆 + 直角尺（模式 0）、劃線規（模式 1、2）
func _build_marking() -> Node3D:
	var n := _root()
	_square = Node3D.new()
	n.add_child(_square)
	_box(_square, Vector3(0.012, 0.002, 0.16), Vector3(0, 0.001, -0.08), M_STEEL)          # 尺身（橫跨板面）
	_box(_square, Vector3(0.025, 0.03, 0.1), Vector3(-0.0125, -0.005, 0.05), M_DARK)      # 尺座（靠著板邊）
	_pencil = Node3D.new()
	n.add_child(_pencil)
	_cyl(_pencil, 0.0035, 0.15, Vector3(0, 0.075, 0), M_YELLOW)
	_cyl(_pencil, 0.0035, 0.012, Vector3(0, 0.006, 0), M_OAK, Vector3.ZERO, 0.0008)
	_pencil.rotation = Vector3(0.4, 0, -0.3)
	_gauge = Node3D.new()
	n.add_child(_gauge)
	_box(_gauge, Vector3(0.02, 0.02, 0.2), Vector3(0, 0.012, -0.03), M_OAK)              # 規桿
	_box(_gauge, Vector3(0.07, 0.07, 0.022), Vector3(0, 0.012, 0.011), M_DARK)           # 定規（靠板邊）
	_cyl(_gauge, 0.002, 0.008, Vector3(0, 0.002, -0.08), M_STEEL)                         # 劃線刀
	return n

## 兩刃鋸：薄鋸片（兩側鋸齒）+ 長柄（原點在鋸齒線中點，鋸片在 XY 平面）
func _build_saw() -> Node3D:
	var n := _root()
	var blade := _box(n, Vector3(0.24, 0.095, 0.0008), Vector3(0, 0.0475, 0), M_STEEL)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_box(n, Vector3(0.24, 0.004, 0.0012), Vector3(0, 0.002, 0), M_BLACK)                 # 鋸齒（下）
	_box(n, Vector3(0.24, 0.004, 0.0012), Vector3(0, 0.093, 0), M_BLACK)                 # 鋸齒（上）
	_box(n, Vector3(0.05, 0.03, 0.006), Vector3(0.135, 0.047, 0), M_STEEL)                # 鋸頸
	_cyl(n, 0.013, 0.26, Vector3(0.29, 0.047, 0), M_DARK, Vector3(0, 0, PI * 0.5))         # 握柄
	return n

## 鑿子：鋼刃 + 銅箍 + 木柄（原點在刃口，向上延伸）
func _build_chisel() -> Node3D:
	var n := _root()
	n.set_meta("blade", _box(n, Vector3(0.008, 0.06, 0.004), Vector3(0, 0.03, 0), M_STEEL))
	_cyl(n, 0.009, 0.015, Vector3(0, 0.068, 0), _mat(Color(0.75, 0.55, 0.25), 0.3, 0.9))
	_cyl(n, 0.012, 0.11, Vector3(0, 0.13, 0), M_DARK, Vector3.ZERO, 0.014)
	_cyl(n, 0.015, 0.008, Vector3(0, 0.188, 0), M_STEEL)                                   # 頭箍
	return n

func _build_mallet() -> Node3D:
	var n := _root()
	_cyl(n, 0.032, 0.11, Vector3.ZERO, M_OAK, Vector3(0, 0, PI * 0.5))                     # 槌頭（原點）
	_cyl(n, 0.011, 0.26, Vector3(0, 0, 0.13), M_DARK, Vector3(PI * 0.5, 0, 0))              # 槌柄朝向玩家
	return n

## 砂磨木塊 + 砂紙（原點在砂紙面）
func _build_sand() -> Node3D:
	var n := _root()
	_box(n, Vector3(0.11, 0.03, 0.065), Vector3(0, 0.017, 0), M_CORK)
	_sand_paper = _box(n, Vector3(0.115, 0.002, 0.068), Vector3(0, 0.001, 0), M_PAPER)
	return n

func _build_glue() -> Node3D:
	var n := _root()
	_cyl(n, 0.026, 0.12, Vector3(0, 0.07, 0), M_WHITE)
	_cyl(n, 0.02, 0.018, Vector3(0, 0.139, 0), M_ORANGE)
	_cyl(n, 0.008, 0.03, Vector3(0, 0.163, 0), M_ORANGE, Vector3.ZERO, 0.002)
	_box(n, Vector3(0.053, 0.05, 0.002), Vector3(0, 0.07, 0.0262), M_YELLOW)               # 標籤
	return n

func _build_finish() -> Node3D:
	var n := _root()
	_box(n, Vector3(0.09, 0.015, 0.07), Vector3(0, 0.0075, 0), M_CLOTH, Vector3(0.05, 0.2, 0.08))
	_box(n, Vector3(0.05, 0.03, 0.05), Vector3(0.01, 0.025, 0.005), M_CLOTH, Vector3(0.3, 0.6, 0.2))
	return n

## 磨刀石（拿在手上的畫面）：雙面砥石 + 正在研磨的刀刃
func _build_whetstone() -> Node3D:
	var n := _root()
	_box(n, Vector3(0.21, 0.025, 0.07), Vector3(0, -0.0125, 0), M_STONE1)
	_box(n, Vector3(0.21, 0.025, 0.07), Vector3(0, -0.0375, 0), M_STONE2)
	_box(n, Vector3(0.23, 0.02, 0.09), Vector3(0, -0.06, 0), M_DARK)                      # 砥台
	_stone_blade = Node3D.new()
	n.add_child(_stone_blade)
	_box(_stone_blade, Vector3(0.05, 0.004, 0.065), Vector3(0, 0.006, 0), M_STEEL, Vector3(0, 0, deg_to_rad(25)))
	_box(_stone_blade, Vector3(0.07, 0.008, 0.066), Vector3(0.05, 0.03, 0), M_STEEL, Vector3(0, 0, deg_to_rad(25)))
	return n

func _build_clamp() -> Node3D:
	var n := _root()
	_box(n, Vector3(0.014, 0.34, 0.026), Vector3(0, 0.17, 0), M_STEEL)                    # 夾桿
	_box(n, Vector3(0.09, 0.022, 0.03), Vector3(0.045, 0.33, 0), M_RED)                    # 固定顎
	_box(n, Vector3(0.09, 0.022, 0.03), Vector3(0.045, 0.0, 0), M_RED)                     # 活動顎
	_cyl(n, 0.012, 0.1, Vector3(0.08, -0.055, 0), M_DARK)                                  # 螺桿把手
	return n

# ================================================================ 每幀擺位與動作
func _process(delta: float) -> void:
	if ws == null or not ws._started or ws.cam == null:
		for m in models.values():
			m.visible = false
		mallet.visible = false
		return
	var t: WorkTool = ws.current_tool()
	for k in models:
		models[k].visible = k == t.id and not ws.hud.menu_open()
	mallet.visible = t.id == "chisel" and t.mode == 0 and models["chisel"].visible
	_can.visible = t.id == "finish" and models["finish"].visible
	_update_clamp()
	var m: Node3D = models.get(t.id)
	if m == null or not m.visible:
		return
	var prev: Vector2 = _last_anim.get(t.id, t.anim)
	var d_anim := t.anim - prev
	_last_anim[t.id] = t.anim
	var target := _target(t, d_anim, delta)
	var k := clampf(delta * 16.0, 0.0, 1.0)
	m.global_transform = m.global_transform.interpolate_with(target, k)
	if t.id == "chisel" and t.mode == 0:
		_update_mallet(t as ChiselTool, m, delta)
	if t.id == "finish":
		_can.global_position = ws.active_piece().to_global(Vector3(ws.active_piece().length * 0.0005 + 0.06, 0, 0.05)) if ws.active_piece() else _hand(t).origin
		_can.global_position.y = ws.BENCH_TOP

## 拿在手上的位置（畫面右下）
func _hand(t: WorkTool) -> Transform3D:
	var tilt := Basis.from_euler(Vector3(-0.35, 0.5, 0.15))
	var off := Vector3(0.16, -0.12, -0.36)
	match t.id:
		"saw":
			tilt = Basis.from_euler(Vector3(0.0, 0.9, 0.5))
			off = Vector3(0.12, -0.16, -0.42)
		"whetstone":
			tilt = Basis.from_euler(Vector3(0.65, 0.0, 0.0))
			off = Vector3(0.02, -0.13, -0.48)
		"chisel":
			tilt = Basis.from_euler(Vector3(0.2, 0.3, -0.2))
	return ws.cam.global_transform * Transform3D(tilt, off)

func _target(t: WorkTool, d_anim: Vector2, delta: float) -> Transform3D:
	var p: WoodPiece = ws.active_piece()
	var hit: Dictionary = ws.last_hit
	if t.id == "whetstone":
		_stone_blade.position.x = clampf(_stone_blade.position.x + d_anim.y * 0.0012, -0.07, 0.07)
		_stone_blade.position.z = clampf(_stone_blade.position.z + d_anim.x * 0.0004, -0.01, 0.01) * 0.9
		return _hand(t)
	if p == null:
		return _hand(t)
	var T := p.mean_thickness()
	var on: bool = hit.get("on_piece", false)
	var lp: Vector3 = hit.get("local", Vector3.ZERO)
	var top: Vector3 = hit.get("top", Vector3.ZERO)
	var pb := p.global_basis
	match t.id:
		"plane":
			if not (on or t.pressed):
				return _hand(t)
			var x := clampf(top.x, -p.length * 0.5 - 140.0, p.length * 0.5 + 140.0)
			var lift := 0.0 if t.pressed else 0.006
			return Transform3D(pb, p.to_global(Vector3(x, T * 0.5, 0) * 0.001) + Vector3.UP * lift)
		"marking":
			if not on:
				_set_marking_mode(t.mode)
				return _hand(t)
			_set_marking_mode(t.mode)
			var w2 := p.width * 0.5
			if t.mode == 0:
				_square.position = Vector3(0, 0, w2 * 0.001)
				_pencil.position = Vector3(0.002, 0, lp.z * 0.001)
			else:
				_gauge.position = Vector3(0, 0, w2 * 0.001)
			return Transform3D(pb, p.to_global(Vector3(lp.x, T * 0.5, 0) * 0.001))
		"saw":
			var saw := t as SawTool
			var j := saw.current_job()
			if j.is_empty():
				return _hand(t)
			_saw_offset = clampf(_saw_offset + d_anim.y * 0.0012, -0.07, 0.07)
			if not t.pressed:
				_saw_offset = lerpf(_saw_offset, 0.0, delta * 3.0)
			return _saw_xform(p, j, T)
		"chisel":
			var ch := t as ChiselTool
			var blade: MeshInstance3D = models["chisel"].get_meta("blade")
			(blade.mesh as BoxMesh).size.x = ch.chisel_width() * 0.001
			if ch.mode == 1 and p.tenon.has("thickness"):
				var e: float = p.tenon["end"]
				var b := pb * Basis(Vector3(0, 0, 1), -e * PI * 0.5)
				var push := ch.force * 0.004 if ch.pressed else 0.0
				return Transform3D(b, p.to_global(Vector3(e * (p.length * 0.5 - float(p.tenon["length"])) + e * push * 1000.0, float(p.tenon["thickness"]) * 0.5, 0) * 0.001))
			if not on:
				return _hand(t)
			var wob := Basis(Vector3(0, 0, 1), clampf(ch.anim.x * 0.002, -0.15, 0.15)) if ch.pressed else Basis.IDENTITY
			return Transform3D(pb * wob, p.to_global(Vector3(lp.x, T * 0.5, lp.z) * 0.001))
		"sand":
			if not (on or t.pressed):
				return _hand(t)
			((_sand_paper.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(0.45, 0.36, 0.25).lerp(Color(0.86, 0.80, 0.66), float((t as SandTool).grit_index) / 4.0)
			return Transform3D(pb, p.to_global(Vector3(lp.x, T * 0.5, lp.z) * 0.001))
		"glue":
			if not on:
				return _hand(t)
			var tilt := Basis(Vector3(0, 0, 1), 2.2 if t.pressed else 0.3)
			return Transform3D(pb * tilt, p.to_global(Vector3(lp.x, T * 0.5 + 25.0, lp.z) * 0.001))
		"finish":
			if not on:
				return _hand(t)
			return Transform3D(pb, p.to_global(Vector3(lp.x, T * 0.5, lp.z) * 0.001))
	return _hand(t)

func _set_marking_mode(mode: int) -> void:
	_square.visible = mode == 0
	_pencil.visible = mode == 0
	_gauge.visible = mode != 0

## 鋸子：放進鋸路，隨進度下沉，隨拉鋸來回移動
func _saw_xform(p: WoodPiece, j: Dictionary, T: float) -> Transform3D:
	var pb := p.global_basis
	var pos := Vector3.ZERO
	var b := Basis.IDENTITY
	var kind := String(j["kind_id"])
	var prog: float = j["progress"]
	if kind == "cheek":
		var e: float = p.tenon["end"]
		var side: float = j["side"]
		pos = Vector3(e * (p.length * 0.5 - prog), side * (float(p.tenon["target"]) * 0.5 + float(j["dev"])), 0)
		b = Basis(Vector3(0, 0, 1), Vector3(e, 0, 0), Vector3(0, e, 0))   # 鋸片水平、齒朝肩部
	else:
		var x: float = (float(j["x"]) if kind == "cross_full" else p.shoulder_x()) + float(j["dev"])
		var side2: float = j.get("side", 1.0)
		pos = Vector3(x, side2 * (T * 0.5 - prog), 0)
		b = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3(0, 0, 1), 0.35)  # 鋸片垂直於木料長度、握柄抬高
		if side2 < 0.0:
			b = Basis(Vector3(1, 0, 0), PI) * b
	b = b.orthonormalized()
	var world_b := pb * b
	var world_pos := p.to_global(pos * 0.001) + world_b.x * _saw_offset
	return Transform3D(world_b, world_pos)

func _update_mallet(ch: ChiselTool, chisel: Node3D, _delta: float) -> void:
	var since := float(Time.get_ticks_msec() - ch.last_strike_ms) / 1000.0
	var h := 0.025
	if ch.pressed:
		h = 0.02 + ch.force * 0.07          # 蓄力：木槌舉高
	elif since < 0.06:
		h = lerpf(0.08, 0.0, since / 0.06)  # 敲下
	elif since < 0.2:
		h = lerpf(0.0, 0.025, (since - 0.06) / 0.14)
	# 以手腕為支點從側面揮動：h 越大，槌頭沿弧線往外、往上抬
	var top := chisel.global_transform * Vector3(0, 0.192 + 0.032, 0)
	var ang := clampf(h / 0.09, 0.0, 1.0) * 1.1
	var r := 0.14
	var off := Vector3(sin(ang) * r, (1.0 - cos(ang)) * r * 0.7, 0.0)
	var swing := Basis(Vector3.UP, 0.9) * Basis(Vector3(1, 0, 0), ang * 0.7)   # 槌柄朝外側、朝向玩家
	mallet.global_transform = Transform3D(chisel.global_basis * swing, top + chisel.global_basis * off)

func _update_clamp() -> void:
	var a: Dictionary = ws.assembly
	var leg: WoodPiece = ws.mortise_piece()
	var rail: WoodPiece = ws.tenon_piece()
	clamp_model.visible = a.get("clamped", false) and leg != null and rail != null
	if not clamp_model.visible:
		return
	var Tl := leg.mean_thickness() * 0.001
	var base := leg.to_global(Vector3(float(leg.mortise["x"]) * 0.001 + rail.width * 0.0005 + 0.03, -leg.mean_thickness() * 0.0005, 0))
	clamp_model.global_position = base
	clamp_model.rotation = Vector3(0, PI, 0)
	var s := (rail.length * 0.001 + Tl) / 0.33
	clamp_model.scale = Vector3(1, s, 1)
