extends SceneTree
## 把程序化音效匯出成 WAV 試聽：godot --headless --script res://tests/export_sfx.gd
## 輸出到 user:// 或環境變數 SFX_OUT 指定的資料夾

func _initialize() -> void:
	var out := OS.get_environment("SFX_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("user://sfx_preview")
	DirAccess.make_dir_recursive_absolute(out)
	var e := SoundEngine.new()
	var shots := {
		"mallet_pine": ["mallet", {"force": 0.9, "hardness": 0.42}],
		"mallet_oak": ["mallet", {"force": 0.9, "hardness": 1.5}],
		"mallet_oak_deep": ["mallet", {"force": 0.9, "hardness": 1.5, "depth": 18.0}],
		"crack": ["crack", {}], "chatter": ["chatter", {}], "saw_jump": ["saw_jump", {}],
		"clunk": ["clunk", {"hardness": 1.0}], "offcut": ["offcut", {"hardness": 1.0}], "clamp": ["clamp", {}],
		"squeeze": ["squeeze", {}], "wipe": ["wipe", {}], "scribe": ["scribe", {}], "pare": ["pare", {}],
		"lever": ["lever", {}], "sweep": ["sweep", {}], "pickup": ["pickup", {}],
	}
	for k in shots:
		e.synth_stream(shots[k][0], shots[k][1]).save_to_wav(out.path_join(k + ".wav"))
	# 連續聲：三次推拉
	var strokes := func(call: Callable, back: Callable) -> Array:
		var a := []
		for i in 3:
			a.append({"dur": 0.55, "call": call})
			a.append({"dur": 0.45, "call": back})
		return a
	var silent := func(): e.drive(0.0, {})
	e.render_offline(strokes.call(func(): e.plane(0.8, 1.0, 0.0), silent)).save_to_wav(out.path_join("plane_sharp.wav"))
	e.render_offline(strokes.call(func(): e.plane(0.8, 0.3, 3.0), silent)).save_to_wav(out.path_join("plane_dull_tearout.wav"))
	e.render_offline(strokes.call(func(): e.saw(0.9, 35.0, false, 1.0, true), func(): e.saw(0.6, 35.0, false, 1.0, false))).save_to_wav(out.path_join("saw_crosscut.wav"))
	e.render_offline(strokes.call(func(): e.saw(0.9, 35.0, true, 0.35, true), func(): e.saw(0.6, 35.0, true, 0.35, false))).save_to_wav(out.path_join("saw_wrong_teeth.wav"))
	e.render_offline(strokes.call(func(): e.sand(0.8, 80), func(): e.sand(0.8, 80))).save_to_wav(out.path_join("sand_80.wav"))
	e.render_offline(strokes.call(func(): e.sand(0.8, 320), func(): e.sand(0.8, 320))).save_to_wav(out.path_join("sand_320.wav"))
	e.render_offline(strokes.call(func(): e.stone(0.8, 1000), func(): e.stone(0.8, 1000))).save_to_wav(out.path_join("stone_1000.wav"))
	print("exported to ", out)
	e.free()
	quit()
