extends Node3D
## 工坊主控：場景建立、輸入、遊戲時間、木料管理、組裝與膠合。

const BENCH_TOP := 0.80

var pieces: Array = []
var active_index: int = 0
var tools: Array = []
var tool_index: int = 0
var cam: Camera3D
var hud: Hud
var workflow: Workflow
var game_minutes: float = 8.0 * 60.0
var start_minutes: float = 8.0 * 60.0
var emc: float = 12.0         ## 工坊平衡含水率（台灣室內約 25°C、相對濕度 65%）
const TIME_SCALE := 1.0       ## 每 1 真實秒 = 幾分鐘遊戲時間（開選單時暫停）
var assembly: Dictionary = {}
var last_hit: Dictionary = {}
var _looking := false
var _yaw := 0.0
var _pitch := -0.88
var _started := false
var _target_fov := 60.0
var tool_models: ToolModels
var sfx: SoundEngine
var fx: WorkshopFx
var day_night: DayNight

# ================================================================ 初始化
func _ready() -> void:
	randomize()
	_reset_assembly()
	_build_world()
	hud = Hud.new()
	add_child(hud)
	hud.rack.ws = self
	hud.new_game_pressed.connect(_on_new_game)
	hud.continue_pressed.connect(_on_continue)
	hud.finish_pressed.connect(_on_finish_product)
	hud.rack.start_work.connect(_on_start_work)
	hud.rack.return_bench.connect(_on_return_bench)
	hud.continue_button.visible = Game.has_save()
	Game.message.connect(say)
	tools = [PlaneTool.new(self), MarkingTool.new(self), SawTool.new(self), ChiselTool.new(self),
		SandTool.new(self), GlueTool.new(self), FinishTool.new(self), WhetstoneTool.new(self)]

func _reset_assembly() -> void:
	assembly = {"dry_fit": false, "glue": 0.0, "glue_time": 0.0, "assembled": false, "open_min": 0.0,
		"clamped": false, "clamp_time": 0.0, "clamp_minutes": 0.0, "pressure": 0.5, "released": false,
		"strength": 0.0, "strength_notes": [], "fit_delta": 0.0}

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.14, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.80, 0.72)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.tonemap_white = 2.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.35
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.1, 1.9, 0.25)
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 0.45
	lamp.omni_range = 3.0
	lamp.shadow_enabled = true
	add_child(lamp)

	# 地板、房間與窗戶、日夜
	_box(Vector3(8, 0.02, 8), Vector3(0, -0.01, 0), Color(0.42, 0.40, 0.37))
	day_night = DayNight.new()
	add_child(day_night)
	day_night.build(env, sun, lamp)
	fx = WorkshopFx.new()
	fx.bench_top = BENCH_TOP
	add_child(fx)
	sfx = SoundEngine.new()
	add_child(sfx)
	tool_models = ToolModels.new()
	tool_models.ws = self
	add_child(tool_models)
	# 工作台：厚實的檯面 + 桌腳 + 橫撐
	_box(Vector3(1.8, 0.08, 0.65), Vector3(0, BENCH_TOP - 0.04, -0.05), Color(0.36, 0.26, 0.16))
	for x in [-0.82, 0.82]:
		for z in [-0.32, 0.22]:
			_box(Vector3(0.08, BENCH_TOP - 0.08, 0.08), Vector3(x, (BENCH_TOP - 0.08) * 0.5, z), Color(0.55, 0.40, 0.24))
		_box(Vector3(0.06, 0.08, 0.55), Vector3(x, 0.2, -0.05), Color(0.55, 0.40, 0.24))
	_box(Vector3(1.6, 0.08, 0.05), Vector3(0, 0.2, -0.05), Color(0.55, 0.40, 0.24))
	# 擋頭（刨削時頂住木料）
	_box(Vector3(0.02, 0.012, 0.08), Vector3(-0.30, BENCH_TOP + 0.006, 0), Color(0.45, 0.32, 0.2))
	# 磨刀石
	_box(Vector3(0.21, 0.025, 0.07), Vector3(0.65, BENCH_TOP + 0.0125, 0.12), Color(0.75, 0.42, 0.25))
	_box(Vector3(0.21, 0.025, 0.07), Vector3(0.65, BENCH_TOP + 0.0125, 0.02), Color(0.88, 0.86, 0.8))
	# 工具牆
	_box(Vector3(0.9, 0.9, 0.02), Vector3(1.45, 1.45, -1.14), Color(0.52, 0.42, 0.30))
	_box(Vector3(0.6, 0.9, 0.02), Vector3(-1.2, 1.45, -1.14), Color(0.52, 0.42, 0.30))
	# 木料架
	for i in 5:
		_box(Vector3(0.06, 0.03, 1.2), Vector3(-2.0 + i * 0.03, 0.5 + i * 0.25, -0.6), Color(0.5, 0.38, 0.25))

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.10, 0.36)
	cam.fov = 60.0
	cam.near = 0.02
	add_child(cam)
	_apply_cam()

func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	return mi

func _apply_cam() -> void:
	cam.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0))

# ================================================================ 開始 / 存讀檔 / 作品流程
func _on_new_game() -> void:
	Game.new_game()
	game_minutes = Game.game_minutes
	_begin_session()
	say("歡迎來到你的木工房！按 [b]H[/b] 看操作說明。")
	say("木料架 ([b]L[/b]) 上有幾塊開業的料；電腦 ([b]P[/b]) 上有一張鄰居的砧板訂單。")

func _on_continue() -> void:
	if not Game.load_game():
		say("讀檔失敗。")
		return
	game_minutes = Game.game_minutes
	_restore_bench()
	_begin_session()
	say("回到工作室。今天是第 %d 天。" % Game.day)

func _begin_session() -> void:
	_started = true
	start_minutes = game_minutes
	hud.hide_select()

func _on_start_work(uid: int, project_id: String, params: Dictionary) -> void:
	var item: Dictionary = {}
	for it in Game.inventory:
		if int(it["uid"]) == uid:
			item = it
	if item.is_empty():
		return
	Game.inventory.erase(item)
	var p: WoodPiece
	if item.has("piece"):
		p = WoodPiece.from_dict(item["piece"])
	else:
		p = WoodPiece.new()
		p.setup(item["species"], float(item["length"]), float(item["width"]), float(item["thickness"]), float(item["mc"]), true)
		p.label_name = "粗胚料"
	p.inv_uid = uid
	add_child(p)
	pieces = [p]
	active_index = 0
	_reset_assembly()
	workflow = Workflow.create(project_id, self, params)
	workflow.setup_tools(tools)
	hud.rack.visible = false
	Game.changed.emit()
	say("把%s拿到工作台，開始做「%s」。先用 [b]M[/b] 量含水率與厚度。" % [p.sp()["name"], workflow.title])

func _piece_to_item(p: WoodPiece) -> Dictionary:
	return {"uid": Game._next_uid(), "species": p.species_id, "source": "kiln", "kind": "offcut", "length": p.length,
		"width": p.width, "thickness": p.mean_thickness(), "mc": p.moisture, "piece": p.to_dict(), "since": game_minutes}

func _clear_bench() -> void:
	for p: WoodPiece in pieces:
		p.queue_free()
	pieces.clear()
	workflow = null
	_reset_assembly()
	Game.changed.emit()

func _on_return_bench() -> void:
	if assembly["assembled"]:
		return
	for p: WoodPiece in pieces:
		Game.inventory.append(_piece_to_item(p))
	_clear_bench()
	hud.rack.refresh()
	say("把料收回木料架了（加工狀態都保留著）。")

func _on_finish_product() -> void:
	if workflow == null or not workflow.is_complete():
		return
	var ev: Dictionary = workflow.evaluate()
	hud.result_panel.visible = false
	var keep: WoodPiece = null
	if workflow.sellable:
		keep = workflow.product_piece()
		var prod: Dictionary = ev["product"]
		prod["photo"] = await _take_photo(keep)
		Game.add_product(prod)
		sfx.oneshot("tap", {"hardness": keep.hardness()})
		say("[b]「%s」[/b]收進庫存了！到電腦 ([b]P[/b]) 上架販售，或交給訂單。" % prod["name"])
	else:
		say("練習件完成，收進櫃子裡當紀念。")
	# 剩下夠長的料回到木料架當餘料
	if not assembly["assembled"]:
		for p: WoodPiece in pieces:
			if p != keep and p.length >= 120.0:
				Game.inventory.append(_piece_to_item(p))
				say("%s（%.0f mm）放回木料架當餘料。" % [p.sp()["name"], p.length])
	_clear_bench()
	save_all()

## 幫作品拍一張商品照（隱藏介面、移動相機、截圖、還原）
func _take_photo(p: WoodPiece) -> String:
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/product_%d_%d.png" % [Game.day, Time.get_ticks_msec()]
	var saved := cam.global_transform
	hud.visible = false
	var target := p.global_position
	cam.global_position = target + Vector3(0.16, 0.30, 0.30)
	cam.look_at(target, Vector3.UP)
	for i in 4:
		await get_tree().process_frame
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		cam.global_transform = saved
		hud.visible = true
		return ""
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(320, 320)
	img.save_png(path)
	cam.global_transform = saved
	hud.visible = true
	return path

func save_all() -> void:
	Game.game_minutes = game_minutes
	if workflow and pieces.size() > 0:
		var arr := []
		for p: WoodPiece in pieces:
			arr.append(p.to_dict())
		Game.bench = {"project": workflow.id, "params": workflow.params, "pieces": arr, "assembly": assembly, "active": active_index}
	else:
		Game.bench = {}
	Game.save_game()

func _restore_bench() -> void:
	var b: Dictionary = Game.bench
	if b.is_empty() or not b.has("pieces"):
		return
	for d in b["pieces"]:
		var p := WoodPiece.from_dict(d)
		add_child(p)
		pieces.append(p)
	assembly = b["assembly"]
	active_index = int(b["active"])
	workflow = Workflow.create(b["project"], self, b["params"])
	workflow.setup_tools(tools)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _started:
		save_all()

## 睡覺：17:00 以後（或凌晨）可以睡，醒來是早上 7:00。夾具、乾燥、含水率都會照常進行。
func sleep() -> void:
	var h := fmod(game_minutes / 60.0, 24.0)
	if h >= 7.0 and h < 17.0:
		say("現在還是白天，17:00 以後再睡吧。")
		return
	var wake: float = floor(game_minutes / 1440.0) * 1440.0 + 7.0 * 60.0
	if h >= 7.0:
		wake += 1440.0
	if float(assembly["glue"]) > 0.0 and not assembly["assembled"]:
		say("[color=orange]上了膠還沒組裝就去睡，膠會整個乾掉……[/color]")
	while game_minutes < wake:
		advance_time(minf(30.0, wake - game_minutes))
	sfx.oneshot("sweep", {}, -12.0)
	say("睡了一覺。早安，第 %d 天 07:00。（已自動存檔）" % Game.day)
	save_all()

# ================================================================ 公用 API（給工具呼叫）
func active_piece() -> WoodPiece:
	if pieces.is_empty():
		return null
	active_index = clampi(active_index, 0, pieces.size() - 1)
	return pieces[active_index]

func current_tool() -> WorkTool:
	return tools[tool_index]

func say(msg: String) -> void:
	if hud:
		hud.add_log("[color=#a89070]%s[/color] %s" % [clock_text(game_minutes), msg])

func clock_text(m: float, duration := false) -> String:
	var total := int(m)
	if duration:
		return "%d 小時 %02d 分" % [total / 60, total % 60]
	var day := total / (24 * 60) + 1
	var hm := total % (24 * 60)
	return "第%d天 %02d:%02d" % [day, hm / 60, hm % 60]

func advance_time(minutes: float) -> void:
	game_minutes += minutes
	Game.game_minutes = game_minutes
	Game.age_inventory(minutes, emc)
	var today := int(game_minutes / 1440.0) + 1
	while Game.day < today:
		var news: Array[String] = Game.new_day()
		say("[b]── 第 %d 天 ──[/b]" % Game.day)
		for line in news:
			say(line)
	var hours := minutes / 60.0
	for p: WoodPiece in pieces:
		var tau := WoodPhysics.moisture_tau_hours(p.mean_thickness())
		if p.finish_coats > 0:
			tau *= 1.0 + p.finish_coats * 1.5    # 塗裝減緩水分交換（但不能完全阻止）
		var new_mc := p.moisture + (emc - p.moisture) * (1.0 - exp(-hours / tau))
		if absf(new_mc - p.moisture) > 0.0005:
			p.set_moisture(new_mc)
		if p.finish_wet > 0.0:
			p.finish_wet = maxf(0.0, p.finish_wet - minutes)
	# 膠的開放時間提醒
	if float(assembly["glue"]) > 0.0 and not assembly["assembled"]:
		var el := game_minutes - float(assembly["glue_time"])
		if el > 10.0 and el - minutes <= 10.0:
			say("[color=red]白膠已超過開放時間，開始結皮！[/color]")

func mortise_piece() -> WoodPiece:
	for p: WoodPiece in pieces:
		if not p.mortise.is_empty():
			return p
	return null

func tenon_piece() -> WoodPiece:
	for p: WoodPiece in pieces:
		if not p.tenon.is_empty():
			return p
	return null

func finish_targets() -> Array:
	if assembly["assembled"]:
		return [mortise_piece(), tenon_piece()]
	return [active_piece()]

func sharpenable_tools() -> Array:
	var out := []
	for t: WorkTool in tools:
		if t.sharpenable:
			out.append(t)
	return out

func split_piece(p: WoodPiece, kerf_center: float, angle: float) -> void:
	var idx := pieces.find(p)
	var kids := p.split_at(kerf_center, angle)
	var first_split := pieces.size() == 1 and workflow != null and workflow.id == "mortise_tenon"
	pieces.remove_at(idx)
	p.queue_free()
	for i in kids.size():
		var k: WoodPiece = kids[i]
		if first_split:
			k.label_name = "腳料（鑿榫眼）" if i == 0 else "橫料（做榫頭）"
		else:
			k.label_name = "%s %.0fmm" % [k.sp()["name"], k.length]
		add_child(k)
		pieces.insert(idx + i, k)
		say("%s：長 %.1f mm" % [k.label_name, k.length])
	active_index = idx

# ================================================================ 量測、組裝、膠合
func measure() -> void:
	var p := active_piece()
	if p == null:
		return
	var m := {"time": game_minutes}
	m["T"] = p.mean_thickness() + randf_range(-0.02, 0.02)
	m["Tmin"] = p.min_thickness()
	m["flat"] = p.flatness() + randf_range(0.0, 0.03)
	m["W"] = p.width + randf_range(-0.02, 0.02)
	m["L"] = p.length
	m["MC"] = p.moisture + randf_range(-0.5, 0.5)
	m["tear"] = p.max_tearout()
	if not p.mortise.is_empty():
		m["mw"] = maxf(float(p.mortise["width"]), float(p.mortise["chisel"])) + randf_range(-0.02, 0.02)
		m["md"] = float(p.mortise["depth"]) + randf_range(-0.1, 0.1)
	if p.tenon.has("thickness"):
		m["tt"] = float(p.tenon["thickness"]) + randf_range(-0.02, 0.02)
	p.measured = m
	advance_time(1.0)
	say("用游標卡尺、直尺與水分計量了 %s。" % p.label_name)

func fit_or_assemble() -> void:
	var leg := mortise_piece()
	var rail := tenon_piece()
	if leg == null or rail == null or not rail.tenon.has("thickness") or leg == rail:
		say("需要一塊有榫眼、另一塊有完成榫頭的木料。")
		return
	if assembly["assembled"]:
		say("已經組裝好了。")
		return
	var mw := maxf(float(leg.mortise["width"]), float(leg.mortise["chisel"]))
	var delta := mw - float(rail.tenon["thickness"])
	var fit := WoodPhysics.fit_grade(delta)
	var len_gap := float(rail.tenon["length"]) - float(leg.mortise["depth"])
	var width_gap := rail.width - float(leg.mortise["length"])
	if float(assembly["glue"]) <= 0.0:
		assembly["dry_fit"] = true
		say("[b]乾試裝[/b]：%s — %s" % [fit["grade"], fit["msg"]])
		sfx.oneshot("tap", {"hardness": leg.hardness()})
		if len_gap > 0.0:
			say("[color=orange]榫頭比榫眼深 %.1f mm，肩部會頂不到底。榫眼再鑿深一點。[/color]" % len_gap)
		if width_gap > 0.5:
			say("[color=orange]橫料比榫眼長度寬 %.1f mm，塞不進去。[/color]" % width_gap)
		advance_time(2.0)
		return
	if not fit["can"]:
		say("[color=red]太緊，塞不進去！[/color]膠正在變乾，快用鑿子修頰面。")
		return
	if delta < -0.15 and randf() < float(leg.sp()["split"]) * 0.6:
		leg.split = true
		sfx.oneshot("crack")
		say("[color=red][b]敲入時榫眼側壁被撐裂了！[/b][/color]")
	assembly["assembled"] = true
	sfx.oneshot("tap" if delta >= -0.08 else "mallet", {"hardness": leg.hardness(), "force": 0.6})
	assembly["open_min"] = game_minutes - float(assembly["glue_time"])
	assembly["fit_delta"] = delta
	assembly["built_mc"] = leg.moisture
	assembly["seat_gap"] = maxf(0.0, len_gap)
	active_index = pieces.find(leg)
	say("[b]組裝完成[/b]（%s）。接著用夾具 (6 → R) 夾緊。" % fit["grade"])
	advance_time(1.0)

func finalize_glue() -> void:
	var a := assembly
	var leg := mortise_piece()
	var rail := tenon_piece()
	var g := WoodPhysics.glue_factor(a["glue"], a["pressure"], a["clamp_minutes"], a["open_min"], maxf(0.0, float(a["fit_delta"])))
	var fit := WoodPhysics.fit_grade(a["fit_delta"])
	var mech := 0.5 + 0.5 * float(fit["score"])
	var notes: Array = g["notes"].duplicate()
	var oc: float = rail.tenon["overcut"]
	if oc > 0.4:
		mech *= clampf(1.0 - oc * 0.15, 0.5, 1.0)
		notes.append("榫肩鋸傷")
	if float(a.get("seat_gap", 0.0)) > 0.0:
		mech *= 0.85
		notes.append("肩部未貼合")
	if leg.split or rail.split:
		mech *= 0.3
		notes.append("木料劈裂")
	var dens := clampf(float(leg.sp()["density"]) / 600.0, 0.75, 1.15)
	a["strength"] = clampf(mech * float(g["factor"]) * dens, 0.0, 1.0)
	a["strength_notes"] = notes
	a["released"] = true
	say("膠合強度約 %d%%。%s" % [int(float(a["strength"]) * 100), "、".join(notes)])

# ================================================================ 輸入
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_looking = mb.pressed
			MOUSE_BUTTON_LEFT:
				if not _started or hud.menu_open():
					current_tool().release(last_hit)
					return
				_update_hit()
				if mb.pressed:
					current_tool().press(last_hit)
				else:
					current_tool().release(last_hit)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed or not _started or hud.menu_open():
					return
				var dir := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				if mb.ctrl_pressed or mb.alt_pressed:
					current_tool().wheel(dir, mb.alt_pressed)   # Ctrl：主要數值；Alt：次要數值
				else:
					_target_fov = clampf(_target_fov - dir * 4.0, 18.0, 75.0)   # 放大縮小畫面
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _looking:
			_yaw -= mm.relative.x * 0.004
			_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.4, 0.6)
			_apply_cam()
		elif _started:
			_update_hit()
			if current_tool().pressed:
				current_tool().anim += mm.relative
			current_tool().motion(mm.relative, last_hit)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			_key(k)

func _key(k: InputEventKey) -> void:
	if k.keycode == KEY_H:
		hud.toggle_help()
		return
	if not _started:
		return
	# 選單
	if k.keycode == KEY_ESCAPE:
		hud.computer.visible = false
		hud.rack.visible = false
		hud.result_panel.visible = false
		hud.help_panel.visible = false
		return
	if k.keycode == KEY_P:
		hud.rack.visible = false
		hud.computer.visible = not hud.computer.visible
		if hud.computer.visible:
			sfx.oneshot("pickup", {}, -10.0)
		return
	if k.keycode == KEY_L:
		hud.computer.visible = false
		hud.rack.visible = not hud.rack.visible
		return
	if hud.computer.visible or hud.rack.visible:
		return
	if k.keycode == KEY_Z:
		sleep()
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_8:
		current_tool().release(last_hit)
		tool_index = k.keycode - KEY_1
		sfx.oneshot("pickup", {}, -6.0)
		say("拿起 %s" % current_tool().display)
		return
	match k.keycode:
		KEY_R:
			current_tool().cycle_mode()
		KEY_TAB:
			if pieces.size() > 1:
				active_index = (active_index + 1) % pieces.size()
				say("工作中的木料：%s" % active_piece().label_name)
		KEY_M:
			measure()
		KEY_F2:
			var i := WoodPhysics.WORK_SPEEDS.find(WoodPhysics.work_speed)
			WoodPhysics.work_speed = WoodPhysics.WORK_SPEEDS[(i + 1) % WoodPhysics.WORK_SPEEDS.size()]
			Game.work_speed = WoodPhysics.work_speed
			say("加工速度 ×%s%s" % [str(WoodPhysics.work_speed).trim_suffix(".0"), "（真實速度）" if WoodPhysics.work_speed == 1.0 else ""])
		KEY_B:
			var n := fx.sweep()
			if n > 0:
				sfx.oneshot("sweep")
				advance_time(2.0)
				say("把工作台上的刨花和木屑掃乾淨了。")
		KEY_F:
			fit_or_assemble()
		KEY_E:
			(tools[3] as ChiselTool).lever_out()
		KEY_K:
			(tools[1] as MarkingTool).set_gauge_from_chisel((tools[3] as ChiselTool).chisel_width())
		KEY_T:
			var mins := 60.0 if k.shift_pressed else 10.0
			advance_time(mins)
			say("等待 %d 分鐘。" % int(mins))
		KEY_ENTER, KEY_KP_ENTER:
			if workflow == null:
				say("工作台是空的。")
				return
			var ev: Dictionary = workflow.evaluate()
			var lbl := ""
			if workflow.is_complete():
				lbl = "完成作品，收進庫存（之後可以上架販售）" if workflow.sellable else "完成練習件"
			hud.show_result(ev["text"], lbl)

# ================================================================ 每幀
func _process(delta: float) -> void:
	if _started and not hud.menu_open():
		advance_time(delta * TIME_SCALE)
	day_night.update_time(game_minutes)
	cam.fov = lerpf(cam.fov, _target_fov, clampf(delta * 12.0, 0.0, 1.0))
	if _started and not hud.menu_open():
		_update_hit()
	_move_cam(delta)
	_layout()
	if _started:
		current_tool().process(delta)
	_update_hud()

func _move_cam(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): v.z -= 1
	if Input.is_key_pressed(KEY_S): v.z += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_SPACE): v.y += 1
	if Input.is_key_pressed(KEY_C): v.y -= 1
	if v == Vector3.ZERO:
		return
	var b := Basis(Vector3.UP, _yaw)
	cam.position += (b * Vector3(v.x, 0, v.z) + Vector3(0, v.y, 0)) * delta * 0.6
	cam.position = cam.position.clamp(Vector3(-2, 0.9, -0.6), Vector3(2, 2.0, 1.5))

func _layout() -> void:
	var leg := mortise_piece()
	var rail := tenon_piece()
	var ap := active_piece()
	var back_z := -(ap.width * 0.0005 + 0.03) if ap else -0.1
	for i in pieces.size():
		var p: WoodPiece = pieces[i]
		if assembly["assembled"] and p == rail:
			continue
		var T := p.mean_thickness() * 0.001
		var front: bool = (i == active_index) or (assembly["assembled"] and p == leg)
		p.basis = Basis.IDENTITY
		if front:
			p.position = Vector3(0, BENCH_TOP + T * 0.5, 0)
		else:
			var w := p.width * 0.001
			p.position = Vector3(0, BENCH_TOP + T * 0.5, back_z - w * 0.5)
			back_z -= w + 0.02
	if assembly["assembled"] and leg and rail:
		var Tl := leg.mean_thickness()
		var top := leg.transform * (Vector3(float(leg.mortise["x"]), Tl * 0.5, 0) * 0.001)
		var e := int(rail.tenon["end"])
		if e == 1:
			rail.basis = Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))
		else:
			rail.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
		var insert := minf(float(rail.tenon["length"]), float(leg.mortise["depth"]))
		rail.position = top + Vector3.UP * (rail.length * 0.5 - insert) * 0.001

var debug_hit := {}   ## 測試用：固定游標命中點

func _update_hit() -> void:
	if not debug_hit.is_empty():
		last_hit = debug_hit
		return
	last_hit = {"on_piece": false, "local": Vector3.ZERO, "top": Vector3.ZERO}
	var p := active_piece()
	if p == null or cam == null:
		return
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	var inv := p.global_transform.affine_inverse()
	var lo := inv * o
	var ld := (inv.basis * d).normalized()
	var he := p.half_extents_m()
	var t := _ray_box(lo, ld, he)
	if t > 0.0:
		last_hit["on_piece"] = true
		last_hit["local"] = (lo + ld * t) * 1000.0
	if absf(ld.y) > 1e-6:
		var t2 := (he.y - lo.y) / ld.y
		last_hit["top"] = (lo + ld * t2) * 1000.0

static func _ray_box(o: Vector3, d: Vector3, he: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for a in 3:
		if absf(d[a]) < 1e-9:
			if o[a] < -he[a] or o[a] > he[a]:
				return -1.0
		else:
			var t1 := (-he[a] - o[a]) / d[a]
			var t2 := (he[a] - o[a]) / d[a]
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return -1.0
	return tmin if tmin > 0.0 else tmax

# ================================================================ HUD 文字
func _update_hud() -> void:
	if hud == null:
		return
	var s := day_night.clock_icon(game_minutes) + " [b]%s[/b]　[color=#e8c27a]NT$ %s[/color]" % [clock_text(game_minutes), ComputerUI._fmt(Game.money)]
	s += "\n工坊 25°C / RH 65%%（平衡含水率 %.1f%%）　加工速度 ×%s（F2）" % [emc, str(WoodPhysics.work_speed).trim_suffix(".0")]
	var n_orders := 0
	for o in Game.orders:
		if o["status"] == "new":
			n_orders += 1
	if n_orders > 0:
		s += "\n[color=#e8a07a]【新訂單 %d 張】按 P 打開電腦[/color]" % n_orders
	var p := active_piece()
	if p:
		s += "\n工作中：[b]%s[/b] %s（%d/%d，Tab 切換）" % [p.label_name, p.sp()["name"], active_index + 1, pieces.size()]
		s += "\n纖維傾斜：%s（目測木紋）" % ("往右上升" if p.grain_runout > 0 else "往左上升")
		if p.split:
			s += "\n[color=red]⚠ 此料已劈裂[/color]"
	hud.set_status(s)

	var st := ""
	if workflow == null:
		st = "[b]工作台是空的[/b]\n按 [b]L[/b] 打開木料架，挑料開始一件作品。\n按 [b]P[/b] 打開電腦：訂單、上架、買木料。\n17:00 以後按 [b]Z[/b] 睡覺。"
	else:
		st = "[b]作品：%s[/b]\n" % workflow.title
		var cur := workflow.current_step()
		for i in workflow.steps.size():
			var stp: Dictionary = workflow.steps[i]
			var done := workflow.check(stp["id"])
			var mark := "[color=lime]✔[/color]" if done else ("[color=yellow]▶[/color]" if i == cur else "・")
			st += "%s %s\n" % [mark, stp["title"]]
			if i == cur:
				st += "　[color=#c8b89a][font_size=14]%s[/font_size][/color]\n" % stp["detail"]
		st += "[font_size=14]Enter：作品評鑑%s[/font_size]" % ("（[color=lime]可以完成了！[/color]）" if workflow.is_complete() else "")
	hud.set_steps(st)

	var t := current_tool()
	var tt := "[b][%d] %s[/b]　" % [tool_index + 1, t.display] + t.status()
	tt += "\n[color=#b0a080][font_size=14]%s[/font_size][/color]" % t.help()
	tt += "\n[color=#807060][font_size=13]1刨 2劃線 3鋸 4鑿 5砂 6膠夾 7塗裝 8磨刀　M量測 F試裝 T快轉 B清掃 L木料架 P電腦 Z睡覺 H說明[/font_size][/color]"
	hud.set_tool(tt, t.id)

	var ms := "[b]量測紀錄[/b]"
	if p and not p.measured.is_empty():
		var m := p.measured
		ms += "（%s，%d 分鐘前）" % [p.label_name, int(game_minutes - float(m["time"]))]
		ms += "\n厚度 平均 %.2f mm　最薄 %.2f" % [m["T"], m["Tmin"]]
		ms += "\n平整度（直尺光隙）%.2f mm" % m["flat"]
		ms += "\n寬 %.2f　長 %.1f mm" % [m["W"], m["L"]]
		ms += "\n含水率 %.1f%%" % m["MC"]
		if float(m["tear"]) > 0.05:
			ms += "\n[color=orange]逆紋撕裂坑 深 %.2f mm[/color]" % m["tear"]
		if m.has("mw"):
			ms += "\n榫眼 寬 %.2f　深 %.1f mm" % [m["mw"], m["md"]]
		if m.has("tt"):
			ms += "\n榫頭 厚 %.2f mm" % m["tt"]
	else:
		ms += "\n（按 M 量測工作中的木料）"
	hud.set_measure(ms)
