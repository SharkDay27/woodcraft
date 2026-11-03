class_name WorkshopFx
extends Node3D
## 木屑特效：全部依物理參數產生，所以看木屑就能判斷手藝——
##  - 刨花：厚度 = 實際吃刀深度，長度 = 刨削行程。薄刨花捲得緊、顏色透亮；
##          刃口鋒利 + 順紋 = 一整條連續長捲；鈍刀或逆紋 = 碎成短片
##  - 鋸屑：縱切齒出粗屑、橫切齒出細粉；鋸屑在料旁堆成小堆，大小 = 鋸掉的木料體積
##  - 鑿屑：每次敲擊飛出小碎片，撬屑 (E) 時一次掏出一把
##  - 榫頭廢料：頰面與肩部都鋸完時真的會掉下來
##  - 砂磨粉塵
## 落到工作台上的木屑會留著，按 B 清掃工作台。

const MAX_BODIES := 90
const BENCH_MIN := Vector2(-0.9, -0.375)   # 工作台 x,z 範圍
const BENCH_MAX := Vector2(0.9, 0.275)

var bench_top := 0.80
var bodies: Array = []      ## {node, vel, ang, radius, rest}
var piles: Array = []       ## {node, volume}

var _active: MeshInstance3D = null
var _active_len := 0.0
var _active_built := 0.0
var _active_thick := 0.1
var _active_width := 40.0
var _active_color := Color.WHITE
var _active_dir := 1.0

var _dust: CPUParticles3D
var _sand: CPUParticles3D
var _dust_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D

func _ready() -> void:
	_dust_mat = _particle_mat()
	_dust = _emitter(_dust_mat, 0.0016, 220, 1.0, 0.25, -2.0)
	_sand_mat = _particle_mat()
	_sand = _emitter(_sand_mat, 0.0009, 160, 1.6, 0.12, -0.4)

func _particle_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	return m

func _emitter(mat: StandardMaterial3D, size: float, amount: int, life: float, vel: float, grav: float) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	e.mesh = q
	e.amount = amount
	e.lifetime = life
	e.emitting = false
	e.direction = Vector3(0, 1, 0)
	e.spread = 70.0
	e.initial_velocity_min = vel * 0.3
	e.initial_velocity_max = vel
	e.gravity = Vector3(0, grav, 0)
	e.damping_min = 0.5
	e.damping_max = 2.0
	e.scale_amount_min = 0.5
	e.scale_amount_max = 1.6
	e.local_coords = false
	add_child(e)
	return e

# ================================================================ 刨花
func begin_shaving(world_pos: Vector3, color: Color, board_width_mm: float, dir: float) -> void:
	end_shaving(false)
	_active = MeshInstance3D.new()
	add_child(_active)
	_active.position = world_pos
	_active_len = 0.0
	_active_built = 0.0
	_active_thick = 0.05
	_active_width = minf(board_width_mm, 42.0) * randf_range(0.7, 1.0)
	_active_color = color
	_active_dir = dir

## 刨削中：在刨口處把刨花「捲」出來
func grow_shaving(world_pos: Vector3, add_len_mm: float, thickness_mm: float) -> void:
	if _active == null:
		return
	_active_len += add_len_mm
	_active_thick = lerpf(_active_thick, thickness_mm, 0.3)
	_active.position = world_pos + Vector3(0, _curl_radius() * 0.001 + 0.004, 0)
	if _active_len - _active_built > 15.0:
		_active_built = _active_len
		_active.mesh = curl_mesh(_active_len, _curl_radius(), _active_width, _active_width * 0.22, _shaving_color(_active_thick, _active_color), false)
		_active.rotation = Vector3(0, PI * 0.5 if _active_dir < 0 else -PI * 0.5, 0)

## 收刨：完整的刨花飛落；broken = 碎成片
func end_shaving(broken: bool) -> void:
	if _active == null:
		return
	if _active_len < 8.0:
		_active.queue_free()
		_active = null
		return
	if broken:
		var pos := _active.position
		var left := _active_len
		_active.queue_free()
		while left > 5.0:
			var l := minf(left, randf_range(8.0, 45.0))
			left -= l
			var m := curl_mesh(l, _curl_radius() * 2.5, _active_width * randf_range(0.3, 0.8), 0.5, _shaving_color(_active_thick, _active_color), true)
			_add_body(m, pos + Vector3(randf_range(-0.05, 0.05), 0.01, randf_range(-0.02, 0.02)),
				Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.2, 0.3)), 0.004)
	else:
		_active.mesh = curl_mesh(_active_len, _curl_radius(), _active_width, _active_width * 0.22, _shaving_color(_active_thick, _active_color), false)
		_add_body_node(_active, Vector3(_active_dir * randf_range(0.2, 0.5), randf_range(0.4, 0.8), randf_range(0.0, 0.3)), _curl_radius() * 0.001 + 0.003)
	_active = null

func _curl_radius() -> float:
	return 3.5 + _active_thick * 40.0   # mm：厚刨花捲得鬆

func _shaving_color(thick: float, base: Color) -> Color:
	# 薄刨花透光，看起來更淡更亮
	return base.lerp(Color(1.0, 0.97, 0.9), clampf(0.35 - thick, 0.0, 0.3))

## 螺旋捲曲的刨花網格
static func curl_mesh(length_mm: float, r0_mm: float, width_mm: float, helix_mm: float, color: Color, ragged: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := maxf(2.0, length_mm / 180.0)
	var n := int(ceil(length_mm / step))
	var prev_a := Vector3.ZERO
	var prev_b := Vector3.ZERO
	var prev_n := Vector3.UP
	var theta := 0.0
	for i in n + 1:
		var r := r0_mm + 1.1 * theta / TAU + sin(theta * 2.7) * 0.25   # 鬆捲：每圈外徑增加，略帶起伏
		var t := float(i) * step
		var w := width_mm * ((randf_range(0.75, 1.0) if ragged else 1.0) * (0.9 + 0.1 * sin(t * 0.13)))
		var c := Vector3(r * sin(theta), r0_mm - r * cos(theta), helix_mm * theta / TAU)
		var nrm := Vector3(sin(theta), -cos(theta), 0)
		var a := (c + Vector3(0, 0, -w * 0.5)) * 0.001
		var b := (c + Vector3(0, 0, w * 0.5)) * 0.001
		if i > 0:
			for v in [[prev_a, prev_n], [prev_b, prev_n], [b, nrm], [prev_a, prev_n], [b, nrm], [a, nrm]]:
				st.set_normal(v[1])
				st.set_color(color)
				st.add_vertex(v[0])
		prev_a = a
		prev_b = b
		prev_n = nrm
		theta += step / maxf(r, 0.5)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.75
	m.backlight_enabled = true
	m.backlight = Color(0.5, 0.4, 0.25)
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh

# ================================================================ 鋸屑
## world_pos：鋸路位置；amount_mm3：這一下鋸掉的體積；coarse：縱切粗屑
func sawdust(world_pos: Vector3, pile_pos: Vector3, amount_mm3: float, coarse: bool, color: Color) -> void:
	_dust.position = world_pos
	_dust.scale_amount_max = 2.6 if coarse else 1.4
	_dust_mat.albedo_color = color.lightened(0.15)
	_dust.color = color.lightened(0.15)
	_dust.emitting = true
	_dust.set_meta("t", 0.12)
	_add_to_pile(pile_pos, amount_mm3, color.lightened(0.2))

func _add_to_pile(pos: Vector3, vol_mm3: float, color: Color) -> void:
	var pile: Dictionary = {}
	for p in piles:
		if (p["node"] as Node3D).position.distance_to(pos) < 0.03:
			pile = p
			break
	if pile.is_empty():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 0.5   # 半球
		sm.is_hemisphere = true
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.08)
		m.roughness = 1.0
		sm.material = m
		sm.radial_segments = 12
		sm.rings = 4
		mi.mesh = sm
		mi.position = Vector3(pos.x, bench_top, pos.z)
		mi.scale = Vector3.ONE * 0.0001
		add_child(mi)
		pile = {"node": mi, "volume": 0.0}
		piles.append(pile)
	pile["volume"] = float(pile["volume"]) + vol_mm3 * 2.5   # 鋸屑蓬鬆，體積約為實木 2.5 倍
	# 半球體積 = 2/3 π r³ (r 以 m 計)，壓扁成 0.4 高度比
	var r := pow(float(pile["volume"]) * 1e-9 / (2.0 / 3.0 * PI * 0.4), 1.0 / 3.0)
	(pile["node"] as Node3D).scale = Vector3(r * 2.4, r * 0.45, r * 1.8)

# ================================================================ 砂磨粉塵
func sand_dust(world_pos: Vector3, color: Color) -> void:
	_sand.position = world_pos
	_sand.color = color.lightened(0.3)
	_sand.emitting = true
	_sand.set_meta("t", 0.12)

# ================================================================ 鑿屑、廢料
func chips(world_pos: Vector3, count: int, width_mm: float, color: Color) -> void:
	for i in count:
		var m := curl_mesh(randf_range(4.0, 14.0), randf_range(6.0, 15.0), width_mm * randf_range(0.4, 1.0), 0.0, color, true)
		_add_body(m, world_pos + Vector3(0, 0.005, 0), Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 1.1), randf_range(-0.3, 0.4)), 0.003)

func offcut(world_xform: Transform3D, size_mm: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size_mm * 0.001
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	bm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	add_child(mi)
	mi.transform = world_xform
	_add_body_node(mi, Vector3(randf_range(-0.1, 0.1), 0.15, 0.25), minf(size_mm.y, size_mm.z) * 0.0005)

# ================================================================ 物理
func _add_body(mesh: Mesh, pos: Vector3, vel: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	mi.position = pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_add_body_node(mi, vel, radius)

func _add_body_node(mi: MeshInstance3D, vel: Vector3, radius: float) -> void:
	bodies.append({"node": mi, "vel": vel, "ang": Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), "radius": radius, "rest": false})
	while bodies.size() > MAX_BODIES:
		(bodies.pop_front()["node"] as Node).queue_free()

func _process(delta: float) -> void:
	for e: CPUParticles3D in [_dust, _sand]:
		if e.emitting:
			var t: float = e.get_meta("t", 0.0) - delta
			e.set_meta("t", t)
			if t <= 0.0:
				e.emitting = false
	for b in bodies:
		if b["rest"]:
			continue
		var node: Node3D = b["node"]
		var v: Vector3 = b["vel"]
		v.y -= 9.8 * 0.45 * delta        # 刨花很輕，空氣阻力大
		v *= 1.0 - 1.2 * delta
		node.position += v * delta
		node.rotation += (b["ang"] as Vector3) * delta
		var p := node.position
		var on_bench := p.x > BENCH_MIN.x and p.x < BENCH_MAX.x and p.z > BENCH_MIN.y and p.z < BENCH_MAX.y
		var floor_y := bench_top if on_bench else 0.0
		var r: float = b["radius"]
		if p.y <= floor_y + r:
			node.position.y = floor_y + r
			if v.y < -0.4:
				v = Vector3(v.x * 0.4, -v.y * 0.25, v.z * 0.4)
				b["ang"] = (b["ang"] as Vector3) * 0.3
			else:
				b["rest"] = true
		b["vel"] = v

## 清掃工作台
func sweep() -> int:
	var n := 0
	var keep := []
	for b in bodies:
		var p: Vector3 = (b["node"] as Node3D).position
		if p.y > 0.5:
			(b["node"] as Node).queue_free()
			n += 1
		else:
			keep.append(b)
	bodies = keep
	for p in piles:
		(p["node"] as Node).queue_free()
	n += piles.size()
	piles.clear()
	return n
