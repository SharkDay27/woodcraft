extends Node
## 工具 3D 模型截圖：SHOT_DIR=... godot --rendering-method gl_compatibility res://tests/tool_shots.tscn
var ws
func _ready() -> void:
	ws = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(ws)
	_run.call_deferred()

func _f(n := 8) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await _f(25)
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("tool_" + name + ".png"))

func _run() -> void:
	await _f(3)
	Game.new_game()
	ws.game_minutes = 10.0 * 60.0
	ws._begin_session()
	ws._on_start_work(Game.inventory[0]["uid"], "cutting_board", {"length": 300.0, "thickness": 20.0})
	var p: WoodPiece = ws.active_piece()
	ws.cam.position = Vector3(0.30, 1.08, 0.42)
	await _f(3)
	ws.cam.look_at(Vector3(0.06, 0.88, 0.0), Vector3.UP)
	ws._target_fov = 50.0
	var T := p.mean_thickness()
	ws.debug_hit = {"on_piece": true, "local": Vector3(60, T / 2, 10), "top": Vector3(60, T / 2, 0)}
	# 手刨（刨削中）
	ws.tool_index = 0
	ws.tools[0].pressed = true
	await _shot("plane")
	ws.tools[0].pressed = false
	# 劃線
	ws.tool_index = 1
	await _shot("marking")
	# 鋸（鋸到一半）
	var mk: MarkingTool = ws.tools[1]
	mk.mode = 0
	mk.press(ws.debug_hit)
	p.cut_jobs[0]["progress"] = 9.0
	p.mark_dirty()
	ws.tool_index = 2
	ws.tools[2].pressed = true
	ws.tools[2].anim = Vector2(0, 30)
	await _shot("saw")
	ws.tools[2].pressed = false
	# 鑿子 + 木槌（蓄力）
	ws.tool_index = 3
	var ch: ChiselTool = ws.tools[3]
	ch.pressed = true
	ch.force = 0.8
	await _shot("chisel")
	ch.pressed = false
	# 砂紙
	ws.tool_index = 4
	await _shot("sand")
	# 膠（擠膠）
	ws.tool_index = 5
	ws.tools[5].pressed = true
	await _shot("glue")
	ws.tools[5].pressed = false
	# 塗裝
	ws.tool_index = 6
	await _shot("finish")
	# 磨刀石（手上）
	ws.tool_index = 7
	await _shot("whetstone")
	# 游標不在木料上：拿在手上
	ws.debug_hit = {"on_piece": false, "local": Vector3.ZERO, "top": Vector3(900, 0, 0)}
	ws.tool_index = 2
	await _shot("saw_hand")
	get_tree().quit()
