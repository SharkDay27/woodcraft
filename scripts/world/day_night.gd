class_name DayNight
extends Node3D
## 工作室與日夜循環。
##  - 封閉的房間，後牆有一扇對外小窗
##  - 太陽依遊戲時間東升西落，陽光從窗戶照進來，在工作台上投下光斑
##  - 月亮依 29.5 天週期變化月相
##  - 環境光、天空色、屋外剪影的燈光都跟著時間變化；天黑時工作燈是主要光源
## 窗景可替換：assets/textures/window_day.png / window_night.png（見 docs/ART_PROMPTS.md）

const SKY_SHADER := preload("res://shaders/window_sky.gdshader")
const WIN_CENTER := Vector3(0.0, 1.42, -1.2)
const WIN_SIZE := Vector2(1.3, 0.72)
const ROOM_MIN := Vector3(-2.3, 0.0, -1.2)
const ROOM_MAX := Vector3(2.3, 2.7, 1.9)

var env: Environment
var sun: DirectionalLight3D
var lamp: OmniLight3D
var _sky_mat: ShaderMaterial
var _window_glow: OmniLight3D

# 一天中的關鍵時刻：小時 -> [天頂色, 地平線色, 環境光強度, 陽光色]
const KEYS := [
	[0.0, Color(0.02, 0.03, 0.08), Color(0.05, 0.06, 0.12), 0.06],
	[5.0, Color(0.05, 0.07, 0.16), Color(0.25, 0.18, 0.22), 0.08],
	[6.5, Color(0.30, 0.42, 0.70), Color(1.00, 0.62, 0.38), 0.18],
	[9.0, Color(0.32, 0.55, 0.88), Color(0.80, 0.85, 0.90), 0.30],
	[15.0, Color(0.30, 0.52, 0.86), Color(0.85, 0.85, 0.85), 0.30],
	[17.8, Color(0.30, 0.38, 0.65), Color(1.00, 0.55, 0.30), 0.18],
	[19.2, Color(0.08, 0.08, 0.20), Color(0.35, 0.18, 0.25), 0.09],
	[24.0, Color(0.02, 0.03, 0.08), Color(0.05, 0.06, 0.12), 0.06],
]

func build(p_env: Environment, p_sun: DirectionalLight3D, p_lamp: OmniLight3D) -> void:
	env = p_env
	sun = p_sun
	lamp = p_lamp
	_build_room()
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 2.4)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("aspect", 4.0 / 2.4)
	var dt := "res://assets/textures/window_day.png"
	var nt := "res://assets/textures/window_night.png"
	if ResourceLoader.exists(dt) and ResourceLoader.exists(nt):
		_sky_mat.set_shader_parameter("day_tex", load(dt))
		_sky_mat.set_shader_parameter("night_tex", load(nt))
		_sky_mat.set_shader_parameter("use_tex", true)
	q.material = _sky_mat
	var sky := MeshInstance3D.new()
	sky.mesh = q
	sky.position = WIN_CENTER + Vector3(0, 0.1, -1.6)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	# 窗戶透進來的天光（陰天/夜晚時的柔光）
	_window_glow = OmniLight3D.new()
	_window_glow.position = WIN_CENTER + Vector3(0, -0.1, 0.35)
	_window_glow.omni_range = 2.2
	_window_glow.shadow_enabled = false
	add_child(_window_glow)

func _build_room() -> void:
	var wall := Color(0.66, 0.60, 0.52)
	var x0 := WIN_CENTER.x - WIN_SIZE.x * 0.5
	var x1 := WIN_CENTER.x + WIN_SIZE.x * 0.5
	var y0 := WIN_CENTER.y - WIN_SIZE.y * 0.5
	var y1 := WIN_CENTER.y + WIN_SIZE.y * 0.5
	var z := ROOM_MIN.z
	var H := ROOM_MAX.y
	# 後牆（留一個窗洞）
	_box(Vector3(x0 - ROOM_MIN.x, H, 0.1), Vector3((ROOM_MIN.x + x0) * 0.5, H * 0.5, z), wall)
	_box(Vector3(ROOM_MAX.x - x1, H, 0.1), Vector3((ROOM_MAX.x + x1) * 0.5, H * 0.5, z), wall)
	_box(Vector3(x1 - x0, y0, 0.1), Vector3(WIN_CENTER.x, y0 * 0.5, z), wall)
	_box(Vector3(x1 - x0, H - y1, 0.1), Vector3(WIN_CENTER.x, (H + y1) * 0.5, z), wall)
	# 窗框、窗台、窗櫺
	var frame := Color(0.36, 0.24, 0.14)
	_box(Vector3(x1 - x0 + 0.1, 0.05, 0.22), Vector3(WIN_CENTER.x, y0 - 0.02, z + 0.04), frame)
	_box(Vector3(x1 - x0 + 0.1, 0.05, 0.12), Vector3(WIN_CENTER.x, y1 + 0.02, z), frame)
	for xx in [x0 - 0.025, x1 + 0.025, WIN_CENTER.x]:
		_box(Vector3(0.04 if xx == WIN_CENTER.x else 0.05, WIN_SIZE.y, 0.12), Vector3(xx, WIN_CENTER.y, z), frame)
	_box(Vector3(x1 - x0, 0.03, 0.08), Vector3(WIN_CENTER.x, WIN_CENTER.y + 0.05, z), frame)
	# 側牆、前牆、天花板
	_box(Vector3(0.1, H, ROOM_MAX.z - ROOM_MIN.z), Vector3(ROOM_MIN.x, H * 0.5, (ROOM_MIN.z + ROOM_MAX.z) * 0.5), wall)
	_box(Vector3(0.1, H, ROOM_MAX.z - ROOM_MIN.z), Vector3(ROOM_MAX.x, H * 0.5, (ROOM_MIN.z + ROOM_MAX.z) * 0.5), wall)
	_box(Vector3(ROOM_MAX.x - ROOM_MIN.x, H, 0.1), Vector3(0, H * 0.5, ROOM_MAX.z), wall)
	_box(Vector3(ROOM_MAX.x - ROOM_MIN.x, 0.1, ROOM_MAX.z - ROOM_MIN.z), Vector3(0, H, (ROOM_MIN.z + ROOM_MAX.z) * 0.5), wall.darkened(0.2))
	# 天花板梁
	for zz in [-0.4, 0.5, 1.4]:
		_box(Vector3(ROOM_MAX.x - ROOM_MIN.x, 0.14, 0.12), Vector3(0, H - 0.12, zz), frame)

func _box(size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	add_child(mi)

## game_minutes：遊戲經過的總分鐘數
func update_time(game_minutes: float) -> void:
	var day := game_minutes / 1440.0
	var hour := fmod(game_minutes / 60.0, 24.0)
	var k := _sample(hour)
	var top: Color = k[0]
	var hor: Color = k[1]
	var amb: float = k[2]
	# 太陽：6:00 東方升起，18:00 西方落下
	var a := (hour - 6.0) / 12.0 * PI
	var sun_up := sin(a)
	var night := clampf(1.0 - (sun_up + 0.15) * 3.0, 0.0, 1.0)
	_sky_mat.set_shader_parameter("top_col", top)
	_sky_mat.set_shader_parameter("hor_col", hor)
	_sky_mat.set_shader_parameter("sun_pos", Vector2(-cos(a) * 0.85, sun_up * 0.9 - 0.25))
	_sky_mat.set_shader_parameter("sun_vis", clampf(sun_up * 4.0 + 0.3, 0.0, 1.0))
	# 月亮：比太陽晚約 (月齡/29.5) 天，月相 0 = 新月
	var phase := fposmod(day / 29.53 + 0.35, 1.0)
	var ma := a - phase * TAU
	_sky_mat.set_shader_parameter("moon_pos", Vector2(-cos(ma) * 0.85, sin(ma) * 0.9 - 0.25))
	_sky_mat.set_shader_parameter("moon_vis", clampf(sin(ma) * 4.0, 0.0, 1.0) * clampf(night * 1.5 + 0.2, 0.0, 1.0))
	_sky_mat.set_shader_parameter("moon_phase", phase)
	_sky_mat.set_shader_parameter("night", night)
	# 陽光：從窗外射入（-z 方向往 +z），在工作台上投下窗格光斑
	if sun_up > 0.0:
		var dir := Vector3(-cos(a) * 0.7, sun_up * 0.9 + 0.15, -1.0).normalized()  # 指向太陽
		sun.visible = true
		sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP)
		sun.light_color = hor.lerp(Color(1.0, 0.95, 0.85), clampf(sun_up * 2.0, 0.0, 1.0))
		sun.light_energy = clampf(sun_up * 3.0, 0.0, 1.0) * 1.6
	else:
		sun.visible = false
	env.ambient_light_color = hor.lerp(top, 0.5)
	env.ambient_light_energy = amb
	env.background_color = top * 0.5
	_window_glow.light_color = hor.lerp(top, 0.5)
	_window_glow.light_energy = 0.15 + (1.0 - night) * 0.35
	# 工作燈：天越暗越需要它
	lamp.light_energy = lerpf(0.3, 0.7, night)

func _sample(hour: float) -> Array:
	for i in KEYS.size() - 1:
		var k0: Array = KEYS[i]
		var k1: Array = KEYS[i + 1]
		if hour >= float(k0[0]) and hour <= float(k1[0]):
			var t := (hour - float(k0[0])) / (float(k1[0]) - float(k0[0]))
			return [(k0[1] as Color).lerp(k1[1], t), (k0[2] as Color).lerp(k1[2], t), lerpf(k0[3], k1[3], t)]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3]]

func clock_icon(game_minutes: float) -> String:
	var hour := fmod(game_minutes / 60.0, 24.0)
	return "☀" if hour >= 6.0 and hour < 18.0 else "☾"
