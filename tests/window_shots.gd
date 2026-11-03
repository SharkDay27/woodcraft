extends Node
## 窗外日夜截圖：SHOT_DIR=... godot --rendering-method gl_compatibility res://tests/window_shots.tscn
func _ready() -> void:
	var ws = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(ws)
	_run.call_deferred(ws)

func _run(ws) -> void:
	for i in 3: await get_tree().process_frame
	ws.hud.select_panel.visible = false
	ws._yaw = 0.0
	ws._pitch = -0.05
	ws.cam.position = Vector3(0, 1.3, 0.9)
	ws._apply_cam()
	for t in [["07_morning", 7.2], ["12_noon", 12.0], ["18_sunset", 17.9], ["22_night", 22.0 + 24.0 * 7]]:
		ws.game_minutes = t[1] * 60.0
		for i in 10: await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("win_" + t[0] + ".png"))
	# 白天陽光照在工作台
	ws.game_minutes = 10.0 * 60.0
	ws._pitch = -0.88
	ws.cam.position = Vector3(0, 1.10, 0.36)
	ws._apply_cam()
	for i in 10: await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("win_bench_10am.png"))
	get_tree().quit()
