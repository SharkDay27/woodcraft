extends Node
## 自動化整合測試：模擬玩家完成整個 T 字方榫委託。
## 執行：godot --headless res://tests/sim_test.tscn

var ws

func _ready() -> void:
	ws = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(ws)
	_run.call_deferred()

func _hit(p: WoodPiece, x: float, z := 0.0) -> Dictionary:
	var T := p.mean_thickness()
	return {"on_piece": true, "local": Vector3(x, T * 0.5, z), "top": Vector3(x, T * 0.5, 0)}

func _shot(name: String) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		return
	ws._update_hud()
	await _frames(12)
	get_tree().root.get_texture().get_image().save_png(dir.path_join(name + ".png"))

func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	await _frames()
	Game.new_game()
	ws.game_minutes = Game.game_minutes
	ws._begin_session()
	var oak_uid := -1
	for it in Game.inventory:
		if it["species"] == "white_oak":
			oak_uid = it["uid"]
	ws._on_start_work(oak_uid, "mortise_tenon", {"thickness": 24.0})
	ws.advance_time(600.0)
	var p: WoodPiece = ws.active_piece()
	print("MC after acclimate: %.2f (emc %.1f)" % [p.moisture, ws.emc])

	# ---- 刨
	var plane: PlaneTool = ws.tools[0]
	ws.tool_index = 0
	var dir := 1.0 if p.grain_runout > 0 else -1.0
	var guard := 0
	while p.mean_thickness() > 24.05 and guard < 400:
		guard += 1
		plane.depth = 0.2 if p.mean_thickness() > 24.6 else 0.04
		if plane.sharpness < 0.5:
			ws.tool_index = 7
			var ws_t: WhetstoneTool = ws.tools[7]
			ws_t.target_index = 0
			for m in 2:
				ws_t.mode = m
				ws_t.press({})
				for k in 300:
					ws_t.motion(Vector2(0, 40), {})
				ws_t.release({})
			ws.tool_index = 0
		plane.press(_hit(p, -dir * 270.0))
		for k in 28:
			plane.motion(Vector2.ZERO, _hit(p, -dir * 270.0 + dir * 20.0 * (k + 1)))
		plane.release({})
	print("Planed: T=%.2f flat=%.2f tear=%.2f strokes=%d sharp=%.2f" % [p.mean_thickness(), p.flatness(), p.max_tearout(), guard, plane.sharpness])

	await _shot("0_shavings")
	# ---- 劃線 + 鋸斷
	var mk: MarkingTool = ws.tools[1]
	mk.mode = 0
	mk.press(_hit(p, 0.0))
	var saw: SawTool = ws.tools[2]
	saw.mode = 1
	saw.press({})
	guard = 0
	while ws.pieces.size() < 2 and guard < 2000:
		guard += 1
		saw.motion(Vector2(0, 40), {})
		saw.motion(Vector2(0, -40), {})
	print("Crosscut after %d strokes, pieces=%d" % [guard, ws.pieces.size()])
	await _frames()

	# ---- 榫眼
	ws.active_index = 0
	var leg: WoodPiece = ws.active_piece()
	mk.mode = 1
	mk.press(_hit(leg, 0.0))
	var ch: ChiselTool = ws.tools[3]
	ch.mode = 0
	ch.width_index = 1
	guard = 0
	while float(leg.mortise["depth"]) < 18.0 and guard < 200:
		guard += 1
		ch.press({})
		ch.process(0.85)
		ch.release(_hit(leg, 0.0))
		if int(leg.mortise["chips"]) >= 2:
			ch.lever_out()
	print("Mortise depth %.1f width %.2f after %d strikes, split=%s" % [leg.mortise["depth"], leg.mortise["width"], guard, leg.split])

	# ---- 榫頭
	ws.active_index = 1
	var rail: WoodPiece = ws.active_piece()
	mk.mode = 2
	mk.press(_hit(rail, 100.0))
	for id in ["cheek_top", "cheek_bot", "shoulder_top", "shoulder_bot"]:
		var js := rail.pending_jobs()
		saw.job_index = 0
		for i in js.size():
			if js[i]["id"] == id:
				saw.job_index = i
		saw.mode = 0 if id.begins_with("cheek") else 1
		saw.press({})
		if id.begins_with("cheek"):
			saw.motion(Vector2(25, 0), {})  # 刻意往廢料側偏 0.3mm（留線）
		guard = 0
		while not rail.job(id)["done"] and guard < 3000:
			guard += 1
			saw.motion(Vector2(0, 30), {})
			saw.motion(Vector2(0, -30), {})
		print("  %s done after %d strokes, dev %.2f" % [id, guard, rail.job(id)["dev"]])
	print("Tenon thickness %.2f (target %.2f)" % [rail.tenon.get("thickness", -1.0), rail.tenon["target"]])

	ws.active_index = 0
	await _shot("1_joinery")
	ws.active_index = 1
	# ---- 試裝與修削
	ws.fit_or_assemble()
	ch.mode = 1
	guard = 0
	while float(rail.tenon["thickness"]) > maxf(float(leg.mortise["width"]), float(leg.mortise["chisel"])) + 0.05 and guard < 20:
		guard += 1
		ch.press({})
		ch.process(0.2)
		ch.release({})
	print("After paring: tenon %.2f mortise %.2f" % [rail.tenon["thickness"], maxf(float(leg.mortise["width"]), float(leg.mortise["chisel"]))])

	# ---- 上膠、組裝、夾持
	var gl: GlueTool = ws.tools[5]
	gl.mode = 0
	gl.press({})
	gl.process(1.6)
	gl.release({})
	ws.fit_or_assemble()
	gl.mode = 1
	gl.press({})
	ws.advance_time(60.0)
	gl.press({})
	await _frames()

	await _shot("2_assembled")
	# ---- 砂磨
	var sd: SandTool = ws.tools[4]
	for pc: WoodPiece in [leg, rail]:
		ws.active_index = ws.pieces.find(pc)
		for gi in [1, 2, 3]:
			sd.grit_index = gi
			sd.press(_hit(pc, 0.0))
			for k in 600:
				sd.motion(Vector2(40, 0), {})
			sd.release({})
		print("  %s scratch %.3f squeeze %.3f marks %s" % [pc.label_name, pc.scratch, pc.glue_squeeze, pc.marks_visible])

	# ---- 塗裝
	var fn: FinishTool = ws.tools[6]
	fn.mode = 0
	for c in 2:
		fn.press(_hit(leg, 0.0))
		ws.advance_time(70.0)
	await _frames(5)

	for st in ws.workflow.steps:
		print("Step %-12s %s" % [st["id"], ws.workflow.check(st["id"])])
	print(ws.workflow.evaluate()["text"])
	await _shot("3_finished")
	ws.hud.show_result(ws.workflow.evaluate()["text"], "完成練習件")
	await _shot("4_result")
	await ws._on_finish_product()
	print("Bench cleared: ", ws.pieces.size(), " workflow null: ", ws.workflow == null)
	await _cutting_board_flow()
	get_tree().quit()

# ================================================================ 砧板 + 市集
func _plane_to(p: WoodPiece, target: float) -> void:
	var plane: PlaneTool = ws.tools[0]
	ws.tool_index = 0
	var dir := 1.0 if p.grain_runout > 0 else -1.0
	var half := p.length * 0.5 + 20.0
	var guard := 0
	while (p.mean_thickness() > target + 0.05 or p.flatness() > 0.25) and guard < 600:
		guard += 1
		plane.depth = 0.2 if p.mean_thickness() > target + 0.6 else 0.04
		if plane.sharpness < 0.6:
			plane.sharpness = 1.0   # 測試：直接磨好
		plane.press(_hit(p, -dir * half))
		var steps := int(half * 2.0 / 20.0)
		for k in steps:
			plane.motion(Vector2.ZERO, _hit(p, -dir * half + dir * 20.0 * (k + 1)))
		plane.release({})
	print("  planed %s T=%.2f flat=%.2f tear=%.2f strokes=%d" % [p.label_name, p.mean_thickness(), p.flatness(), p.max_tearout(), guard])

func _crosscut(p: WoodPiece, x: float) -> void:
	var mk: MarkingTool = ws.tools[1]
	mk.mode = 0
	ws.active_index = ws.pieces.find(p)
	mk.press(_hit(p, x))
	var saw: SawTool = ws.tools[2]
	saw.mode = 1
	saw.job_index = 0
	saw.press({})
	var n: int = ws.pieces.size()
	var guard := 0
	while ws.pieces.size() == n and guard < 3000:
		guard += 1
		saw.motion(Vector2(0, 35), {})
		saw.motion(Vector2(0, -35), {})
	print("  crosscut after %d strokes" % guard)
	await _frames()

func _longest() -> WoodPiece:
	var best: WoodPiece = null
	for p: WoodPiece in ws.pieces:
		if best == null or p.length > best.length:
			best = p
	return best

func _make_board(species: String, L: float, T: float) -> void:
	var uid := -1
	for it in Game.inventory:
		if it["species"] == species and it["size"] == "wide" and not it.has("piece"):
			uid = it["uid"]
	ws._on_start_work(uid, "cutting_board", {"length": L, "thickness": T})
	var p: WoodPiece = ws.active_piece()
	ws.advance_time(900.0)   # 讓料適應工坊濕度
	print("[%s] MC %.1f (emc %.1f) width %.1f" % [species, p.moisture, ws.emc, p.width])
	_plane_to(p, T)
	await _crosscut(p, -p.length * 0.5 + 12.0)          # 鋸齊左端
	var big := _longest()
	await _crosscut(big, -big.length * 0.5 + L + 0.3)   # 鋸到長度
	var cb: WoodPiece = ws.workflow.product_piece()
	ws.active_index = ws.pieces.find(cb)
	var sd: SandTool = ws.tools[4]
	for gi in [1, 2, 3]:
		sd.grit_index = gi
		sd.press(_hit(cb, 0.0))
		for k in 700:
			sd.motion(Vector2(40, 0), _hit(cb, 0.0))
		sd.release({})
	var fn: FinishTool = ws.tools[6]
	fn.mode = 0
	for c in 2:
		fn.press(_hit(cb, 0.0))
		ws.advance_time(35.0)
	for st in ws.workflow.steps:
		print("  step %-10s %s" % [st["id"], ws.workflow.check(st["id"])])
	var ev: Dictionary = ws.workflow.evaluate()
	print("  score %.0f  product: %s" % [ev["score"], ev["product"]["name"]])
	await ws._on_finish_product()

func _cutting_board_flow() -> void:
	print("--- cutting boards ---")
	await _make_board("white_pine", 300.0, 20.0)
	await _make_board("hinoki", 300.0, 20.0)
	print("Products: ", Game.products.size(), "  inventory: ", Game.inventory.size(), "  photo exists: ", FileAccess.file_exists(Game.products[0]["photo"]))
	# 交張阿姨的訂單（松木）
	var o: Dictionary = Game.orders[0]
	Game.accept_order(o)
	var pine_p: Dictionary = Game.products[0]
	print("Order mismatch: '%s'" % Game.order_mismatch(o, pine_p))
	if Game.order_mismatch(o, pine_p) == "":
		Game.deliver_order(o, pine_p)
	# 檜木砧板用建議價上架
	var hp: Dictionary = Game.products[1]
	Game.set_listed(hp, true, Game.suggested_price(hp))
	print("Listed hinoki at NT$ %d (ref %.0f)" % [hp["price"], Game.reference_price(hp)])
	ws.hud.computer.visible = true
	await _frames(3)
	await _shot("5_market")
	ws.hud.computer.tabs.current_tab = 1
	await _shot("6_orders")
	ws.hud.computer.tabs.current_tab = 2
	await _shot("7_lumber")
	ws.hud.computer.visible = false
	# 模擬一週
	var money0 := Game.money
	for d in 7:
		ws.advance_time(1440.0)
	print("After a week: day %d money %d -> %d, status %s, reviews %d, rep %.1f, orders %d" % [Game.day, money0, Game.money, hp["status"], Game.reviews.size(), Game.reputation, Game.orders.size()])
	for rv in Game.reviews:
		print("  review ", rv["stars"], "★ ", rv["client"], ": ", rv["text"])
	print("Buy walnut wide: ", Game.buy_board("black_walnut", "kiln", "wide"), " money ", Game.money)
	ws.save_all()
	var m := Game.money
	Game.money = 0
	Game.load_game()
	print("Save/load money ok: ", Game.money == m)
	ws.hud.computer.visible = true
	ws.hud.computer.tabs.current_tab = 3
	await _shot("8_reviews")
	ws.hud.computer.tabs.current_tab = 1
	await _shot("9_orders_new")
	ws.hud.computer.visible = false
	ws.hud.rack.visible = true
	await _shot("10_rack")
